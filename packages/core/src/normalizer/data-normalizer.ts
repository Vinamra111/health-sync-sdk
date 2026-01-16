/**
 * Data Normalizer
 *
 * Main class for transforming platform-specific health data into unified models.
 * Handles validation, quality scoring, unit conversion, and data transformation.
 *
 * @module normalizer/data-normalizer
 */

import {
  UnifiedHealthData,
  AnyHealthData,
  DataType,
  DataMetadata,
  DataQuality,
  StepsData,
  HeartRateData,
  SleepData,
  ActivityData,
  CaloriesData,
  DistanceData,
  BloodOxygenData,
  BloodPressureData,
  WeightData,
  HeartRateVariabilityData,
  VO2MaxData,
  HeartRateContext,
  SleepStage,
  ActivityType,
} from '../models/unified-data';
import { RawHealthData } from '../plugins/plugin-interface';
import { UnitConverter } from './unit-converter';
import { DataValidator } from './validator';
import { QualityScorer, QualityScore } from './quality-scorer';
import { ValidationError } from '../types/config';

/**
 * Normalization options
 *
 * @interface NormalizationOptions
 */
export interface NormalizationOptions {
  /** Whether to validate data (default: true) */
  validate?: boolean;

  /** Whether to calculate quality scores (default: true) */
  calculateQuality?: boolean;

  /** Whether to throw on validation errors (default: false) */
  strictValidation?: boolean;

  /** Minimum quality threshold (data below this is rejected) */
  minQuality?: DataQuality;

  /** Custom ID generator */
  generateId?: () => string;
}

/**
 * Normalization result
 *
 * @interface NormalizationResult
 */
export interface NormalizationResult {
  /** Normalized data */
  data: AnyHealthData[];

  /** Validation warnings */
  warnings: string[];

  /** Items that failed validation */
  failed: Array<{ raw: RawHealthData; errors: string[] }>;

  /** Statistics */
  stats: {
    total: number;
    normalized: number;
    failed: number;
    warnings: number;
  };
}

/**
 * Default normalization options
 */
const DEFAULT_OPTIONS: Required<NormalizationOptions> = {
  validate: true,
  calculateQuality: true,
  strictValidation: false,
  minQuality: DataQuality.LOW,
  generateId: () => `health_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
};

/**
 * Data Normalizer
 *
 * Transforms raw platform-specific data into unified health data models.
 *
 * @class DataNormalizer
 */
export class DataNormalizer {
  private options: Required<NormalizationOptions>;

  /**
   * Create a new DataNormalizer
   *
   * @param {NormalizationOptions} [options] - Normalization options
   */
  constructor(options?: NormalizationOptions) {
    this.options = { ...DEFAULT_OPTIONS, ...options };
  }

  /**
   * Normalize raw health data
   *
   * @param {RawHealthData[]} rawData - Raw data from plugin
   * @returns {NormalizationResult} Normalization result
   */
  normalize(rawData: RawHealthData[]): NormalizationResult {
    const normalized: AnyHealthData[] = [];
    const warnings: string[] = [];
    const failed: Array<{ raw: RawHealthData; errors: string[] }> = [];

    for (const raw of rawData) {
      try {
        const data = this.normalizeOne(raw);

        // Apply quality threshold
        if (this.options.calculateQuality && this.options.minQuality) {
          const qualityScore = data.metadata.quality;
          if (!QualityScorer.meetsThreshold({ quality: qualityScore } as QualityScore, this.options.minQuality)) {
            warnings.push(`Data quality below threshold for ${raw.sourceId ?? 'unknown'}`);
            continue;
          }
        }

        normalized.push(data);
      } catch (error) {
        const errorMessage = (error as Error).message;
        warnings.push(errorMessage);
        failed.push({ raw, errors: [errorMessage] });

        if (this.options.strictValidation) {
          throw error;
        }
      }
    }

    return {
      data: normalized,
      warnings,
      failed,
      stats: {
        total: rawData.length,
        normalized: normalized.length,
        failed: failed.length,
        warnings: warnings.length,
      },
    };
  }

  /**
   * Normalize a single raw data item
   *
   * @param {RawHealthData} raw - Raw data item
   * @returns {AnyHealthData} Normalized data
   * @private
   */
  private normalizeOne(raw: RawHealthData): AnyHealthData {
    // Determine data type from source data type or infer
    const dataType = this.inferDataType(raw);

    // Create base metadata
    const metadata = this.createMetadata(raw, dataType);

    // Create base unified data
    const base: UnifiedHealthData = {
      id: this.options.generateId(),
      source: raw.source,
      dataType,
      timestamp: raw.timestamp,
      metadata,
    };

    if (raw.endTimestamp !== undefined) {
      base.endTimestamp = raw.endTimestamp;
    }

    // Normalize based on data type
    switch (dataType) {
      case DataType.STEPS:
        return this.normalizeSteps(raw, base);

      case DataType.HEART_RATE:
      case DataType.RESTING_HEART_RATE:
        return this.normalizeHeartRate(raw, base);

      case DataType.SLEEP:
        return this.normalizeSleep(raw, base);

      case DataType.ACTIVITY:
        return this.normalizeActivity(raw, base);

      case DataType.CALORIES:
        return this.normalizeCalories(raw, base);

      case DataType.DISTANCE:
        return this.normalizeDistance(raw, base);

      case DataType.BLOOD_OXYGEN:
        return this.normalizeBloodOxygen(raw, base);

      case DataType.BLOOD_PRESSURE:
        return this.normalizeBloodPressure(raw, base);

      case DataType.WEIGHT:
        return this.normalizeWeight(raw, base);

      case DataType.HEART_RATE_VARIABILITY:
        return this.normalizeHeartRateVariability(raw, base);

      case DataType.VO2_MAX:
        return this.normalizeVO2Max(raw, base);

      default:
        // Return base data for unsupported types
        return base;
    }
  }

  /**
   * Infer data type from raw data
   *
   * @param {RawHealthData} raw - Raw data
   * @returns {DataType} Inferred data type
   * @private
   */
  private inferDataType(raw: RawHealthData): DataType {
    const sourceType = raw.sourceDataType.toLowerCase();

    // Map common source type names to DataType
    if (sourceType.includes('step')) {
      return DataType.STEPS;
    }
    if (sourceType.includes('heart') && sourceType.includes('rate')) {
      return DataType.HEART_RATE;
    }
    if (sourceType.includes('sleep')) {
      return DataType.SLEEP;
    }
    if (sourceType.includes('activity') || sourceType.includes('workout')) {
      return DataType.ACTIVITY;
    }
    if (sourceType.includes('calorie')) {
      return DataType.CALORIES;
    }
    if (sourceType.includes('distance')) {
      return DataType.DISTANCE;
    }
    if (sourceType.includes('oxygen') || sourceType.includes('spo2')) {
      return DataType.BLOOD_OXYGEN;
    }
    if (sourceType.includes('blood') && sourceType.includes('pressure')) {
      return DataType.BLOOD_PRESSURE;
    }
    if (sourceType.includes('weight')) {
      return DataType.WEIGHT;
    }
    if (sourceType.includes('hrv')) {
      return DataType.HEART_RATE_VARIABILITY;
    }
    if (sourceType.includes('vo2')) {
      return DataType.VO2_MAX;
    }

    // Default fallback - use raw.raw.type if available
    if (raw.raw['type']) {
      return raw.raw['type'] as DataType;
    }

    throw new ValidationError(
      `Unable to infer data type from source type: ${raw.sourceDataType}`,
      ['sourceDataType']
    );
  }

  /**
   * Create metadata for normalized data
   *
   * @param {RawHealthData} raw - Raw data
   * @param {DataType} dataType - Data type
   * @returns {DataMetadata} Metadata
   * @private
   */
  private createMetadata(raw: RawHealthData, dataType: DataType): DataMetadata {
    const device = (raw.raw['device'] as string) ?? undefined;
    const manufacturer = (raw.raw['manufacturer'] as string) ?? undefined;
    const model = (raw.raw['model'] as string) ?? undefined;
    const platform = (raw.raw['platform'] as string) ?? undefined;
    const isManualEntry = (raw.raw['isManual'] as boolean) ?? false;
    const recordedAt = raw.timestamp;
    const syncedAt = new Date().toISOString();

    let quality = DataQuality.MEDIUM;

    if (this.options.calculateQuality) {
      const qualityScore = QualityScorer.calculateQualityScore({
        source: raw.source,
        dataType,
        manufacturer,
        model,
        isManualEntry,
        recordedAt: new Date(recordedAt),
        syncedAt: new Date(syncedAt),
        completeness: 1.0,
      });

      quality = qualityScore.quality;
    }

    const metadata: DataMetadata = {
      quality,
      isManualEntry,
      recordedAt,
      syncedAt,
    };

    if (device !== undefined) {
      metadata.device = device;
    }
    if (manufacturer !== undefined) {
      metadata.manufacturer = manufacturer;
    }
    if (model !== undefined) {
      metadata.model = model;
    }
    if (platform !== undefined) {
      metadata.platform = platform;
    }
    if (raw.sourceId !== undefined) {
      metadata.sourceId = raw.sourceId;
    }

    const customMetadata = raw.raw['metadata'] as Record<string, unknown> | undefined;
    if (customMetadata !== undefined) {
      metadata.custom = customMetadata;
    }

    return metadata;
  }

  // ============================================================================
  // Data Type Normalizers
  // ============================================================================

  /**
   * Normalize steps data
   *
   * @param {RawHealthData} raw - Raw data
   * @param {UnifiedHealthData} base - Base unified data
   * @returns {StepsData} Normalized steps data
   * @private
   */
  private normalizeSteps(raw: RawHealthData, base: UnifiedHealthData): StepsData {
    const count = Number(raw.raw['count'] ?? raw.raw['steps'] ?? 0);
    const distance = raw.raw['distance'] ? Number(raw.raw['distance']) : undefined;

    if (this.options.validate) {
      const validation = DataValidator.validateSteps(count);
      if (!validation.valid) {
        throw new ValidationError(`Invalid steps data: ${validation.errors.join(', ')}`, ['count']);
      }
    }

    const result: StepsData = {
      ...base,
      dataType: DataType.STEPS,
      count,
    };

    if (distance !== undefined) {
      result.distance = distance;
    }

    return result;
  }

  /**
   * Normalize heart rate data
   *
   * @param {RawHealthData} raw - Raw data
   * @param {UnifiedHealthData} base - Base unified data
   * @returns {HeartRateData} Normalized heart rate data
   * @private
   */
  private normalizeHeartRate(raw: RawHealthData, base: UnifiedHealthData): HeartRateData {
    const bpm = Number(raw.raw['bpm'] ?? raw.raw['heartRate'] ?? 0);
    const context = (raw.raw['context'] as HeartRateContext) ?? HeartRateContext.GENERAL;
    const minBpm = raw.raw['minBpm'] ? Number(raw.raw['minBpm']) : undefined;
    const maxBpm = raw.raw['maxBpm'] ? Number(raw.raw['maxBpm']) : undefined;

    if (this.options.validate) {
      const validation = DataValidator.validateHeartRate(bpm);
      if (!validation.valid) {
        throw new ValidationError(`Invalid heart rate data: ${validation.errors.join(', ')}`, ['bpm']);
      }
    }

    const result: HeartRateData = {
      ...base,
      dataType: DataType.HEART_RATE,
      bpm,
      context,
    };

    if (minBpm !== undefined) {
      result.minBpm = minBpm;
    }
    if (maxBpm !== undefined) {
      result.maxBpm = maxBpm;
    }

    return result;
  }

  /**
   * Normalize sleep data
   *
   * @param {RawHealthData} raw - Raw data
   * @param {UnifiedHealthData} base - Base unified data
   * @returns {SleepData} Normalized sleep data
   * @private
   */
  private normalizeSleep(raw: RawHealthData, base: UnifiedHealthData): SleepData {
    const stages = (raw.raw['stages'] as Array<{ stage: SleepStage; startTime: string; endTime: string; duration: number }>) ?? [];
    const totalDuration = Number(raw.raw['totalDuration'] ?? 0);
    const efficiency = Number(raw.raw['efficiency'] ?? 100);

    if (this.options.validate) {
      const validation = DataValidator.validateSleepDuration(totalDuration);
      const efficiencyValidation = DataValidator.validateSleepEfficiency(efficiency);

      if (!validation.valid) {
        throw new ValidationError(`Invalid sleep duration: ${validation.errors.join(', ')}`, ['totalDuration']);
      }
      if (!efficiencyValidation.valid) {
        throw new ValidationError(`Invalid sleep efficiency: ${efficiencyValidation.errors.join(', ')}`, ['efficiency']);
      }
    }

    const result: SleepData = {
      ...base,
      dataType: DataType.SLEEP,
      stages,
      totalDuration,
      efficiency,
    };

    if (raw.raw['timeInBed']) {
      result.timeInBed = Number(raw.raw['timeInBed']);
    }
    if (raw.raw['timeToFallAsleep']) {
      result.timeToFallAsleep = Number(raw.raw['timeToFallAsleep']);
    }
    if (raw.raw['awakeDuration']) {
      result.awakeDuration = Number(raw.raw['awakeDuration']);
    }
    if (raw.raw['lightSleepDuration']) {
      result.lightSleepDuration = Number(raw.raw['lightSleepDuration']);
    }
    if (raw.raw['deepSleepDuration']) {
      result.deepSleepDuration = Number(raw.raw['deepSleepDuration']);
    }
    if (raw.raw['remSleepDuration']) {
      result.remSleepDuration = Number(raw.raw['remSleepDuration']);
    }

    return result;
  }

  /**
   * Normalize activity data
   *
   * @param {RawHealthData} raw - Raw data
   * @param {UnifiedHealthData} base - Base unified data
   * @returns {ActivityData} Normalized activity data
   * @private
   */
  private normalizeActivity(raw: RawHealthData, base: UnifiedHealthData): ActivityData {
    const activityType = (raw.raw['activityType'] as ActivityType) ?? ActivityType.OTHER;
    const duration = Number(raw.raw['duration'] ?? 0);

    const result: ActivityData = {
      ...base,
      dataType: DataType.ACTIVITY,
      activityType,
      duration,
    };

    if (raw.raw['calories']) {
      result.calories = Number(raw.raw['calories']);
    }
    if (raw.raw['distance']) {
      result.distance = Number(raw.raw['distance']);
    }
    if (raw.raw['averageHeartRate']) {
      result.averageHeartRate = Number(raw.raw['averageHeartRate']);
    }
    if (raw.raw['peakHeartRate']) {
      result.peakHeartRate = Number(raw.raw['peakHeartRate']);
    }
    if (raw.raw['averagePace']) {
      result.averagePace = Number(raw.raw['averagePace']);
    }
    if (raw.raw['elevationGain']) {
      result.elevationGain = Number(raw.raw['elevationGain']);
    }
    if (raw.raw['metrics']) {
      result.metrics = raw.raw['metrics'] as Record<string, number>;
    }

    return result;
  }

  /**
   * Normalize calories data
   *
   * @param {RawHealthData} raw - Raw data
   * @param {UnifiedHealthData} base - Base unified data
   * @returns {CaloriesData} Normalized calories data
   * @private
   */
  private normalizeCalories(raw: RawHealthData, base: UnifiedHealthData): CaloriesData {
    const total = Number(raw.raw['total'] ?? raw.raw['calories'] ?? 0);

    if (this.options.validate) {
      const validation = DataValidator.validateCalories(total);
      if (!validation.valid) {
        throw new ValidationError(`Invalid calories data: ${validation.errors.join(', ')}`, ['total']);
      }
    }

    const result: CaloriesData = {
      ...base,
      dataType: DataType.CALORIES,
      total,
    };

    if (raw.raw['active']) {
      result.active = Number(raw.raw['active']);
    }
    if (raw.raw['bmr']) {
      result.bmr = Number(raw.raw['bmr']);
    }

    return result;
  }

  /**
   * Normalize distance data
   *
   * @param {RawHealthData} raw - Raw data
   * @param {UnifiedHealthData} base - Base unified data
   * @returns {DistanceData} Normalized distance data
   * @private
   */
  private normalizeDistance(raw: RawHealthData, base: UnifiedHealthData): DistanceData {
    let meters = Number(raw.raw['meters'] ?? raw.raw['distance'] ?? 0);

    // Convert if in different unit
    const unit = raw.raw['unit'] as string;
    if (unit === 'km' || unit === 'kilometers') {
      meters = UnitConverter.kmToMeters(meters);
    } else if (unit === 'miles') {
      meters = UnitConverter.milesToMeters(meters);
    }

    if (this.options.validate) {
      const validation = DataValidator.validateDistance(meters);
      if (!validation.valid) {
        throw new ValidationError(`Invalid distance data: ${validation.errors.join(', ')}`, ['meters']);
      }
    }

    const result: DistanceData = {
      ...base,
      dataType: DataType.DISTANCE,
      meters,
    };

    const measurementSource = raw.raw['source'] as string | undefined;
    if (measurementSource !== undefined) {
      result.measurementSource = measurementSource;
    }

    return result;
  }

  /**
   * Normalize blood oxygen data
   *
   * @param {RawHealthData} raw - Raw data
   * @param {UnifiedHealthData} base - Base unified data
   * @returns {BloodOxygenData} Normalized blood oxygen data
   * @private
   */
  private normalizeBloodOxygen(raw: RawHealthData, base: UnifiedHealthData): BloodOxygenData {
    const percentage = Number(raw.raw['percentage'] ?? raw.raw['spo2'] ?? 0);

    if (this.options.validate) {
      const validation = DataValidator.validateBloodOxygen(percentage);
      if (!validation.valid) {
        throw new ValidationError(`Invalid blood oxygen data: ${validation.errors.join(', ')}`, ['percentage']);
      }
    }

    const result: BloodOxygenData = {
      ...base,
      dataType: DataType.BLOOD_OXYGEN,
      percentage,
    };

    const method = raw.raw['method'] as string | undefined;
    if (method !== undefined) {
      result.method = method;
    }

    return result;
  }

  /**
   * Normalize blood pressure data
   *
   * @param {RawHealthData} raw - Raw data
   * @param {UnifiedHealthData} base - Base unified data
   * @returns {BloodPressureData} Normalized blood pressure data
   * @private
   */
  private normalizeBloodPressure(raw: RawHealthData, base: UnifiedHealthData): BloodPressureData {
    const systolic = Number(raw.raw['systolic'] ?? 0);
    const diastolic = Number(raw.raw['diastolic'] ?? 0);

    if (this.options.validate) {
      const validation = DataValidator.validateBloodPressure(systolic, diastolic);
      if (!validation.valid) {
        throw new ValidationError(`Invalid blood pressure data: ${validation.errors.join(', ')}`, ['systolic', 'diastolic']);
      }
    }

    const result: BloodPressureData = {
      ...base,
      dataType: DataType.BLOOD_PRESSURE,
      systolic,
      diastolic,
    };

    const pulsePressure = systolic - diastolic;
    if (pulsePressure !== undefined) {
      result.pulsePressure = pulsePressure;
    }

    const position = raw.raw['position'] as string | undefined;
    if (position !== undefined) {
      result.position = position;
    }

    return result;
  }

  /**
   * Normalize weight data
   *
   * @param {RawHealthData} raw - Raw data
   * @param {UnifiedHealthData} base - Base unified data
   * @returns {WeightData} Normalized weight data
   * @private
   */
  private normalizeWeight(raw: RawHealthData, base: UnifiedHealthData): WeightData {
    let kilograms = Number(raw.raw['kilograms'] ?? raw.raw['weight'] ?? 0);

    // Convert if in different unit
    const unit = raw.raw['unit'] as string;
    if (unit === 'lbs' || unit === 'pounds') {
      kilograms = UnitConverter.poundsToKg(kilograms);
    }

    if (this.options.validate) {
      const validation = DataValidator.validateWeight(kilograms);
      if (!validation.valid) {
        throw new ValidationError(`Invalid weight data: ${validation.errors.join(', ')}`, ['kilograms']);
      }
    }

    const result: WeightData = {
      ...base,
      dataType: DataType.WEIGHT,
      kilograms,
    };

    // Always include pounds conversion for convenience
    const pounds = UnitConverter.kgToPounds(kilograms);
    if (pounds !== undefined) {
      result.pounds = pounds;
    }

    return result;
  }

  /**
   * Normalize heart rate variability data
   *
   * @param {RawHealthData} raw - Raw data
   * @param {UnifiedHealthData} base - Base unified data
   * @returns {HeartRateVariabilityData} Normalized HRV data
   * @private
   */
  private normalizeHeartRateVariability(raw: RawHealthData, base: UnifiedHealthData): HeartRateVariabilityData {
    const milliseconds = Number(raw.raw['milliseconds'] ?? raw.raw['hrv'] ?? 0);

    const result: HeartRateVariabilityData = {
      ...base,
      dataType: DataType.HEART_RATE_VARIABILITY,
      milliseconds,
    };

    const method = (raw.raw['method'] as 'SDNN' | 'RMSSD' | 'pNN50' | 'other') ?? 'SDNN';
    if (method !== undefined) {
      result.method = method;
    }

    return result;
  }

  /**
   * Normalize VO2 Max data
   *
   * @param {RawHealthData} raw - Raw data
   * @param {UnifiedHealthData} base - Base unified data
   * @returns {VO2MaxData} Normalized VO2 Max data
   * @private
   */
  private normalizeVO2Max(raw: RawHealthData, base: UnifiedHealthData): VO2MaxData {
    const value = Number(raw.raw['value'] ?? raw.raw['vo2max'] ?? 0);

    const result: VO2MaxData = {
      ...base,
      dataType: DataType.VO2_MAX,
      value,
    };

    const method = raw.raw['method'] as string | undefined;
    if (method !== undefined) {
      result.method = method;
    }

    return result;
  }
}
