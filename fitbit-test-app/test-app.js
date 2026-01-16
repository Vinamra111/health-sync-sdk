/**
 * Fitbit Plugin Test App
 *
 * This test application demonstrates the Fitbit plugin functionality
 * for the HealthSync SDK.
 */

import { FitbitPlugin } from '../plugins/fitbit/dist/index.js';
import { DataType, ConnectionStatus } from '../packages/core/dist/index.js';

// ============================================================================
// Configuration
// ============================================================================

const config = {
  clientId: 'YOUR_FITBIT_CLIENT_ID',
  clientSecret: 'YOUR_FITBIT_CLIENT_SECRET',
  redirectUri: 'http://localhost:3000/callback',
};

// Check for config in localStorage (for persistence)
const savedConfig = localStorage.getItem('fitbitConfig');
if (savedConfig) {
  Object.assign(config, JSON.parse(savedConfig));
}

// ============================================================================
// Global State
// ============================================================================

let fitbitPlugin = null;
let isConnected = false;
let fetchedData = [];

// ============================================================================
// DOM Elements
// ============================================================================

const elements = {
  // Status
  statusDot: document.getElementById('statusDot'),
  statusTitle: document.getElementById('statusTitle'),
  statusMessage: document.getElementById('statusMessage'),
  pluginStatus: document.getElementById('pluginStatus'),
  alertContainer: document.getElementById('alertContainer'),

  // Buttons
  btnConnect: document.getElementById('btnConnect'),
  btnDisconnect: document.getElementById('btnDisconnect'),
  btnCheckConnection: document.getElementById('btnCheckConnection'),
  btnFetchSteps: document.getElementById('btnFetchSteps'),
  btnFetchHeartRate: document.getElementById('btnFetchHeartRate'),
  btnFetchSleep: document.getElementById('btnFetchSleep'),
  btnFetchWeight: document.getElementById('btnFetchWeight'),
  btnFetchAll: document.getElementById('btnFetchAll'),
  btnCheckRateLimit: document.getElementById('btnCheckRateLimit'),

  // Rate Limit
  rateLimitRemaining: document.getElementById('rateLimitRemaining'),
  rateLimitTotal: document.getElementById('rateLimitTotal'),
  rateLimitReset: document.getElementById('rateLimitReset'),
  rateLimitBar: document.getElementById('rateLimitBar'),

  // Data
  totalRecords: document.getElementById('totalRecords'),
  dataContainer: document.getElementById('dataContainer'),
};

// ============================================================================
// Initialization
// ============================================================================

async function initialize() {
  showInfo('Initializing Fitbit plugin...');

  try {
    // Initialize plugin
    fitbitPlugin = new FitbitPlugin({
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
      autoRefreshToken: true,
      logger: console,
    });

    await fitbitPlugin.initialize();

    updateStatus('initialized', 'Plugin Initialized', 'Ready to connect to Fitbit');
    elements.pluginStatus.textContent = 'Initialized';

    showSuccess('Fitbit plugin initialized successfully!');

    // Check if we have saved tokens
    const connectionStatus = fitbitPlugin.getConnectionStatus();
    if (connectionStatus === ConnectionStatus.CONNECTED) {
      handleConnected();
    }

    // Handle OAuth callback if we're on the callback URL
    handleOAuthCallback();
  } catch (error) {
    console.error('Initialization error:', error);
    showError(`Initialization failed: ${error.message}`);
    updateStatus('disconnected', 'Initialization Failed', error.message);
  }
}

// ============================================================================
// OAuth Flow
// ============================================================================

async function connectToFitbit() {
  if (!fitbitPlugin) {
    showError('Plugin not initialized');
    return;
  }

  setButtonLoading(elements.btnConnect, true);
  showInfo('Starting OAuth flow...');

  try {
    const result = await fitbitPlugin.connect();

    if (result.status === ConnectionStatus.PENDING && result.metadata?.custom?.authorizationUrl) {
      const authUrl = result.metadata.custom.authorizationUrl;
      const verifier = result.metadata.custom.verifier;

      // Save verifier for callback
      sessionStorage.setItem('fitbitVerifier', verifier);

      // Redirect to Fitbit authorization
      showInfo('Redirecting to Fitbit authorization page...');
      setTimeout(() => {
        window.location.href = authUrl;
      }, 1000);
    } else if (result.status === ConnectionStatus.CONNECTED) {
      handleConnected();
    } else {
      throw new Error('Unexpected connection result');
    }
  } catch (error) {
    console.error('Connect error:', error);
    showError(`Connection failed: ${error.message}`);
    setButtonLoading(elements.btnConnect, false);
  }
}

function handleOAuthCallback() {
  const urlParams = new URLSearchParams(window.location.search);
  const code = urlParams.get('code');
  const error = urlParams.get('error');

  if (error) {
    showError(`OAuth error: ${error}`);
    window.history.replaceState({}, document.title, window.location.pathname);
    return;
  }

  if (code) {
    const verifier = sessionStorage.getItem('fitbitVerifier');
    if (!verifier) {
      showError('Missing PKCE verifier (session expired)');
      window.history.replaceState({}, document.title, window.location.pathname);
      return;
    }

    completeAuthorization(code, verifier);
  }
}

async function completeAuthorization(code, verifier) {
  showInfo('Completing authorization...');

  try {
    const result = await fitbitPlugin.completeAuthorization(code, verifier);

    if (result.status === ConnectionStatus.CONNECTED) {
      sessionStorage.removeItem('fitbitVerifier');
      window.history.replaceState({}, document.title, window.location.pathname);
      handleConnected();
    } else {
      throw new Error('Authorization failed');
    }
  } catch (error) {
    console.error('Authorization error:', error);
    showError(`Authorization failed: ${error.message}`);
    window.history.replaceState({}, document.title, window.location.pathname);
  }
}

function handleConnected() {
  isConnected = true;
  updateStatus('connected', 'Connected to Fitbit', 'Ready to fetch data');
  elements.pluginStatus.textContent = 'Connected';

  // Enable data fetch buttons
  elements.btnFetchSteps.disabled = false;
  elements.btnFetchHeartRate.disabled = false;
  elements.btnFetchSleep.disabled = false;
  elements.btnFetchWeight.disabled = false;
  elements.btnFetchAll.disabled = false;
  elements.btnDisconnect.disabled = false;

  showSuccess('Successfully connected to Fitbit!');

  // Update rate limit
  updateRateLimit();
}

async function disconnect() {
  if (!fitbitPlugin) return;

  setButtonLoading(elements.btnDisconnect, true);
  showInfo('Disconnecting from Fitbit...');

  try {
    await fitbitPlugin.disconnect();

    isConnected = false;
    updateStatus('disconnected', 'Disconnected', 'Click "Connect to Fitbit" to reconnect');
    elements.pluginStatus.textContent = 'Disconnected';

    // Disable data fetch buttons
    elements.btnFetchSteps.disabled = true;
    elements.btnFetchHeartRate.disabled = true;
    elements.btnFetchSleep.disabled = true;
    elements.btnFetchWeight.disabled = true;
    elements.btnFetchAll.disabled = true;
    elements.btnDisconnect.disabled = true;

    // Clear data
    fetchedData = [];
    renderData();

    showSuccess('Disconnected from Fitbit');
  } catch (error) {
    console.error('Disconnect error:', error);
    showError(`Disconnect failed: ${error.message}`);
  } finally {
    setButtonLoading(elements.btnDisconnect, false);
  }
}

// ============================================================================
// Data Fetching
// ============================================================================

async function fetchStepsData() {
  await fetchData(DataType.STEPS, 'Steps', elements.btnFetchSteps);
}

async function fetchHeartRateData() {
  await fetchData(DataType.HEART_RATE, 'Heart Rate', elements.btnFetchHeartRate);
}

async function fetchSleepData() {
  await fetchData(DataType.SLEEP, 'Sleep', elements.btnFetchSleep);
}

async function fetchWeightData() {
  await fetchData(DataType.WEIGHT, 'Weight', elements.btnFetchWeight);
}

async function fetchData(dataType, label, button) {
  if (!isConnected) {
    showError('Please connect to Fitbit first');
    return;
  }

  setButtonLoading(button, true);
  showInfo(`Fetching ${label} data...`);

  try {
    const endDate = new Date();
    const startDate = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);

    const data = await fitbitPlugin.fetchData({
      dataType,
      startDate: startDate.toISOString(),
      endDate: endDate.toISOString(),
    });

    // Add to fetched data
    fetchedData = [...fetchedData, ...data];
    renderData();

    showSuccess(`Fetched ${data.length} ${label} records`);

    // Update rate limit
    await updateRateLimit();
  } catch (error) {
    console.error(`Fetch ${label} error:`, error);
    showError(`Failed to fetch ${label}: ${error.message}`);
  } finally {
    setButtonLoading(button, false);
  }
}

async function fetchAllData() {
  if (!isConnected) {
    showError('Please connect to Fitbit first');
    return;
  }

  setButtonLoading(elements.btnFetchAll, true);
  showInfo('Fetching all data types...');

  try {
    const endDate = new Date();
    const startDate = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);

    const dataTypes = [
      DataType.STEPS,
      DataType.HEART_RATE,
      DataType.SLEEP,
      DataType.WEIGHT,
    ];

    const results = await Promise.all(
      dataTypes.map(dataType =>
        fitbitPlugin.fetchData({
          dataType,
          startDate: startDate.toISOString(),
          endDate: endDate.toISOString(),
        })
      )
    );

    // Combine all results
    const allData = results.flat();
    fetchedData = [...fetchedData, ...allData];
    renderData();

    showSuccess(`Fetched ${allData.length} total records across ${dataTypes.length} data types`);

    // Update rate limit
    await updateRateLimit();
  } catch (error) {
    console.error('Fetch all data error:', error);
    showError(`Failed to fetch data: ${error.message}`);
  } finally {
    setButtonLoading(elements.btnFetchAll, false);
  }
}

// ============================================================================
// Rate Limit
// ============================================================================

async function updateRateLimit() {
  try {
    const rateLimitStatus = await fitbitPlugin.getRateLimitStatus();

    if (rateLimitStatus) {
      elements.rateLimitRemaining.textContent = rateLimitStatus.requestsRemaining || 150;
      elements.rateLimitTotal.textContent = rateLimitStatus.requestsLimit || 150;

      if (rateLimitStatus.resetTime) {
        const resetTime = new Date(rateLimitStatus.resetTime);
        elements.rateLimitReset.textContent = resetTime.toLocaleTimeString();
      }

      // Update bar
      const percentage = ((rateLimitStatus.requestsRemaining || 150) / (rateLimitStatus.requestsLimit || 150)) * 100;
      elements.rateLimitBar.style.width = `${percentage}%`;
      elements.rateLimitBar.textContent = `${Math.round(percentage)}%`;

      // Change color based on percentage
      if (percentage < 20) {
        elements.rateLimitBar.style.background = 'linear-gradient(90deg, #dc3545 0%, #c82333 100%)';
      } else if (percentage < 50) {
        elements.rateLimitBar.style.background = 'linear-gradient(90deg, #ffc107 0%, #e0a800 100%)';
      } else {
        elements.rateLimitBar.style.background = 'linear-gradient(90deg, #28a745 0%, #20c997 100%)';
      }
    }
  } catch (error) {
    console.error('Rate limit update error:', error);
  }
}

// ============================================================================
// UI Updates
// ============================================================================

function updateStatus(status, title, message) {
  elements.statusDot.className = `status-dot ${status}`;
  elements.statusTitle.textContent = title;
  elements.statusMessage.textContent = message;
}

function renderData() {
  elements.totalRecords.textContent = fetchedData.length;

  if (fetchedData.length === 0) {
    elements.dataContainer.innerHTML = `
      <div class="empty-state">
        <svg fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M3 3a1 1 0 011-1h12a1 1 0 011 1v12a1 1 0 01-1 1H4a1 1 0 01-1-1V3zm11 4a1 1 0 10-2 0v4a1 1 0 102 0V7zm-3 1a1 1 0 10-2 0v3a1 1 0 102 0V8zM8 9a1 1 0 00-2 0v2a1 1 0 102 0V9z" clip-rule="evenodd"/>
        </svg>
        <p>No data fetched yet</p>
        <p style="font-size: 12px; margin-top: 8px;">Connect to Fitbit and fetch some data!</p>
      </div>
    `;
    return;
  }

  // Group data by type
  const groupedData = {};
  fetchedData.forEach(item => {
    const type = item.sourceDataType || 'Unknown';
    if (!groupedData[type]) {
      groupedData[type] = [];
    }
    groupedData[type].push(item);
  });

  let html = '';
  Object.entries(groupedData).forEach(([type, items]) => {
    items.slice(0, 5).forEach((item, index) => {
      const timestamp = new Date(item.timestamp).toLocaleString();
      const value = formatDataValue(item);

      html += `
        <div class="data-item">
          <strong>${type}</strong>
          <span class="data-value">${value}</span><br>
          <span>${timestamp}</span>
        </div>
      `;
    });

    if (items.length > 5) {
      html += `
        <div class="data-item" style="background: #e9ecef; border-left-color: #6c757d;">
          <span>... and ${items.length - 5} more ${type} records</span>
        </div>
      `;
    }
  });

  elements.dataContainer.innerHTML = html;
}

function formatDataValue(item) {
  const raw = item.raw || {};

  if (raw.steps !== undefined) {
    return `${raw.steps} steps`;
  } else if (raw.heartRate !== undefined) {
    return `${raw.heartRate} bpm`;
  } else if (raw.restingHeartRate !== undefined) {
    return `${raw.restingHeartRate} bpm (resting)`;
  } else if (raw.duration !== undefined) {
    const hours = Math.floor(raw.duration / (1000 * 60 * 60));
    const minutes = Math.floor((raw.duration % (1000 * 60 * 60)) / (1000 * 60));
    return `${hours}h ${minutes}m sleep`;
  } else if (raw.weight !== undefined) {
    return `${raw.weight} kg`;
  } else if (raw.calories !== undefined) {
    return `${raw.calories} cal`;
  }

  return 'Data received';
}

// ============================================================================
// Alerts
// ============================================================================

function showSuccess(message) {
  showAlert(message, 'success');
}

function showError(message) {
  showAlert(message, 'error');
}

function showWarning(message) {
  showAlert(message, 'warning');
}

function showInfo(message) {
  showAlert(message, 'info');
}

function showAlert(message, type) {
  const alert = document.createElement('div');
  alert.className = `alert alert-${type}`;
  alert.innerHTML = `
    <span>${message}</span>
  `;

  elements.alertContainer.appendChild(alert);

  // Auto-remove after 5 seconds
  setTimeout(() => {
    alert.style.opacity = '0';
    setTimeout(() => alert.remove(), 300);
  }, 5000);
}

function setButtonLoading(button, loading) {
  if (loading) {
    button.disabled = true;
    const originalText = button.querySelector('span').textContent;
    button.dataset.originalText = originalText;
    button.innerHTML = '<div class="loading"></div><span>Loading...</span>';
  } else {
    button.disabled = false;
    const originalText = button.dataset.originalText || 'Button';
    button.innerHTML = `<span>${originalText}</span>`;
  }
}

// ============================================================================
// Event Listeners
// ============================================================================

elements.btnConnect.addEventListener('click', connectToFitbit);
elements.btnDisconnect.addEventListener('click', disconnect);
elements.btnCheckConnection.addEventListener('click', () => {
  const status = fitbitPlugin?.getConnectionStatus() || ConnectionStatus.DISCONNECTED;
  showInfo(`Connection status: ${status}`);
});

elements.btnFetchSteps.addEventListener('click', fetchStepsData);
elements.btnFetchHeartRate.addEventListener('click', fetchHeartRateData);
elements.btnFetchSleep.addEventListener('click', fetchSleepData);
elements.btnFetchWeight.addEventListener('click', fetchWeightData);
elements.btnFetchAll.addEventListener('click', fetchAllData);

elements.btnCheckRateLimit.addEventListener('click', updateRateLimit);

// ============================================================================
// Initialize on Load
// ============================================================================

initialize();
