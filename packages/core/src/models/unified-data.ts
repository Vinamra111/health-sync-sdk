/**
 * Unified Health Data Models
 *
 * This module defines the standardized data structures used across all health data sources.
 * All plugins must transform their native data formats into these unified models.
 *
 * @module models/unified-data
 */

/**
 * Enumeration of supported health data sources
 *
 * @enum {string}
 */
export enum HealthSource {
  /** Google Health Connect (Android) */
  HEALTH_CONNECT = 'health_connect',

  /** Apple HealthKit (iOS) */
  APPLE_HEALTH = 'apple_health',

  /** Fitbit Cloud API */
  FITBIT = 'fitbit',

  /** Garmin Connect API */
  GARMIN = 'garmin',

  /** Oura Ring API */
  OURA = 'oura',

  /** Whoop API */
  WHOOP = 'whoop',

  /** Strava API */
  STRAVA = 'strava',

  /** MyFitnessPal API */
  MYFITNESSPAL = 'myfitnesspal',

  /** Generic/Unknown source */
  UNKNOWN = 'unknown',
}

/**
 * Enumeration of supported health data types
 *
 * @enum {string}
 */
export enum DataType {
  /** Step count data */
  STEPS = 'steps',

  /** Heart rate measurements (BPM) */
  HEART_RATE = 'heart_rate',

  /** Sleep session data */
  SLEEP = 'sleep',

  /** Physical activity/workout sessions */
  ACTIVITY = 'activity',

  /** Calories burned */
  CALORIES = 'calories',

  /** Distance traveled */
  DISTANCE = 'distance',

  /** Active minutes/energy */
  ACTIVE_MINUTES = 'active_minutes',

  /** Blood oxygen saturation (SpO2) */
  BLOOD_OXYGEN = 'blood_oxygen',

  /** Blood pressure measurements */
  BLOOD_PRESSURE = 'blood_pressure',

  /** Blood glucose levels */
  BLOOD_GLUCOSE = 'blood_glucose',

  /** Body temperature */
  BODY_TEMPERATURE = 'body_temperature',

  /** Body weight measurements */
  WEIGHT = 'weight',

  /** Height measurements */
  HEIGHT = 'height',

  /** Body Mass Index */
  BMI = 'bmi',

  /** Body fat percentage */
  BODY_FAT = 'body_fat',

  /** Hydration/water intake */
  HYDRATION = 'hydration',

  /** Nutrition/food intake */
  NUTRITION = 'nutrition',

  /** Respiratory rate */
  RESPIRATORY_RATE = 'respiratory_rate',

  /** Heart rate variability */
  HEART_RATE_VARIABILITY = 'heart_rate_variability',

  /** Resting heart rate */
  RESTING_HEART_RATE = 'resting_heart_rate',

  /** VO2 Max (cardio fitness) */
  VO2_MAX = 'vo2_max',
}

/**
 * Data quality/reliability scoring
 *
 * @enum {string}
 */
export enum DataQuality {
  /** High confidence data from medical-grade devices */
  HIGH = 'high',

  /** Medium confidence data from consumer devices */
  MEDIUM = 'medium',

  /** Low confidence data from estimated/derived sources */
  LOW = 'low',

  /** Unknown quality */
  UNKNOWN = 'unknown',
}

/**
 * Metadata associated with health data entries
 *
 * @interface DataMetadata
 */
export interface DataMetadata {
  /** Device or app that recorded the data */
  device?: string;

  /** Manufacturer of the recording device */
  manufacturer?: string;

  /** Model identifier of the device */
  model?: string;

  /** Platform/OS version */
  platform?: string;

  /** Quality/reliability score of the data */
  quality: DataQuality;

  /** Whether this data was manually entered by the user */
  isManualEntry: boolean;

  /** ISO timestamp when data was recorded by the source */
  recordedAt: string;

  /** ISO timestamp when data was synced to SDK */
  syncedAt: string;

  /** Original source-specific identifier */
  sourceId?: string;

  /** Additional platform-specific metadata */
  custom?: Record<string, unknown>;
}

/**
 * Base interface for all unified health data
 * All specific data types extend this interface
 *
 * @interface UnifiedHealthData
 */
export interface UnifiedHealthData {
  /** Unique identifier for this data entry (SDK-generated) */
  id: string;

  /** The health platform that provided this data */
  source: HealthSource;

  /** The type of health data */
  dataType: DataType;

  /** ISO 8601 timestamp of when the measurement was taken */
  timestamp: string;

  /** End timestamp for range-based data (e.g., sleep sessions, activities) */
  endTimestamp?: string;

  /** Metadata about the data source and quality */
  metadata: DataMetadata;
}

/**
 * Step count data
 *
 * @interface StepsData
 * @extends {UnifiedHealthData}
 */
export interface StepsData extends UnifiedHealthData {
  dataType: DataType.STEPS;

  /** Total number of steps */
  count: number;

  /** Distance covered in meters (if available) */
  distance?: number;
}

/**
 * Heart rate context/measurement type
 *
 * @enum {string}
 */
export enum HeartRateContext {
  /** Resting heart rate */
  RESTING = 'resting',

  /** Active/exercise heart rate */
  ACTIVE = 'active',

  /** Peak heart rate during intense activity */
  PEAK = 'peak',

  /** General/unspecified context */
  GENERAL = 'general',
}

/**
 * Heart rate measurement data
 *
 * @interface HeartRateData
 * @extends {UnifiedHealthData}
 */
export interface HeartRateData extends UnifiedHealthData {
  dataType: DataType.HEART_RATE;

  /** Heart rate in beats per minute */
  bpm: number;

  /** Context of the measurement */
  context: HeartRateContext;

  /** Minimum BPM in this measurement period (for aggregated data) */
  minBpm?: number;

  /** Maximum BPM in this measurement period (for aggregated data) */
  maxBpm?: number;
}

/**
 * Sleep stage types
 *
 * @enum {string}
 */
export enum SleepStage {
  /** Awake during sleep session */
  AWAKE = 'awake',

  /** Light sleep */
  LIGHT = 'light',

  /** Deep sleep */
  DEEP = 'deep',

  /** REM (Rapid Eye Movement) sleep */
  REM = 'rem',

  /** Unknown or unclassified stage */
  UNKNOWN = 'unknown',
}

/**
 * Individual sleep stage segment
 *
 * @interface SleepStageSegment
 */
export interface SleepStageSegment {
  /** Type of sleep stage */
  stage: SleepStage;

  /** ISO timestamp when this stage started */
  startTime: string;

  /** ISO timestamp when this stage ended */
  endTime: string;

  /** Duration of this stage in minutes */
  duration: number;
}

/**
 * Sleep session data
 *
 * @interface SleepData
 * @extends {UnifiedHealthData}
 */
export interface SleepData extends UnifiedHealthData {
  dataType: DataType.SLEEP;

  /** Array of sleep stages throughout the session */
  stages: SleepStageSegment[];

  /** Total sleep duration in minutes */
  totalDuration: number;

  /** Sleep efficiency percentage (0-100) */
  efficiency: number;

  /** Time in bed in minutes */
  timeInBed?: number;

  /** Time to fall asleep in minutes */
  timeToFallAsleep?: number;

  /** Number of times awoken during sleep */
  awakeDuration?: number;

  /** Total light sleep in minutes */
  lightSleepDuration?: number;

  /** Total deep sleep in minutes */
  deepSleepDuration?: number;

  /** Total REM sleep in minutes */
  remSleepDuration?: number;
}

/**
 * Activity/Exercise type
 *
 * @enum {string}
 */
export enum ActivityType {
  /** Walking */
  WALKING = 'walking',

  /** Running */
  RUNNING = 'running',

  /** Cycling */
  CYCLING = 'cycling',

  /** Swimming */
  SWIMMING = 'swimming',

  /** Hiking */
  HIKING = 'hiking',

  /** Yoga */
  YOGA = 'yoga',

  /** Weight training */
  WEIGHT_TRAINING = 'weight_training',

  /** General gym workout */
  WORKOUT = 'workout',

  /** Sports activity */
  SPORTS = 'sports',

  /** Dancing */
  DANCING = 'dancing',

  /** Meditation */
  MEDITATION = 'meditation',

  /** Other/unspecified activity */
  OTHER = 'other',
}

/**
 * Physical activity/workout session data
 *
 * @interface ActivityData
 * @extends {UnifiedHealthData}
 */
export interface ActivityData extends UnifiedHealthData {
  dataType: DataType.ACTIVITY;

  /** Type of activity performed */
  activityType: ActivityType;

  /** Duration of activity in minutes */
  duration: number;

  /** Calories burned during activity */
  calories?: number;

  /** Distance covered in meters */
  distance?: number;

  /** Average heart rate during activity */
  averageHeartRate?: number;

  /** Peak heart rate during activity */
  peakHeartRate?: number;

  /** Average pace (minutes per kilometer) */
  averagePace?: number;

  /** Elevation gained in meters */
  elevationGain?: number;

  /** Activity-specific metrics */
  metrics?: Record<string, number>;
}

/**
 * Calorie data
 *
 * @interface CaloriesData
 * @extends {UnifiedHealthData}
 */
export interface CaloriesData extends UnifiedHealthData {
  dataType: DataType.CALORIES;

  /** Total calories burned */
  total: number;

  /** Active calories (from exercise) */
  active?: number;

  /** Basal metabolic rate calories */
  bmr?: number;
}

/**
 * Distance data
 *
 * @interface DistanceData
 * @extends {UnifiedHealthData}
 */
export interface DistanceData extends UnifiedHealthData {
  dataType: DataType.DISTANCE;

  /** Distance in meters */
  meters: number;

  /** Source of distance measurement (GPS, pedometer, etc.) */
  measurementSource?: string;
}

/**
 * Blood oxygen (SpO2) data
 *
 * @interface BloodOxygenData
 * @extends {UnifiedHealthData}
 */
export interface BloodOxygenData extends UnifiedHealthData {
  dataType: DataType.BLOOD_OXYGEN;

  /** Oxygen saturation percentage (0-100) */
  percentage: number;

  /** Measurement method (pulse oximeter, etc.) */
  method?: string;
}

/**
 * Blood pressure data
 *
 * @interface BloodPressureData
 * @extends {UnifiedHealthData}
 */
export interface BloodPressureData extends UnifiedHealthData {
  dataType: DataType.BLOOD_PRESSURE;

  /** Systolic pressure in mmHg */
  systolic: number;

  /** Diastolic pressure in mmHg */
  diastolic: number;

  /** Pulse pressure (systolic - diastolic) */
  pulsePressure?: number;

  /** Measurement position (sitting, standing, lying) */
  position?: string;
}

/**
 * Body weight data
 *
 * @interface WeightData
 * @extends {UnifiedHealthData}
 */
export interface WeightData extends UnifiedHealthData {
  dataType: DataType.WEIGHT;

  /** Weight in kilograms */
  kilograms: number;

  /** Weight in pounds (auto-converted) */
  pounds?: number;
}

/**
 * Heart rate variability data
 *
 * @interface HeartRateVariabilityData
 * @extends {UnifiedHealthData}
 */
export interface HeartRateVariabilityData extends UnifiedHealthData {
  dataType: DataType.HEART_RATE_VARIABILITY;

  /** HRV in milliseconds (SDNN or RMSSD) */
  milliseconds: number;

  /** Type of HRV measurement */
  method?: 'SDNN' | 'RMSSD' | 'pNN50' | 'other';
}

/**
 * VO2 Max (cardio fitness) data
 *
 * @interface VO2MaxData
 * @extends {UnifiedHealthData}
 */
export interface VO2MaxData extends UnifiedHealthData {
  dataType: DataType.VO2_MAX;

  /** VO2 Max value in mL/kg/min */
  value: number;

  /** Measurement method (test, estimated, etc.) */
  method?: string;
}

/**
 * Union type of all specific health data types
 * Used for type-safe handling of any health data
 */
export type AnyHealthData =
  | StepsData
  | HeartRateData
  | SleepData
  | ActivityData
  | CaloriesData
  | DistanceData
  | BloodOxygenData
  | BloodPressureData
  | WeightData
  | HeartRateVariabilityData
  | VO2MaxData
  | UnifiedHealthData;

/**
 * Type guard to check if data is of a specific type
 *
 * @template T - The specific health data type
 * @param {UnifiedHealthData} data - The data to check
 * @param {DataType} type - The expected data type
 * @returns {data is T} True if data matches the type
 */
export function isDataType<T extends UnifiedHealthData>(
  data: UnifiedHealthData,
  type: DataType
): data is T {
  return data.dataType === type;
}

/**
 * Helper function to validate health data structure
 *
 * @param {unknown} data - Data to validate
 * @returns {data is UnifiedHealthData} True if data has valid structure
 */
export function isValidHealthData(data: unknown): data is UnifiedHealthData {
  if (!data || typeof data !== 'object') {
    return false;
  }

  const obj = data as Record<string, unknown>;

  return (
    typeof obj['id'] === 'string' &&
    typeof obj['source'] === 'string' &&
    typeof obj['dataType'] === 'string' &&
    typeof obj['timestamp'] === 'string' &&
    typeof obj['metadata'] === 'object' &&
    obj['metadata'] !== null
  );
}
