/**
 * React Native Health Connect Bridge
 *
 * TypeScript bindings for the native Health Connect module.
 * Implements the HealthConnectBridge interface from @healthsync/core.
 */

import { NativeModules, Platform } from 'react-native';
import type {
  HealthConnectBridge as IHealthConnectBridge,
  HealthConnectRecord,
} from '@healthsync/core/dist/plugins/health-connect/health-connect-plugin';
import {
  HealthConnectAvailability,
  HealthConnectPermission,
  type PermissionStatus,
} from '@healthsync/core/dist/plugins/health-connect/types';

const LINKING_ERROR =
  `The package '@healthsync/react-native' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo Go\n';

const HealthConnectModule = NativeModules.HealthConnectModule
  ? NativeModules.HealthConnectModule
  : new Proxy(
      {},
      {
        get() {
          throw new Error(LINKING_ERROR);
        },
      }
    );

/**
 * Read records request
 */
interface ReadRecordsRequest {
  recordType: string;
  startTime: Date;
  endTime: Date;
  limit?: number;
  offset?: number;
}

/**
 * React Native implementation of Health Connect Bridge
 *
 * This class bridges TypeScript code to the native Android Health Connect module.
 */
export class HealthConnectBridge implements IHealthConnectBridge {
  /**
   * Check Health Connect availability
   */
  async checkAvailability(): Promise<HealthConnectAvailability> {
    if (Platform.OS !== 'android') {
      return HealthConnectAvailability.NOT_SUPPORTED;
    }

    try {
      const result: string = await HealthConnectModule.checkAvailability();

      switch (result) {
        case 'installed':
          return HealthConnectAvailability.INSTALLED;
        case 'not_installed':
          return HealthConnectAvailability.NOT_INSTALLED;
        default:
          return HealthConnectAvailability.NOT_SUPPORTED;
      }
    } catch (error) {
      console.error('[HealthConnect] Failed to check availability:', error);
      return HealthConnectAvailability.NOT_SUPPORTED;
    }
  }

  /**
   * Check permissions
   */
  async checkPermissions(
    permissions: HealthConnectPermission[]
  ): Promise<PermissionStatus[]> {
    if (Platform.OS !== 'android') {
      return permissions.map(p => ({
        permission: p,
        granted: false,
        checkedAt: new Date().toISOString(),
      }));
    }

    try {
      const result: Array<{
        permission: string;
        granted: boolean;
        checkedAt: string;
      }> = await HealthConnectModule.checkPermissions(permissions);

      return result.map(item => ({
        permission: item.permission as HealthConnectPermission,
        granted: item.granted,
        checkedAt: item.checkedAt,
      }));
    } catch (error) {
      console.error('[HealthConnect] Failed to check permissions:', error);
      throw error;
    }
  }

  /**
   * Request permissions
   *
   * IMPORTANT: MainActivity must extend ReactFragmentActivity for this to work.
   */
  async requestPermissions(
    permissions: HealthConnectPermission[]
  ): Promise<HealthConnectPermission[]> {
    if (Platform.OS !== 'android') {
      console.warn('[HealthConnect] Permissions only available on Android');
      return [];
    }

    try {
      const granted: string[] = await HealthConnectModule.requestPermissions(
        permissions
      );

      return granted as HealthConnectPermission[];
    } catch (error) {
      console.error('[HealthConnect] Failed to request permissions:', error);
      throw error;
    }
  }

  /**
   * Read records from Health Connect
   *
   * CRITICAL: Dates are converted to UTC ISO 8601 format with 'Z' suffix
   * This matches the fix we implemented in Flutter (v2.1)
   */
  async readRecords(request: ReadRecordsRequest): Promise<HealthConnectRecord[]> {
    if (Platform.OS !== 'android') {
      console.warn('[HealthConnect] Read records only available on Android');
      return [];
    }

    try {
      // CRITICAL: Convert to UTC and use toISOString() to ensure 'Z' suffix
      // JavaScript Date.toISOString() always returns UTC with 'Z' suffix
      // Example: "2025-12-31T15:53:13.406Z" (WITH timezone)
      // This matches our Flutter v2.1 fix: .toUtc().toIso8601String()
      const requestData = {
        recordType: request.recordType,
        startTime: request.startTime.toISOString(), // Always includes 'Z' for UTC
        endTime: request.endTime.toISOString(),     // Always includes 'Z' for UTC
        ...(request.limit !== undefined && { limit: request.limit }),
        ...(request.offset !== undefined && { offset: request.offset }),
      };

      const records: any[] = await HealthConnectModule.readRecords(requestData);

      return records as HealthConnectRecord[];
    } catch (error) {
      console.error('[HealthConnect] Failed to read records:', error);
      throw error;
    }
  }
}
