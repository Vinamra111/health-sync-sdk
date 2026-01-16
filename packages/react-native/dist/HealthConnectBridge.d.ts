/**
 * React Native Health Connect Bridge
 *
 * TypeScript bindings for the native Health Connect module.
 * Implements the HealthConnectBridge interface from @healthsync/core.
 */
import type { HealthConnectBridge as IHealthConnectBridge, HealthConnectRecord } from '@healthsync/core/dist/plugins/health-connect/health-connect-plugin';
import { HealthConnectAvailability, HealthConnectPermission, type PermissionStatus } from '@healthsync/core/dist/plugins/health-connect/types';
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
export declare class HealthConnectBridge implements IHealthConnectBridge {
    /**
     * Check Health Connect availability
     */
    checkAvailability(): Promise<HealthConnectAvailability>;
    /**
     * Check permissions
     */
    checkPermissions(permissions: HealthConnectPermission[]): Promise<PermissionStatus[]>;
    /**
     * Request permissions
     *
     * IMPORTANT: MainActivity must extend ReactFragmentActivity for this to work.
     */
    requestPermissions(permissions: HealthConnectPermission[]): Promise<HealthConnectPermission[]>;
    /**
     * Read records from Health Connect
     *
     * CRITICAL: Dates are converted to UTC ISO 8601 format with 'Z' suffix
     * This matches the fix we implemented in Flutter (v2.1)
     */
    readRecords(request: ReadRecordsRequest): Promise<HealthConnectRecord[]>;
}
export {};
