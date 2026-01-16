/**
 * HealthSync SDK - Core Package
 *
 * Universal health data integration platform with plugin architecture.
 * Provides unified access to multiple health data sources through a single, elegant API.
 *
 * @module @healthsync/core
 * @version 1.0.0
 */

// ============================================================================
// Unified Data Models
// ============================================================================

export {
  // Enums
  HealthSource,
  DataType,
  DataQuality,
  HeartRateContext,
  SleepStage,
  ActivityType,

  // Interfaces
  type DataMetadata,
  type UnifiedHealthData,
  type StepsData,
  type HeartRateData,
  type SleepData,
  type SleepStageSegment,
  type ActivityData,
  type CaloriesData,
  type DistanceData,
  type BloodOxygenData,
  type BloodPressureData,
  type WeightData,
  type HeartRateVariabilityData,
  type VO2MaxData,
  type AnyHealthData,

  // Type Guards & Utilities
  isDataType,
  isValidHealthData,
} from './models/unified-data';

// ============================================================================
// Plugin System
// ============================================================================

export {
  // Enums
  ConnectionStatus,
  ErrorAction,

  // Interfaces
  type IHealthDataPlugin,
  type PluginConfig,
  type PluginInfo,
  type ConnectionResult,
  type DataQuery,
  type RawHealthData,
  type Subscription,
  type UpdateCallback,
  type RateLimitInfo,

  // Base Class
  BasePlugin,
} from './plugins/plugin-interface';

// ============================================================================
// Configuration & Types
// ============================================================================

export {
  // Enums
  LogLevel,
  CacheLayer,

  // Interfaces
  type SDKConfig,
  type CacheConfig,
  type RetryConfig,
  type Logger,
  type SyncOptions,
  type SyncProgress,
  type SyncResult,
  type SourceSyncResult,
  type DataTypeSyncResult,

  // Callbacks
  type SyncProgressCallback,
  type SyncCompleteCallback,
  type SyncErrorCallback,

  // Error Classes
  SDKError,
  ConfigurationError,
  AuthenticationError,
  ConnectionError,
  DataFetchError,
  RateLimitError,
  ValidationError,
  PluginError,
  CacheError,
  SyncError,
  NetworkError,

  // Default Configurations
  DEFAULT_SDK_CONFIG,
  DEFAULT_SYNC_OPTIONS,
} from './types/config';

// ============================================================================
// Query & Response Types
// ============================================================================

export {
  // Interfaces
  type HealthDataQuery,
  type HealthDataResponse,
  type QueryFilters,
  type QueryMetadata,
  type DataUpdateCallback,
  type SDKEventData,

  // Enums
  SDKEvent,
} from './types/query';

// ============================================================================
// Main SDK
// ============================================================================

export { HealthSyncSDK } from './sdk';

// ============================================================================
// Plugin Registry
// ============================================================================

export { PluginRegistry } from './plugins/plugin-registry';

// ============================================================================
// Health Connect Plugin
// ============================================================================

export {
  HealthConnectPlugin,
  type HealthConnectBridge,
  type HealthConnectRecord,
  HealthConnectPermission,
  HealthConnectRecordType,
  HealthConnectSleepStage,
  HealthConnectExerciseType,
  HealthConnectAvailability,
  type HealthConnectConfig,
  type PermissionStatus,
  HEALTH_CONNECT_TYPE_MAP,
  DEFAULT_HEALTH_CONNECT_CONFIG,
} from './plugins/health-connect';

// ============================================================================
// Data Normalizer
// ============================================================================

export {
  DataNormalizer,
  type NormalizationOptions,
  type NormalizationResult,
} from './normalizer/data-normalizer';

export {
  UnitConverter,
  type TemperatureUnit,
  type DistanceUnit,
  type WeightUnit,
} from './normalizer/unit-converter';

export {
  DataValidator,
  type ValidationResult,
} from './normalizer/validator';

export {
  QualityScorer,
  type QualityFactors,
  type QualityScore,
} from './normalizer/quality-scorer';

// ============================================================================
// Cache System
// ============================================================================

export {
  type ICacheProvider,
  type CacheEntry,
  type CacheKey,
  type CacheStats,
  generateCacheKey,
  parseCacheKey,
} from './cache/cache-provider';

export { MemoryCacheProvider } from './cache/memory-cache';

export {
  CacheManager,
  type CacheManagerConfig,
} from './cache/cache-manager';

// ============================================================================
// Utilities
// ============================================================================

export {
  EventEmitter,
  type EventListener,
  type EventSubscription,
} from './utils/event-emitter';

// ============================================================================
// Version
// ============================================================================

/**
 * Current SDK version
 */
export const VERSION = '1.0.0';

/**
 * SDK name
 */
export const SDK_NAME = 'HealthSync SDK';

/**
 * SDK description
 */
export const SDK_DESCRIPTION = 'Universal health data integration platform';
