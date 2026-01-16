# Fitbit Plugin for HealthSync SDK

**Status**: Production-Ready
**Version**: 1.0.0
**API**: Fitbit Web API v1.2
**Auth**: OAuth 2.0

---

## Overview

The Fitbit plugin provides seamless integration with Fitbit's health and fitness data through their Web API. This plugin handles OAuth authentication, data fetching, rate limiting, and data normalization to HealthSync's unified format.

---

## Features

✅ **OAuth 2.0 Authentication** - Complete authorization flow
✅ **20+ Data Types** - Activity, sleep, heart rate, nutrition, and more
✅ **Automatic Token Refresh** - Handles expired tokens automatically
✅ **Rate Limit Management** - Respects Fitbit's API limits (150 requests/hour)
✅ **Error Handling** - Comprehensive error classification and retry logic
✅ **Data Normalization** - Transforms Fitbit data to UnifiedHealthData format
✅ **Type Safety** - Full TypeScript support with strict typing

---

## Supported Data Types

### Activity & Exercise
- Steps
- Distance
- Calories (active & total)
- Elevation
- Floors climbed
- Activity sessions
- Heart rate zones

### Sleep
- Sleep sessions
- Sleep stages (deep, light, REM, awake)
- Sleep efficiency
- Time in bed vs asleep

### Body Measurements
- Weight
- Body fat percentage
- BMI

### Nutrition & Hydration
- Calorie intake
- Macronutrients
- Water intake
- Food logs

### Heart Rate
- Intraday heart rate
- Resting heart rate
- Heart rate zones
- Cardio fitness score (VO2 Max)

---

## Installation

```bash
npm install @healthsync/plugin-fitbit
```

---

## Usage

### 1. Setup

```typescript
import { FitbitPlugin } from '@healthsync/plugin-fitbit';
import { HealthSyncManager } from '@healthsync/core';

const fitbitPlugin = new FitbitPlugin({
  clientId: process.env.FITBIT_CLIENT_ID!,
  clientSecret: process.env.FITBIT_CLIENT_SECRET!,
  redirectUri: 'https://yourapp.com/auth/fitbit/callback',
  scopes: [
    'activity',
    'heartrate',
    'sleep',
    'weight',
    'nutrition'
  ]
});

const sdk = new HealthSyncManager({
  plugins: [fitbitPlugin]
});
```

### 2. Authenticate User

```typescript
// Get authorization URL
const authUrl = await fitbitPlugin.getAuthorizationUrl();

// Redirect user to authUrl
// User grants permissions on Fitbit

// After redirect back, exchange code for tokens
const credentials = await fitbitPlugin.exchangeAuthorizationCode(code);

// Connect plugin
await sdk.connect('fitbit', credentials);
```

### 3. Fetch Data

```typescript
import { DataType } from '@healthsync/core';

// Fetch steps data
const steps = await sdk.fetchData({
  source: 'fitbit',
  dataType: DataType.STEPS,
  startDate: new Date('2024-01-01'),
  endDate: new Date()
});

console.log(steps);
// [
//   {
//     sourceDataType: 'Steps',
//     source: 'FITBIT',
//     timestamp: '2024-01-01T00:00:00Z',
//     raw: { count: 10523, ... }
//   },
//   ...
// ]
```

---

## Configuration

### Fitbit App Setup

1. Go to https://dev.fitbit.com/apps
2. Create new application
3. Set OAuth 2.0 Application Type: "Server"
4. Set Redirect URL: Your callback URL
5. Copy Client ID and Client Secret

### Required Scopes

| Scope | Description | Data Types |
|-------|-------------|------------|
| `activity` | Activity and exercise data | Steps, distance, calories, floors |
| `heartrate` | Heart rate data | HR, resting HR, HR zones |
| `sleep` | Sleep data | Sleep sessions, stages |
| `weight` | Body measurements | Weight, body fat, BMI |
| `nutrition` | Nutrition and hydration | Food logs, water intake |
| `profile` | User profile | Basic user info |

---

## API Rate Limits

Fitbit enforces the following limits:

- **150 requests per hour** per user
- **Personal apps**: Lower limits
- **Production apps**: Higher limits (request increase)

The plugin automatically:
- Tracks requests per hour
- Implements exponential backoff
- Retries on 429 (Rate Limit) errors
- Provides rate limit status via `getRateLimitStatus()`

---

## Error Handling

### Common Errors

#### Authentication Errors
```typescript
try {
  await sdk.connect('fitbit', credentials);
} catch (error) {
  if (error.code === 'AUTHENTICATION_ERROR') {
    // Token expired - refresh or re-auth
    const newCredentials = await fitbitPlugin.refreshToken(credentials.refreshToken);
    await sdk.connect('fitbit', newCredentials);
  }
}
```

#### Rate Limit Errors
```typescript
try {
  await sdk.fetchData({...});
} catch (error) {
  if (error.code === 'RATE_LIMIT_ERROR') {
    // Wait and retry
    console.log(`Retry after ${error.retryAfter} seconds`);
    await sleep(error.retryAfter * 1000);
    // Retry...
  }
}
```

---

## Data Normalization

All Fitbit data is transformed to HealthSync's `UnifiedHealthData` format:

### Example: Steps Data

**Fitbit Response**:
```json
{
  "activities-steps": [{
    "dateTime": "2024-01-01",
    "value": "10523"
  }]
}
```

**Normalized Output**:
```typescript
{
  sourceDataType: 'Steps',
  source: HealthSource.FITBIT,
  timestamp: new Date('2024-01-01T00:00:00Z'),
  endTimestamp: new Date('2024-01-01T23:59:59Z'),
  quality: DataQuality.HIGH,
  raw: {
    count: 10523,
    date: '2024-01-01',
    _original: { /* complete Fitbit response */ }
  }
}
```

---

## Advanced Features

### Token Management

```typescript
// Check if token is expiring soon
if (credentials.expiresAt < new Date(Date.now() + 3600000)) {
  // Refresh proactively
  const newCredentials = await fitbitPlugin.refreshToken(credentials.refreshToken);
  // Update stored credentials
}
```

### Custom Date Ranges

```typescript
// Intraday data (1-minute granularity)
const intradayHR = await sdk.fetchData({
  source: 'fitbit',
  dataType: DataType.HEART_RATE,
  startDate: new Date('2024-01-01T00:00:00'),
  endDate: new Date('2024-01-01T23:59:59'),
  options: {
    granularity: '1min'
  }
});
```

### Batch Requests

```typescript
// Fetch multiple data types efficiently
const [steps, sleep, heartRate] = await Promise.all([
  sdk.fetchData({ source: 'fitbit', dataType: DataType.STEPS, ... }),
  sdk.fetchData({ source: 'fitbit', dataType: DataType.SLEEP, ... }),
  sdk.fetchData({ source: 'fitbit', dataType: DataType.HEART_RATE, ... })
]);
```

---

## Testing

### Unit Tests

```bash
npm test
```

### Integration Tests (requires Fitbit account)

```bash
# Set environment variables
export FITBIT_CLIENT_ID=your_client_id
export FITBIT_CLIENT_SECRET=your_client_secret
export FITBIT_TEST_TOKEN=your_test_token

npm run test:integration
```

---

## Troubleshooting

### Issue: "invalid_grant" error

**Cause**: Authorization code expired or already used
**Solution**: Generate new authorization code (codes expire in 10 minutes)

### Issue: "Insufficient permissions"

**Cause**: Missing required scope
**Solution**: Re-authenticate with correct scopes

### Issue: Rate limit exceeded

**Cause**: Too many requests in 1 hour
**Solution**: Wait for reset or implement request queueing

---

## Architecture

```
FitbitPlugin
├── FitbitApiClient - Handles HTTP requests to Fitbit API
├── FitbitDataMapper - Transforms Fitbit data to UnifiedHealthData
├── FitbitAuthManager - Manages OAuth flow and tokens
└── FitbitRateLimiter - Tracks and enforces rate limits
```

---

## References

- [Fitbit Web API Documentation](https://dev.fitbit.com/build/reference/web-api/)
- [OAuth 2.0 Guide](https://dev.fitbit.com/build/reference/web-api/authorization/)
- [Rate Limits](https://dev.fitbit.com/build/reference/web-api/rate-limits/)

---

## License

MIT

---

*Built with ❤️ for HealthSync SDK*
*Version: 1.0.0*
*Last Updated: January 7, 2026*
