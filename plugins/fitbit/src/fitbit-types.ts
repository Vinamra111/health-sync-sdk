/**
 * Fitbit Plugin Types
 * Complete type definitions for Fitbit Web API v1.2
 */

// ============================================================================
// AUTHENTICATION & CREDENTIALS
// ============================================================================

export interface FitbitCredentials {
  accessToken: string;
  refreshToken: string;
  expiresAt: Date;
  userId: string;
  tokenType: 'Bearer';
  scopes: FitbitScope[];
}

export interface FitbitApiConfig {
  clientId: string;
  clientSecret: string;
  redirectUri: string;
  scopes: FitbitScope[];
  /** API base URL (default: https://api.fitbit.com) */
  baseUrl?: string;
  /** Enable automatic token refresh (default: true) */
  autoRefreshToken?: boolean;
}

export enum FitbitScope {
  ACTIVITY = 'activity',
  HEART_RATE = 'heartrate',
  SLEEP = 'sleep',
  WEIGHT = 'weight',
  NUTRITION = 'nutrition',
  LOCATION = 'location',
  PROFILE = 'profile',
  SETTINGS = 'settings',
  SOCIAL = 'social',
}

// ============================================================================
// API RESPONSES
// ============================================================================

/**
 * Activity Data
 */
export interface FitbitActivityResponse {
  'activities-steps'?: Array<{
    dateTime: string;
    value: string;
  }>;
  'activities-distance'?: Array<{
    dateTime: string;
    value: string;
  }>;
  'activities-calories'?: Array<{
    dateTime: string;
    value: string;
  }>;
  'activities-floors'?: Array<{
    dateTime: string;
    value: string;
  }>;
  'activities-elevation'?: Array<{
    dateTime: string;
    value: string;
  }>;
}

export interface FitbitActivitySession {
  activityId: number;
  activityParentId: number;
  activityParentName: string;
  calories: number;
  description: string;
  distance: number;
  duration: number;
  hasStartTime: boolean;
  isFavorite: boolean;
  logId: number;
  name: string;
  startDate: string;
  startTime: string;
  steps?: number;
  tcxLink?: string;
  activeDuration?: number;
  elevationGain?: number;
  hasActiveZoneMinutes?: boolean;
  heartRateZones?: FitbitHeartRateZone[];
}

/**
 * Heart Rate Data
 */
export interface FitbitHeartRateResponse {
  'activities-heart': Array<{
    dateTime: string;
    value: {
      customHeartRateZones?: any[];
      heartRateZones: FitbitHeartRateZone[];
      restingHeartRate?: number;
    };
  }>;
}

export interface FitbitHeartRateZone {
  caloriesOut: number;
  max: number;
  min: number;
  minutes: number;
  name: 'Out of Range' | 'Fat Burn' | 'Cardio' | 'Peak';
}

export interface FitbitIntradayHeartRate {
  'activities-heart-intraday': {
    dataset: Array<{
      time: string;
      value: number;
    }>;
    datasetInterval: number;
    datasetType: 'minute';
  };
}

/**
 * Sleep Data
 */
export interface FitbitSleepResponse {
  sleep: FitbitSleepSession[];
  summary: {
    stages?: {
      deep: number;
      light: number;
      rem: number;
      wake: number;
    };
    totalMinutesAsleep: number;
    totalSleepRecords: number;
    totalTimeInBed: number;
  };
}

export interface FitbitSleepSession {
  dateOfSleep: string;
  duration: number;
  efficiency: number;
  endTime: string;
  infoCode: number;
  isMainSleep: boolean;
  levels: {
    data: FitbitSleepLevel[];
    shortData?: FitbitSleepLevel[];
    summary: {
      deep?: { count: number; minutes: number; thirtyDayAvgMinutes?: number };
      light?: { count: number; minutes: number; thirtyDayAvgMinutes?: number };
      rem?: { count: number; minutes: number; thirtyDayAvgMinutes?: number };
      wake?: { count: number; minutes: number; thirtyDayAvgMinutes?: number };
    };
  };
  logId: number;
  minutesAfterWakeup: number;
  minutesAsleep: number;
  minutesAwake: number;
  minutesToFallAsleep: number;
  startTime: string;
  timeInBed: number;
  type: 'stages' | 'classic';
}

export interface FitbitSleepLevel {
  dateTime: string;
  level: 'deep' | 'light' | 'rem' | 'wake' | 'asleep' | 'restless' | 'awake';
  seconds: number;
}

/**
 * Body Measurements
 */
export interface FitbitWeightResponse {
  weight: Array<{
    bmi: number;
    date: string;
    fat?: number;
    logId: number;
    source: string;
    time: string;
    weight: number;
  }>;
}

export interface FitbitBodyFatResponse {
  fat: Array<{
    date: string;
    fat: number;
    logId: number;
    source: string;
    time: string;
  }>;
}

/**
 * Nutrition Data
 */
export interface FitbitNutritionResponse {
  foods: Array<{
    isFavorite: boolean;
    logDate: string;
    logId: number;
    loggedFood: {
      accessLevel: string;
      amount: number;
      brand: string;
      calories: number;
      foodId: number;
      mealTypeId: number;
      name: string;
      unit: {
        id: number;
        name: string;
        plural: string;
      };
      units: any[];
    };
    nutritionalValues: {
      calories: number;
      carbs: number;
      fat: number;
      fiber: number;
      protein: number;
      sodium: number;
    };
  }>;
  summary: {
    calories: number;
    carbs: number;
    fat: number;
    fiber: number;
    protein: number;
    sodium: number;
    water: number;
  };
}

export interface FitbitWaterResponse {
  water: Array<{
    amount: number;
    logId: number;
  }>;
  summary: {
    water: number;
  };
}

/**
 * User Profile
 */
export interface FitbitUserProfile {
  user: {
    age: number;
    ambassador: boolean;
    autoStrideEnabled: boolean;
    avatar: string;
    avatar150: string;
    avatar640: string;
    averageDailySteps: number;
    challengesBeta: boolean;
    clockTimeDisplayFormat: '12hour' | '24hour';
    corporate: boolean;
    corporateAdmin: boolean;
    country: string;
    dateOfBirth: string;
    displayName: string;
    displayNameSetting: string;
    distanceUnit: 'en_US' | 'en_GB' | 'METRIC';
    encodedId: string;
    features: {
      exerciseGoal: boolean;
    };
    firstName: string;
    foodsLocale: string;
    fullName: string;
    gender: 'MALE' | 'FEMALE' | 'NA';
    glucoseUnit: 'en_US' | 'METRIC';
    height: number;
    heightUnit: 'en_US' | 'METRIC';
    isBugReportEnabled: boolean;
    isChild: boolean;
    isCoach: boolean;
    languageLocale: string;
    lastName: string;
    legalTermsAcceptRequired: boolean;
    locale: string;
    memberSince: string;
    mfaEnabled: boolean;
    offsetFromUTCMillis: number;
    sdkDeveloper: boolean;
    sleepTracking: string;
    startDayOfWeek: string;
    strideLengthRunning: number;
    strideLengthRunningType: string;
    strideLengthWalking: number;
    strideLengthWalkingType: string;
    swimUnit: 'en_US' | 'METRIC';
    temperatureUnit: 'en_US' | 'METRIC';
    timezone: string;
    topBadges: any[];
    visibleUser: boolean;
    waterUnit: 'en_US' | 'METRIC';
    waterUnitName: string;
    weight: number;
    weightUnit: 'en_US' | 'METRIC';
  };
}

// ============================================================================
// REQUEST PARAMETERS
// ============================================================================

export interface FitbitDataQuery {
  userId?: string; // Default: "-" (current user)
  date?: string; // Format: yyyy-MM-dd
  startDate?: string;
  endDate?: string;
  period?: '1d' | '7d' | '30d' | '1w' | '1m' | '3m' | '6m' | '1y';
}

export interface FitbitIntradayQuery extends FitbitDataQuery {
  detailLevel: '1sec' | '1min' | '5min' | '15min';
  startTime?: string; // HH:mm
  endTime?: string; // HH:mm
}

// ============================================================================
// ERROR TYPES
// ============================================================================

export interface FitbitApiError {
  errors: Array<{
    errorType: string;
    fieldName?: string;
    message: string;
  }>;
  success: boolean;
}

export enum FitbitErrorType {
  EXPIRED_TOKEN = 'expired_token',
  INVALID_GRANT = 'invalid_grant',
  INVALID_CLIENT = 'invalid_client',
  INVALID_TOKEN = 'invalid_token',
  INSUFFICIENT_PERMISSIONS = 'insufficient_permissions',
  INSUFFICIENT_SCOPE = 'insufficient_scope',
  RATE_LIMIT = 'request-limit',
  INVALID_REQUEST = 'validation',
  NOT_FOUND = 'not_found',
  SYSTEM = 'system',
}

// ============================================================================
// RATE LIMITING
// ============================================================================

export interface FitbitRateLimitInfo {
  limit: number; // Max requests per hour
  remaining: number; // Requests remaining
  resetAt: Date; // When limit resets
  isLimited: boolean; // Currently rate limited?
}

// ============================================================================
// TOKEN RESPONSE
// ============================================================================

export interface FitbitTokenResponse {
  access_token: string;
  expires_in: number;
  refresh_token: string;
  scope: string;
  token_type: 'Bearer';
  user_id: string;
}

// ============================================================================
// DATA TYPE MAPPINGS
// ============================================================================

/**
 * Maps HealthSync DataType to Fitbit API resource
 */
export const FITBIT_RESOURCE_MAP = {
  STEPS: 'activities/steps',
  DISTANCE: 'activities/distance',
  CALORIES: 'activities/calories',
  ACTIVE_CALORIES: 'activities/activityCalories',
  FLOORS: 'activities/floors',
  ELEVATION: 'activities/elevation',
  HEART_RATE: 'activities/heart',
  SLEEP: 'sleep',
  WEIGHT: 'body/weight',
  BODY_FAT: 'body/fat',
  BMI: 'body/bmi',
  NUTRITION: 'foods/log',
  WATER: 'foods/log/water',
} as const;

/**
 * Maps Fitbit scope to required data types
 */
export const FITBIT_SCOPE_DATA_TYPES = {
  [FitbitScope.ACTIVITY]: ['STEPS', 'DISTANCE', 'CALORIES', 'FLOORS', 'ELEVATION'],
  [FitbitScope.HEART_RATE]: ['HEART_RATE'],
  [FitbitScope.SLEEP]: ['SLEEP'],
  [FitbitScope.WEIGHT]: ['WEIGHT', 'BODY_FAT', 'BMI'],
  [FitbitScope.NUTRITION]: ['NUTRITION', 'WATER'],
} as const;

// ============================================================================
// UTILITY TYPES
// ============================================================================

export type FitbitResourceType = typeof FITBIT_RESOURCE_MAP[keyof typeof FITBIT_RESOURCE_MAP];

export interface FitbitRequestConfig {
  url: string;
  method: 'GET' | 'POST' | 'DELETE';
  headers?: Record<string, string>;
  params?: Record<string, string | number>;
  body?: any;
  requiresAuth: boolean;
}
