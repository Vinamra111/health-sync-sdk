/**
 * Quality Scorer
 *
 * Assesses the quality and reliability of health data based on various factors
 * such as source type, device accuracy, manual entry, and data completeness.
 *
 * @module normalizer/quality-scorer
 */

import { HealthSource, DataType, DataQuality } from '../models/unified-data';

/**
 * Quality score factors
 *
 * @interface QualityFactors
 */
export interface QualityFactors {
  /** Source reliability (0-1) */
  sourceReliability: number;

  /** Device accuracy rating (0-1) */
  deviceAccuracy: number;

  /** Data completeness (0-1) */
  completeness: number;

  /** Freshness of data (0-1) */
  freshness: number;

  /** Whether data was manually entered */
  isManual: boolean;
}

/**
 * Quality score result
 *
 * @interface QualityScore
 */
export interface QualityScore {
  /** Overall quality level */
  quality: DataQuality;

  /** Numeric score (0-100) */
  score: number;

  /** Individual factor scores */
  factors: QualityFactors;

  /** Confidence level (0-1) */
  confidence: number;
}

/**
 * Quality Scorer
 *
 * Calculates quality scores for health data.
 *
 * @class QualityScorer
 */
export class QualityScorer {
  /**
   * Source reliability ratings
   * Medical-grade devices have highest reliability
   */
  private static readonly SOURCE_RELIABILITY: Record<HealthSource, number> = {
    [HealthSource.HEALTH_CONNECT]: 0.8, // Aggregated data, generally reliable
    [HealthSource.APPLE_HEALTH]: 0.85, // Apple's quality control
    [HealthSource.FITBIT]: 0.75, // Consumer device
    [HealthSource.GARMIN]: 0.8, // Sports/fitness focused
    [HealthSource.OURA]: 0.85, // High-quality sleep tracking
    [HealthSource.WHOOP]: 0.85, // Professional athlete-grade
    [HealthSource.STRAVA]: 0.7, // Activity tracking
    [HealthSource.MYFITNESSPAL]: 0.6, // Self-reported nutrition
    [HealthSource.UNKNOWN]: 0.5, // Unknown source
  };

  /**
   * Device manufacturer accuracy ratings
   */
  private static readonly DEVICE_ACCURACY: Record<string, number> = {
    apple: 0.9,
    samsung: 0.85,
    garmin: 0.85,
    fitbit: 0.8,
    oura: 0.9,
    whoop: 0.9,
    polar: 0.85,
    withings: 0.8,
    xiaomi: 0.7,
    huawei: 0.75,
    unknown: 0.6,
  };

  /**
   * Calculate quality score for health data
   *
   * @param {Object} params - Scoring parameters
   * @param {HealthSource} params.source - Data source
   * @param {DataType} params.dataType - Type of data
   * @param {string} [params.manufacturer] - Device manufacturer
   * @param {string} [params.model] - Device model
   * @param {boolean} [params.isManualEntry] - Whether manually entered
   * @param {Date} [params.recordedAt] - When data was recorded
   * @param {Date} [params.syncedAt] - When data was synced
   * @param {number} [params.completeness] - Data completeness (0-1)
   * @returns {QualityScore} Quality score
   */
  static calculateQualityScore(params: {
    source: HealthSource;
    dataType: DataType;
    manufacturer?: string;
    model?: string;
    isManualEntry?: boolean;
    recordedAt?: Date;
    syncedAt?: Date;
    completeness?: number;
  }): QualityScore {
    const {
      source,
      dataType,
      manufacturer,
      isManualEntry = false,
      recordedAt,
      syncedAt,
      completeness = 1.0,
    } = params;

    // Get source reliability
    const sourceReliability = this.SOURCE_RELIABILITY[source] ?? 0.5;

    // Get device accuracy
    const deviceAccuracy = this.getDeviceAccuracy(manufacturer, dataType);

    // Calculate freshness
    const freshness = this.calculateFreshness(recordedAt, syncedAt);

    // Calculate overall score
    const factors: QualityFactors = {
      sourceReliability,
      deviceAccuracy,
      completeness,
      freshness,
      isManual: isManualEntry,
    };

    // Weighted average (manual entries get lower weight)
    const weights = {
      source: 0.3,
      device: 0.3,
      completeness: 0.2,
      freshness: 0.2,
    };

    let score =
      sourceReliability * weights.source +
      deviceAccuracy * weights.device +
      completeness * weights.completeness +
      freshness * weights.freshness;

    // Penalty for manual entry (less reliable)
    if (isManualEntry) {
      score *= 0.7;
    }

    // Convert to 0-100 scale
    const numericScore = Math.round(score * 100);

    // Determine quality level
    const quality = this.scoreToQuality(numericScore);

    // Calculate confidence based on factor variance
    const confidence = this.calculateConfidence(factors);

    return {
      quality,
      score: numericScore,
      factors,
      confidence,
    };
  }

  /**
   * Get device accuracy rating
   *
   * @param {string} [manufacturer] - Device manufacturer
   * @param {DataType} dataType - Type of data
   * @returns {number} Accuracy rating (0-1)
   * @private
   */
  private static getDeviceAccuracy(manufacturer: string | undefined, dataType: DataType): number {
    if (!manufacturer) {
      return 0.6;
    }

    const mfr = manufacturer.toLowerCase();
    let baseAccuracy = this.DEVICE_ACCURACY[mfr] ?? this.DEVICE_ACCURACY['unknown'] ?? 0.6;

    // Adjust based on data type
    // Some devices are more accurate for specific metrics
    if (dataType === DataType.HEART_RATE) {
      // Chest straps and dedicated monitors are more accurate
      if (mfr.includes('polar') || mfr.includes('garmin')) {
        baseAccuracy *= 1.1;
      }
    } else if (dataType === DataType.SLEEP) {
      // Specialized sleep trackers
      if (mfr.includes('oura') || mfr.includes('whoop')) {
        baseAccuracy *= 1.1;
      }
    } else if (dataType === DataType.STEPS) {
      // Most devices are good at step counting
      baseAccuracy *= 1.05;
    }

    return Math.min(baseAccuracy, 1.0);
  }

  /**
   * Calculate freshness score based on recording and sync times
   *
   * @param {Date} [recordedAt] - When data was recorded
   * @param {Date} [syncedAt] - When data was synced
   * @returns {number} Freshness score (0-1)
   * @private
   */
  private static calculateFreshness(recordedAt?: Date, _syncedAt?: Date): number {
    if (!recordedAt) {
      return 0.7; // Default if no timestamp
    }

    const now = Date.now();
    const recorded = recordedAt.getTime();
    const ageMs = now - recorded;

    // Data age scoring (fresher = better)
    // 0-1 hour: 1.0
    // 1-24 hours: 0.9
    // 1-7 days: 0.8
    // 1-30 days: 0.7
    // >30 days: 0.6

    const ageHours = ageMs / (1000 * 60 * 60);

    if (ageHours <= 1) {
      return 1.0;
    } else if (ageHours <= 24) {
      return 0.9;
    } else if (ageHours <= 24 * 7) {
      return 0.8;
    } else if (ageHours <= 24 * 30) {
      return 0.7;
    } else {
      return 0.6;
    }
  }

  /**
   * Convert numeric score to quality level
   *
   * @param {number} score - Numeric score (0-100)
   * @returns {DataQuality} Quality level
   * @private
   */
  private static scoreToQuality(score: number): DataQuality {
    if (score >= 80) {
      return DataQuality.HIGH;
    } else if (score >= 60) {
      return DataQuality.MEDIUM;
    } else if (score >= 40) {
      return DataQuality.LOW;
    } else {
      return DataQuality.UNKNOWN;
    }
  }

  /**
   * Calculate confidence in the quality score
   *
   * Higher variance in factors = lower confidence
   *
   * @param {QualityFactors} factors - Quality factors
   * @returns {number} Confidence level (0-1)
   * @private
   */
  private static calculateConfidence(factors: QualityFactors): number {
    const values = [
      factors.sourceReliability,
      factors.deviceAccuracy,
      factors.completeness,
      factors.freshness,
    ];

    // Calculate variance
    const mean = values.reduce((sum, val) => sum + val, 0) / values.length;
    const variance =
      values.reduce((sum, val) => sum + Math.pow(val - mean, 2), 0) / values.length;

    // Lower variance = higher confidence
    // Variance ranges from 0 (perfect agreement) to ~0.25 (max disagreement)
    const confidence = 1 - Math.min(variance * 4, 1);

    return confidence;
  }

  /**
   * Compare quality scores
   *
   * Returns the better quality score.
   *
   * @param {QualityScore} a - First score
   * @param {QualityScore} b - Second score
   * @returns {QualityScore} Better quality score
   */
  static compareBetter(a: QualityScore, b: QualityScore): QualityScore {
    if (a.score > b.score) {
      return a;
    } else if (b.score > a.score) {
      return b;
    } else {
      // Same score, use confidence as tiebreaker
      return a.confidence >= b.confidence ? a : b;
    }
  }

  /**
   * Check if quality meets minimum threshold
   *
   * @param {QualityScore} score - Quality score
   * @param {DataQuality} minQuality - Minimum acceptable quality
   * @returns {boolean} True if quality meets threshold
   */
  static meetsThreshold(score: QualityScore, minQuality: DataQuality): boolean {
    const qualityOrder = [
      DataQuality.UNKNOWN,
      DataQuality.LOW,
      DataQuality.MEDIUM,
      DataQuality.HIGH,
    ];

    const scoreIndex = qualityOrder.indexOf(score.quality);
    const thresholdIndex = qualityOrder.indexOf(minQuality);

    return scoreIndex >= thresholdIndex;
  }
}
