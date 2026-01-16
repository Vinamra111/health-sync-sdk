/**
 * Fitbit Data Transformer
 *
 * Transforms Fitbit API responses to RawHealthData format
 * for normalization by HealthSync SDK
 */

import { HealthSource } from '@healthsync/core';
import type { RawHealthData } from '@healthsync/core';
import type {
  FitbitActivitySession,
  FitbitHeartRateResponse,
  FitbitIntradayHeartRate,
  FitbitSleepResponse,
  FitbitSleepSession,
  FitbitWeightResponse,
} from './fitbit-types';

/**
 * Fitbit Data Transformer
 *
 * Converts Fitbit-specific data structures to unified RawHealthData format
 */
export class FitbitTransformer {
  /**
   * Transform activity summary to RawHealthData
   * Extracts: steps, distance, calories, active minutes, floors
   */
  transformActivitySummary(fitbitData: any, date: string): RawHealthData[] {
    const results: RawHealthData[] = [];
    const summary = fitbitData.summary;

    if (!summary) {
      return results;
    }

    const startTimestamp = `${date}T00:00:00.000Z`;
    const endTimestamp = `${date}T23:59:59.999Z`;

    // Steps
    if (summary.steps !== undefined) {
      results.push(this.createRawHealthData(
        'fitbit-steps',
        startTimestamp,
        { steps: summary.steps, ...summary },
        endTimestamp
      ));
    }

    // Distance
    if (summary.distances && summary.distances.length > 0) {
      const totalDistance = summary.distances.reduce((sum: number, d: any) => sum + d.distance, 0);
      results.push(this.createRawHealthData(
        'fitbit-distance',
        startTimestamp,
        { distance: totalDistance, distances: summary.distances },
        endTimestamp
      ));
    }

    // Calories
    if (summary.caloriesOut !== undefined) {
      results.push(this.createRawHealthData(
        'fitbit-calories',
        startTimestamp,
        {
          calories: summary.caloriesOut,
          caloriesIn: summary.caloriesIn,
          activeCalories: summary.activityCalories,
        },
        endTimestamp
      ));
    }

    // Active Minutes
    if (summary.fairlyActiveMinutes !== undefined || summary.veryActiveMinutes !== undefined) {
      const activeMinutes = (summary.fairlyActiveMinutes || 0) + (summary.veryActiveMinutes || 0);
      results.push(this.createRawHealthData(
        'fitbit-active-minutes',
        startTimestamp,
        {
          activeMinutes,
          sedentaryMinutes: summary.sedentaryMinutes,
          lightlyActiveMinutes: summary.lightlyActiveMinutes,
          fairlyActiveMinutes: summary.fairlyActiveMinutes,
          veryActiveMinutes: summary.veryActiveMinutes,
        },
        endTimestamp
      ));
    }

    // Floors
    if (summary.floors !== undefined) {
      results.push(this.createRawHealthData(
        'fitbit-floors',
        startTimestamp,
        { floors: summary.floors, elevation: summary.elevation },
        endTimestamp
      ));
    }

    return results;
  }

  /**
   * Transform activity time series to RawHealthData
   */
  transformActivityTimeSeries(fitbitData: any, resource: string): RawHealthData[] {
    const results: RawHealthData[] = [];

    // Fitbit time series format: { "activities-steps": [{dateTime, value}] }
    const seriesKey = Object.keys(fitbitData).find(key => key.startsWith('activities-'));

    if (!seriesKey || !fitbitData[seriesKey]) {
      return results;
    }

    const series = fitbitData[seriesKey];

    for (const dataPoint of series) {
      const date = dataPoint.dateTime;
      const value = parseFloat(dataPoint.value);

      const startTimestamp = `${date}T00:00:00.000Z`;
      const endTimestamp = `${date}T23:59:59.999Z`;

      results.push(this.createRawHealthData(
        `fitbit-${resource}`,
        startTimestamp,
        { [resource]: value, dateTime: date },
        endTimestamp
      ));
    }

    return results;
  }

  /**
   * Transform activity logs (exercise sessions) to RawHealthData
   */
  transformActivityLogs(activities: FitbitActivitySession[]): RawHealthData[] {
    const results: RawHealthData[] = [];

    for (const activity of activities) {
      // Parse start time
      const startTime = new Date(`${activity.startDate}T${activity.startTime}`);
      const startTimestamp = startTime.toISOString();

      // Calculate end time from duration
      const endTime = new Date(startTime.getTime() + activity.duration);
      const endTimestamp = endTime.toISOString();

      results.push(this.createRawHealthData(
        'fitbit-activity',
        startTimestamp,
        {
          activityId: activity.activityId,
          activityName: activity.name,
          calories: activity.calories,
          distance: activity.distance,
          duration: activity.duration,
          steps: activity.steps,
          heartRateZones: activity.heartRateZones,
          ...activity,
        },
        endTimestamp,
        activity.logId.toString()
      ));
    }

    return results;
  }

  /**
   * Transform heart rate time series to RawHealthData
   */
  transformHeartRateTimeSeries(fitbitData: FitbitHeartRateResponse): RawHealthData[] {
    const results: RawHealthData[] = [];

    if (!fitbitData['activities-heart']) {
      return results;
    }

    for (const dayData of fitbitData['activities-heart']) {
      const date = dayData.dateTime;
      const timestamp = `${date}T00:00:00.000Z`;

      // Resting heart rate
      if (dayData.value.restingHeartRate !== undefined) {
        results.push(this.createRawHealthData(
          'fitbit-resting-heart-rate',
          timestamp,
          {
            restingHeartRate: dayData.value.restingHeartRate,
            heartRateZones: dayData.value.heartRateZones,
            dateTime: date,
          }
        ));
      }

      // Heart rate zones
      if (dayData.value.heartRateZones && dayData.value.heartRateZones.length > 0) {
        results.push(this.createRawHealthData(
          'fitbit-heart-rate-zones',
          timestamp,
          {
            heartRateZones: dayData.value.heartRateZones,
            dateTime: date,
          }
        ));
      }
    }

    return results;
  }

  /**
   * Transform heart rate intraday to RawHealthData
   */
  transformHeartRateIntraday(fitbitData: FitbitIntradayHeartRate): RawHealthData[] {
    const results: RawHealthData[] = [];

    const intraday = fitbitData['activities-heart-intraday'];
    if (!intraday || !intraday.dataset) {
      return results;
    }

    // Group intraday data by minute/hour for better performance
    // Instead of one record per second, group by minute
    const groupedData: Record<string, { sum: number; count: number; times: string[] }> = {};

    for (const dataPoint of intraday.dataset) {
      // Extract date from time (format: "HH:mm:ss")
      // We need the base date from parent response, default to today
      const baseDate = new Date().toISOString().split('T')[0];
      const timestamp = `${baseDate}T${dataPoint.time}.000Z`;

      // Group by minute
      const minuteKey = timestamp.substring(0, 16); // "YYYY-MM-DDTHH:mm"

      if (!groupedData[minuteKey]) {
        groupedData[minuteKey] = { sum: 0, count: 0, times: [] };
      }

      groupedData[minuteKey].sum += dataPoint.value;
      groupedData[minuteKey].count++;
      groupedData[minuteKey].times.push(dataPoint.time);
    }

    // Create RawHealthData records for each minute
    for (const [minuteKey, data] of Object.entries(groupedData)) {
      const avgHeartRate = Math.round(data.sum / data.count);

      results.push(this.createRawHealthData(
        'fitbit-heart-rate',
        `${minuteKey}:00.000Z`,
        {
          heartRate: avgHeartRate,
          samples: data.count,
          interval: intraday.datasetInterval,
          datasetType: intraday.datasetType,
        },
        `${minuteKey}:59.999Z`
      ));
    }

    return results;
  }

  /**
   * Transform sleep logs to RawHealthData
   */
  transformSleepLogs(fitbitData: FitbitSleepResponse): RawHealthData[] {
    const results: RawHealthData[] = [];

    if (!fitbitData.sleep) {
      return results;
    }

    for (const sleepSession of fitbitData.sleep) {
      results.push(this.transformSleepSession(sleepSession));
    }

    return results;
  }

  /**
   * Transform individual sleep session
   */
  private transformSleepSession(session: FitbitSleepSession): RawHealthData {
    // Parse timestamps
    const startTimestamp = new Date(session.startTime).toISOString();
    const endTimestamp = new Date(session.endTime).toISOString();

    // Extract sleep stages
    const stages = session.levels?.summary || {};

    return this.createRawHealthData(
      'fitbit-sleep',
      startTimestamp,
      {
        duration: session.duration,
        efficiency: session.efficiency,
        minutesAsleep: session.minutesAsleep,
        minutesAwake: session.minutesAwake,
        minutesToFallAsleep: session.minutesToFallAsleep,
        timeInBed: session.timeInBed,
        type: session.type,
        isMainSleep: session.isMainSleep,
        stages: {
          deep: stages.deep?.minutes || 0,
          light: stages.light?.minutes || 0,
          rem: stages.rem?.minutes || 0,
          wake: stages.wake?.minutes || 0,
        },
        levels: session.levels,
        dateOfSleep: session.dateOfSleep,
      },
      endTimestamp,
      session.logId.toString()
    );
  }

  /**
   * Transform weight logs to RawHealthData
   */
  transformWeightLogs(fitbitData: FitbitWeightResponse): RawHealthData[] {
    const results: RawHealthData[] = [];

    if (!fitbitData.weight) {
      return results;
    }

    for (const weightEntry of fitbitData.weight) {
      // Parse timestamp
      const timestamp = new Date(`${weightEntry.date}T${weightEntry.time}`).toISOString();

      results.push(this.createRawHealthData(
        'fitbit-weight',
        timestamp,
        {
          weight: weightEntry.weight,
          bmi: weightEntry.bmi,
          fat: weightEntry.fat,
          source: weightEntry.source,
          date: weightEntry.date,
          time: weightEntry.time,
        },
        undefined,
        weightEntry.logId.toString()
      ));
    }

    return results;
  }

  /**
   * Transform SpO2 (blood oxygen) data to RawHealthData
   */
  transformSpO2(fitbitData: any): RawHealthData[] {
    const results: RawHealthData[] = [];

    // Fitbit SpO2 format varies, handle common structures
    if (fitbitData.value !== undefined) {
      // Single value format
      const timestamp = fitbitData.dateTime
        ? new Date(fitbitData.dateTime).toISOString()
        : new Date().toISOString();

      results.push(this.createRawHealthData(
        'fitbit-spo2',
        timestamp,
        {
          spo2: fitbitData.value,
          ...fitbitData,
        }
      ));
    } else if (Array.isArray(fitbitData)) {
      // Array format
      for (const entry of fitbitData) {
        const timestamp = entry.dateTime
          ? new Date(entry.dateTime).toISOString()
          : new Date().toISOString();

        results.push(this.createRawHealthData(
          'fitbit-spo2',
          timestamp,
          {
            spo2: entry.value,
            ...entry,
          }
        ));
      }
    }

    return results;
  }

  /**
   * Transform HRV (heart rate variability) data to RawHealthData
   */
  transformHRV(fitbitData: any): RawHealthData[] {
    const results: RawHealthData[] = [];

    // Fitbit HRV format
    if (fitbitData.hrv && Array.isArray(fitbitData.hrv)) {
      for (const entry of fitbitData.hrv) {
        const timestamp = entry.dateTime
          ? new Date(entry.dateTime).toISOString()
          : new Date().toISOString();

        results.push(this.createRawHealthData(
          'fitbit-hrv',
          timestamp,
          {
            dailyRmssd: entry.value?.dailyRmssd,
            deepRmssd: entry.value?.deepRmssd,
            ...entry,
          }
        ));
      }
    }

    return results;
  }

  /**
   * Transform VO2 Max (cardio fitness) data to RawHealthData
   */
  transformVO2Max(fitbitData: any): RawHealthData[] {
    const results: RawHealthData[] = [];

    // Fitbit VO2 Max format
    if (fitbitData.cardioScore && Array.isArray(fitbitData.cardioScore)) {
      for (const entry of fitbitData.cardioScore) {
        const timestamp = entry.dateTime
          ? new Date(entry.dateTime).toISOString()
          : new Date().toISOString();

        results.push(this.createRawHealthData(
          'fitbit-vo2max',
          timestamp,
          {
            vo2Max: entry.value?.vo2Max,
            ...entry,
          }
        ));
      }
    }

    return results;
  }

  /**
   * Transform temperature data to RawHealthData
   */
  transformTemperature(fitbitData: any): RawHealthData[] {
    const results: RawHealthData[] = [];

    // Fitbit temperature format
    if (fitbitData.tempSkin && Array.isArray(fitbitData.tempSkin)) {
      for (const entry of fitbitData.tempSkin) {
        const timestamp = entry.dateTime
          ? new Date(entry.dateTime).toISOString()
          : new Date().toISOString();

        results.push(this.createRawHealthData(
          'fitbit-temperature',
          timestamp,
          {
            temperature: entry.value?.nightlyRelative,
            ...entry,
          }
        ));
      }
    }

    return results;
  }

  /**
   * Transform breathing rate data to RawHealthData
   */
  transformBreathingRate(fitbitData: any): RawHealthData[] {
    const results: RawHealthData[] = [];

    // Fitbit breathing rate format
    if (fitbitData.br && Array.isArray(fitbitData.br)) {
      for (const entry of fitbitData.br) {
        const timestamp = entry.dateTime
          ? new Date(entry.dateTime).toISOString()
          : new Date().toISOString();

        results.push(this.createRawHealthData(
          'fitbit-breathing-rate',
          timestamp,
          {
            breathingRate: entry.value?.breathingRate,
            ...entry,
          }
        ));
      }
    }

    return results;
  }

  // ============================================================================
  // Helper Methods
  // ============================================================================

  /**
   * Create RawHealthData object with standard format
   */
  private createRawHealthData(
    sourceDataType: string,
    timestamp: string,
    raw: Record<string, unknown>,
    endTimestamp?: string,
    sourceId?: string
  ): RawHealthData {
    const data: RawHealthData = {
      sourceDataType,
      source: HealthSource.FITBIT,
      timestamp,
      raw,
    };

    if (endTimestamp !== undefined) {
      data.endTimestamp = endTimestamp;
    }

    if (sourceId !== undefined) {
      data.sourceId = sourceId;
    }

    return data;
  }

  /**
   * Format date to Fitbit API format (yyyy-MM-dd)
   */
  formatDate(date: Date): string {
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }

  /**
   * Parse Fitbit date string to Date object
   */
  parseDate(dateStr: string): Date {
    return new Date(dateStr);
  }
}
