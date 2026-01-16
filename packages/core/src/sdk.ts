/**
 * HealthSync SDK - Main Entry Point
 *
 * Central coordination and configuration hub for the HealthSync SDK.
 * Provides unified access to multiple health data sources through plugins.
 *
 * @module sdk
 */

import { HealthSource, UnifiedHealthData } from './models/unified-data';
import {
  IHealthDataPlugin,
  PluginInfo,
  ConnectionResult,
  ConnectionStatus,
  DataQuery as PluginDataQuery,
} from './plugins/plugin-interface';
import { PluginRegistry } from './plugins/plugin-registry';
import {
  SDKConfig,
  SyncOptions,
  SyncResult,
  SourceSyncResult,
  DataTypeSyncResult,
  DEFAULT_SDK_CONFIG,
  DEFAULT_SYNC_OPTIONS,
  ConnectionError,
  SyncError,
  LogLevel,
  Logger,
} from './types/config';
import {
  HealthDataQuery,
  HealthDataResponse,
  DataUpdateCallback,
  SDKEvent,
  SDKEventData,
} from './types/query';
import { EventEmitter, EventSubscription } from './utils/event-emitter';
import { DataNormalizer } from './normalizer/data-normalizer';
import { CacheManager, CacheManagerConfig } from './cache/cache-manager';

/**
 * SDK Events type map
 */
type SDKEvents = {
  [SDKEvent.INITIALIZED]: SDKEventData;
  [SDKEvent.PLUGIN_REGISTERED]: SDKEventData;
  [SDKEvent.PLUGIN_REMOVED]: SDKEventData;
  [SDKEvent.CONNECTED]: SDKEventData;
  [SDKEvent.DISCONNECTED]: SDKEventData;
  [SDKEvent.DATA_UPDATE]: SDKEventData;
  [SDKEvent.SYNC_STARTED]: SDKEventData;
  [SDKEvent.SYNC_COMPLETED]: SDKEventData;
  [SDKEvent.SYNC_FAILED]: SDKEventData;
  [SDKEvent.ERROR]: SDKEventData;
};

/**
 * Default console logger
 */
const defaultLogger: Logger = {
  debug: (message: string, ...args: unknown[]): void => {
    console.debug(`[HealthSync DEBUG] ${message}`, ...args);
  },
  info: (message: string, ...args: unknown[]): void => {
    console.info(`[HealthSync INFO] ${message}`, ...args);
  },
  warn: (message: string, ...args: unknown[]): void => {
    console.warn(`[HealthSync WARN] ${message}`, ...args);
  },
  error: (message: string, error?: Error, ...args: unknown[]): void => {
    console.error(`[HealthSync ERROR] ${message}`, error, ...args);
  },
};

/**
 * HealthSync SDK
 *
 * Main SDK class providing unified access to health data sources.
 * Manages plugins, connections, queries, and synchronization.
 *
 * @class HealthSyncSDK
 */
export class HealthSyncSDK {
  /** SDK configuration */
  private config: SDKConfig;

  /** Plugin registry */
  private pluginRegistry: PluginRegistry;

  /** Event emitter */
  private eventEmitter: EventEmitter<SDKEvents>;

  /** Logger instance */
  private logger: Logger;

  /** Data normalizer */
  private normalizer: DataNormalizer;

  /** Cache manager */
  private cacheManager: CacheManager;

  /** Singleton instance */
  private static instance: HealthSyncSDK | null = null;

  /**
   * Private constructor (use static initialize method)
   *
   * @param {SDKConfig} config - SDK configuration
   * @private
   */
  private constructor(config: SDKConfig) {
    this.config = {
      ...DEFAULT_SDK_CONFIG,
      ...config,
      cache: { ...DEFAULT_SDK_CONFIG.cache, ...config.cache },
      retry: { ...DEFAULT_SDK_CONFIG.retry, ...config.retry },
    };

    this.logger = config.logger ?? defaultLogger;
    this.pluginRegistry = new PluginRegistry();
    this.eventEmitter = new EventEmitter<SDKEvents>();
    this.normalizer = new DataNormalizer({
      validate: true,
      calculateQuality: true,
      strictValidation: false,
    });
    // Build cache manager configuration
    const cacheManagerConfig: CacheManagerConfig = {
      enabled: this.config.cache?.enabled ?? true,
      logger: this.logger,
    };

    if (this.config.cache?.defaultTTL !== undefined) {
      cacheManagerConfig.defaultTTL = this.config.cache.defaultTTL;
    }

    if (this.config.cache?.ttlByDataType !== undefined) {
      cacheManagerConfig.ttlByDataType = this.config.cache.ttlByDataType;
    }

    if (this.config.cache?.maxSize !== undefined) {
      // Convert MB to approximate entry count (assuming ~1KB per entry)
      cacheManagerConfig.maxMemoryEntries = this.config.cache.maxSize * 1024;
    }

    this.cacheManager = new CacheManager(cacheManagerConfig);
  }

  /**
   * Initialize the SDK
   *
   * Creates a singleton instance of the SDK with the provided configuration.
   * If an instance already exists, it will be disposed and a new one created.
   *
   * @param {SDKConfig} config - SDK configuration
   * @returns {Promise<HealthSyncSDK>} Initialized SDK instance
   * @throws {ConfigurationError} If configuration is invalid
   */
  static async initialize(config: SDKConfig): Promise<HealthSyncSDK> {
    // Dispose existing instance if present
    if (HealthSyncSDK.instance) {
      await HealthSyncSDK.instance.dispose();
    }

    const sdk = new HealthSyncSDK(config);
    await sdk.init();

    HealthSyncSDK.instance = sdk;
    return sdk;
  }

  /**
   * Get the current SDK instance
   *
   * @returns {HealthSyncSDK | null} SDK instance or null if not initialized
   */
  static getInstance(): HealthSyncSDK | null {
    return HealthSyncSDK.instance;
  }

  /**
   * Internal initialization
   *
   * @returns {Promise<void>}
   * @private
   */
  private async init(): Promise<void> {
    this.log(LogLevel.INFO, 'Initializing HealthSync SDK...');

    // Register provided plugins
    if (this.config.plugins && this.config.plugins.length > 0) {
      for (const plugin of this.config.plugins) {
        this.registerPlugin(plugin);
      }
    }

    this.log(LogLevel.INFO, 'HealthSync SDK initialized successfully');

    // Emit initialized event
    await this.emitEvent(SDKEvent.INITIALIZED, {
      event: SDKEvent.INITIALIZED,
      timestamp: new Date().toISOString(),
      data: { pluginCount: this.pluginRegistry.count() },
    });
  }

  // ============================================================================
  // Plugin Management
  // ============================================================================

  /**
   * Register a plugin
   *
   * @param {IHealthDataPlugin} plugin - Plugin to register
   * @returns {void}
   * @throws {PluginError} If plugin is invalid or already registered
   */
  registerPlugin(plugin: IHealthDataPlugin): void {
    this.log(LogLevel.INFO, `Registering plugin: ${plugin.name} (${plugin.id})`);

    this.pluginRegistry.register(plugin);

    // Emit plugin registered event
    this.emitEvent(SDKEvent.PLUGIN_REGISTERED, {
      event: SDKEvent.PLUGIN_REGISTERED,
      timestamp: new Date().toISOString(),
      data: { pluginId: plugin.id, pluginName: plugin.name },
    }).catch((error) => {
      this.log(LogLevel.ERROR, 'Error emitting plugin registered event', error);
    });
  }

  /**
   * Unregister a plugin
   *
   * @param {string} pluginId - ID of the plugin to unregister
   * @returns {Promise<void>}
   * @throws {PluginError} If plugin is not found
   */
  async unregisterPlugin(pluginId: string): Promise<void> {
    this.log(LogLevel.INFO, `Unregistering plugin: ${pluginId}`);

    await this.pluginRegistry.unregister(pluginId);

    // Emit plugin removed event
    await this.emitEvent(SDKEvent.PLUGIN_REMOVED, {
      event: SDKEvent.PLUGIN_REMOVED,
      timestamp: new Date().toISOString(),
      data: { pluginId },
    });
  }

  /**
   * Get available plugins
   *
   * @returns {Promise<PluginInfo[]>} Array of plugin information
   */
  async getAvailablePlugins(): Promise<PluginInfo[]> {
    return this.pluginRegistry.getPluginInfo();
  }

  /**
   * Get active (connected) plugins
   *
   * @returns {IHealthDataPlugin[]} Array of connected plugins
   */
  getActivePlugins(): IHealthDataPlugin[] {
    return this.pluginRegistry.getConnectedPlugins();
  }

  // ============================================================================
  // Connection Management
  // ============================================================================

  /**
   * Connect to a health data source
   *
   * @param {HealthSource} source - Health source to connect to
   * @returns {Promise<ConnectionResult>} Connection result
   * @throws {ConnectionError} If connection fails
   */
  async connect(source: HealthSource): Promise<ConnectionResult> {
    this.log(LogLevel.INFO, `Connecting to ${source}...`);

    const plugin = this.pluginRegistry.getPluginBySource(source);
    if (!plugin) {
      throw new ConnectionError(
        `No plugin registered for source: ${source}`,
        source,
        404
      );
    }

    try {
      // Initialize plugin if not already initialized
      if (!this.pluginRegistry.isInitialized(plugin.id)) {
        this.log(LogLevel.DEBUG, `Initializing plugin ${plugin.id}...`);
        await plugin.initialize({});
        this.pluginRegistry.markInitialized(plugin.id);
      }

      // Update status to connecting
      this.pluginRegistry.updateConnectionStatus(plugin.id, ConnectionStatus.CONNECTING);

      // Attempt connection
      const result = await plugin.connect();

      // Update status based on result
      const newStatus = result.success ? ConnectionStatus.CONNECTED : ConnectionStatus.ERROR;
      this.pluginRegistry.updateConnectionStatus(plugin.id, newStatus);

      if (result.success) {
        this.log(LogLevel.INFO, `Successfully connected to ${source}`);

        // Emit connected event
        await this.emitEvent(SDKEvent.CONNECTED, {
          event: SDKEvent.CONNECTED,
          timestamp: new Date().toISOString(),
          data: { source, pluginId: plugin.id, result },
        });
      } else {
        this.log(LogLevel.WARN, `Failed to connect to ${source}: ${result.message}`);
      }

      return result;
    } catch (error) {
      this.pluginRegistry.updateConnectionStatus(plugin.id, ConnectionStatus.ERROR);
      this.log(LogLevel.ERROR, `Error connecting to ${source}`, error as Error);

      throw new ConnectionError(
        `Failed to connect to ${source}: ${(error as Error).message}`,
        source,
        500,
        { originalError: error }
      );
    }
  }

  /**
   * Disconnect from a health data source
   *
   * @param {HealthSource} source - Health source to disconnect from
   * @returns {Promise<void>}
   * @throws {ConnectionError} If disconnection fails
   */
  async disconnect(source: HealthSource): Promise<void> {
    this.log(LogLevel.INFO, `Disconnecting from ${source}...`);

    const plugin = this.pluginRegistry.getPluginBySource(source);
    if (!plugin) {
      throw new ConnectionError(
        `No plugin registered for source: ${source}`,
        source,
        404
      );
    }

    try {
      this.pluginRegistry.updateConnectionStatus(plugin.id, ConnectionStatus.DISCONNECTING);

      await plugin.disconnect();

      this.pluginRegistry.updateConnectionStatus(plugin.id, ConnectionStatus.DISCONNECTED);

      this.log(LogLevel.INFO, `Successfully disconnected from ${source}`);

      // Emit disconnected event
      await this.emitEvent(SDKEvent.DISCONNECTED, {
        event: SDKEvent.DISCONNECTED,
        timestamp: new Date().toISOString(),
        data: { source, pluginId: plugin.id },
      });
    } catch (error) {
      this.log(LogLevel.ERROR, `Error disconnecting from ${source}`, error as Error);

      throw new ConnectionError(
        `Failed to disconnect from ${source}: ${(error as Error).message}`,
        source,
        500,
        { originalError: error }
      );
    }
  }

  /**
   * Get connection status for a health source
   *
   * @param {HealthSource} source - Health source
   * @returns {ConnectionStatus} Connection status
   */
  getConnectionStatus(source: HealthSource): ConnectionStatus {
    const plugin = this.pluginRegistry.getPluginBySource(source);
    if (!plugin) {
      return ConnectionStatus.DISCONNECTED;
    }

    return this.pluginRegistry.getConnectionStatus(plugin.id);
  }

  // ============================================================================
  // Data Operations
  // ============================================================================

  /**
   * Query health data
   *
   * @param {HealthDataQuery} request - Query request
   * @returns {Promise<HealthDataResponse>} Query response with data
   * @throws {DataFetchError} If query fails
   */
  async query(request: HealthDataQuery): Promise<HealthDataResponse> {
    const startTime = Date.now();
    this.log(LogLevel.INFO, `Querying ${request.dataType} from ${request.startDate} to ${request.endDate}`);

    const sources = request.sources ?? this.getActivePlugins().map((p) => this.getSourceForPlugin(p));
    const allData: UnifiedHealthData[] = [];
    const errors: SyncError[] = [];
    const sourcesQueried: HealthSource[] = [];
    const sourcesWithData: HealthSource[] = [];
    const sourcesFailed: HealthSource[] = [];
    let fromCache = false;

    for (const source of sources) {
      if (source === HealthSource.UNKNOWN) {
        continue;
      }

      sourcesQueried.push(source);

      try {
        const plugin = this.pluginRegistry.getPluginBySource(source);
        if (!plugin) {
          this.log(LogLevel.WARN, `No plugin for source: ${source}`);
          continue;
        }

        // Check if plugin is connected
        const status = this.pluginRegistry.getConnectionStatus(plugin.id);
        if (status !== ConnectionStatus.CONNECTED) {
          this.log(LogLevel.WARN, `Plugin ${plugin.id} is not connected`);
          sourcesFailed.push(source);
          continue;
        }

        // Check cache first
        const cacheKey = {
          source,
          dataType: request.dataType,
          startDate: request.startDate,
          endDate: request.endDate,
          params: {
            limit: request.limit,
            offset: request.offset,
            sortOrder: request.sortOrder,
          },
        };

        const cachedData = await this.cacheManager.get(cacheKey);

        if (cachedData && cachedData.length > 0) {
          this.log(LogLevel.DEBUG, `Using cached data for ${source}`);
          sourcesWithData.push(source);
          allData.push(...cachedData);
          fromCache = true;
          continue;
        }

        // Build plugin query
        const pluginQuery: PluginDataQuery = {
          dataType: request.dataType,
          startDate: request.startDate,
          endDate: request.endDate,
        };

        if (request.limit !== undefined) {
          pluginQuery.limit = request.limit;
        }
        if (request.offset !== undefined) {
          pluginQuery.offset = request.offset;
        }
        if (request.sortOrder !== undefined) {
          pluginQuery.sortOrder = request.sortOrder;
        }

        // Fetch raw data
        const rawData = await plugin.fetchData(pluginQuery);

        // Normalize data
        const normalizationResult = this.normalizer.normalize(rawData);

        if (normalizationResult.data.length > 0) {
          sourcesWithData.push(source);
          allData.push(...normalizationResult.data);

          // Cache the normalized data
          await this.cacheManager.set(cacheKey, normalizationResult.data);
        }

        // Log normalization warnings
        if (normalizationResult.warnings.length > 0) {
          this.log(
            LogLevel.WARN,
            `Normalization warnings for ${source}: ${normalizationResult.warnings.join(', ')}`
          );
        }
      } catch (error) {
        this.log(LogLevel.ERROR, `Error querying ${source}`, error as Error);
        sourcesFailed.push(source);
        errors.push(
          new SyncError(
            `Failed to query ${source}: ${(error as Error).message}`,
            'fetch',
            source,
            request.dataType
          )
        );
      }
    }

    const duration = Date.now() - startTime;

    const response: HealthDataResponse = {
      success: allData.length > 0 || errors.length === 0,
      data: allData,
      totalCount: allData.length,
      count: allData.length,
      metadata: {
        executedAt: new Date().toISOString(),
        duration,
        fromCache,
        sourcesQueried,
        sourcesWithData,
      },
    };

    if (sourcesFailed.length > 0) {
      response.metadata.sourcesFailed = sourcesFailed;
    }

    if (errors.length > 0) {
      response.errors = errors;
    }

    return response;
  }

  /**
   * Sync health data
   *
   * @param {SyncOptions} [options] - Sync options
   * @returns {Promise<SyncResult>} Sync result
   */
  async sync(options?: SyncOptions): Promise<SyncResult> {
    const opts = { ...DEFAULT_SYNC_OPTIONS, ...options };
    const startTime = Date.now();
    const startedAt = new Date().toISOString();

    this.log(LogLevel.INFO, 'Starting data sync...');

    // Emit sync started event
    await this.emitEvent(SDKEvent.SYNC_STARTED, {
      event: SDKEvent.SYNC_STARTED,
      timestamp: startedAt,
      data: { options: opts },
    });

    const sources = opts.sources ?? this.getActivePlugins().map((p) => this.getSourceForPlugin(p));
    const dataTypes = opts.dataTypes ?? this.config.defaultDataTypes ?? [];

    const sourceResults: SourceSyncResult[] = [];
    let totalRecords = 0;
    let newRecords = 0;
    let updatedRecords = 0;
    let failedRecords = 0;
    const errors: SyncError[] = [];

    for (const source of sources) {
      if (source === HealthSource.UNKNOWN) {
        continue;
      }

      const dataTypeResults: DataTypeSyncResult[] = [];
      let sourceRecordCount = 0;
      let sourceSuccess = true;

      for (const dataType of dataTypes) {
        try {
          const query: HealthDataQuery = {
            dataType,
            startDate: opts.startDate ?? new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString(),
            endDate: opts.endDate ?? new Date().toISOString(),
            sources: [source],
          };

          const response = await this.query(query);
          const recordCount = response.data.length;

          dataTypeResults.push({
            dataType,
            success: true,
            recordCount,
          });

          sourceRecordCount += recordCount;
          totalRecords += recordCount;
          newRecords += recordCount; // TODO: Differentiate new vs updated
        } catch (error) {
          sourceSuccess = false;
          failedRecords++;

          dataTypeResults.push({
            dataType,
            success: false,
            recordCount: 0,
            error: error as Error,
          });

          errors.push(
            new SyncError(
              `Sync failed for ${source} - ${dataType}`,
              'fetch',
              source,
              dataType
            )
          );
        }
      }

      sourceResults.push({
        source,
        success: sourceSuccess,
        recordCount: sourceRecordCount,
        dataTypeResults,
      });
    }

    const completedAt = new Date().toISOString();
    const duration = Date.now() - startTime;

    const result: SyncResult = {
      success: errors.length === 0,
      totalRecords,
      newRecords,
      updatedRecords,
      failedRecords,
      startedAt,
      completedAt,
      duration,
      sourceResults,
    };

    if (errors.length > 0) {
      result.errors = errors;
    }

    this.log(LogLevel.INFO, `Sync completed: ${totalRecords} records in ${duration}ms`);

    // Emit sync completed event
    await this.emitEvent(SDKEvent.SYNC_COMPLETED, {
      event: SDKEvent.SYNC_COMPLETED,
      timestamp: completedAt,
      data: { result },
    });

    // Call completion callback if provided
    if (opts.onComplete) {
      opts.onComplete(result);
    }

    return result;
  }

  /**
   * Subscribe to data updates
   *
   * @param {DataUpdateCallback} callback - Callback function for data updates
   * @returns {EventSubscription} Subscription object
   */
  subscribe(callback: DataUpdateCallback): EventSubscription {
    return this.eventEmitter.on(SDKEvent.DATA_UPDATE, (eventData) => {
      if (eventData.data && Array.isArray(eventData.data)) {
        callback(eventData.data as UnifiedHealthData[]);
      }
    });
  }

  /**
   * Subscribe to SDK events
   *
   * @param {SDKEvent} event - Event to subscribe to
   * @param {(data: SDKEventData) => void} callback - Callback function
   * @returns {EventSubscription} Subscription object
   */
  on(event: SDKEvent, callback: (data: SDKEventData) => void): EventSubscription {
    return this.eventEmitter.on(event, callback);
  }

  // ============================================================================
  // Lifecycle
  // ============================================================================

  /**
   * Dispose the SDK
   *
   * Cleans up all resources, disconnects plugins, and clears state.
   *
   * @returns {Promise<void>}
   */
  async dispose(): Promise<void> {
    this.log(LogLevel.INFO, 'Disposing HealthSync SDK...');

    // Clear event listeners
    this.eventEmitter.clear();

    // Dispose cache manager
    await this.cacheManager.dispose();

    // Dispose all plugins
    await this.pluginRegistry.clear();

    if (HealthSyncSDK.instance === this) {
      HealthSyncSDK.instance = null;
    }

    this.log(LogLevel.INFO, 'HealthSync SDK disposed');
  }

  // ============================================================================
  // Helper Methods
  // ============================================================================

  /**
   * Log a message
   *
   * @param {LogLevel} level - Log level
   * @param {string} message - Message to log
   * @param {Error} [error] - Optional error object
   * @private
   */
  private log(level: LogLevel, message: string, error?: Error): void {
    if (this.shouldLog(level)) {
      switch (level) {
        case LogLevel.DEBUG:
          this.logger.debug(message);
          break;
        case LogLevel.INFO:
          this.logger.info(message);
          break;
        case LogLevel.WARN:
          this.logger.warn(message);
          break;
        case LogLevel.ERROR:
          this.logger.error(message, error);
          break;
      }
    }
  }

  /**
   * Check if a log level should be logged
   *
   * @param {LogLevel} level - Log level to check
   * @returns {boolean} True if should log
   * @private
   */
  private shouldLog(level: LogLevel): boolean {
    const levels = [LogLevel.NONE, LogLevel.ERROR, LogLevel.WARN, LogLevel.INFO, LogLevel.DEBUG];
    const configLevelIndex = levels.indexOf(this.config.logLevel ?? LogLevel.WARN);
    const messageLevelIndex = levels.indexOf(level);

    return messageLevelIndex <= configLevelIndex;
  }

  /**
   * Emit an SDK event
   *
   * @param {SDKEvent} event - Event type
   * @param {SDKEventData} data - Event data
   * @returns {Promise<void>}
   * @private
   */
  private async emitEvent(event: SDKEvent, data: SDKEventData): Promise<void> {
    await this.eventEmitter.emit(event, data);
  }

  /**
   * Get health source for a plugin
   *
   * @param {IHealthDataPlugin} plugin - Plugin
   * @returns {HealthSource} Health source
   * @private
   */
  private getSourceForPlugin(plugin: IHealthDataPlugin): HealthSource {
    // Map plugin ID to health source
    const mapping: Record<string, HealthSource> = {
      'health-connect': HealthSource.HEALTH_CONNECT,
      'health_connect': HealthSource.HEALTH_CONNECT,
      'apple-health': HealthSource.APPLE_HEALTH,
      'apple_health': HealthSource.APPLE_HEALTH,
      healthkit: HealthSource.APPLE_HEALTH,
      fitbit: HealthSource.FITBIT,
      garmin: HealthSource.GARMIN,
      oura: HealthSource.OURA,
      whoop: HealthSource.WHOOP,
      strava: HealthSource.STRAVA,
      myfitnesspal: HealthSource.MYFITNESSPAL,
    };

    return mapping[plugin.id.toLowerCase()] ?? HealthSource.UNKNOWN;
  }
}
