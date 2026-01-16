/**
 * Fitbit Plugin Example
 *
 * This example demonstrates how to use the Fitbit plugin with HealthSync SDK
 * including OAuth 2.0 authentication, data fetching, and error handling.
 *
 * Prerequisites:
 * 1. Create a Fitbit app at https://dev.fitbit.com/apps
 * 2. Set environment variables:
 *    - FITBIT_CLIENT_ID
 *    - FITBIT_CLIENT_SECRET
 *    - FITBIT_REDIRECT_URI
 */

import express from 'express';
import { FitbitPlugin } from '../src/fitbit-plugin';
import { InMemoryTokenStorage } from '../src/fitbit-auth';
import { DataType, ConnectionStatus } from '@healthsync/core';

// ============================================================================
// Configuration
// ============================================================================

const PORT = 3000;
const config = {
  clientId: process.env.FITBIT_CLIENT_ID!,
  clientSecret: process.env.FITBIT_CLIENT_SECRET!,
  redirectUri: process.env.FITBIT_REDIRECT_URI || `http://localhost:${PORT}/auth/fitbit/callback`,
};

// Validate configuration
if (!config.clientId || !config.clientSecret) {
  console.error('❌ Missing required environment variables:');
  console.error('   - FITBIT_CLIENT_ID');
  console.error('   - FITBIT_CLIENT_SECRET');
  process.exit(1);
}

// ============================================================================
// Initialize Plugin
// ============================================================================

// Create token storage (in production, use persistent storage like database)
const tokenStorage = new InMemoryTokenStorage();

// Initialize Fitbit plugin
const fitbitPlugin = new FitbitPlugin({
  clientId: config.clientId,
  clientSecret: config.clientSecret,
  redirectUri: config.redirectUri,
  scopes: [
    'activity',
    'heartrate',
    'sleep',
    'weight',
    'nutrition',
    'oxygen_saturation',
    'respiratory_rate',
    'temperature',
  ],
  tokenStorage,
  autoRefreshToken: true, // Automatically refresh expired tokens
  logger: console, // Use console for logging
});

// ============================================================================
// Express Server
// ============================================================================

const app = express();

// Store PKCE verifier temporarily (in production, use session storage)
const verifierStore = new Map<string, string>();

// ============================================================================
// Route: Home Page
// ============================================================================

app.get('/', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html>
      <head>
        <title>Fitbit Plugin Example</title>
        <style>
          body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
          }
          h1 { color: #00B0B9; }
          .button {
            display: inline-block;
            padding: 12px 24px;
            background: #00B0B9;
            color: white;
            text-decoration: none;
            border-radius: 4px;
            margin: 10px 5px;
          }
          .button:hover {
            background: #009aa3;
          }
          .status {
            padding: 10px;
            margin: 20px 0;
            border-radius: 4px;
            background: #f0f0f0;
          }
          code {
            background: #f4f4f4;
            padding: 2px 6px;
            border-radius: 3px;
          }
        </style>
      </head>
      <body>
        <h1>🏃 Fitbit Plugin Example</h1>

        <div class="status">
          <strong>Plugin Status:</strong> ${
            fitbitPlugin.getConnectionStatus() === ConnectionStatus.CONNECTED
              ? '✅ Connected'
              : '⚠️ Not Connected'
          }
        </div>

        <h2>Getting Started</h2>
        <ol>
          <li>Click "Connect to Fitbit" below</li>
          <li>Authorize the application on Fitbit</li>
          <li>You'll be redirected back here</li>
          <li>Start fetching your health data!</li>
        </ol>

        <a href="/auth/fitbit" class="button">🔐 Connect to Fitbit</a>

        ${
          fitbitPlugin.getConnectionStatus() === ConnectionStatus.CONNECTED
            ? `
          <h2>Fetch Data</h2>
          <a href="/data/steps" class="button">📊 Get Steps</a>
          <a href="/data/heart-rate" class="button">❤️ Get Heart Rate</a>
          <a href="/data/sleep" class="button">😴 Get Sleep</a>
          <a href="/data/weight" class="button">⚖️ Get Weight</a>
          <a href="/data/all" class="button">📈 Get All Data</a>

          <h2>Utilities</h2>
          <a href="/rate-limit" class="button">📊 Rate Limit Status</a>
          <a href="/disconnect" class="button">🔓 Disconnect</a>
        `
            : ''
        }

        <h2>API Endpoints</h2>
        <ul>
          <li><code>GET /auth/fitbit</code> - Start OAuth flow</li>
          <li><code>GET /auth/fitbit/callback</code> - OAuth callback</li>
          <li><code>GET /data/steps</code> - Fetch steps data</li>
          <li><code>GET /data/heart-rate</code> - Fetch heart rate data</li>
          <li><code>GET /data/sleep</code> - Fetch sleep data</li>
          <li><code>GET /data/weight</code> - Fetch weight data</li>
          <li><code>GET /data/all</code> - Fetch all available data</li>
          <li><code>GET /rate-limit</code> - Check rate limit status</li>
          <li><code>GET /disconnect</code> - Disconnect from Fitbit</li>
        </ul>
      </body>
    </html>
  `);
});

// ============================================================================
// Route: Start OAuth Flow
// ============================================================================

app.get('/auth/fitbit', async (req, res) => {
  try {
    console.log('🔐 Starting Fitbit OAuth flow...');

    // Connect (this will return authorization URL if not connected)
    const result = await fitbitPlugin.connect();

    if (result.status === ConnectionStatus.PENDING && result.metadata?.custom?.authorizationUrl) {
      const authUrl = result.metadata.custom.authorizationUrl as string;
      const verifier = result.metadata.custom.verifier as string;

      // Store verifier for callback (use session storage in production)
      const state = Math.random().toString(36).substring(7);
      verifierStore.set(state, verifier);

      // Add state parameter to URL
      const authUrlWithState = `${authUrl}&state=${state}`;

      console.log('📍 Redirecting to Fitbit authorization page...');
      res.redirect(authUrlWithState);
    } else if (result.status === ConnectionStatus.CONNECTED) {
      console.log('✅ Already connected to Fitbit');
      res.redirect('/?message=already-connected');
    } else {
      throw new Error('Unexpected connection result');
    }
  } catch (error) {
    console.error('❌ OAuth flow error:', error);
    res.status(500).send(`
      <h1>Authentication Error</h1>
      <p>${error instanceof Error ? error.message : 'Unknown error'}</p>
      <a href="/">← Back to Home</a>
    `);
  }
});

// ============================================================================
// Route: OAuth Callback
// ============================================================================

app.get('/auth/fitbit/callback', async (req, res) => {
  try {
    const { code, state, error } = req.query;

    // Check for OAuth errors
    if (error) {
      throw new Error(`OAuth error: ${error}`);
    }

    // Validate required parameters
    if (!code || typeof code !== 'string') {
      throw new Error('Missing authorization code');
    }

    if (!state || typeof state !== 'string') {
      throw new Error('Missing state parameter');
    }

    // Retrieve verifier from storage
    const verifier = verifierStore.get(state);
    if (!verifier) {
      throw new Error('Invalid state parameter (possible CSRF attack)');
    }

    // Clean up verifier
    verifierStore.delete(state);

    console.log('🔄 Exchanging authorization code for tokens...');

    // Complete authorization
    const result = await fitbitPlugin.completeAuthorization(code, verifier);

    if (result.status === ConnectionStatus.CONNECTED) {
      console.log('✅ Successfully connected to Fitbit!');
      res.redirect('/?message=connected');
    } else {
      throw new Error('Failed to complete authorization');
    }
  } catch (error) {
    console.error('❌ OAuth callback error:', error);
    res.status(500).send(`
      <h1>Authentication Failed</h1>
      <p>${error instanceof Error ? error.message : 'Unknown error'}</p>
      <a href="/">← Back to Home</a>
    `);
  }
});

// ============================================================================
// Route: Disconnect
// ============================================================================

app.get('/disconnect', async (req, res) => {
  try {
    console.log('🔓 Disconnecting from Fitbit...');
    await fitbitPlugin.disconnect();
    console.log('✅ Disconnected successfully');
    res.redirect('/?message=disconnected');
  } catch (error) {
    console.error('❌ Disconnect error:', error);
    res.status(500).send(`
      <h1>Disconnect Error</h1>
      <p>${error instanceof Error ? error.message : 'Unknown error'}</p>
      <a href="/">← Back to Home</a>
    `);
  }
});

// ============================================================================
// Route: Fetch Steps Data
// ============================================================================

app.get('/data/steps', async (req, res) => {
  try {
    // Check connection
    if (fitbitPlugin.getConnectionStatus() !== ConnectionStatus.CONNECTED) {
      return res.redirect('/?message=not-connected');
    }

    console.log('📊 Fetching steps data...');

    // Fetch last 7 days of steps
    const endDate = new Date();
    const startDate = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);

    const data = await fitbitPlugin.fetchData({
      dataType: DataType.STEPS,
      startDate: startDate.toISOString(),
      endDate: endDate.toISOString(),
    });

    console.log(`✅ Retrieved ${data.length} steps records`);

    res.json({
      success: true,
      count: data.length,
      data: data.map(d => ({
        date: d.timestamp,
        steps: d.raw.steps,
        source: d.source,
      })),
    });
  } catch (error) {
    console.error('❌ Steps fetch error:', error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

// ============================================================================
// Route: Fetch Heart Rate Data
// ============================================================================

app.get('/data/heart-rate', async (req, res) => {
  try {
    if (fitbitPlugin.getConnectionStatus() !== ConnectionStatus.CONNECTED) {
      return res.redirect('/?message=not-connected');
    }

    console.log('❤️ Fetching heart rate data...');

    const endDate = new Date();
    const startDate = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);

    const data = await fitbitPlugin.fetchData({
      dataType: DataType.HEART_RATE,
      startDate: startDate.toISOString(),
      endDate: endDate.toISOString(),
    });

    console.log(`✅ Retrieved ${data.length} heart rate records`);

    res.json({
      success: true,
      count: data.length,
      data: data.map(d => ({
        timestamp: d.timestamp,
        heartRate: d.raw.heartRate || d.raw.restingHeartRate,
        type: d.sourceDataType,
        source: d.source,
      })),
    });
  } catch (error) {
    console.error('❌ Heart rate fetch error:', error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

// ============================================================================
// Route: Fetch Sleep Data
// ============================================================================

app.get('/data/sleep', async (req, res) => {
  try {
    if (fitbitPlugin.getConnectionStatus() !== ConnectionStatus.CONNECTED) {
      return res.redirect('/?message=not-connected');
    }

    console.log('😴 Fetching sleep data...');

    const endDate = new Date();
    const startDate = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);

    const data = await fitbitPlugin.fetchData({
      dataType: DataType.SLEEP,
      startDate: startDate.toISOString(),
      endDate: endDate.toISOString(),
    });

    console.log(`✅ Retrieved ${data.length} sleep records`);

    res.json({
      success: true,
      count: data.length,
      data: data.map(d => ({
        date: d.timestamp,
        endDate: d.endTimestamp,
        duration: d.raw.duration,
        efficiency: d.raw.efficiency,
        minutesAsleep: d.raw.minutesAsleep,
        stages: d.raw.stages,
        source: d.source,
      })),
    });
  } catch (error) {
    console.error('❌ Sleep fetch error:', error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

// ============================================================================
// Route: Fetch Weight Data
// ============================================================================

app.get('/data/weight', async (req, res) => {
  try {
    if (fitbitPlugin.getConnectionStatus() !== ConnectionStatus.CONNECTED) {
      return res.redirect('/?message=not-connected');
    }

    console.log('⚖️ Fetching weight data...');

    const endDate = new Date();
    const startDate = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000); // Last 30 days

    const data = await fitbitPlugin.fetchData({
      dataType: DataType.WEIGHT,
      startDate: startDate.toISOString(),
      endDate: endDate.toISOString(),
    });

    console.log(`✅ Retrieved ${data.length} weight records`);

    res.json({
      success: true,
      count: data.length,
      data: data.map(d => ({
        timestamp: d.timestamp,
        weight: d.raw.weight,
        bmi: d.raw.bmi,
        fat: d.raw.fat,
        source: d.source,
      })),
    });
  } catch (error) {
    console.error('❌ Weight fetch error:', error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

// ============================================================================
// Route: Fetch All Data
// ============================================================================

app.get('/data/all', async (req, res) => {
  try {
    if (fitbitPlugin.getConnectionStatus() !== ConnectionStatus.CONNECTED) {
      return res.redirect('/?message=not-connected');
    }

    console.log('📈 Fetching all available data...');

    const endDate = new Date();
    const startDate = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);

    // Fetch multiple data types in parallel
    const [steps, heartRate, sleep, weight] = await Promise.all([
      fitbitPlugin.fetchData({
        dataType: DataType.STEPS,
        startDate: startDate.toISOString(),
        endDate: endDate.toISOString(),
      }),
      fitbitPlugin.fetchData({
        dataType: DataType.HEART_RATE,
        startDate: startDate.toISOString(),
        endDate: endDate.toISOString(),
      }),
      fitbitPlugin.fetchData({
        dataType: DataType.SLEEP,
        startDate: startDate.toISOString(),
        endDate: endDate.toISOString(),
      }),
      fitbitPlugin.fetchData({
        dataType: DataType.WEIGHT,
        startDate: startDate.toISOString(),
        endDate: endDate.toISOString(),
      }),
    ]);

    console.log('✅ Retrieved all data successfully');

    res.json({
      success: true,
      summary: {
        steps: steps.length,
        heartRate: heartRate.length,
        sleep: sleep.length,
        weight: weight.length,
        total: steps.length + heartRate.length + sleep.length + weight.length,
      },
      data: {
        steps: steps.slice(0, 5), // Sample
        heartRate: heartRate.slice(0, 5),
        sleep: sleep.slice(0, 5),
        weight: weight.slice(0, 5),
      },
    });
  } catch (error) {
    console.error('❌ Fetch all data error:', error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

// ============================================================================
// Route: Check Rate Limit Status
// ============================================================================

app.get('/rate-limit', async (req, res) => {
  try {
    const rateLimitStatus = await fitbitPlugin.getRateLimitStatus();

    res.json({
      success: true,
      rateLimit: rateLimitStatus,
    });
  } catch (error) {
    console.error('❌ Rate limit check error:', error);
    res.status(500).json({
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

// ============================================================================
// Start Server
// ============================================================================

app.listen(PORT, () => {
  console.log('');
  console.log('🚀 Fitbit Plugin Example Server Started');
  console.log('========================================');
  console.log(`📍 URL: http://localhost:${PORT}`);
  console.log(`🔧 Client ID: ${config.clientId.substring(0, 10)}...`);
  console.log(`🔗 Redirect URI: ${config.redirectUri}`);
  console.log('');
  console.log('💡 Open your browser and navigate to the URL above to get started!');
  console.log('');
});

// ============================================================================
// Error Handling Examples
// ============================================================================

/**
 * Example: Handling Authentication Errors
 */
async function handleAuthErrorExample() {
  try {
    await fitbitPlugin.connect();
  } catch (error: any) {
    if (error.type === 'AUTHENTICATION_ERROR') {
      console.log('Authentication failed - need to re-authorize');
      // Redirect user to authorization flow
    } else if (error.type === 'TOKEN_EXPIRED') {
      console.log('Token expired - refreshing...');
      // Plugin will automatically refresh if autoRefreshToken is true
      await fitbitPlugin.refreshAuth();
    }
  }
}

/**
 * Example: Handling Rate Limit Errors
 */
async function handleRateLimitExample() {
  try {
    const data = await fitbitPlugin.fetchData({
      dataType: DataType.STEPS,
      startDate: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString(),
      endDate: new Date().toISOString(),
    });
  } catch (error: any) {
    if (error.type === 'RATE_LIMIT_ERROR') {
      console.log(`Rate limit exceeded. Retry after: ${error.retryAfter} seconds`);

      // Option 1: Wait and retry
      await new Promise(resolve => setTimeout(resolve, error.retryAfter * 1000));
      // Retry request...

      // Option 2: Queue request for later
      // queueManager.enqueue(request);
    }
  }
}

/**
 * Example: Custom Token Storage
 */
class DatabaseTokenStorage {
  async saveCredentials(userId: string, credentials: any): Promise<void> {
    // Save to database
    console.log('Saving credentials to database...');
    // await db.tokens.upsert({ userId, credentials });
  }

  async getCredentials(userId: string): Promise<any | null> {
    // Retrieve from database
    console.log('Loading credentials from database...');
    // return await db.tokens.findOne({ userId });
    return null;
  }

  async deleteCredentials(userId: string): Promise<void> {
    // Delete from database
    console.log('Deleting credentials from database...');
    // await db.tokens.delete({ userId });
  }

  async hasCredentials(userId: string): Promise<boolean> {
    // Check if credentials exist
    // return await db.tokens.exists({ userId });
    return false;
  }
}

/**
 * Example: Using Custom Token Storage
 */
async function customStorageExample() {
  const dbStorage = new DatabaseTokenStorage();

  const plugin = new FitbitPlugin({
    clientId: config.clientId,
    clientSecret: config.clientSecret,
    redirectUri: config.redirectUri,
    tokenStorage: dbStorage,
  });

  // Tokens will now be stored in your database
  await plugin.connect();
}
