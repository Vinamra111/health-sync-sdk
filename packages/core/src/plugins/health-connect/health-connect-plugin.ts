/**
 * Health Connect Plugin
 *
 * Plugin for Android Health Connect integration.
 * Provides access to unified health and fitness data on Android devices.
 *
 * @module plugins/health-connect/health-connect-plugin
 */

import { BasePlugin } from '../plugin-interface';
import {
  PluginConfig,
  ConnectionResult,
  ConnectionStatus,
  DataQuery,
  RawHealthData,
  Subscription,
  UpdateCallback,
  ErrorAction,
} from '../plugin-interface';
import { DataType, HealthSource } from '../../models/unified-data';
import { AuthenticationError, ConnectionError, DataFetchError, Logger } from '../../types/config';
import {
  HealthConnectConfig,
  HealthConnectPermission,
  HealthConnectAvailability,
  PermissionStatus,
  HEALTH_CONNECT_TYPE_MAP,
  DEFAULT_HEALTH_CONNECT_CONFIG,
} from './types';

/**
 * Health Connect Plugin
 *
 * Integrates with Android Health Connect API to fetch health and fitness data.
 *
 * @class HealthConnectPlugin
 * @extends {BasePlugin}
 */
export class HealthConnectPlugin extends BasePlugin {
  // Required BasePlugin properties
  readonly id: string = 'health-connect';
  readonly name: string = 'Health Connect';
  readonly version: string = '1.0.0';
  readonly supportedDataTypes: readonly DataType[] = [
    DataType.STEPS,
    DataType.HEART_RATE,
    DataType.RESTING_HEART_RATE,
    DataType.SLEEP,
    DataType.ACTIVITY,
    DataType.CALORIES,
    DataType.DISTANCE,
    DataType.BLOOD_OXYGEN,
    DataType.BLOOD_PRESSURE,
    DataType.BODY_TEMPERATURE,
    DataType.WEIGHT,
    DataType.HEIGHT,
    DataType.HEART_RATE_VARIABILITY,
  ];
  readonly requiresAuthentication: boolean = false; // Uses permissions instead
  readonly isCloudBased: boolean = false;

  /** Plugin configuration */
  private hcConfig: Required<HealthConnectConfig>;

  /** Logger instance */
  private logger?: Logger;

  /** Granted permissions */
  private grantedPermissions: Set<HealthConnectPermission> = new Set();

  /** Active subscriptions */
  private subscriptions: Map<string, { callback: UpdateCallback; active: boolean }> = new Map();

  /** Subscription counter for unique IDs */
  private subscriptionCounter: number = 0;

  /** Platform bridge (set by platform-specific code) */
  private platformBridge?: HealthConnectBridge;

  /**
   * Create Health Connect plugin
   *
   * @param {HealthConnectConfig} [config] - Plugin configuration
   */
  constructor(config: HealthConnectConfig = {}) {
    super();

    this.hcConfig = {
      ...DEFAULT_HEALTH_CONNECT_CONFIG,
      ...config,
    };
  }

  /**
   * Set platform bridge
   *
   * Platform-specific code must call this to provide native functionality.
   *
   * @param {HealthConnectBridge} bridge - Platform bridge
   */
  setPlatformBridge(bridge: HealthConnectBridge): void {
    this.platformBridge = bridge;
  }

  /**
   * Initialize plugin
   *
   * @param {PluginConfig} config - Plugin configuration
   * @returns {Promise<void>}
   */
  async initialize(config: PluginConfig): Promise<void> {
    this.config = config;
    // Logger can be passed through custom config if needed
    if (config.custom?.['logger']) {
      this.logger = config.custom['logger'] as Logger;
    }
    this.log('info', 'Initializing Health Connect plugin...');

    // Check availability
    const availability = await this.checkAvailability();

    if (availability !== HealthConnectAvailability.INSTALLED) {
      throw new ConnectionError(
        `Health Connect is ${availability}. Please install Health Connect from Google Play Store.`,
        HealthSource.HEALTH_CONNECT,
        undefined,
        { code: 'HEALTH_CONNECT_NOT_AVAILABLE', availability }
      );
    }

    this.log('info', 'Health Connect plugin initialized');
  }

  /**
   * Dispose plugin
   *
   * @returns {Promise<void>}
   */
  async dispose(): Promise<void> {
    this.log('info', 'Disposing Health Connect plugin...');

    // Clear subscriptions
    this.subscriptions.clear();
    this.grantedPermissions.clear();
    this.connectionStatus = ConnectionStatus.DISCONNECTED;

    this.log('info', 'Health Connect plugin disposed');
  }

  /**
   * Connect to Health Connect
   *
   * @returns {Promise<ConnectionResult>} Connection result
   */
  async connect(): Promise<ConnectionResult> {
    this.log('info', 'Connecting to Health Connect...');

    try {
      // Check availability
      const availability = await this.checkAvailability();

      if (availability !== HealthConnectAvailability.INSTALLED) {
        this.connectionStatus = ConnectionStatus.ERROR;
        return {
          success: false,
          message: `Health Connect is ${availability}`,
          metadata: {
            custom: {
              source: HealthSource.HEALTH_CONNECT,
              availability,
            },
          },
        };
      }

      // Check and request permissions if needed
      if (this.hcConfig.autoRequestPermissions) {
        const allPermissions = this.getAllRequiredPermissions();
        const permissionStatuses = await this.checkPermissions(allPermissions);

        const missingPermissions = permissionStatuses
          .filter(p => !p.granted)
          .map(p => p.permission);

        if (missingPermissions.length > 0) {
          this.log('info', `Requesting ${missingPermissions.length} permissions...`);
          await this.requestPermissions(missingPermissions);
        }
      }

      this.connectionStatus = ConnectionStatus.CONNECTED;

      this.log('info', 'Connected to Health Connect');

      return {
        success: true,
        message: 'Successfully connected to Health Connect',
        metadata: {
          custom: {
            source: HealthSource.HEALTH_CONNECT,
            connectedAt: new Date().toISOString(),
          },
        },
      };
    } catch (error) {
      this.log('error', 'Failed to connect to Health Connect', error as Error);
      this.connectionStatus = ConnectionStatus.ERROR;

      return {
        success: false,
        message: `Connection failed: ${(error as Error).message}`,
        error: error as Error,
        metadata: {
          custom: {
            source: HealthSource.HEALTH_CONNECT,
          },
        },
      };
    }
  }

  /**
   * Disconnect from Health Connect
   *
   * @returns {Promise<void>}
   */
  async disconnect(): Promise<void> {
    this.log('info', 'Disconnecting from Health Connect...');

    this.connectionStatus = ConnectionStatus.DISCONNECTED;
    this.subscriptions.clear();

    this.log('info', 'Disconnected from Health Connect');
  }

  /**
   * Fetch data
   *
   * @param {DataQuery} query - Data query
   * @returns {Promise<RawHealthData[]>} Raw health data
   */
  async fetchData(query: DataQuery): Promise<RawHealthData[]> {
    if (this.connectionStatus !== ConnectionStatus.CONNECTED) {
      throw new ConnectionError(
        'Not connected to Health Connect',
        HealthSource.HEALTH_CONNECT,
        undefined,
        { code: 'NOT_CONNECTED' }
      );
    }

    this.log('info', `Fetching ${query.dataType} data from ${query.startDate} to ${query.endDate}`);

    // Check if data type is supported
    const typeInfo = HEALTH_CONNECT_TYPE_MAP[query.dataType];

    if (!typeInfo || !typeInfo.recordType) {
      throw new DataFetchError(
        `Data type ${query.dataType} is not supported by Health Connect`,
        HealthSource.HEALTH_CONNECT,
        query.dataType,
        undefined,
        { code: 'UNSUPPORTED_DATA_TYPE' }
      );
    }

    // Check if platform bridge is available
    if (!this.platformBridge) {
      this.log('warn', 'Platform bridge not set, returning mock data');
      return this.getMockData(query);
    }

    // Check permissions
    const hasPermission = await this.hasPermissionsForDataType(query.dataType);

    if (!hasPermission) {
      throw new AuthenticationError(
        `Missing permissions for ${query.dataType}`,
        undefined,
        { code: 'MISSING_PERMISSIONS', dataType: query.dataType, source: HealthSource.HEALTH_CONNECT }
      );
    }

    try {
      const readRequest: ReadRecordsRequest = {
        recordType: typeInfo.recordType,
        startTime: new Date(query.startDate),
        endTime: new Date(query.endDate),
      };

      if (query.limit !== undefined) {
        readRequest.limit = query.limit;
      }
      if (query.offset !== undefined) {
        readRequest.offset = query.offset;
      }

      const records = await this.platformBridge.readRecords(readRequest);

      const rawData: RawHealthData[] = records.map(record => {
        const data: RawHealthData = {
          sourceDataType: typeInfo.recordType!,
          source: HealthSource.HEALTH_CONNECT,
          timestamp: record.time || record.startTime || new Date().toISOString(),
          raw: record,
        };

        // Conditionally add endTimestamp to satisfy exactOptionalPropertyTypes
        if (record.endTime !== undefined) {
          data.endTimestamp = record.endTime;
        }

        return data;
      });

      this.log('info', `Fetched ${rawData.length} records`);

      return rawData;
    } catch (error) {
      this.log('error', `Failed to fetch data: ${(error as Error).message}`);

      throw new DataFetchError(
        `Failed to fetch ${query.dataType} data: ${(error as Error).message}`,
        HealthSource.HEALTH_CONNECT,
        query.dataType,
        undefined,
        { code: 'FETCH_FAILED', originalError: error }
      );
    }
  }

  /**
   * Subscribe to data updates
   *
   * @param {UpdateCallback} callback - Update callback
   * @returns {Promise<Subscription>} Subscription
   */
  async subscribeToUpdates(callback: UpdateCallback): Promise<Subscription> {
    const subscriptionId = `hc-sub-${Date.now()}-${++this.subscriptionCounter}`;

    this.subscriptions.set(subscriptionId, {
      callback,
      active: true,
    });

    this.log('info', `Created subscription: ${subscriptionId}`);

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

  /**
   * Handle error
   *
   * @param {Error} error - Error
   * @returns {ErrorAction} Error action
   */
  override handleError(error: Error): ErrorAction {
    if (error.message.includes('permission')) {
      return ErrorAction.RETRY;
    }

    if (error.message.includes('not installed') || error.message.includes('not available')) {
      return ErrorAction.RETRY;
    }

    if (error.message.includes('network') || error.message.includes('timeout')) {
      return ErrorAction.RETRY;
    }

    return ErrorAction.FAIL;
  }

  // ============================================================================
  // Helper Methods
  // ============================================================================

  /**
   * Check Health Connect availability
   *
   * @returns {Promise<HealthConnectAvailability>} Availability status
   * @private
   */
  private async checkAvailability(): Promise<HealthConnectAvailability> {
    if (!this.platformBridge) {
      this.log('warn', 'Platform bridge not set, assuming not supported');
      return HealthConnectAvailability.NOT_SUPPORTED;
    }

    return await this.platformBridge.checkAvailability();
  }

  /**
   * Get all required permissions for supported data types
   *
   * @returns {HealthConnectPermission[]} Required permissions
   * @private
   */
  private getAllRequiredPermissions(): HealthConnectPermission[] {
    const permissions = new Set<HealthConnectPermission>();

    this.supportedDataTypes.forEach((dataType: DataType) => {
      const typeInfo = HEALTH_CONNECT_TYPE_MAP[dataType];
      if (typeInfo) {
        typeInfo.permissions.forEach((p: HealthConnectPermission) => permissions.add(p));
      }
    });

    return Array.from(permissions);
  }

  /**
   * Check permissions
   *
   * @param {HealthConnectPermission[]} permissions - Permissions to check
   * @returns {Promise<PermissionStatus[]>} Permission statuses
   * @private
   */
  private async checkPermissions(
    permissions: HealthConnectPermission[]
  ): Promise<PermissionStatus[]> {
    if (!this.platformBridge) {
      return permissions.map(p => ({
        permission: p,
        granted: false,
        checkedAt: new Date().toISOString(),
      }));
    }

    return await this.platformBridge.checkPermissions(permissions);
  }

  /**
   * Request permissions
   *
   * @param {HealthConnectPermission[]} permissions - Permissions to request
   * @returns {Promise<void>}
   * @private
   */
  private async requestPermissions(permissions: HealthConnectPermission[]): Promise<void> {
    if (!this.platformBridge) {
      this.log('warn', 'Platform bridge not set, cannot request permissions');
      return;
    }

    const granted = await this.platformBridge.requestPermissions(permissions);

    granted.forEach(p => this.grantedPermissions.add(p));

    this.log('info', `Granted ${granted.length} of ${permissions.length} permissions`);
  }

  /**
   * Check if has permissions for data type
   *
   * @param {DataType} dataType - Data type
   * @returns {Promise<boolean>} True if has required permissions
   * @private
   */
  private async hasPermissionsForDataType(dataType: DataType): Promise<boolean> {
    const typeInfo = HEALTH_CONNECT_TYPE_MAP[dataType];

    if (!typeInfo || typeInfo.permissions.length === 0) {
      return true;
    }

    const statuses = await this.checkPermissions(typeInfo.permissions);

    return statuses.every(s => s.granted);
  }

  /**
   * Get mock data for testing
   *
   * @param {DataQuery} query - Data query
   * @returns {RawHealthData[]} Mock data
   * @private
   */
  private getMockData(query: DataQuery): RawHealthData[] {
    const typeInfo = HEALTH_CONNECT_TYPE_MAP[query.dataType];
    const mockRecord: Record<string, unknown> = {
      id: 'mock-record-1',
      time: query.startDate,
      startTime: query.startDate,
      endTime: query.endDate,
      value: 5000,
    };

    return [
      {
        sourceDataType: typeInfo?.recordType || 'Unknown',
        source: HealthSource.HEALTH_CONNECT,
        timestamp: query.startDate,
        endTimestamp: query.endDate,
        raw: mockRecord,
      },
    ];
  }

  /**
   * Log message
   *
   * @param {'info' | 'warn' | 'error'} level - Log level
   * @param {string} message - Message
   * @param {Error} [error] - Optional error
   * @private
   */
  private log(level: 'info' | 'warn' | 'error', message: string, error?: Error): void {
    if (!this.logger) {
      return;
    }

    const msg = `[HealthConnect] ${message}`;

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

/**
 * Read records request
 *
 * @interface ReadRecordsRequest
 */
interface ReadRecordsRequest {
  recordType: string;
  startTime: Date;
  endTime: Date;
  limit?: number;
  offset?: number;
}

/**
 * Health Connect Bridge Interface
 *
 * Platform-specific code must implement this interface to provide
 * native Health Connect functionality.
 *
 * @interface HealthConnectBridge
 */
export interface HealthConnectBridge {
  /**
   * Check Health Connect availability
   *
   * @returns {Promise<HealthConnectAvailability>} Availability status
   */
  checkAvailability(): Promise<HealthConnectAvailability>;

  /**
   * Check permissions
   *
   * @param {HealthConnectPermission[]} permissions - Permissions to check
   * @returns {Promise<PermissionStatus[]>} Permission statuses
   */
  checkPermissions(permissions: HealthConnectPermission[]): Promise<PermissionStatus[]>;

  /**
   * Request permissions
   *
   * @param {HealthConnectPermission[]} permissions - Permissions to request
   * @returns {Promise<HealthConnectPermission[]>} Granted permissions
   */
  requestPermissions(permissions: HealthConnectPermission[]): Promise<HealthConnectPermission[]>;

  /**
   * Read records
   *
   * @param {ReadRecordsRequest} request - Read request
   * @returns {Promise<HealthConnectRecord[]>} Health Connect records
   */
  readRecords(request: ReadRecordsRequest): Promise<HealthConnectRecord[]>;
}

/**
 * Health Connect Record
 *
 * @interface HealthConnectRecord
 */
export interface HealthConnectRecord {
  /** Record ID */
  id?: string;

  /** Timestamp (for instantaneous records) */
  time?: string;

  /** Start time (for interval records) */
  startTime?: string;

  /** End time (for interval records) */
  endTime?: string;

  /** Record data */
  [key: string]: unknown;
}
