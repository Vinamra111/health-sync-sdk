/**
 * @healthsync/react-native
 *
 * React Native Health Connect integration for HealthSync SDK.
 * Provides access to Android Health Connect data through a unified API.
 *
 * @example
 * ```typescript
 * import { HealthConnectPlugin } from '@healthsync/react-native';
 * import { HealthSyncSDK } from '@healthsync/core';
 *
 * // Initialize SDK with Health Connect plugin
 * const sdk = new HealthSyncSDK();
 * const healthConnect = new HealthConnectPlugin();
 *
 * await sdk.registerPlugin(healthConnect);
 * await healthConnect.connect();
 *
 * // Fetch data
 * const data = await healthConnect.fetchData({
 *   dataType: DataType.STEPS,
 *   startDate: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString(),
 *   endDate: new Date().toISOString(),
 * });
 * ```
 */
import { HealthConnectPlugin as CoreHealthConnectPlugin } from '@healthsync/core/dist/plugins/health-connect/health-connect-plugin';
/**
 * Health Connect Plugin for React Native
 *
 * This extends the core HealthConnectPlugin and automatically sets up
 * the React Native platform bridge.
 */
export declare class HealthConnectPlugin extends CoreHealthConnectPlugin {
    constructor(config?: {});
}
export type { HealthConnectConfig, PermissionStatus, } from '@healthsync/core/dist/plugins/health-connect/types';
export { HealthConnectPermission, HealthConnectRecordType, HealthConnectAvailability, HealthConnectSleepStage, HealthConnectExerciseType, HEALTH_CONNECT_TYPE_MAP, DEFAULT_HEALTH_CONNECT_CONFIG, } from '@healthsync/core/dist/plugins/health-connect/types';
export { DataType, HealthSource, UnifiedHealthData, } from '@healthsync/core/dist/models/unified-data';
export { ConnectionStatus, ErrorAction, } from '@healthsync/core/dist/plugins/plugin-interface';
export { HealthConnectBridge } from './HealthConnectBridge';
