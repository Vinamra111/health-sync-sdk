import '../../models/data_type.dart';

/// Health Connect availability status
enum HealthConnectAvailability {
  /// Health Connect is installed and available
  installed,

  /// Health Connect is not installed
  notInstalled,

  /// Health Connect is not supported on this device
  notSupported,
}

extension HealthConnectAvailabilityExtension on HealthConnectAvailability {
  String toValue() {
    switch (this) {
      case HealthConnectAvailability.installed:
        return 'installed';
      case HealthConnectAvailability.notInstalled:
        return 'not_installed';
      case HealthConnectAvailability.notSupported:
        return 'not_supported';
    }
  }

  static HealthConnectAvailability fromValue(String value) {
    switch (value) {
      case 'installed':
        return HealthConnectAvailability.installed;
      case 'not_installed':
        return HealthConnectAvailability.notInstalled;
      case 'not_supported':
        return HealthConnectAvailability.notSupported;
      default:
        return HealthConnectAvailability.notSupported;
    }
  }
}

/// Health Connect permission types - Complete list as of 2025
enum HealthConnectPermission {
  // Activity & Exercise
  readSteps,
  readDistance,
  readExercise,
  readExerciseRoute, // New in 2025
  readActiveCaloriesBurned,
  readTotalCaloriesBurned,
  readElevationGained,
  readFloorsClimbed,
  readPower,
  readSpeed,
  readCyclingPedalingCadence,
  readWheelchairPushes,
  readPlannedExercise, // New in 2025

  // Body Measurements
  readWeight,
  readHeight,
  readBodyFat,
  readBodyWaterMass,
  readBoneMass,
  readLeanBodyMass,
  readBasalMetabolicRate,

  // Vitals
  readHeartRate,
  readHeartRateVariability,
  readRestingHeartRate,
  readBloodPressure,
  readBloodGlucose,
  readOxygenSaturation,
  readRespiratoryRate,
  readBodyTemperature,
  readBasalBodyTemperature,
  readSkinTemperature, // New in 2025

  // Sleep
  readSleep,

  // Nutrition & Hydration
  readNutrition,
  readHydration,

  // Cycle Tracking
  readMenstruation,
  readOvulationTest,
  readCervicalMucus,
  readIntermenstrualBleeding,
  readSexualActivity,

  // Fitness
  readVo2Max,

  // Mindfulness
  readMindfulness, // New in 2025

  // Special Permissions (2025)
  readHealthDataInBackground, // New in 2025
  readHealthDataHistory, // New in 2025
}

extension HealthConnectPermissionExtension on HealthConnectPermission {
  String toValue() {
    switch (this) {
      // Activity & Exercise
      case HealthConnectPermission.readSteps:
        return 'android.permission.health.READ_STEPS';
      case HealthConnectPermission.readDistance:
        return 'android.permission.health.READ_DISTANCE';
      case HealthConnectPermission.readExercise:
        return 'android.permission.health.READ_EXERCISE';
      case HealthConnectPermission.readExerciseRoute:
        return 'android.permission.health.READ_EXERCISE_ROUTE';
      case HealthConnectPermission.readActiveCaloriesBurned:
        return 'android.permission.health.READ_ACTIVE_CALORIES_BURNED';
      case HealthConnectPermission.readTotalCaloriesBurned:
        return 'android.permission.health.READ_TOTAL_CALORIES_BURNED';
      case HealthConnectPermission.readElevationGained:
        return 'android.permission.health.READ_ELEVATION_GAINED';
      case HealthConnectPermission.readFloorsClimbed:
        return 'android.permission.health.READ_FLOORS_CLIMBED';
      case HealthConnectPermission.readPower:
        return 'android.permission.health.READ_POWER';
      case HealthConnectPermission.readSpeed:
        return 'android.permission.health.READ_SPEED';
      case HealthConnectPermission.readCyclingPedalingCadence:
        return 'android.permission.health.READ_CYCLING_PEDALING_CADENCE';
      case HealthConnectPermission.readWheelchairPushes:
        return 'android.permission.health.READ_WHEELCHAIR_PUSHES';
      case HealthConnectPermission.readPlannedExercise:
        return 'android.permission.health.READ_PLANNED_EXERCISE';

      // Body Measurements
      case HealthConnectPermission.readWeight:
        return 'android.permission.health.READ_WEIGHT';
      case HealthConnectPermission.readHeight:
        return 'android.permission.health.READ_HEIGHT';
      case HealthConnectPermission.readBodyFat:
        return 'android.permission.health.READ_BODY_FAT';
      case HealthConnectPermission.readBodyWaterMass:
        return 'android.permission.health.READ_BODY_WATER_MASS';
      case HealthConnectPermission.readBoneMass:
        return 'android.permission.health.READ_BONE_MASS';
      case HealthConnectPermission.readLeanBodyMass:
        return 'android.permission.health.READ_LEAN_BODY_MASS';
      case HealthConnectPermission.readBasalMetabolicRate:
        return 'android.permission.health.READ_BASAL_METABOLIC_RATE';

      // Vitals
      case HealthConnectPermission.readHeartRate:
        return 'android.permission.health.READ_HEART_RATE';
      case HealthConnectPermission.readHeartRateVariability:
        return 'android.permission.health.READ_HEART_RATE_VARIABILITY';
      case HealthConnectPermission.readRestingHeartRate:
        return 'android.permission.health.READ_RESTING_HEART_RATE';
      case HealthConnectPermission.readBloodPressure:
        return 'android.permission.health.READ_BLOOD_PRESSURE';
      case HealthConnectPermission.readBloodGlucose:
        return 'android.permission.health.READ_BLOOD_GLUCOSE';
      case HealthConnectPermission.readOxygenSaturation:
        return 'android.permission.health.READ_OXYGEN_SATURATION';
      case HealthConnectPermission.readRespiratoryRate:
        return 'android.permission.health.READ_RESPIRATORY_RATE';
      case HealthConnectPermission.readBodyTemperature:
        return 'android.permission.health.READ_BODY_TEMPERATURE';
      case HealthConnectPermission.readBasalBodyTemperature:
        return 'android.permission.health.READ_BASAL_BODY_TEMPERATURE';
      case HealthConnectPermission.readSkinTemperature:
        return 'android.permission.health.READ_SKIN_TEMPERATURE';

      // Sleep
      case HealthConnectPermission.readSleep:
        return 'android.permission.health.READ_SLEEP';

      // Nutrition & Hydration
      case HealthConnectPermission.readNutrition:
        return 'android.permission.health.READ_NUTRITION';
      case HealthConnectPermission.readHydration:
        return 'android.permission.health.READ_HYDRATION';

      // Cycle Tracking
      case HealthConnectPermission.readMenstruation:
        return 'android.permission.health.READ_MENSTRUATION';
      case HealthConnectPermission.readOvulationTest:
        return 'android.permission.health.READ_OVULATION_TEST';
      case HealthConnectPermission.readCervicalMucus:
        return 'android.permission.health.READ_CERVICAL_MUCUS';
      case HealthConnectPermission.readIntermenstrualBleeding:
        return 'android.permission.health.READ_INTERMENSTRUAL_BLEEDING';
      case HealthConnectPermission.readSexualActivity:
        return 'android.permission.health.READ_SEXUAL_ACTIVITY';

      // Fitness
      case HealthConnectPermission.readVo2Max:
        return 'android.permission.health.READ_VO2_MAX';

      // Mindfulness
      case HealthConnectPermission.readMindfulness:
        return 'android.permission.health.READ_MINDFULNESS';

      // Special Permissions (2025)
      case HealthConnectPermission.readHealthDataInBackground:
        return 'android.permission.health.READ_HEALTH_DATA_IN_BACKGROUND';
      case HealthConnectPermission.readHealthDataHistory:
        return 'android.permission.health.READ_HEALTH_DATA_HISTORY';
    }
  }

  static HealthConnectPermission fromValue(String value) {
    switch (value) {
      // Activity & Exercise
      case 'android.permission.health.READ_STEPS':
        return HealthConnectPermission.readSteps;
      case 'android.permission.health.READ_DISTANCE':
        return HealthConnectPermission.readDistance;
      case 'android.permission.health.READ_EXERCISE':
        return HealthConnectPermission.readExercise;
      case 'android.permission.health.READ_EXERCISE_ROUTE':
        return HealthConnectPermission.readExerciseRoute;
      case 'android.permission.health.READ_ACTIVE_CALORIES_BURNED':
        return HealthConnectPermission.readActiveCaloriesBurned;
      case 'android.permission.health.READ_TOTAL_CALORIES_BURNED':
        return HealthConnectPermission.readTotalCaloriesBurned;
      case 'android.permission.health.READ_ELEVATION_GAINED':
        return HealthConnectPermission.readElevationGained;
      case 'android.permission.health.READ_FLOORS_CLIMBED':
        return HealthConnectPermission.readFloorsClimbed;
      case 'android.permission.health.READ_POWER':
        return HealthConnectPermission.readPower;
      case 'android.permission.health.READ_SPEED':
        return HealthConnectPermission.readSpeed;
      case 'android.permission.health.READ_CYCLING_PEDALING_CADENCE':
        return HealthConnectPermission.readCyclingPedalingCadence;
      case 'android.permission.health.READ_WHEELCHAIR_PUSHES':
        return HealthConnectPermission.readWheelchairPushes;
      case 'android.permission.health.READ_PLANNED_EXERCISE':
        return HealthConnectPermission.readPlannedExercise;

      // Body Measurements
      case 'android.permission.health.READ_WEIGHT':
        return HealthConnectPermission.readWeight;
      case 'android.permission.health.READ_HEIGHT':
        return HealthConnectPermission.readHeight;
      case 'android.permission.health.READ_BODY_FAT':
        return HealthConnectPermission.readBodyFat;
      case 'android.permission.health.READ_BODY_WATER_MASS':
        return HealthConnectPermission.readBodyWaterMass;
      case 'android.permission.health.READ_BONE_MASS':
        return HealthConnectPermission.readBoneMass;
      case 'android.permission.health.READ_LEAN_BODY_MASS':
        return HealthConnectPermission.readLeanBodyMass;
      case 'android.permission.health.READ_BASAL_METABOLIC_RATE':
        return HealthConnectPermission.readBasalMetabolicRate;

      // Vitals
      case 'android.permission.health.READ_HEART_RATE':
        return HealthConnectPermission.readHeartRate;
      case 'android.permission.health.READ_HEART_RATE_VARIABILITY':
        return HealthConnectPermission.readHeartRateVariability;
      case 'android.permission.health.READ_RESTING_HEART_RATE':
        return HealthConnectPermission.readRestingHeartRate;
      case 'android.permission.health.READ_BLOOD_PRESSURE':
        return HealthConnectPermission.readBloodPressure;
      case 'android.permission.health.READ_BLOOD_GLUCOSE':
        return HealthConnectPermission.readBloodGlucose;
      case 'android.permission.health.READ_OXYGEN_SATURATION':
        return HealthConnectPermission.readOxygenSaturation;
      case 'android.permission.health.READ_RESPIRATORY_RATE':
        return HealthConnectPermission.readRespiratoryRate;
      case 'android.permission.health.READ_BODY_TEMPERATURE':
        return HealthConnectPermission.readBodyTemperature;
      case 'android.permission.health.READ_BASAL_BODY_TEMPERATURE':
        return HealthConnectPermission.readBasalBodyTemperature;
      case 'android.permission.health.READ_SKIN_TEMPERATURE':
        return HealthConnectPermission.readSkinTemperature;

      // Sleep
      case 'android.permission.health.READ_SLEEP':
        return HealthConnectPermission.readSleep;

      // Nutrition & Hydration
      case 'android.permission.health.READ_NUTRITION':
        return HealthConnectPermission.readNutrition;
      case 'android.permission.health.READ_HYDRATION':
        return HealthConnectPermission.readHydration;

      // Cycle Tracking
      case 'android.permission.health.READ_MENSTRUATION':
        return HealthConnectPermission.readMenstruation;
      case 'android.permission.health.READ_OVULATION_TEST':
        return HealthConnectPermission.readOvulationTest;
      case 'android.permission.health.READ_CERVICAL_MUCUS':
        return HealthConnectPermission.readCervicalMucus;
      case 'android.permission.health.READ_INTERMENSTRUAL_BLEEDING':
        return HealthConnectPermission.readIntermenstrualBleeding;
      case 'android.permission.health.READ_SEXUAL_ACTIVITY':
        return HealthConnectPermission.readSexualActivity;

      // Fitness
      case 'android.permission.health.READ_VO2_MAX':
        return HealthConnectPermission.readVo2Max;

      // Mindfulness
      case 'android.permission.health.READ_MINDFULNESS':
        return HealthConnectPermission.readMindfulness;

      // Special Permissions
      case 'android.permission.health.READ_HEALTH_DATA_IN_BACKGROUND':
        return HealthConnectPermission.readHealthDataInBackground;
      case 'android.permission.health.READ_HEALTH_DATA_HISTORY':
        return HealthConnectPermission.readHealthDataHistory;

      default:
        throw ArgumentError('Unknown permission: $value');
    }
  }
}

/// Permission status
class PermissionStatus {
  /// Permission identifier
  final HealthConnectPermission permission;

  /// Whether permission is granted
  final bool granted;

  /// Timestamp when status was checked
  final DateTime checkedAt;

  const PermissionStatus({
    required this.permission,
    required this.granted,
    required this.checkedAt,
  });

  factory PermissionStatus.fromJson(Map<String, dynamic> json) {
    return PermissionStatus(
      permission: HealthConnectPermissionExtension.fromValue(
        json['permission'] as String,
      ),
      granted: json['granted'] as bool,
      checkedAt: DateTime.parse(json['checkedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'permission': permission.toValue(),
      'granted': granted,
      'checkedAt': checkedAt.toIso8601String(),
    };
  }
}

/// Recording method for Health Connect data
/// Based on RecordingMethod from Health Connect SDK
enum RecordingMethod {
  /// Data was manually entered by the user
  manualEntry,

  /// Data was automatically recorded by a device or app
  automaticallyRecorded,

  /// Data was actively recorded (e.g., during a workout)
  activelyRecorded,

  /// Recording method is unknown or not specified
  unknown,
}

extension RecordingMethodExtension on RecordingMethod {
  String toValue() {
    switch (this) {
      case RecordingMethod.manualEntry:
        return 'MANUAL_ENTRY';
      case RecordingMethod.automaticallyRecorded:
        return 'AUTOMATICALLY_RECORDED';
      case RecordingMethod.activelyRecorded:
        return 'ACTIVELY_RECORDED';
      case RecordingMethod.unknown:
        return 'UNKNOWN';
    }
  }

  static RecordingMethod fromValue(String value) {
    switch (value.toUpperCase()) {
      case 'MANUAL_ENTRY':
        return RecordingMethod.manualEntry;
      case 'AUTOMATICALLY_RECORDED':
        return RecordingMethod.automaticallyRecorded;
      case 'ACTIVELY_RECORDED':
        return RecordingMethod.activelyRecorded;
      case 'UNKNOWN':
      default:
        return RecordingMethod.unknown;
    }
  }
}

/// Fraud prevention configuration for Health Connect
class FraudPreventionConfig {
  /// Filter out manually entered STEPS data (fraud prevention)
  /// Other data types (sleep, weight, etc.) keep manual entries as they're legitimate
  final bool filterManualSteps;

  /// Only allow data from trusted sources
  final bool filterUnknownSources;

  /// Enable anomaly detection for unrealistic values
  final bool enableAnomalyDetection;

  /// Maximum reasonable daily step count (default: 100,000)
  final int maxDailySteps;

  /// Maximum reasonable heart rate (default: 220 bpm)
  final int maxHeartRate;

  /// Minimum reasonable heart rate (default: 30 bpm)
  final int minHeartRate;

  // Tier 1 Fraud Detection - Temporal Analysis

  /// Enable burst detection (detects rapid step accumulation from shaking)
  /// Flags records with >500 steps in <5 minutes
  final bool enableBurstDetection;

  /// Maximum sustainable steps per minute (default: 250)
  /// Normal fast running: 180 spm, Elite sprinting: 180-200 spm
  /// Shaking can generate 300+ spm
  /// Set conservatively high to avoid ANY false positives from legitimate activity
  final int maxStepsPerMinute;

  /// Minimum duration for burst detection in minutes (default: 5)
  final int burstWindowMinutes;

  /// Minimum steps to consider as burst (default: 500)
  final int burstThreshold;

  /// Enable midnight activity anomaly detection (12am-5am)
  /// Most people don't walk significantly during these hours
  final bool enableMidnightFlagging;

  /// Start hour for midnight window (default: 0 = 12am)
  final int midnightStartHour;

  /// End hour for midnight window (default: 5 = 5am)
  final int midnightEndHour;

  /// Midnight steps threshold - flag if exceeds this (default: 1000)
  /// Allows bathroom trips, night shift workers need higher threshold
  final int midnightStepsThreshold;

  const FraudPreventionConfig({
    this.filterManualSteps = true, // Only filter manual STEPS by default
    this.filterUnknownSources = false,
    this.enableAnomalyDetection = true,
    this.maxDailySteps = 100000,
    this.maxHeartRate = 220,
    this.minHeartRate = 30,
    // Tier 1 Temporal Analysis (Shake Detection)
    this.enableBurstDetection = true,
    this.maxStepsPerMinute = 250, // Ultra-conservative: allows any human activity
    this.burstWindowMinutes = 5,
    this.burstThreshold = 500,
    this.enableMidnightFlagging = false, // Disabled - prevents night shift false positives
    this.midnightStartHour = 0,
    this.midnightEndHour = 5,
    this.midnightStepsThreshold = 1000,
  });
}

/// Health Connect configuration
class HealthConnectConfig {
  /// Enable automatic permission requests
  final bool autoRequestPermissions;

  /// Batch size for data queries
  final int batchSize;

  /// Fraud prevention configuration
  final FraudPreventionConfig fraudPrevention;

  /// Enable data caching (default: true)
  final bool enableCaching;

  const HealthConnectConfig({
    this.autoRequestPermissions = true,
    this.batchSize = 1000,
    this.fraudPrevention = const FraudPreventionConfig(),
    this.enableCaching = true,
  });
}

/// Health Connect type mapping information
class HealthConnectTypeInfo {
  /// Record type name (null if not supported)
  final String? recordType;

  /// Required permissions
  final List<HealthConnectPermission> permissions;

  const HealthConnectTypeInfo({
    required this.recordType,
    required this.permissions,
  });
}

/// Mapping of DataType to Health Connect record types and permissions
const Map<DataType, HealthConnectTypeInfo> healthConnectTypeMap = {
  DataType.steps: HealthConnectTypeInfo(
    recordType: 'Steps',
    permissions: [HealthConnectPermission.readSteps],
  ),
  DataType.heartRate: HealthConnectTypeInfo(
    recordType: 'HeartRate',
    permissions: [HealthConnectPermission.readHeartRate],
  ),
  DataType.restingHeartRate: HealthConnectTypeInfo(
    recordType: 'HeartRate',
    permissions: [HealthConnectPermission.readHeartRate],
  ),
  DataType.sleep: HealthConnectTypeInfo(
    recordType: 'SleepSession',
    permissions: [HealthConnectPermission.readSleep],
  ),
  DataType.activity: HealthConnectTypeInfo(
    recordType: 'ExerciseSession',
    permissions: [HealthConnectPermission.readExercise],
  ),
  DataType.calories: HealthConnectTypeInfo(
    recordType: 'TotalCaloriesBurned',
    permissions: [
      HealthConnectPermission.readTotalCaloriesBurned,
      HealthConnectPermission.readActiveCaloriesBurned,
    ],
  ),
  DataType.distance: HealthConnectTypeInfo(
    recordType: 'Distance',
    permissions: [HealthConnectPermission.readDistance],
  ),
  DataType.bloodOxygen: HealthConnectTypeInfo(
    recordType: 'OxygenSaturation',
    permissions: [HealthConnectPermission.readOxygenSaturation],
  ),
  DataType.bloodPressure: HealthConnectTypeInfo(
    recordType: 'BloodPressure',
    permissions: [HealthConnectPermission.readBloodPressure],
  ),
  DataType.bodyTemperature: HealthConnectTypeInfo(
    recordType: 'BodyTemperature',
    permissions: [HealthConnectPermission.readBodyTemperature],
  ),
  DataType.weight: HealthConnectTypeInfo(
    recordType: 'Weight',
    permissions: [HealthConnectPermission.readWeight],
  ),
  DataType.height: HealthConnectTypeInfo(
    recordType: 'Height',
    permissions: [HealthConnectPermission.readHeight],
  ),
  DataType.heartRateVariability: HealthConnectTypeInfo(
    recordType: 'HeartRateVariabilityRmssd',
    permissions: [HealthConnectPermission.readHeartRateVariability],
  ),
  // Unsupported data types
  DataType.vo2Max: HealthConnectTypeInfo(
    recordType: null,
    permissions: [],
  ),
  DataType.activeMinutes: HealthConnectTypeInfo(
    recordType: null,
    permissions: [],
  ),
  DataType.bloodGlucose: HealthConnectTypeInfo(
    recordType: null,
    permissions: [],
  ),
  DataType.bmi: HealthConnectTypeInfo(
    recordType: null,
    permissions: [],
  ),
  DataType.bodyFat: HealthConnectTypeInfo(
    recordType: null,
    permissions: [],
  ),
  DataType.hydration: HealthConnectTypeInfo(
    recordType: null,
    permissions: [],
  ),
  DataType.nutrition: HealthConnectTypeInfo(
    recordType: null,
    permissions: [],
  ),
  DataType.respiratoryRate: HealthConnectTypeInfo(
    recordType: null,
    permissions: [],
  ),
};
