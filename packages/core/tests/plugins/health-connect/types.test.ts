/**
 * Health Connect Types Tests
 *
 * Tests for Health Connect type definitions and mappings
 */

import {
  HealthConnectPermission,
  HealthConnectRecordType,
  HealthConnectSleepStage,
  HealthConnectExerciseType,
  HealthConnectAvailability,
  HEALTH_CONNECT_TYPE_MAP,
  DEFAULT_HEALTH_CONNECT_CONFIG,
} from '../../../src/plugins/health-connect';
import { DataType } from '../../../src/models/unified-data';

describe('Health Connect Types', () => {
  // ============================================================================
  // Enums
  // ============================================================================

  describe('HealthConnectPermission', () => {
    it('should have correct READ_STEPS permission', () => {
      expect(HealthConnectPermission.READ_STEPS).toBe('android.permission.health.READ_STEPS');
    });

    it('should have correct READ_HEART_RATE permission', () => {
      expect(HealthConnectPermission.READ_HEART_RATE).toBe('android.permission.health.READ_HEART_RATE');
    });

    it('should have correct READ_SLEEP permission', () => {
      expect(HealthConnectPermission.READ_SLEEP).toBe('android.permission.health.READ_SLEEP');
    });

    it('should have correct READ_DISTANCE permission', () => {
      expect(HealthConnectPermission.READ_DISTANCE).toBe('android.permission.health.READ_DISTANCE');
    });

    it('should have correct READ_EXERCISE permission', () => {
      expect(HealthConnectPermission.READ_EXERCISE).toBe('android.permission.health.READ_EXERCISE');
    });

    it('should have correct READ_TOTAL_CALORIES_BURNED permission', () => {
      expect(HealthConnectPermission.READ_TOTAL_CALORIES_BURNED).toBe(
        'android.permission.health.READ_TOTAL_CALORIES_BURNED'
      );
    });

    it('should have correct READ_ACTIVE_CALORIES_BURNED permission', () => {
      expect(HealthConnectPermission.READ_ACTIVE_CALORIES_BURNED).toBe(
        'android.permission.health.READ_ACTIVE_CALORIES_BURNED'
      );
    });

    it('should have correct READ_OXYGEN_SATURATION permission', () => {
      expect(HealthConnectPermission.READ_OXYGEN_SATURATION).toBe(
        'android.permission.health.READ_OXYGEN_SATURATION'
      );
    });

    it('should have correct READ_BLOOD_PRESSURE permission', () => {
      expect(HealthConnectPermission.READ_BLOOD_PRESSURE).toBe(
        'android.permission.health.READ_BLOOD_PRESSURE'
      );
    });

    it('should have correct READ_BODY_TEMPERATURE permission', () => {
      expect(HealthConnectPermission.READ_BODY_TEMPERATURE).toBe(
        'android.permission.health.READ_BODY_TEMPERATURE'
      );
    });

    it('should have correct READ_WEIGHT permission', () => {
      expect(HealthConnectPermission.READ_WEIGHT).toBe('android.permission.health.READ_WEIGHT');
    });

    it('should have correct READ_HEIGHT permission', () => {
      expect(HealthConnectPermission.READ_HEIGHT).toBe('android.permission.health.READ_HEIGHT');
    });

    it('should have correct READ_HEART_RATE_VARIABILITY permission', () => {
      expect(HealthConnectPermission.READ_HEART_RATE_VARIABILITY).toBe(
        'android.permission.health.READ_HEART_RATE_VARIABILITY'
      );
    });
  });

  describe('HealthConnectRecordType', () => {
    it('should have correct STEPS record type', () => {
      expect(HealthConnectRecordType.STEPS).toBe('Steps');
    });

    it('should have correct HEART_RATE record type', () => {
      expect(HealthConnectRecordType.HEART_RATE).toBe('HeartRate');
    });

    it('should have correct SLEEP_SESSION record type', () => {
      expect(HealthConnectRecordType.SLEEP_SESSION).toBe('SleepSession');
    });

    it('should have correct DISTANCE record type', () => {
      expect(HealthConnectRecordType.DISTANCE).toBe('Distance');
    });

    it('should have correct EXERCISE_SESSION record type', () => {
      expect(HealthConnectRecordType.EXERCISE_SESSION).toBe('ExerciseSession');
    });

    it('should have correct TOTAL_CALORIES_BURNED record type', () => {
      expect(HealthConnectRecordType.TOTAL_CALORIES_BURNED).toBe('TotalCaloriesBurned');
    });

    it('should have correct ACTIVE_CALORIES_BURNED record type', () => {
      expect(HealthConnectRecordType.ACTIVE_CALORIES_BURNED).toBe('ActiveCaloriesBurned');
    });

    it('should have correct OXYGEN_SATURATION record type', () => {
      expect(HealthConnectRecordType.OXYGEN_SATURATION).toBe('OxygenSaturation');
    });

    it('should have correct BLOOD_PRESSURE record type', () => {
      expect(HealthConnectRecordType.BLOOD_PRESSURE).toBe('BloodPressure');
    });

    it('should have correct BODY_TEMPERATURE record type', () => {
      expect(HealthConnectRecordType.BODY_TEMPERATURE).toBe('BodyTemperature');
    });

    it('should have correct WEIGHT record type', () => {
      expect(HealthConnectRecordType.WEIGHT).toBe('Weight');
    });

    it('should have correct HEIGHT record type', () => {
      expect(HealthConnectRecordType.HEIGHT).toBe('Height');
    });

    it('should have correct HEART_RATE_VARIABILITY_RMSSD record type', () => {
      expect(HealthConnectRecordType.HEART_RATE_VARIABILITY_RMSSD).toBe('HeartRateVariabilityRmssd');
    });
  });

  describe('HealthConnectSleepStage', () => {
    it('should have correct AWAKE stage', () => {
      expect(HealthConnectSleepStage.AWAKE).toBe(1);
    });

    it('should have correct SLEEPING stage', () => {
      expect(HealthConnectSleepStage.SLEEPING).toBe(2);
    });

    it('should have correct OUT_OF_BED stage', () => {
      expect(HealthConnectSleepStage.OUT_OF_BED).toBe(3);
    });

    it('should have correct LIGHT stage', () => {
      expect(HealthConnectSleepStage.LIGHT).toBe(4);
    });

    it('should have correct DEEP stage', () => {
      expect(HealthConnectSleepStage.DEEP).toBe(5);
    });

    it('should have correct REM stage', () => {
      expect(HealthConnectSleepStage.REM).toBe(6);
    });

    it('should have correct AWAKE_IN_BED stage', () => {
      expect(HealthConnectSleepStage.AWAKE_IN_BED).toBe(7);
    });
  });

  describe('HealthConnectExerciseType', () => {
    it('should have correct exercise types', () => {
      expect(HealthConnectExerciseType.WALKING).toBe('walking');
      expect(HealthConnectExerciseType.RUNNING).toBe('running');
      expect(HealthConnectExerciseType.CYCLING).toBe('cycling');
      expect(HealthConnectExerciseType.SWIMMING).toBe('swimming');
      expect(HealthConnectExerciseType.YOGA).toBe('yoga');
      expect(HealthConnectExerciseType.STRENGTH_TRAINING).toBe('strength_training');
      expect(HealthConnectExerciseType.HIKING).toBe('hiking');
      expect(HealthConnectExerciseType.OTHER).toBe('other');
    });
  });

  describe('HealthConnectAvailability', () => {
    it('should have correct availability statuses', () => {
      expect(HealthConnectAvailability.INSTALLED).toBe('installed');
      expect(HealthConnectAvailability.NOT_INSTALLED).toBe('not_installed');
      expect(HealthConnectAvailability.NOT_SUPPORTED).toBe('not_supported');
    });
  });

  // ============================================================================
  // Type Map
  // ============================================================================

  describe('HEALTH_CONNECT_TYPE_MAP', () => {
    it('should map STEPS correctly', () => {
      const mapping = HEALTH_CONNECT_TYPE_MAP[DataType.STEPS];

      expect(mapping.recordType).toBe(HealthConnectRecordType.STEPS);
      expect(mapping.permissions).toEqual([HealthConnectPermission.READ_STEPS]);
    });

    it('should map HEART_RATE correctly', () => {
      const mapping = HEALTH_CONNECT_TYPE_MAP[DataType.HEART_RATE];

      expect(mapping.recordType).toBe(HealthConnectRecordType.HEART_RATE);
      expect(mapping.permissions).toEqual([HealthConnectPermission.READ_HEART_RATE]);
    });

    it('should map RESTING_HEART_RATE correctly', () => {
      const mapping = HEALTH_CONNECT_TYPE_MAP[DataType.RESTING_HEART_RATE];

      expect(mapping.recordType).toBe(HealthConnectRecordType.HEART_RATE);
      expect(mapping.permissions).toEqual([HealthConnectPermission.READ_HEART_RATE]);
    });

    it('should map SLEEP correctly', () => {
      const mapping = HEALTH_CONNECT_TYPE_MAP[DataType.SLEEP];

      expect(mapping.recordType).toBe(HealthConnectRecordType.SLEEP_SESSION);
      expect(mapping.permissions).toEqual([HealthConnectPermission.READ_SLEEP]);
    });

    it('should map ACTIVITY correctly', () => {
      const mapping = HEALTH_CONNECT_TYPE_MAP[DataType.ACTIVITY];

      expect(mapping.recordType).toBe(HealthConnectRecordType.EXERCISE_SESSION);
      expect(mapping.permissions).toEqual([HealthConnectPermission.READ_EXERCISE]);
    });

    it('should map CALORIES with multiple permissions', () => {
      const mapping = HEALTH_CONNECT_TYPE_MAP[DataType.CALORIES];

      expect(mapping.recordType).toBe(HealthConnectRecordType.TOTAL_CALORIES_BURNED);
      expect(mapping.permissions).toEqual([
        HealthConnectPermission.READ_TOTAL_CALORIES_BURNED,
        HealthConnectPermission.READ_ACTIVE_CALORIES_BURNED,
      ]);
    });

    it('should map DISTANCE correctly', () => {
      const mapping = HEALTH_CONNECT_TYPE_MAP[DataType.DISTANCE];

      expect(mapping.recordType).toBe(HealthConnectRecordType.DISTANCE);
      expect(mapping.permissions).toEqual([HealthConnectPermission.READ_DISTANCE]);
    });

    it('should map BLOOD_OXYGEN correctly', () => {
      const mapping = HEALTH_CONNECT_TYPE_MAP[DataType.BLOOD_OXYGEN];

      expect(mapping.recordType).toBe(HealthConnectRecordType.OXYGEN_SATURATION);
      expect(mapping.permissions).toEqual([HealthConnectPermission.READ_OXYGEN_SATURATION]);
    });

    it('should map BLOOD_PRESSURE correctly', () => {
      const mapping = HEALTH_CONNECT_TYPE_MAP[DataType.BLOOD_PRESSURE];

      expect(mapping.recordType).toBe(HealthConnectRecordType.BLOOD_PRESSURE);
      expect(mapping.permissions).toEqual([HealthConnectPermission.READ_BLOOD_PRESSURE]);
    });

    it('should map BODY_TEMPERATURE correctly', () => {
      const mapping = HEALTH_CONNECT_TYPE_MAP[DataType.BODY_TEMPERATURE];

      expect(mapping.recordType).toBe(HealthConnectRecordType.BODY_TEMPERATURE);
      expect(mapping.permissions).toEqual([HealthConnectPermission.READ_BODY_TEMPERATURE]);
    });

    it('should map WEIGHT correctly', () => {
      const mapping = HEALTH_CONNECT_TYPE_MAP[DataType.WEIGHT];

      expect(mapping.recordType).toBe(HealthConnectRecordType.WEIGHT);
      expect(mapping.permissions).toEqual([HealthConnectPermission.READ_WEIGHT]);
    });

    it('should map HEIGHT correctly', () => {
      const mapping = HEALTH_CONNECT_TYPE_MAP[DataType.HEIGHT];

      expect(mapping.recordType).toBe(HealthConnectRecordType.HEIGHT);
      expect(mapping.permissions).toEqual([HealthConnectPermission.READ_HEIGHT]);
    });

    it('should map HEART_RATE_VARIABILITY correctly', () => {
      const mapping = HEALTH_CONNECT_TYPE_MAP[DataType.HEART_RATE_VARIABILITY];

      expect(mapping.recordType).toBe(HealthConnectRecordType.HEART_RATE_VARIABILITY_RMSSD);
      expect(mapping.permissions).toEqual([HealthConnectPermission.READ_HEART_RATE_VARIABILITY]);
    });

    it('should mark unsupported data types with null recordType', () => {
      expect(HEALTH_CONNECT_TYPE_MAP[DataType.VO2_MAX].recordType).toBeNull();
      expect(HEALTH_CONNECT_TYPE_MAP[DataType.ACTIVE_MINUTES].recordType).toBeNull();
      expect(HEALTH_CONNECT_TYPE_MAP[DataType.BLOOD_GLUCOSE].recordType).toBeNull();
      expect(HEALTH_CONNECT_TYPE_MAP[DataType.BMI].recordType).toBeNull();
      expect(HEALTH_CONNECT_TYPE_MAP[DataType.BODY_FAT].recordType).toBeNull();
      expect(HEALTH_CONNECT_TYPE_MAP[DataType.HYDRATION].recordType).toBeNull();
      expect(HEALTH_CONNECT_TYPE_MAP[DataType.NUTRITION].recordType).toBeNull();
      expect(HEALTH_CONNECT_TYPE_MAP[DataType.RESPIRATORY_RATE].recordType).toBeNull();
    });

    it('should have empty permissions for unsupported data types', () => {
      expect(HEALTH_CONNECT_TYPE_MAP[DataType.VO2_MAX].permissions).toEqual([]);
      expect(HEALTH_CONNECT_TYPE_MAP[DataType.ACTIVE_MINUTES].permissions).toEqual([]);
      expect(HEALTH_CONNECT_TYPE_MAP[DataType.BLOOD_GLUCOSE].permissions).toEqual([]);
      expect(HEALTH_CONNECT_TYPE_MAP[DataType.BMI].permissions).toEqual([]);
      expect(HEALTH_CONNECT_TYPE_MAP[DataType.BODY_FAT].permissions).toEqual([]);
      expect(HEALTH_CONNECT_TYPE_MAP[DataType.HYDRATION].permissions).toEqual([]);
      expect(HEALTH_CONNECT_TYPE_MAP[DataType.NUTRITION].permissions).toEqual([]);
      expect(HEALTH_CONNECT_TYPE_MAP[DataType.RESPIRATORY_RATE].permissions).toEqual([]);
    });

    it('should have mapping for all DataType enum values', () => {
      const allDataTypes = Object.values(DataType);

      allDataTypes.forEach(dataType => {
        expect(HEALTH_CONNECT_TYPE_MAP[dataType]).toBeDefined();
        expect(HEALTH_CONNECT_TYPE_MAP[dataType]).toHaveProperty('recordType');
        expect(HEALTH_CONNECT_TYPE_MAP[dataType]).toHaveProperty('permissions');
        expect(Array.isArray(HEALTH_CONNECT_TYPE_MAP[dataType].permissions)).toBe(true);
      });
    });

    it('should have 21 mappings total', () => {
      const mappingCount = Object.keys(HEALTH_CONNECT_TYPE_MAP).length;
      expect(mappingCount).toBe(21);
    });
  });

  // ============================================================================
  // Default Configuration
  // ============================================================================

  describe('DEFAULT_HEALTH_CONNECT_CONFIG', () => {
    it('should have correct package name', () => {
      expect(DEFAULT_HEALTH_CONNECT_CONFIG.packageName).toBe('com.google.android.apps.healthdata');
    });

    it('should enable auto request permissions by default', () => {
      expect(DEFAULT_HEALTH_CONNECT_CONFIG.autoRequestPermissions).toBe(true);
    });

    it('should have correct default batch size', () => {
      expect(DEFAULT_HEALTH_CONNECT_CONFIG.batchSize).toBe(1000);
    });

    it('should disable background sync by default', () => {
      expect(DEFAULT_HEALTH_CONNECT_CONFIG.enableBackgroundSync).toBe(false);
    });

    it('should have correct default sync interval', () => {
      expect(DEFAULT_HEALTH_CONNECT_CONFIG.syncInterval).toBe(15 * 60 * 1000); // 15 minutes
    });

    it('should have all required configuration fields', () => {
      expect(DEFAULT_HEALTH_CONNECT_CONFIG).toHaveProperty('packageName');
      expect(DEFAULT_HEALTH_CONNECT_CONFIG).toHaveProperty('autoRequestPermissions');
      expect(DEFAULT_HEALTH_CONNECT_CONFIG).toHaveProperty('batchSize');
      expect(DEFAULT_HEALTH_CONNECT_CONFIG).toHaveProperty('enableBackgroundSync');
      expect(DEFAULT_HEALTH_CONNECT_CONFIG).toHaveProperty('syncInterval');
    });
  });

  // ============================================================================
  // Type Coverage
  // ============================================================================

  describe('Type Coverage', () => {
    it('should cover all supported data types', () => {
      const supportedTypes = [
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

      supportedTypes.forEach(dataType => {
        const mapping = HEALTH_CONNECT_TYPE_MAP[dataType];
        expect(mapping.recordType).not.toBeNull();
        expect(mapping.permissions.length).toBeGreaterThan(0);
      });
    });

    it('should identify unsupported data types', () => {
      const unsupportedTypes = [
        DataType.VO2_MAX,
        DataType.ACTIVE_MINUTES,
        DataType.BLOOD_GLUCOSE,
        DataType.BMI,
        DataType.BODY_FAT,
        DataType.HYDRATION,
        DataType.NUTRITION,
        DataType.RESPIRATORY_RATE,
      ];

      unsupportedTypes.forEach(dataType => {
        const mapping = HEALTH_CONNECT_TYPE_MAP[dataType];
        expect(mapping.recordType).toBeNull();
        expect(mapping.permissions).toEqual([]);
      });
    });
  });
});
