/**
 * Health Connect Plugin
 *
 * Android Health Connect integration for unified health and fitness data access.
 *
 * @module plugins/health-connect
 */

export { HealthConnectPlugin } from './health-connect-plugin';
export type { HealthConnectBridge, HealthConnectRecord } from './health-connect-plugin';

export {
  HealthConnectPermission,
  HealthConnectRecordType,
  HealthConnectSleepStage,
  HealthConnectExerciseType,
  HealthConnectAvailability,
  HEALTH_CONNECT_TYPE_MAP,
  DEFAULT_HEALTH_CONNECT_CONFIG,
} from './types';
export type { HealthConnectConfig, PermissionStatus } from './types';
