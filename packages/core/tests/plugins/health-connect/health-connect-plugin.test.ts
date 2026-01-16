/**
 * Health Connect Plugin Tests
 *
 * Tests for Android Health Connect plugin
 */

import {
  HealthConnectPlugin,
  HealthConnectBridge,
  HealthConnectAvailability,
  HealthConnectPermission,
  HealthConnectRecordType,
  HealthConnectRecord,
  PermissionStatus,
} from '../../../src/plugins/health-connect';
import { DataType, HealthSource } from '../../../src/models/unified-data';
import { ConnectionStatus } from '../../../src/plugins/plugin-interface';
import {
  ConnectionError,
  AuthenticationError,
  DataFetchError,
} from '../../../src/types/config';

describe('HealthConnectPlugin', () => {
  let plugin: HealthConnectPlugin;
  let mockBridge: jest.Mocked<HealthConnectBridge>;

  beforeEach(() => {
    // Create mock platform bridge
    mockBridge = {
      checkAvailability: jest.fn(),
      checkPermissions: jest.fn(),
      requestPermissions: jest.fn(),
      readRecords: jest.fn(),
    };

    plugin = new HealthConnectPlugin({
      autoRequestPermissions: false, // Disable auto-request for testing
    });

    plugin.setPlatformBridge(mockBridge);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  // ============================================================================
  // Plugin Metadata
  // ============================================================================

  describe('Plugin Metadata', () => {
    it('should have correct plugin ID', () => {
      expect(plugin.id).toBe('health-connect');
    });

    it('should have correct plugin name', () => {
      expect(plugin.name).toBe('Health Connect');
    });

    it('should have correct version', () => {
      expect(plugin.version).toBe('1.0.0');
    });

    it('should support correct data types', () => {
      expect(plugin.supportedDataTypes).toContain(DataType.STEPS);
      expect(plugin.supportedDataTypes).toContain(DataType.HEART_RATE);
      expect(plugin.supportedDataTypes).toContain(DataType.SLEEP);
      expect(plugin.supportedDataTypes).toContain(DataType.ACTIVITY);
      expect(plugin.supportedDataTypes.length).toBe(13);
    });

    it('should not require authentication', () => {
      expect(plugin.requiresAuthentication).toBe(false);
    });

    it('should not be cloud-based', () => {
      expect(plugin.isCloudBased).toBe(false);
    });

    it('should return plugin info', async () => {
      const info = await plugin.getInfo();

      expect(info.id).toBe('health-connect');
      expect(info.name).toBe('Health Connect');
      expect(info.version).toBe('1.0.0');
      expect(info.supportedDataTypes).toEqual(plugin.supportedDataTypes);
      expect(info.requiresAuthentication).toBe(false);
      expect(info.isCloudBased).toBe(false);
    });
  });

  // ============================================================================
  // Initialization
  // ============================================================================

  describe('Initialization', () => {
    it('should initialize successfully when Health Connect is installed', async () => {
      mockBridge.checkAvailability.mockResolvedValue(HealthConnectAvailability.INSTALLED);

      await expect(
        plugin.initialize({
          custom: {
            logger: {
              debug: jest.fn(),
              info: jest.fn(),
              warn: jest.fn(),
              error: jest.fn(),
            },
          },
        })
      ).resolves.not.toThrow();

      expect(mockBridge.checkAvailability).toHaveBeenCalledTimes(1);
    });

    it('should throw ConnectionError when Health Connect is not installed', async () => {
      mockBridge.checkAvailability.mockResolvedValue(HealthConnectAvailability.NOT_INSTALLED);

      await expect(
        plugin.initialize({})
      ).rejects.toThrow(ConnectionError);

      await expect(
        plugin.initialize({})
      ).rejects.toThrow('Please install Health Connect from Google Play Store');
    });

    it('should throw ConnectionError when Health Connect is not supported', async () => {
      mockBridge.checkAvailability.mockResolvedValue(HealthConnectAvailability.NOT_SUPPORTED);

      await expect(
        plugin.initialize({})
      ).rejects.toThrow(ConnectionError);
    });

    it('should accept custom configuration', () => {
      const customPlugin = new HealthConnectPlugin({
        packageName: 'com.custom.healthconnect',
        autoRequestPermissions: true,
        batchSize: 500,
        enableBackgroundSync: true,
        syncInterval: 30000,
      });

      expect(customPlugin).toBeDefined();
    });
  });

  // ============================================================================
  // Connection Management
  // ============================================================================

  describe('Connection Management', () => {
    beforeEach(async () => {
      mockBridge.checkAvailability.mockResolvedValue(HealthConnectAvailability.INSTALLED);
      await plugin.initialize({});
    });

    it('should connect successfully when Health Connect is available', async () => {
      const result = await plugin.connect();

      expect(result.success).toBe(true);
      expect(result.message).toBe('Successfully connected to Health Connect');
      expect(result.metadata?.custom?.source).toBe(HealthSource.HEALTH_CONNECT);
      expect(await plugin.isConnected()).toBe(true);
      expect(await plugin.getConnectionStatus()).toBe(ConnectionStatus.CONNECTED);
    });

    it('should fail to connect when Health Connect becomes unavailable', async () => {
      mockBridge.checkAvailability.mockResolvedValue(HealthConnectAvailability.NOT_INSTALLED);

      const result = await plugin.connect();

      expect(result.success).toBe(false);
      expect(result.message).toContain('not_installed');
      expect(await plugin.isConnected()).toBe(false);
      expect(await plugin.getConnectionStatus()).toBe(ConnectionStatus.ERROR);
    });

    it('should request permissions when autoRequestPermissions is enabled', async () => {
      const pluginWithAutoPermissions = new HealthConnectPlugin({
        autoRequestPermissions: true,
      });
      pluginWithAutoPermissions.setPlatformBridge(mockBridge);

      await pluginWithAutoPermissions.initialize({});

      mockBridge.checkPermissions.mockResolvedValue([
        {
          permission: HealthConnectPermission.READ_STEPS,
          granted: false,
          checkedAt: new Date().toISOString(),
        },
      ]);

      mockBridge.requestPermissions.mockResolvedValue([
        HealthConnectPermission.READ_STEPS,
      ]);

      await pluginWithAutoPermissions.connect();

      expect(mockBridge.checkPermissions).toHaveBeenCalled();
      expect(mockBridge.requestPermissions).toHaveBeenCalled();
    });

    it('should disconnect successfully', async () => {
      await plugin.connect();
      await plugin.disconnect();

      expect(await plugin.isConnected()).toBe(false);
      expect(await plugin.getConnectionStatus()).toBe(ConnectionStatus.DISCONNECTED);
    });

    it('should handle connection errors gracefully', async () => {
      mockBridge.checkAvailability.mockRejectedValue(new Error('Platform error'));

      const result = await plugin.connect();

      expect(result.success).toBe(false);
      expect(result.error).toBeDefined();
      expect(result.message).toContain('Platform error');
    });
  });

  // ============================================================================
  // Data Fetching
  // ============================================================================

  describe('Data Fetching', () => {
    beforeEach(async () => {
      mockBridge.checkAvailability.mockResolvedValue(HealthConnectAvailability.INSTALLED);
      await plugin.initialize({});
      await plugin.connect();
    });

    it('should fetch steps data successfully', async () => {
      const mockRecords: HealthConnectRecord[] = [
        {
          id: 'record-1',
          time: '2024-01-15T10:00:00Z',
          count: 5000,
        },
        {
          id: 'record-2',
          time: '2024-01-15T11:00:00Z',
          count: 3000,
        },
      ];

      mockBridge.checkPermissions.mockResolvedValue([
        {
          permission: HealthConnectPermission.READ_STEPS,
          granted: true,
          checkedAt: new Date().toISOString(),
        },
      ]);

      mockBridge.readRecords.mockResolvedValue(mockRecords);

      const result = await plugin.fetchData({
        dataType: DataType.STEPS,
        startDate: '2024-01-15T00:00:00Z',
        endDate: '2024-01-15T23:59:59Z',
      });

      expect(result).toHaveLength(2);
      expect(result[0].sourceDataType).toBe(HealthConnectRecordType.STEPS);
      expect(result[0].source).toBe(HealthSource.HEALTH_CONNECT);
      expect(result[0].timestamp).toBe('2024-01-15T10:00:00Z');
      expect(result[0].raw).toEqual(mockRecords[0]);

      expect(mockBridge.readRecords).toHaveBeenCalledWith({
        recordType: HealthConnectRecordType.STEPS,
        startTime: new Date('2024-01-15T00:00:00Z'),
        endTime: new Date('2024-01-15T23:59:59Z'),
      });
    });

    it('should fetch heart rate data with endTimestamp', async () => {
      const mockRecords: HealthConnectRecord[] = [
        {
          id: 'record-1',
          startTime: '2024-01-15T10:00:00Z',
          endTime: '2024-01-15T10:05:00Z',
          bpm: 75,
        },
      ];

      mockBridge.checkPermissions.mockResolvedValue([
        {
          permission: HealthConnectPermission.READ_HEART_RATE,
          granted: true,
          checkedAt: new Date().toISOString(),
        },
      ]);

      mockBridge.readRecords.mockResolvedValue(mockRecords);

      const result = await plugin.fetchData({
        dataType: DataType.HEART_RATE,
        startDate: '2024-01-15T00:00:00Z',
        endDate: '2024-01-15T23:59:59Z',
      });

      expect(result).toHaveLength(1);
      expect(result[0].timestamp).toBe('2024-01-15T10:00:00Z');
      expect(result[0].endTimestamp).toBe('2024-01-15T10:05:00Z');
    });

    it('should handle limit and offset parameters', async () => {
      mockBridge.checkPermissions.mockResolvedValue([
        {
          permission: HealthConnectPermission.READ_STEPS,
          granted: true,
          checkedAt: new Date().toISOString(),
        },
      ]);

      mockBridge.readRecords.mockResolvedValue([]);

      await plugin.fetchData({
        dataType: DataType.STEPS,
        startDate: '2024-01-15T00:00:00Z',
        endDate: '2024-01-15T23:59:59Z',
        limit: 100,
        offset: 50,
      });

      expect(mockBridge.readRecords).toHaveBeenCalledWith({
        recordType: HealthConnectRecordType.STEPS,
        startTime: new Date('2024-01-15T00:00:00Z'),
        endTime: new Date('2024-01-15T23:59:59Z'),
        limit: 100,
        offset: 50,
      });
    });

    it('should throw ConnectionError when not connected', async () => {
      await plugin.disconnect();

      await expect(
        plugin.fetchData({
          dataType: DataType.STEPS,
          startDate: '2024-01-15T00:00:00Z',
          endDate: '2024-01-15T23:59:59Z',
        })
      ).rejects.toThrow(ConnectionError);

      await expect(
        plugin.fetchData({
          dataType: DataType.STEPS,
          startDate: '2024-01-15T00:00:00Z',
          endDate: '2024-01-15T23:59:59Z',
        })
      ).rejects.toThrow('Not connected to Health Connect');
    });

    it('should throw DataFetchError for unsupported data type', async () => {
      await expect(
        plugin.fetchData({
          dataType: DataType.BLOOD_GLUCOSE,
          startDate: '2024-01-15T00:00:00Z',
          endDate: '2024-01-15T23:59:59Z',
        })
      ).rejects.toThrow(DataFetchError);

      await expect(
        plugin.fetchData({
          dataType: DataType.BLOOD_GLUCOSE,
          startDate: '2024-01-15T00:00:00Z',
          endDate: '2024-01-15T23:59:59Z',
        })
      ).rejects.toThrow('not supported by Health Connect');
    });

    it('should throw AuthenticationError when permissions are missing', async () => {
      mockBridge.checkPermissions.mockResolvedValue([
        {
          permission: HealthConnectPermission.READ_STEPS,
          granted: false,
          checkedAt: new Date().toISOString(),
        },
      ]);

      await expect(
        plugin.fetchData({
          dataType: DataType.STEPS,
          startDate: '2024-01-15T00:00:00Z',
          endDate: '2024-01-15T23:59:59Z',
        })
      ).rejects.toThrow(AuthenticationError);

      await expect(
        plugin.fetchData({
          dataType: DataType.STEPS,
          startDate: '2024-01-15T00:00:00Z',
          endDate: '2024-01-15T23:59:59Z',
        })
      ).rejects.toThrow('Missing permissions');
    });

    it('should throw DataFetchError when readRecords fails', async () => {
      mockBridge.checkPermissions.mockResolvedValue([
        {
          permission: HealthConnectPermission.READ_STEPS,
          granted: true,
          checkedAt: new Date().toISOString(),
        },
      ]);

      mockBridge.readRecords.mockRejectedValue(new Error('Read failed'));

      await expect(
        plugin.fetchData({
          dataType: DataType.STEPS,
          startDate: '2024-01-15T00:00:00Z',
          endDate: '2024-01-15T23:59:59Z',
        })
      ).rejects.toThrow(DataFetchError);

      await expect(
        plugin.fetchData({
          dataType: DataType.STEPS,
          startDate: '2024-01-15T00:00:00Z',
          endDate: '2024-01-15T23:59:59Z',
        })
      ).rejects.toThrow('Read failed');
    });

    it('should return mock data when platform bridge is not set', async () => {
      const pluginWithoutBridge = new HealthConnectPlugin();
      const mockBridgeForInit = {
        checkAvailability: jest.fn().mockResolvedValue(HealthConnectAvailability.INSTALLED),
        checkPermissions: jest.fn().mockResolvedValue([
          {
            permission: HealthConnectPermission.READ_STEPS,
            granted: true,
            checkedAt: new Date().toISOString(),
          },
        ]),
        requestPermissions: jest.fn(),
        readRecords: jest.fn(),
      };

      // Set bridge for initialization and connection
      pluginWithoutBridge.setPlatformBridge(mockBridgeForInit);
      await pluginWithoutBridge.initialize({});
      await pluginWithoutBridge.connect();

      // Remove bridge to test mock data fallback
      pluginWithoutBridge.setPlatformBridge(undefined as any);

      const result = await pluginWithoutBridge.fetchData({
        dataType: DataType.STEPS,
        startDate: '2024-01-15T00:00:00Z',
        endDate: '2024-01-15T23:59:59Z',
      });

      expect(result).toHaveLength(1);
      expect(result[0].raw).toHaveProperty('id', 'mock-record-1');
    });
  });

  // ============================================================================
  // Subscriptions
  // ============================================================================

  describe('Subscriptions', () => {
    beforeEach(async () => {
      mockBridge.checkAvailability.mockResolvedValue(HealthConnectAvailability.INSTALLED);
      await plugin.initialize({});
      await plugin.connect();
    });

    it('should create subscription successfully', async () => {
      const callback = jest.fn();
      const subscription = await plugin.subscribeToUpdates(callback);

      expect(subscription).toBeDefined();
      expect(subscription.id).toBeDefined();
      expect(subscription.id).toContain('hc-sub-');
      expect(subscription.isActive()).toBe(true);
    });

    it('should unsubscribe successfully', async () => {
      const callback = jest.fn();
      const subscription = await plugin.subscribeToUpdates(callback);

      expect(subscription.isActive()).toBe(true);

      await subscription.unsubscribe();

      expect(subscription.isActive()).toBe(false);
    });

    it('should handle multiple subscriptions', async () => {
      const callback1 = jest.fn();
      const callback2 = jest.fn();
      const callback3 = jest.fn();

      const sub1 = await plugin.subscribeToUpdates(callback1);
      const sub2 = await plugin.subscribeToUpdates(callback2);
      const sub3 = await plugin.subscribeToUpdates(callback3);

      expect(sub1.id).not.toBe(sub2.id);
      expect(sub2.id).not.toBe(sub3.id);
      expect(sub1.isActive()).toBe(true);
      expect(sub2.isActive()).toBe(true);
      expect(sub3.isActive()).toBe(true);
    });

    it('should allow safe multiple unsubscribe calls', async () => {
      const callback = jest.fn();
      const subscription = await plugin.subscribeToUpdates(callback);

      await subscription.unsubscribe();
      await subscription.unsubscribe();
      await subscription.unsubscribe();

      expect(subscription.isActive()).toBe(false);
    });
  });

  // ============================================================================
  // Disposal
  // ============================================================================

  describe('Disposal', () => {
    beforeEach(async () => {
      mockBridge.checkAvailability.mockResolvedValue(HealthConnectAvailability.INSTALLED);
      await plugin.initialize({});
      await plugin.connect();
    });

    it('should dispose successfully', async () => {
      const callback = jest.fn();
      await plugin.subscribeToUpdates(callback);

      await plugin.dispose();

      expect(await plugin.isConnected()).toBe(false);
      expect(await plugin.getConnectionStatus()).toBe(ConnectionStatus.DISCONNECTED);
    });

    it('should clear all subscriptions on dispose', async () => {
      const sub1 = await plugin.subscribeToUpdates(jest.fn());
      const sub2 = await plugin.subscribeToUpdates(jest.fn());

      await plugin.dispose();

      expect(sub1.isActive()).toBe(false);
      expect(sub2.isActive()).toBe(false);
    });
  });

  // ============================================================================
  // Error Handling
  // ============================================================================

  describe('Error Handling', () => {
    it('should recommend RETRY for permission errors', () => {
      const error = new Error('permission denied');
      const action = plugin.handleError(error);

      expect(action).toBe('retry');
    });

    it('should recommend RETRY for not installed errors', () => {
      const error = new Error('Health Connect not installed');
      const action = plugin.handleError(error);

      expect(action).toBe('retry');
    });

    it('should recommend RETRY for network errors', () => {
      const error = new Error('network timeout');
      const action = plugin.handleError(error);

      expect(action).toBe('retry');
    });

    it('should recommend FAIL for unknown errors', () => {
      const error = new Error('unknown error');
      const action = plugin.handleError(error);

      // Health Connect plugin overrides BasePlugin and returns FAIL for unknown errors
      expect(action).toBe('fail');
    });
  });

  // ============================================================================
  // Platform Bridge
  // ============================================================================

  describe('Platform Bridge', () => {
    it('should work without platform bridge during construction', () => {
      const newPlugin = new HealthConnectPlugin();
      expect(newPlugin).toBeDefined();
    });

    it('should allow setting platform bridge after construction', () => {
      const newPlugin = new HealthConnectPlugin();

      expect(() => {
        newPlugin.setPlatformBridge(mockBridge);
      }).not.toThrow();
    });

    it('should use platform bridge for availability check', async () => {
      mockBridge.checkAvailability.mockResolvedValue(HealthConnectAvailability.INSTALLED);

      await plugin.initialize({});

      expect(mockBridge.checkAvailability).toHaveBeenCalled();
    });

    it('should assume not supported when bridge is not set', async () => {
      const pluginWithoutBridge = new HealthConnectPlugin();

      await expect(
        pluginWithoutBridge.initialize({})
      ).rejects.toThrow(ConnectionError);

      await expect(
        pluginWithoutBridge.initialize({})
      ).rejects.toThrow('not_supported');
    });
  });

  // ============================================================================
  // Edge Cases
  // ============================================================================

  describe('Edge Cases', () => {
    beforeEach(async () => {
      mockBridge.checkAvailability.mockResolvedValue(HealthConnectAvailability.INSTALLED);
      await plugin.initialize({});
      await plugin.connect();
    });

    it('should handle records with only time field', async () => {
      const mockRecords: HealthConnectRecord[] = [
        {
          id: 'record-1',
          time: '2024-01-15T10:00:00Z',
          value: 100,
        },
      ];

      mockBridge.checkPermissions.mockResolvedValue([
        {
          permission: HealthConnectPermission.READ_STEPS,
          granted: true,
          checkedAt: new Date().toISOString(),
        },
      ]);

      mockBridge.readRecords.mockResolvedValue(mockRecords);

      const result = await plugin.fetchData({
        dataType: DataType.STEPS,
        startDate: '2024-01-15T00:00:00Z',
        endDate: '2024-01-15T23:59:59Z',
      });

      expect(result[0].timestamp).toBe('2024-01-15T10:00:00Z');
      expect(result[0].endTimestamp).toBeUndefined();
    });

    it('should handle records with startTime but no endTime', async () => {
      const mockRecords: HealthConnectRecord[] = [
        {
          id: 'record-1',
          startTime: '2024-01-15T10:00:00Z',
          value: 100,
        },
      ];

      mockBridge.checkPermissions.mockResolvedValue([
        {
          permission: HealthConnectPermission.READ_STEPS,
          granted: true,
          checkedAt: new Date().toISOString(),
        },
      ]);

      mockBridge.readRecords.mockResolvedValue(mockRecords);

      const result = await plugin.fetchData({
        dataType: DataType.STEPS,
        startDate: '2024-01-15T00:00:00Z',
        endDate: '2024-01-15T23:59:59Z',
      });

      expect(result[0].timestamp).toBe('2024-01-15T10:00:00Z');
      expect(result[0].endTimestamp).toBeUndefined();
    });

    it('should handle empty records array', async () => {
      mockBridge.checkPermissions.mockResolvedValue([
        {
          permission: HealthConnectPermission.READ_STEPS,
          granted: true,
          checkedAt: new Date().toISOString(),
        },
      ]);

      mockBridge.readRecords.mockResolvedValue([]);

      const result = await plugin.fetchData({
        dataType: DataType.STEPS,
        startDate: '2024-01-15T00:00:00Z',
        endDate: '2024-01-15T23:59:59Z',
      });

      expect(result).toHaveLength(0);
    });

    it('should handle multiple permissions for same data type', async () => {
      mockBridge.checkPermissions.mockResolvedValue([
        {
          permission: HealthConnectPermission.READ_TOTAL_CALORIES_BURNED,
          granted: true,
          checkedAt: new Date().toISOString(),
        },
        {
          permission: HealthConnectPermission.READ_ACTIVE_CALORIES_BURNED,
          granted: true,
          checkedAt: new Date().toISOString(),
        },
      ]);

      mockBridge.readRecords.mockResolvedValue([]);

      await expect(
        plugin.fetchData({
          dataType: DataType.CALORIES,
          startDate: '2024-01-15T00:00:00Z',
          endDate: '2024-01-15T23:59:59Z',
        })
      ).resolves.toBeDefined();
    });

    it('should fail if any required permission is missing', async () => {
      mockBridge.checkPermissions.mockResolvedValue([
        {
          permission: HealthConnectPermission.READ_TOTAL_CALORIES_BURNED,
          granted: true,
          checkedAt: new Date().toISOString(),
        },
        {
          permission: HealthConnectPermission.READ_ACTIVE_CALORIES_BURNED,
          granted: false, // One permission missing
          checkedAt: new Date().toISOString(),
        },
      ]);

      await expect(
        plugin.fetchData({
          dataType: DataType.CALORIES,
          startDate: '2024-01-15T00:00:00Z',
          endDate: '2024-01-15T23:59:59Z',
        })
      ).rejects.toThrow(AuthenticationError);
    });
  });
});
