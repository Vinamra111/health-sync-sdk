/**
 * Query and Response Types
 *
 * This module defines the types for querying health data and handling responses.
 *
 * @module types/query
 */

import { DataType, HealthSource, UnifiedHealthData, AnyHealthData } from '../models/unified-data';
import { SyncError } from './config';

/**
 * Health data query request
 *
 * @interface HealthDataQuery
 */
export interface HealthDataQuery {
  /** Type of data to query */
  dataType: DataType;

  /** Start date for query range (ISO 8601 format) */
  startDate: string;

  /** End date for query range (ISO 8601 format) */
  endDate: string;

  /** Specific health sources to query (if not specified, query all connected sources) */
  sources?: HealthSource[];

  /** Maximum number of records to return */
  limit?: number;

  /** Offset for pagination */
  offset?: number;

  /** Sort order */
  sortOrder?: 'asc' | 'desc';

  /** Sort by field */
  sortBy?: 'timestamp' | 'source' | 'quality';

  /** Whether to include cached data */
  includeCache?: boolean;

  /** Whether to force a fresh fetch (bypass cache) */
  forceFresh?: boolean;

  /** Additional filters */
  filters?: QueryFilters;
}

/**
 * Additional query filters
 *
 * @interface QueryFilters
 */
export interface QueryFilters {
  /** Minimum quality level */
  minQuality?: 'high' | 'medium' | 'low';

  /** Include only manual entries */
  manualOnly?: boolean;

  /** Include only automatic entries */
  automaticOnly?: boolean;

  /** Filter by device manufacturer */
  manufacturer?: string;

  /** Filter by device model */
  model?: string;

  /** Custom filters */
  custom?: Record<string, unknown>;
}

/**
 * Health data query response
 *
 * @interface HealthDataResponse
 */
export interface HealthDataResponse {
  /** Whether the query was successful */
  success: boolean;

  /** Array of health data records */
  data: AnyHealthData[];

  /** Total count of records matching query (before pagination) */
  totalCount: number;

  /** Number of records returned */
  count: number;

  /** Query metadata */
  metadata: QueryMetadata;

  /** Errors encountered during query (if any) */
  errors?: SyncError[];
}

/**
 * Query execution metadata
 *
 * @interface QueryMetadata
 */
export interface QueryMetadata {
  /** Timestamp when query was executed (ISO 8601) */
  executedAt: string;

  /** Query execution duration in milliseconds */
  duration: number;

  /** Whether results came from cache */
  fromCache: boolean;

  /** Sources that were queried */
  sourcesQueried: HealthSource[];

  /** Sources that returned data */
  sourcesWithData: HealthSource[];

  /** Sources that failed to respond */
  sourcesFailed?: HealthSource[];

  /** Cache hit ratio (0-1) */
  cacheHitRatio?: number;

  /** Additional metadata */
  custom?: Record<string, unknown>;
}

/**
 * Data update callback type
 *
 * @callback DataUpdateCallback
 * @param {UnifiedHealthData[]} data - New or updated health data
 * @returns {void | Promise<void>}
 */
export type DataUpdateCallback = (data: UnifiedHealthData[]) => void | Promise<void>;

/**
 * Event types emitted by the SDK
 *
 * @enum {string}
 */
export enum SDKEvent {
  /** SDK initialized */
  INITIALIZED = 'initialized',

  /** Plugin registered */
  PLUGIN_REGISTERED = 'plugin_registered',

  /** Plugin removed */
  PLUGIN_REMOVED = 'plugin_removed',

  /** Connection established */
  CONNECTED = 'connected',

  /** Connection lost */
  DISCONNECTED = 'disconnected',

  /** Data update received */
  DATA_UPDATE = 'data_update',

  /** Sync started */
  SYNC_STARTED = 'sync_started',

  /** Sync completed */
  SYNC_COMPLETED = 'sync_completed',

  /** Sync failed */
  SYNC_FAILED = 'sync_failed',

  /** Error occurred */
  ERROR = 'error',
}

/**
 * Event data for SDK events
 *
 * @interface SDKEventData
 */
export interface SDKEventData {
  /** Event type */
  event: SDKEvent;

  /** Timestamp when event occurred (ISO 8601) */
  timestamp: string;

  /** Event payload */
  data?: unknown;

  /** Error if applicable */
  error?: Error;
}
