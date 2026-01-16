# Fitbit Plugin Examples

This directory contains example applications demonstrating how to use the Fitbit plugin with HealthSync SDK.

## Examples

### 1. `fitbit-example.ts` - Complete Integration Example

A full-featured Express.js application demonstrating:
- OAuth 2.0 authentication with PKCE
- Multiple data type fetching (steps, heart rate, sleep, weight)
- Error handling and rate limit management
- Token storage and refresh
- Web interface for easy testing

## Running the Example

### Prerequisites

1. **Create a Fitbit Application**
   - Go to https://dev.fitbit.com/apps
   - Click "Register a new app"
   - Fill in the details:
     - Application Name: `HealthSync Example`
     - Description: `Testing HealthSync SDK`
     - Application Website: `http://localhost:3000`
     - Organization: Your name/organization
     - OAuth 2.0 Application Type: `Server`
     - Callback URL: `http://localhost:3000/auth/fitbit/callback`
     - Default Access Type: `Read-Only`
   - Save and note your Client ID and Client Secret

2. **Set Environment Variables**

   **Windows (Command Prompt):**
   ```cmd
   set FITBIT_CLIENT_ID=your_client_id_here
   set FITBIT_CLIENT_SECRET=your_client_secret_here
   set FITBIT_REDIRECT_URI=http://localhost:3000/auth/fitbit/callback
   ```

   **Windows (PowerShell):**
   ```powershell
   $env:FITBIT_CLIENT_ID="your_client_id_here"
   $env:FITBIT_CLIENT_SECRET="your_client_secret_here"
   $env:FITBIT_REDIRECT_URI="http://localhost:3000/auth/fitbit/callback"
   ```

   **Linux/Mac:**
   ```bash
   export FITBIT_CLIENT_ID=your_client_id_here
   export FITBIT_CLIENT_SECRET=your_client_secret_here
   export FITBIT_REDIRECT_URI=http://localhost:3000/auth/fitbit/callback
   ```

### Installation

```bash
# Navigate to examples directory
cd examples

# Install dependencies
npm install
```

### Run the Example

```bash
# Start the server
npm start

# Or use nodemon for development (auto-restart on changes)
npm run dev
```

### Using the Example Application

1. **Start the server** (see above)
2. **Open your browser** and navigate to http://localhost:3000
3. **Click "Connect to Fitbit"** - you'll be redirected to Fitbit's authorization page
4. **Authorize the application** - grant the requested permissions
5. **You'll be redirected back** to the example app
6. **Fetch your data** - click any of the data buttons:
   - 📊 Get Steps
   - ❤️ Get Heart Rate
   - 😴 Get Sleep
   - ⚖️ Get Weight
   - 📈 Get All Data

## Available API Endpoints

### Authentication
- `GET /` - Home page with UI
- `GET /auth/fitbit` - Start OAuth flow
- `GET /auth/fitbit/callback` - OAuth callback handler
- `GET /disconnect` - Disconnect from Fitbit

### Data Fetching
- `GET /data/steps` - Fetch last 7 days of steps
- `GET /data/heart-rate` - Fetch last 7 days of heart rate
- `GET /data/sleep` - Fetch last 7 days of sleep
- `GET /data/weight` - Fetch last 30 days of weight
- `GET /data/all` - Fetch all available data

### Utilities
- `GET /rate-limit` - Check current rate limit status

## Example Response Formats

### Steps Data
```json
{
  "success": true,
  "count": 7,
  "data": [
    {
      "date": "2026-01-01T00:00:00.000Z",
      "steps": 10523,
      "source": "FITBIT"
    }
  ]
}
```

### Heart Rate Data
```json
{
  "success": true,
  "count": 7,
  "data": [
    {
      "timestamp": "2026-01-01T00:00:00.000Z",
      "heartRate": 72,
      "type": "fitbit-resting-heart-rate",
      "source": "FITBIT"
    }
  ]
}
```

### Sleep Data
```json
{
  "success": true,
  "count": 7,
  "data": [
    {
      "date": "2026-01-01T23:15:00.000Z",
      "endDate": "2026-01-02T07:30:00.000Z",
      "duration": 29700000,
      "efficiency": 92,
      "minutesAsleep": 455,
      "stages": {
        "deep": 120,
        "light": 240,
        "rem": 95,
        "wake": 20
      },
      "source": "FITBIT"
    }
  ]
}
```

### Rate Limit Status
```json
{
  "success": true,
  "rateLimit": {
    "requestsRemaining": 142,
    "requestsLimit": 150,
    "resetTime": "2026-01-07T15:00:00.000Z"
  }
}
```

## Code Examples from the App

### 1. Initialize Plugin

```typescript
import { FitbitPlugin } from '@healthsync/plugin-fitbit';
import { InMemoryTokenStorage } from '@healthsync/plugin-fitbit';

const tokenStorage = new InMemoryTokenStorage();

const fitbitPlugin = new FitbitPlugin({
  clientId: process.env.FITBIT_CLIENT_ID!,
  clientSecret: process.env.FITBIT_CLIENT_SECRET!,
  redirectUri: 'http://localhost:3000/auth/fitbit/callback',
  scopes: ['activity', 'heartrate', 'sleep', 'weight'],
  tokenStorage,
  autoRefreshToken: true,
});
```

### 2. Start OAuth Flow

```typescript
const result = await fitbitPlugin.connect();

if (result.status === ConnectionStatus.PENDING) {
  const authUrl = result.metadata?.custom?.authorizationUrl;
  const verifier = result.metadata?.custom?.verifier;

  // Redirect user to authUrl
  // Store verifier for callback
}
```

### 3. Complete Authorization

```typescript
const result = await fitbitPlugin.completeAuthorization(code, verifier);

if (result.status === ConnectionStatus.CONNECTED) {
  console.log('Successfully connected!');
}
```

### 4. Fetch Data

```typescript
const data = await fitbitPlugin.fetchData({
  dataType: DataType.STEPS,
  startDate: new Date('2026-01-01').toISOString(),
  endDate: new Date().toISOString(),
});
```

### 5. Handle Errors

```typescript
try {
  const data = await fitbitPlugin.fetchData({...});
} catch (error: any) {
  if (error.type === 'RATE_LIMIT_ERROR') {
    console.log(`Rate limit exceeded. Retry after ${error.retryAfter}s`);
  } else if (error.type === 'AUTHENTICATION_ERROR') {
    console.log('Token expired - need to re-authorize');
  }
}
```

## Troubleshooting

### "Missing required environment variables"

**Problem**: You didn't set the FITBIT_CLIENT_ID or FITBIT_CLIENT_SECRET

**Solution**: Set the environment variables before running (see "Set Environment Variables" above)

### "Invalid redirect_uri"

**Problem**: The redirect URI doesn't match the one configured in your Fitbit app

**Solution**: Ensure the redirect URI in your Fitbit app settings matches exactly: `http://localhost:3000/auth/fitbit/callback`

### "Invalid state parameter"

**Problem**: CSRF protection detected an issue, or you refreshed the callback page

**Solution**: Start the OAuth flow again from the beginning

### "Rate limit exceeded"

**Problem**: You've made more than 150 requests in the current hour

**Solution**: Wait for the rate limit to reset (top of next hour) or check `/rate-limit` endpoint

## Custom Token Storage

The example uses `InMemoryTokenStorage` which is suitable for testing but not production. For production, implement your own `TokenStorage`:

```typescript
import { TokenStorage, FitbitCredentials } from '@healthsync/plugin-fitbit';

class DatabaseTokenStorage implements TokenStorage {
  async saveCredentials(userId: string, credentials: FitbitCredentials): Promise<void> {
    await db.tokens.upsert({ userId, credentials });
  }

  async getCredentials(userId: string): Promise<FitbitCredentials | null> {
    return await db.tokens.findOne({ userId });
  }

  async deleteCredentials(userId: string): Promise<void> {
    await db.tokens.delete({ userId });
  }

  async hasCredentials(userId: string): Promise<boolean> {
    return await db.tokens.exists({ userId });
  }
}

// Use it
const plugin = new FitbitPlugin({
  clientId: '...',
  clientSecret: '...',
  redirectUri: '...',
  tokenStorage: new DatabaseTokenStorage(),
});
```

## Security Notes

1. **Never commit credentials** - Use environment variables
2. **Use HTTPS in production** - Required for OAuth 2.0
3. **Implement proper session management** - Don't use in-memory storage in production
4. **Validate state parameter** - Protects against CSRF attacks
5. **Store tokens securely** - Encrypt in database
6. **Use secure cookies** - For session management

## Next Steps

- Add user authentication to associate Fitbit data with app users
- Implement persistent token storage (database)
- Add webhook support for real-time data updates
- Build a dashboard to visualize the fetched data
- Add more data types (nutrition, body composition, etc.)

## Resources

- [Fitbit Web API Documentation](https://dev.fitbit.com/build/reference/web-api/)
- [OAuth 2.0 Guide](https://dev.fitbit.com/build/reference/web-api/authorization/)
- [HealthSync Core Documentation](../../packages/core/README.md)
