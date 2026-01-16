/**
 * Configuration Types
 *
 * This module defines all configuration interfaces and types for the HealthSync SDK,
 * including SDK initialization config, sync options, and error types.
 *
 * @module types/config
 */

import { DataType, HealthSource } from '../models/unified-data';
import { IHealthDataPlugin } from '../plugins/plugin-interface';

/**
 * Log level enumeration
 *
 * @enum {string}
 */
export enum LogLevel {
  /** No logging */
  NONE = 'none',

  /** Log errors only */
  ERROR = 'error',

  /** Log warnings and errors */
  WARN = 'warn',

  /** Log info, warnings, and errors */
  INFO = 'info',

  /** Log everything including debug messages */
  DEBUG = 'debug',
}

/**
 * Cache storage layer
 *
 * @enum {string}
 */
export enum CacheLayer {
  /** In-memory cache (fastest, session-only) */
  MEMORY = 'memory',

  /** Local database cache (SQLite, IndexedDB) */
  LOCAL_DB = 'local_db',

  /** Cloud storage cache (user's backend) */
  CLOUD = 'cloud',

  /** All cache layers */
  ALL = 'all',
}

/**
 * Cache configuration options
 *
 * @interface CacheConfig
 */
export interface CacheConfig {
  /** Enable caching */
  enabled: boolean;

  /** Which cache layers to use */
  layers: CacheLayer[];

  /** Default cache duration in milliseconds */
  defaultTTL: number;

  /** Maximum cache size in MB */
  maxSize?: number;

  /** Custom TTL per data type (in milliseconds) */
  ttlByDataType?: Partial<Record<DataType, number>>;

  /** Whether to use LRU eviction for memory cache */
  useLRU?: boolean;

  /** Cloud cache endpoint (if using cloud layer) */
  cloudEndpoint?: string;

  /** Cloud cache authentication */
  cloudAuth?: {
    apiKey?: string;
    token?: string;
    headers?: Record<string, string>;
  };
}

/**
 * Retry strategy configuration
 *
 * @interface RetryConfig
 */
export interface RetryConfig {
  /** Maximum number of retry attempts */
  maxAttempts: number;

  /** Initial delay in milliseconds */
  initialDelay: number;

  /** Maximum delay in milliseconds */
  maxDelay: number;

  /** Backoff multiplier (2 = exponential doubling) */
  backoffMultiplier: number;

  /** Whether to add random jitter to delays */
  useJitter: boolean;

  /** Timeout for each attempt in milliseconds */
  timeout: number;
}

/**
 * Main SDK configuration
 *
 * @interface SDKConfig
 */
export interface SDKConfig {
  /** Base URL for backend API (optional) */
  apiBaseUrl?: string;

  /** Client application identifier */
  clientId?: string;

  /** Client application secret (for server-side apps) */
  clientSecret?: string;

  /** Environment (development, staging, production) */
  environment?: 'development' | 'staging' | 'production';

  /** Cache configuration */
  cache?: Partial<CacheConfig>;

  /** Retry configuration */
  retry?: Partial<RetryConfig>;

  /** Log level for SDK operations */
  logLevel?: LogLevel;

  /** Custom logger implementation */
  logger?: Logger;

  /** Plugins to register on initialization */
  plugins?: IHealthDataPlugin[];

  /** Default data types to sync */
  defaultDataTypes?: DataType[];

  /** Whether to sync data automatically on initialization */
  autoSync?: boolean;

  /** Interval for background sync in milliseconds (0 = disabled) */
  syncInterval?: number;

  /** Maximum age of data to fetch in days */
  maxDataAge?: number;

  /** Whether to enable real-time updates */
  enableRealtimeUpdates?: boolean;

  /** Custom user identifier */
  userId?: string;

  /** Additional custom configuration */
  custom?: Record<string, unknown>;
}

/**
 * Logger interface for custom logging implementations
 *
 * @interface Logger
 */
export interface Logger {
  /** Log debug message */
  debug(message: string, ...args: unknown[]): void;

  /** Log info message */
  info(message: string, ...args: unknown[]): void;

  /** Log warning message */
  warn(message: string, ...args: unknown[]): void;

  /** Log error message */
  error(message: string, error?: Error, ...args: unknown[]): void;
}

/**
 * Sync options for data synchronization
 *
 * @interface SyncOptions
 */
export interface SyncOptions {
  /** Health sources to sync from (if not specified, sync all connected sources) */
  sources?: HealthSource[];

  /** Data types to sync (if not specified, sync all supported types) */
  dataTypes?: DataType[];

  /** Start date for data sync (ISO 8601 format) */
  startDate?: string;

  /** End date for data sync (ISO 8601 format) */
  endDate?: string;

  /** Whether to force a full sync (ignore cache) */
  forceFull?: boolean;

  /** Whether to sync in the background */
  background?: boolean;

  /** Callback for sync progress updates */
  onProgress?: SyncProgressCallback;

  /** Callback when sync completes */
  onComplete?: SyncCompleteCallback;

  /** Callback when sync fails */
  onError?: SyncErrorCallback;

  /** Maximum concurrent sync operations */
  maxConcurrency?: number;

  /** Priority level (higher = sync first) */
  priority?: number;
}

/**
 * Sync progress information
 *
 * @interface SyncProgress
 */
export interface SyncProgress {
  /** Current source being synced */
  currentSource: HealthSource;

  /** Current data type being synced */
  currentDataType: DataType;

  /** Total number of sources to sync */
  totalSources: number;

  /** Number of sources completed */
  completedSources: number;

  /** Total number of data types to sync */
  totalDataTypes: number;

  /** Number of data types completed */
  completedDataTypes: number;

  /** Total records synced so far */
  totalRecords: number;

  /** Overall progress percentage (0-100) */
  percentage: number;

  /** Estimated time remaining in milliseconds */
  estimatedTimeRemaining?: number;
}

/**
 * Sync result information
 *
 * @interface SyncResult
 */
export interface SyncResult {
  /** Whether the sync was successful */
  success: boolean;

  /** Total number of records synced */
  totalRecords: number;

  /** Number of new records added */
  newRecords: number;

  /** Number of records updated */
  updatedRecords: number;

  /** Number of records that failed to sync */
  failedRecords: number;

  /** Sync start timestamp (ISO 8601) */
  startedAt: string;

  /** Sync completion timestamp (ISO 8601) */
  completedAt: string;

  /** Total duration in milliseconds */
  duration: number;

  /** Results per source */
  sourceResults: SourceSyncResult[];

  /** Errors encountered during sync */
  errors?: SyncError[];
}

/**
 * Sync result for a specific source
 *
 * @interface SourceSyncResult
 */
export interface SourceSyncResult {
  /** Health source */
  source: HealthSource;

  /** Whether this source sync succeeded */
  success: boolean;

  /** Number of records synced from this source */
  recordCount: number;

  /** Results per data type */
  dataTypeResults: DataTypeSyncResult[];

  /** Error if sync failed */
  error?: Error;
}

/**
 * Sync result for a specific data type
 *
 * @interface DataTypeSyncResult
 */
export interface DataTypeSyncResult {
  /** Data type */
  dataType: DataType;

  /** Whether this data type sync succeeded */
  success: boolean;

  /** Number of records synced for this type */
  recordCount: number;

  /** Error if sync failed */
  error?: Error;
}

/**
 * Sync progress callback
 *
 * @callback SyncProgressCallback
 * @param {SyncProgress} progress - Current sync progress
 * @returns {void}
 */
export type SyncProgressCallback = (progress: SyncProgress) => void;

/**
 * Sync complete callback
 *
 * @callback SyncCompleteCallback
 * @param {SyncResult} result - Sync result
 * @returns {void}
 */
export type SyncCompleteCallback = (result: SyncResult) => void;

/**
 * Sync error callback
 *
 * @callback SyncErrorCallback
 * @param {SyncError} error - Sync error
 * @returns {void}
 */
export type SyncErrorCallback = (error: SyncError) => void;

// ============================================================================
// Error Types
// ============================================================================

/**
 * Base error class for all SDK errors
 *
 * @class SDKError
 * @extends {Error}
 */
export class SDKError extends Error {
  /** Error code */
  public readonly code: string;

  /** HTTP status code (if applicable) */
  public readonly statusCode?: number;

  /** Additional error details */
  public readonly details?: Record<string, unknown>;

  /** Original error (if wrapped) */
  public readonly originalError?: Error;

  constructor(
    message: string,
    code: string,
    statusCode?: number,
    details?: Record<string, unknown>,
    originalError?: Error
  ) {
    super(message);
    this.name = 'SDKError';
    this.code = code;
    if (statusCode !== undefined) {
      this.statusCode = statusCode;
    }
    if (details !== undefined) {
      this.details = details;
    }
    if (originalError !== undefined) {
      this.originalError = originalError;
    }

    // Maintain proper stack trace
    if (Error.captureStackTrace) {
      Error.captureStackTrace(this, this.constructor);
    }
  }
}

/**
 * Configuration error
 *
 * @class ConfigurationError
 * @extends {SDKError}
 */
export class ConfigurationError extends SDKError {
  constructor(message: string, details?: Record<string, unknown>) {
    super(message, 'CONFIGURATION_ERROR', undefined, details);
    this.name = 'ConfigurationError';
  }
}

/**
 * Authentication error
 *
 * @class AuthenticationError
 * @extends {SDKError}
 */
export class AuthenticationError extends SDKError {
  constructor(message: string, statusCode?: number, details?: Record<string, unknown>) {
    super(message, 'AUTHENTICATION_ERROR', statusCode, details);
    this.name = 'AuthenticationError';
  }
}

/**
 * Connection error
 *
 * @class ConnectionError
 * @extends {SDKError}
 */
export class ConnectionError extends SDKError {
  /** Source that failed to connect */
  public readonly source: HealthSource;

  constructor(
    message: string,
    source: HealthSource,
    statusCode?: number,
    details?: Record<string, unknown>
  ) {
    super(message, 'CONNECTION_ERROR', statusCode, details);
    this.name = 'ConnectionError';
    this.source = source;
  }
}

/**
 * Data fetch error
 *
 * @class DataFetchError
 * @extends {SDKError}
 */
export class DataFetchError extends SDKError {
  /** Source where fetch failed */
  public readonly source: HealthSource;

  /** Data type that failed to fetch */
  public readonly dataType: DataType;

  constructor(
    message: string,
    source: HealthSource,
    dataType: DataType,
    statusCode?: number,
    details?: Record<string, unknown>
  ) {
    super(message, 'DATA_FETCH_ERROR', statusCode, details);
    this.name = 'DataFetchError';
    this.source = source;
    this.dataType = dataType;
  }
}

/**
 * Rate limit error
 *
 * @class RateLimitError
 * @extends {SDKError}
 */
export class RateLimitError extends SDKError {
  /** Timestamp when rate limit resets (ISO 8601) */
  public readonly resetAt: string;

  /** Retry after duration in seconds */
  public readonly retryAfter: number;

  constructor(message: string, resetAt: string, retryAfter: number) {
    super(message, 'RATE_LIMIT_ERROR', 429, { resetAt, retryAfter });
    this.name = 'RateLimitError';
    this.resetAt = resetAt;
    this.retryAfter = retryAfter;
  }
}

/**
 * Validation error
 *
 * @class ValidationError
 * @extends {SDKError}
 */
export class ValidationError extends SDKError {
  /** Fields that failed validation */
  public readonly fields: string[];

  constructor(message: string, fields: string[], details?: Record<string, unknown>) {
    super(message, 'VALIDATION_ERROR', 400, { ...details, fields });
    this.name = 'ValidationError';
    this.fields = fields;
  }
}

/**
 * Plugin error
 *
 * @class PluginError
 * @extends {SDKError}
 */
export class PluginError extends SDKError {
  /** Plugin ID where error occurred */
  public readonly pluginId: string;

  constructor(
    message: string,
    pluginId: string,
    statusCode?: number,
    details?: Record<string, unknown>
  ) {
    super(message, 'PLUGIN_ERROR', statusCode, { ...details, pluginId });
    this.name = 'PluginError';
    this.pluginId = pluginId;
  }
}

/**
 * Cache error
 *
 * @class CacheError
 * @extends {SDKError}
 */
export class CacheError extends SDKError {
  /** Cache layer where error occurred */
  public readonly layer: CacheLayer;

  constructor(message: string, layer: CacheLayer, details?: Record<string, unknown>) {
    super(message, 'CACHE_ERROR', undefined, { ...details, layer });
    this.name = 'CacheError';
    this.layer = layer;
  }
}

/**
 * Sync error
 *
 * @class SyncError
 * @extends {SDKError}
 */
export class SyncError extends SDKError {
  /** Source where sync failed */
  public readonly source?: HealthSource;

  /** Data type where sync failed */
  public readonly dataType?: DataType;

  /** Phase where sync failed */
  public readonly phase: 'connection' | 'fetch' | 'normalize' | 'cache' | 'unknown';

  constructor(
    message: string,
    phase: 'connection' | 'fetch' | 'normalize' | 'cache' | 'unknown',
    source?: HealthSource,
    dataType?: DataType,
    details?: Record<string, unknown>
  ) {
    super(message, 'SYNC_ERROR', undefined, { ...details, phase, source, dataType });
    this.name = 'SyncError';
    if (source !== undefined) {
      this.source = source;
    }
    if (dataType !== undefined) {
      this.dataType = dataType;
    }
    this.phase = phase;
  }
}

/**
 * Network error
 *
 * @class NetworkError
 * @extends {SDKError}
 */
export class NetworkError extends SDKError {
  /** Whether the error is retryable */
  public readonly isRetryable: boolean;

  constructor(
    message: string,
    statusCode?: number,
    isRetryable: boolean = true,
    details?: Record<string, unknown>
  ) {
    super(message, 'NETWORK_ERROR', statusCode, { ...details, isRetryable });
    this.name = 'NetworkError';
    this.isRetryable = isRetryable;
  }
}

/**
 * Default SDK configuration values
 */
export const DEFAULT_SDK_CONFIG: Required<
  Omit<SDKConfig, 'apiBaseUrl' | 'clientId' | 'clientSecret' | 'logger' | 'userId' | 'custom'>
> = {
  environment: 'production',
  cache: {
    enabled: true,
    layers: [CacheLayer.MEMORY, CacheLayer.LOCAL_DB],
    defaultTTL: 24 * 60 * 60 * 1000, // 24 hours
    maxSize: 50, // 50 MB
    useLRU: true,
  },
  retry: {
    maxAttempts: 3,
    initialDelay: 1000,
    maxDelay: 30000,
    backoffMultiplier: 2,
    useJitter: true,
    timeout: 30000,
  },
  logLevel: LogLevel.WARN,
  plugins: [],
  defaultDataTypes: [DataType.STEPS, DataType.HEART_RATE, DataType.SLEEP, DataType.ACTIVITY],
  autoSync: false,
  syncInterval: 0,
  maxDataAge: 90, // 90 days
  enableRealtimeUpdates: false,
};

/**
 * Default sync options
 */
export const DEFAULT_SYNC_OPTIONS: Partial<SyncOptions> = {
  forceFull: false,
  background: false,
  maxConcurrency: 3,
  priority: 1,
};
