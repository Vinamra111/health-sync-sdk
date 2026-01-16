/**
 * @healthsync/plugin-fitbit
 *
 * Fitbit integration plugin for HealthSync SDK
 * Provides access to Fitbit health and fitness data through OAuth 2.0
 *
 * @example
 * ```typescript
 * import { FitbitPlugin } from '@healthsync/plugin-fitbit';
 * import { HealthSyncSDK, DataType } from '@healthsync/core';
 *
 * // Initialize plugin
 * const fitbit = new FitbitPlugin({
 *   clientId: 'YOUR_CLIENT_ID',
 *   clientSecret: 'YOUR_CLIENT_SECRET',
 *   redirectUri: 'YOUR_REDIRECT_URI',
 * });
 *
 * // Initialize SDK
 * const sdk = new HealthSyncSDK();
 * await sdk.registerPlugin(fitbit);
 *
 * // Connect (starts OAuth flow)
 * const result = await fitbit.connect();
 * if (!result.success && result.metadata?.custom?.authorizationUrl) {
 *   console.log('Visit:', result.metadata.custom.authorizationUrl);
 *   // After user authorizes, complete the flow:
 *   await fitbit.completeAuthorization(code, verifier);
 * }
 *
 * // Fetch data
 * const data = await fitbit.fetchData({
 *   dataType: DataType.STEPS,
 *   startDate: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString(),
 *   endDate: new Date().toISOString(),
 * });
 * ```
 */

// Main plugin
export { FitbitPlugin } from './fitbit-plugin';
export type { FitbitConfig } from './fitbit-plugin';
export { DEFAULT_FITBIT_CONFIG } from './fitbit-plugin';

// OAuth module
export { FitbitAuth, PKCEGenerator } from './fitbit-auth';
export type { TokenStorage } from './fitbit-auth';
export { InMemoryTokenStorage } from './fitbit-auth';

// API client
export { FitbitAPI, RateLimiter, RequestQueue } from './fitbit-api';
export type { FitbitAPIConfig } from './fitbit-api';

// Data transformer
export { FitbitTransformer } from './fitbit-transformer';

// Types
export {
  FitbitScope,
  FitbitErrorType,
  FITBIT_RESOURCE_MAP,
  FITBIT_SCOPE_DATA_TYPES,
} from './fitbit-types';

export type {
  FitbitCredentials,
  FitbitApiConfig,
  FitbitActivityResponse,
  FitbitActivitySession,
  FitbitHeartRateResponse,
  FitbitIntradayHeartRate,
  FitbitSleepResponse,
  FitbitSleepSession,
  FitbitSleepLevel,
  FitbitWeightResponse,
  FitbitUserProfile,
  FitbitDataQuery,
  FitbitIntradayQuery,
  FitbitApiError,
  FitbitRateLimitInfo,
  FitbitTokenResponse,
} from './fitbit-types';

// Re-export core types for convenience
export {
  DataType,
  HealthSource,
  ConnectionStatus,
  ErrorAction,
} from '@healthsync/core';
