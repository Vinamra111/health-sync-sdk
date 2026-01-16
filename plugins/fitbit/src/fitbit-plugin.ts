/**
 * Fitbit Plugin for HealthSync SDK
 *
 * Cloud-based health data integration with Fitbit Web API v1.2
 * Features: OAuth 2.0, rate limiting, comprehensive data types
 */

import {
  BasePlugin,
  DataType,
  HealthSource,
  ConnectionStatus,
  ErrorAction,
  type PluginConfig,
  type ConnectionResult,
  type DataQuery,
  type RawHealthData,
  type Subscription,
  type UpdateCallback,
  type RateLimitInfo,
  type Logger,
  ConnectionError,
  DataFetchError,
  AuthenticationError,
} from '@healthsync/core';

import { FitbitAuth, InMemoryTokenStorage } from './fitbit-auth';
import type { TokenStorage } from './fitbit-auth';
import { FitbitAPI } from './fitbit-api';
import { FitbitTransformer } from './fitbit-transformer';
import type {
  FitbitApiConfig,
  FitbitScope,
  FitbitCredentials,
} from './fitbit-types';

/**
 * Fitbit Plugin Configuration
 */
export interface FitbitConfig extends Partial<FitbitApiConfig> {
  /** Enable automatic permission requests */
  autoRequestPermissions?: boolean;

  /** Custom token storage (default: in-memory) */
  tokenStorage?: TokenStorage;

  /** API request timeout in ms (default: 30000) */
  timeout?: number;

  /** Enable debug logging */
  debug?: boolean;
}

/**
 * Default Fitbit Configuration
 */
export const DEFAULT_FITBIT_CONFIG: Required<Omit<FitbitConfig, 'clientId' | 'clientSecret' | 'redirectUri'>> = {
  scopes: [
    FitbitScope.ACTIVITY,
    FitbitScope.HEART_RATE,
    FitbitScope.SLEEP,
    FitbitScope.WEIGHT,
  ],
  baseUrl: 'https://api.fitbit.com',
  autoRefreshToken: true,
  autoRequestPermissions: true,
  timeout: 30000,
  debug: false,
};

/**
 * Fitbit Plugin
 *
 * Integrates with Fitbit Web API to fetch health and fitness data
 */
export class FitbitPlugin extends BasePlugin {
  // Required BasePlugin properties
  readonly id = 'fitbit';
  readonly name = 'Fitbit';
  readonly version = '1.0.0';
  readonly supportedDataTypes: readonly DataType[] = [
    DataType.STEPS,
    DataType.HEART_RATE,
    DataType.RESTING_HEART_RATE,
    DataType.SLEEP,
    DataType.ACTIVITY,
    DataType.CALORIES,
    DataType.DISTANCE,
    DataType.BLOOD_OXYGEN,
    DataType.WEIGHT,
    DataType.HEART_RATE_VARIABILITY,
    DataType.VO2_MAX,
    DataType.ACTIVE_MINUTES,
    DataType.BODY_TEMPERATURE,
    DataType.RESPIRATORY_RATE,
  ];
  readonly requiresAuthentication = true;
  readonly isCloudBased = true;

  // Internal modules
  private auth!: FitbitAuth;
  private api!: FitbitAPI;
  private transformer: FitbitTransformer;

  // Configuration
  private fitbitConfig: FitbitConfig;
  private logger?: Logger;

  // Subscriptions
  private subscriptions: Map<string, { callback: UpdateCallback; active: boolean }> = new Map();
  private subscriptionCounter = 0;

  /**
   * Create Fitbit plugin
   *
   * @param config Fitbit plugin configuration
   */
  constructor(config: FitbitConfig) {
    super();

    // Validate required config
    if (!config.clientId) {
      throw new Error('Fitbit clientId is required');
    }
    if (!config.clientSecret) {
      throw new Error('Fitbit clientSecret is required');
    }
    if (!config.redirectUri) {
      throw new Error('Fitbit redirectUri is required');
    }

    this.fitbitConfig = {
      ...DEFAULT_FITBIT_CONFIG,
      ...config,
    };

    this.transformer = new FitbitTransformer();
  }

  // ============================================================================
  // Lifecycle Methods
  // ============================================================================

  /**
   * Initialize the plugin
   */
  async initialize(config: PluginConfig): Promise<void> {
    this.config = config;
    this.logger = config.custom?.['logger'] as Logger;

    this.log('info', 'Initializing Fitbit plugin...');

    try {
      // Initialize auth module
      this.auth = new FitbitAuth(
        {
          clientId: this.fitbitConfig.clientId!,
          clientSecret: this.fitbitConfig.clientSecret!,
          redirectUri: this.fitbitConfig.redirectUri!,
          scopes: this.fitbitConfig.scopes!,
          baseUrl: this.fitbitConfig.baseUrl,
          autoRefreshToken: this.fitbitConfig.autoRefreshToken,
        },
        this.fitbitConfig.tokenStorage || new InMemoryTokenStorage()
      );

      // Initialize API client
      this.api = new FitbitAPI(this.auth, {
        baseUrl: this.fitbitConfig.baseUrl,
        timeout: this.fitbitConfig.timeout,
      });

      this.log('info', 'Fitbit plugin initialized successfully');
    } catch (error) {
      this.log('error', 'Failed to initialize Fitbit plugin', error as Error);
      throw error;
    }
  }

  /**
   * Dispose plugin resources
   */
  async dispose(): Promise<void> {
    this.log('info', 'Disposing Fitbit plugin...');

    // Clear subscriptions
    this.subscriptions.clear();

    // Disconnect
    if (this.connectionStatus === ConnectionStatus.CONNECTED) {
      await this.disconnect();
    }

    this.log('info', 'Fitbit plugin disposed');
  }

  // ============================================================================
  // Connection Management
  // ============================================================================

  /**
   * Connect to Fitbit
   *
   * Handles OAuth flow or validates existing tokens
   */
  async connect(): Promise<ConnectionResult> {
    try {
      this.connectionStatus = ConnectionStatus.CONNECTING;
      this.log('info', 'Connecting to Fitbit...');

      // Check if we have valid tokens
      const hasTokens = await this.auth.hasValidTokens();

      if (!hasTokens) {
        // Need to go through OAuth flow
        const authData = await this.auth.generateAuthorizationUrl(
          this.fitbitConfig.scopes
        );

        this.connectionStatus = ConnectionStatus.REQUIRES_AUTH;

        return {
          success: false,
          message: 'Authorization required. Please visit the authorization URL.',
          metadata: {
            custom: {
              authorizationUrl: authData.url,
              codeVerifier: authData.verifier,
              requiresUserAction: true,
              instructions: [
                '1. Visit the authorization URL',
                '2. Log in to your Fitbit account',
                '3. Grant the requested permissions',
                '4. You will be redirected to your redirect URI with an authorization code',
                '5. Call completeAuthorization(code, verifier) with the code from the redirect',
              ],
            },
          },
        };
      }

      // Test connection with a simple API call
      const profile = await this.api.getUserProfile();

      this.connectionStatus = ConnectionStatus.CONNECTED;
      this.log('info', `Connected to Fitbit as ${profile.user.displayName}`);

      return {
        success: true,
        message: 'Successfully connected to Fitbit',
        metadata: {
          userId: profile.user.encodedId,
          username: profile.user.displayName,
          custom: {
            source: HealthSource.FITBIT,
            memberSince: profile.user.memberSince,
          },
        },
      };
    } catch (error) {
      this.connectionStatus = ConnectionStatus.ERROR;
      this.log('error', 'Failed to connect to Fitbit', error as Error);

      return {
        success: false,
        message: `Connection failed: ${(error as Error).message}`,
        error: error as Error,
      };
    }
  }

  /**
   * Complete OAuth authorization after user grants permissions
   *
   * @param code Authorization code from redirect
   * @param verifier Code verifier from generateAuthorizationUrl
   */
  async completeAuthorization(code: string, verifier: string): Promise<ConnectionResult> {
    try {
      this.log('info', 'Completing authorization...');

      // Exchange code for tokens
      const credentials = await this.auth.exchangeCodeForTokens(code, verifier);

      // Test connection
      const profile = await this.api.getUserProfile();

      this.connectionStatus = ConnectionStatus.CONNECTED;
      this.log('info', `Authorization complete. Connected as ${profile.user.displayName}`);

      return {
        success: true,
        message: 'Authorization completed successfully',
        metadata: {
          userId: credentials.userId,
          username: profile.user.displayName,
          custom: {
            source: HealthSource.FITBIT,
            scopes: credentials.scopes,
          },
        },
      };
    } catch (error) {
      this.connectionStatus = ConnectionStatus.ERROR;
      this.log('error', 'Failed to complete authorization', error as Error);

      return {
        success: false,
        message: `Authorization failed: ${(error as Error).message}`,
        error: error as Error,
      };
    }
  }

  /**
   * Disconnect from Fitbit
   */
  async disconnect(): Promise<void> {
    this.log('info', 'Disconnecting from Fitbit...');

    try {
      // Revoke tokens
      await this.auth.revokeTokens();
    } catch (error) {
      this.log('warn', 'Error revoking tokens during disconnect', error as Error);
    }

    this.connectionStatus = ConnectionStatus.DISCONNECTED;
    this.subscriptions.clear();

    this.log('info', 'Disconnected from Fitbit');
  }

  // ============================================================================
  // Data Operations
  // ============================================================================

  /**
   * Fetch health data from Fitbit
   */
  async fetchData(query: DataQuery): Promise<RawHealthData[]> {
    if (this.connectionStatus !== ConnectionStatus.CONNECTED) {
      throw new ConnectionError(
        'Not connected to Fitbit',
        HealthSource.FITBIT,
        undefined,
        { code: 'NOT_CONNECTED' }
      );
    }

    // Validate data type is supported
    if (!this.supportedDataTypes.includes(query.dataType)) {
      throw new DataFetchError(
        `Data type ${query.dataType} is not supported by Fitbit`,
        HealthSource.FITBIT,
        query.dataType,
        undefined,
        { code: 'UNSUPPORTED_DATA_TYPE' }
      );
    }

    this.log('info', `Fetching ${query.dataType} from ${query.startDate} to ${query.endDate}`);

    try {
      // Parse dates
      const startDate = new Date(query.startDate);
      const endDate = new Date(query.endDate);

      // Route to appropriate fetch method based on data type
      let rawData: RawHealthData[] = [];

      switch (query.dataType) {
        case DataType.STEPS:
        case DataType.DISTANCE:
        case DataType.CALORIES:
        case DataType.ACTIVE_MINUTES:
          rawData = await this.fetchActivityData(query, startDate, endDate);
          break;

        case DataType.HEART_RATE:
        case DataType.RESTING_HEART_RATE:
          rawData = await this.fetchHeartRateData(query, startDate, endDate);
          break;

        case DataType.SLEEP:
          rawData = await this.fetchSleepData(startDate, endDate);
          break;

        case DataType.ACTIVITY:
          rawData = await this.fetchActivityLogs(startDate, endDate, query.limit);
          break;

        case DataType.WEIGHT:
          rawData = await this.fetchWeightData(startDate, endDate);
          break;

        case DataType.BLOOD_OXYGEN:
          rawData = await this.fetchSpO2Data(startDate, endDate);
          break;

        case DataType.HEART_RATE_VARIABILITY:
          rawData = await this.fetchHRVData(startDate, endDate);
          break;

        case DataType.VO2_MAX:
          rawData = await this.fetchVO2MaxData(startDate, endDate);
          break;

        case DataType.BODY_TEMPERATURE:
          rawData = await this.fetchTemperatureData(startDate, endDate);
          break;

        case DataType.RESPIRATORY_RATE:
          rawData = await this.fetchBreathingRateData(startDate, endDate);
          break;

        default:
          throw new DataFetchError(
            `Fetching ${query.dataType} is not yet implemented`,
            HealthSource.FITBIT,
            query.dataType,
            undefined,
            { code: 'NOT_IMPLEMENTED' }
          );
      }

      this.log('info', `Fetched ${rawData.length} ${query.dataType} records`);
      return rawData;

    } catch (error) {
      this.log('error', `Failed to fetch ${query.dataType}`, error as Error);

      if (
        error instanceof ConnectionError ||
        error instanceof DataFetchError ||
        error instanceof AuthenticationError
      ) {
        throw error;
      }

      throw new DataFetchError(
        `Failed to fetch ${query.dataType}: ${(error as Error).message}`,
        HealthSource.FITBIT,
        query.dataType,
        error as Error
      );
    }
  }

  /**
   * Subscribe to real-time updates (webhooks)
   * Note: Fitbit webhooks require special approval
   */
  async subscribeToUpdates(callback: UpdateCallback): Promise<Subscription> {
    const subscriptionId = `fitbit-sub-${Date.now()}-${++this.subscriptionCounter}`;

    this.subscriptions.set(subscriptionId, {
      callback,
      active: true,
    });

    this.log('info', `Created subscription: ${subscriptionId}`);

    // TODO: Implement Fitbit webhooks when approved
    this.log('warn', 'Fitbit webhooks require special approval and are not yet implemented');

    return {
      id: subscriptionId,
      unsubscribe: async () => {
        const sub = this.subscriptions.get(subscriptionId);
        if (sub) {
          sub.active = false;
        }
        this.subscriptions.delete(subscriptionId);
        this.log('info', `Unsubscribed: ${subscriptionId}`);
      },
      isActive: () => {
        const sub = this.subscriptions.get(subscriptionId);
        return sub ? sub.active : false;
      },
    };
  }

  // ============================================================================
  // Error Handling
  // ============================================================================

  /**
   * Handle plugin-specific errors
   */
  override handleError(error: Error): ErrorAction {
    const msg = error.message.toLowerCase();

    // Fitbit-specific errors
    if (msg.includes('expired_token') || msg.includes('401')) {
      return ErrorAction.REAUTH;
    }

    if (msg.includes('rate_limit') || msg.includes('429')) {
      return ErrorAction.QUEUE;
    }

    if (msg.includes('insufficient_scope') || msg.includes('403')) {
      // User needs to re-authorize with more scopes
      return ErrorAction.REAUTH;
    }

    if (msg.includes('invalid_grant') || msg.includes('invalid_token')) {
      return ErrorAction.REAUTH;
    }

    // Use base class default handling for other errors
    return super.handleError(error);
  }

  // ============================================================================
  // Optional Methods
  // ============================================================================

  /**
   * Refresh authentication tokens
   */
  async refreshAuth(): Promise<boolean> {
    try {
      this.log('info', 'Refreshing authentication...');
      await this.auth.refreshAccessToken();
      this.log('info', 'Authentication refreshed successfully');
      return true;
    } catch (error) {
      this.log('error', 'Failed to refresh authentication', error as Error);
      return false;
    }
  }

  /**
   * Get rate limit status
   */
  async getRateLimitStatus(): Promise<RateLimitInfo> {
    const fitbitLimit = this.api.getRateLimitStatus();

    return {
      limit: fitbitLimit.limit,
      remaining: fitbitLimit.remaining,
      resetAt: fitbitLimit.resetAt.toISOString(),
      resetInSeconds: Math.max(0, Math.floor((fitbitLimit.resetAt.getTime() - Date.now()) / 1000)),
    };
  }

  /**
   * Get current credentials (for debugging/testing)
   */
  async getCredentials(): Promise<FitbitCredentials | null> {
    return await this.auth.getCredentials();
  }

  // ============================================================================
  // Private Data Fetching Methods
  // ============================================================================

  private async fetchActivityData(
    query: DataQuery,
    startDate: Date,
    endDate: Date
  ): Promise<RawHealthData[]> {
    const results: RawHealthData[] = [];

    // Iterate through each day in the range
    for (let date = new Date(startDate); date <= endDate; date.setDate(date.getDate() + 1)) {
      const dateStr = this.transformer.formatDate(date);

      // Fetch daily activity summary
      const activityData = await this.api.getActivitySummary(dateStr);

      // Transform to RawHealthData
      const transformed = this.transformer.transformActivitySummary(activityData, dateStr);

      // Filter by requested data type
      const filtered = transformed.filter(d => {
        if (query.dataType === DataType.STEPS) return d.sourceDataType === 'fitbit-steps';
        if (query.dataType === DataType.DISTANCE) return d.sourceDataType === 'fitbit-distance';
        if (query.dataType === DataType.CALORIES) return d.sourceDataType === 'fitbit-calories';
        if (query.dataType === DataType.ACTIVE_MINUTES) return d.sourceDataType === 'fitbit-active-minutes';
        return false;
      });

      results.push(...filtered);
    }

    return results;
  }

  private async fetchHeartRateData(
    query: DataQuery,
    startDate: Date,
    endDate: Date
  ): Promise<RawHealthData[]> {
    const results: RawHealthData[] = [];

    // Determine detail level based on date range
    const daysDiff = Math.ceil((endDate.getTime() - startDate.getTime()) / (1000 * 60 * 60 * 24));

    if (daysDiff <= 1) {
      // Single day - fetch intraday data
      const dateStr = this.transformer.formatDate(startDate);
      const intradayData = await this.api.getHeartRateIntraday(dateStr, '1min');
      results.push(...this.transformer.transformHeartRateIntraday(intradayData));
    } else {
      // Multiple days - fetch time series
      const startStr = this.transformer.formatDate(startDate);
      const endStr = this.transformer.formatDate(endDate);
      const timeSeriesData = await this.api.getHeartRateTimeSeries(startStr, '30d');
      results.push(...this.transformer.transformHeartRateTimeSeries(timeSeriesData));
    }

    return results;
  }

  private async fetchSleepData(startDate: Date, endDate: Date): Promise<RawHealthData[]> {
    const results: RawHealthData[] = [];

    // Fetch sleep logs for date range
    const startStr = this.transformer.formatDate(startDate);
    const endStr = this.transformer.formatDate(endDate);

    const sleepData = await this.api.getSleepLogsRange(startStr, endStr);
    results.push(...this.transformer.transformSleepLogs(sleepData));

    return results;
  }

  private async fetchActivityLogs(
    startDate: Date,
    endDate: Date,
    limit?: number
  ): Promise<RawHealthData[]> {
    const startStr = this.transformer.formatDate(startDate);
    const logsData = await this.api.getActivityLogs(startStr, 'asc', limit || 100);
    return this.transformer.transformActivityLogs(logsData.activities);
  }

  private async fetchWeightData(startDate: Date, endDate: Date): Promise<RawHealthData[]> {
    const results: RawHealthData[] = [];

    const startStr = this.transformer.formatDate(startDate);
    const weightData = await this.api.getWeightLogs(startStr, '30d');
    results.push(...this.transformer.transformWeightLogs(weightData));

    return results;
  }

  private async fetchSpO2Data(startDate: Date, endDate: Date): Promise<RawHealthData[]> {
    const results: RawHealthData[] = [];

    for (let date = new Date(startDate); date <= endDate; date.setDate(date.getDate() + 1)) {
      const dateStr = this.transformer.formatDate(date);
      const spo2Data = await this.api.getSpO2(dateStr);
      results.push(...this.transformer.transformSpO2(spo2Data));
    }

    return results;
  }

  private async fetchHRVData(startDate: Date, endDate: Date): Promise<RawHealthData[]> {
    const results: RawHealthData[] = [];

    for (let date = new Date(startDate); date <= endDate; date.setDate(date.getDate() + 1)) {
      const dateStr = this.transformer.formatDate(date);
      const hrvData = await this.api.getHRV(dateStr);
      results.push(...this.transformer.transformHRV(hrvData));
    }

    return results;
  }

  private async fetchVO2MaxData(startDate: Date, endDate: Date): Promise<RawHealthData[]> {
    const results: RawHealthData[] = [];

    for (let date = new Date(startDate); date <= endDate; date.setDate(date.getDate() + 1)) {
      const dateStr = this.transformer.formatDate(date);
      const vo2Data = await this.api.getVO2Max(dateStr);
      results.push(...this.transformer.transformVO2Max(vo2Data));
    }

    return results;
  }

  private async fetchTemperatureData(startDate: Date, endDate: Date): Promise<RawHealthData[]> {
    const results: RawHealthData[] = [];

    for (let date = new Date(startDate); date <= endDate; date.setDate(date.getDate() + 1)) {
      const dateStr = this.transformer.formatDate(date);
      const tempData = await this.api.getTemperature(dateStr);
      results.push(...this.transformer.transformTemperature(tempData));
    }

    return results;
  }

  private async fetchBreathingRateData(startDate: Date, endDate: Date): Promise<RawHealthData[]> {
    const results: RawHealthData[] = [];

    for (let date = new Date(startDate); date <= endDate; date.setDate(date.getDate() + 1)) {
      const dateStr = this.transformer.formatDate(date);
      const brData = await this.api.getBreathingRate(dateStr);
      results.push(...this.transformer.transformBreathingRate(brData));
    }

    return results;
  }

  // ============================================================================
  // Logging
  // ============================================================================

  private log(level: 'info' | 'warn' | 'error', message: string, error?: Error): void {
    if (!this.logger) {
      return;
    }

    const msg = `[Fitbit] ${message}`;

    switch (level) {
      case 'info':
        this.logger.info(msg);
        break;
      case 'warn':
        this.logger.warn(msg);
        break;
      case 'error':
        this.logger.error(msg, error);
        break;
    }
  }
}
