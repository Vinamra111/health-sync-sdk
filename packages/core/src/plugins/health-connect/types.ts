/**
 * Health Connect Types
 *
 * Type definitions for Android Health Connect integration.
 * Health Connect is Android's unified health and fitness data platform.
 *
 * @module plugins/health-connect/types
 */

import { DataType } from '../../models/unified-data';

/**
 * Health Connect permission types
 *
 * @enum HealthConnectPermission
 */
export enum HealthConnectPermission {
  READ_STEPS = 'android.permission.health.READ_STEPS',
  READ_HEART_RATE = 'android.permission.health.READ_HEART_RATE',
  READ_SLEEP = 'android.permission.health.READ_SLEEP',
  READ_DISTANCE = 'android.permission.health.READ_DISTANCE',
  READ_EXERCISE = 'android.permission.health.READ_EXERCISE',
  READ_TOTAL_CALORIES_BURNED = 'android.permission.health.READ_TOTAL_CALORIES_BURNED',
  READ_ACTIVE_CALORIES_BURNED = 'android.permission.health.READ_ACTIVE_CALORIES_BURNED',
  READ_OXYGEN_SATURATION = 'android.permission.health.READ_OXYGEN_SATURATION',
  READ_BLOOD_PRESSURE = 'android.permission.health.READ_BLOOD_PRESSURE',
  READ_BODY_TEMPERATURE = 'android.permission.health.READ_BODY_TEMPERATURE',
  READ_WEIGHT = 'android.permission.health.READ_WEIGHT',
  READ_HEIGHT = 'android.permission.health.READ_HEIGHT',
  READ_HEART_RATE_VARIABILITY = 'android.permission.health.READ_HEART_RATE_VARIABILITY',
}

/**
 * Health Connect record types
 *
 * Maps to Android Health Connect record class names
 *
 * @enum HealthConnectRecordType
 */
export enum HealthConnectRecordType {
  STEPS = 'Steps',
  HEART_RATE = 'HeartRate',
  SLEEP_SESSION = 'SleepSession',
  DISTANCE = 'Distance',
  EXERCISE_SESSION = 'ExerciseSession',
  TOTAL_CALORIES_BURNED = 'TotalCaloriesBurned',
  ACTIVE_CALORIES_BURNED = 'ActiveCaloriesBurned',
  OXYGEN_SATURATION = 'OxygenSaturation',
  BLOOD_PRESSURE = 'BloodPressure',
  BODY_TEMPERATURE = 'BodyTemperature',
  WEIGHT = 'Weight',
  HEIGHT = 'Height',
  HEART_RATE_VARIABILITY_RMSSD = 'HeartRateVariabilityRmssd',
}

/**
 * Health Connect data type mapping
 *
 * Maps our unified DataType to Health Connect record types and permissions
 */
export const HEALTH_CONNECT_TYPE_MAP: Record<
  DataType,
  {
    recordType: HealthConnectRecordType | null;
    permissions: HealthConnectPermission[];
  }
> = {
  [DataType.STEPS]: {
    recordType: HealthConnectRecordType.STEPS,
    permissions: [HealthConnectPermission.READ_STEPS],
  },
  [DataType.HEART_RATE]: {
    recordType: HealthConnectRecordType.HEART_RATE,
    permissions: [HealthConnectPermission.READ_HEART_RATE],
  },
  [DataType.RESTING_HEART_RATE]: {
    recordType: HealthConnectRecordType.HEART_RATE,
    permissions: [HealthConnectPermission.READ_HEART_RATE],
  },
  [DataType.SLEEP]: {
    recordType: HealthConnectRecordType.SLEEP_SESSION,
    permissions: [HealthConnectPermission.READ_SLEEP],
  },
  [DataType.ACTIVITY]: {
    recordType: HealthConnectRecordType.EXERCISE_SESSION,
    permissions: [HealthConnectPermission.READ_EXERCISE],
  },
  [DataType.CALORIES]: {
    recordType: HealthConnectRecordType.TOTAL_CALORIES_BURNED,
    permissions: [
      HealthConnectPermission.READ_TOTAL_CALORIES_BURNED,
      HealthConnectPermission.READ_ACTIVE_CALORIES_BURNED,
    ],
  },
  [DataType.DISTANCE]: {
    recordType: HealthConnectRecordType.DISTANCE,
    permissions: [HealthConnectPermission.READ_DISTANCE],
  },
  [DataType.BLOOD_OXYGEN]: {
    recordType: HealthConnectRecordType.OXYGEN_SATURATION,
    permissions: [HealthConnectPermission.READ_OXYGEN_SATURATION],
  },
  [DataType.BLOOD_PRESSURE]: {
    recordType: HealthConnectRecordType.BLOOD_PRESSURE,
    permissions: [HealthConnectPermission.READ_BLOOD_PRESSURE],
  },
  [DataType.BODY_TEMPERATURE]: {
    recordType: HealthConnectRecordType.BODY_TEMPERATURE,
    permissions: [HealthConnectPermission.READ_BODY_TEMPERATURE],
  },
  [DataType.WEIGHT]: {
    recordType: HealthConnectRecordType.WEIGHT,
    permissions: [HealthConnectPermission.READ_WEIGHT],
  },
  [DataType.HEIGHT]: {
    recordType: HealthConnectRecordType.HEIGHT,
    permissions: [HealthConnectPermission.READ_HEIGHT],
  },
  [DataType.HEART_RATE_VARIABILITY]: {
    recordType: HealthConnectRecordType.HEART_RATE_VARIABILITY_RMSSD,
    permissions: [HealthConnectPermission.READ_HEART_RATE_VARIABILITY],
  },
  [DataType.VO2_MAX]: {
    recordType: null, // Not supported by Health Connect
    permissions: [],
  },
  [DataType.ACTIVE_MINUTES]: {
    recordType: null, // Not directly supported, use ExerciseSession
    permissions: [],
  },
  [DataType.BLOOD_GLUCOSE]: {
    recordType: null, // Not supported by Health Connect
    permissions: [],
  },
  [DataType.BMI]: {
    recordType: null, // Not directly supported, calculated from weight/height
    permissions: [],
  },
  [DataType.BODY_FAT]: {
    recordType: null, // Not supported by Health Connect
    permissions: [],
  },
  [DataType.HYDRATION]: {
    recordType: null, // Not supported by Health Connect
    permissions: [],
  },
  [DataType.NUTRITION]: {
    recordType: null, // Not supported by Health Connect
    permissions: [],
  },
  [DataType.RESPIRATORY_RATE]: {
    recordType: null, // Not supported by Health Connect
    permissions: [],
  },
};

/**
 * Health Connect sleep stage mapping
 */
export enum HealthConnectSleepStage {
  AWAKE = 1,
  SLEEPING = 2,
  OUT_OF_BED = 3,
  LIGHT = 4,
  DEEP = 5,
  REM = 6,
  AWAKE_IN_BED = 7,
}

/**
 * Health Connect exercise type
 */
export enum HealthConnectExerciseType {
  WALKING = 'walking',
  RUNNING = 'running',
  CYCLING = 'cycling',
  SWIMMING = 'swimming',
  YOGA = 'yoga',
  STRENGTH_TRAINING = 'strength_training',
  HIKING = 'hiking',
  OTHER = 'other',
}

/**
 * Health Connect configuration
 *
 * @interface HealthConnectConfig
 */
export interface HealthConnectConfig {
  /** Package name of the Health Connect app */
  packageName?: string;

  /** Enable automatic permission requests */
  autoRequestPermissions?: boolean;

  /** Batch size for data queries */
  batchSize?: number;

  /** Enable background sync */
  enableBackgroundSync?: boolean;

  /** Background sync interval in milliseconds */
  syncInterval?: number;
}

/**
 * Default Health Connect configuration
 */
export const DEFAULT_HEALTH_CONNECT_CONFIG: Required<HealthConnectConfig> = {
  packageName: 'com.google.android.apps.healthdata',
  autoRequestPermissions: true,
  batchSize: 1000,
  enableBackgroundSync: false,
  syncInterval: 15 * 60 * 1000, // 15 minutes
};

/**
 * Health Connect availability status
 *
 * @enum HealthConnectAvailability
 */
export enum HealthConnectAvailability {
  INSTALLED = 'installed',
  NOT_INSTALLED = 'not_installed',
  NOT_SUPPORTED = 'not_supported',
}

/**
 * Permission status
 *
 * @interface PermissionStatus
 */
export interface PermissionStatus {
  /** Permission identifier */
  permission: HealthConnectPermission;

  /** Whether permission is granted */
  granted: boolean;

  /** Timestamp when status was checked */
  checkedAt: string;
}
