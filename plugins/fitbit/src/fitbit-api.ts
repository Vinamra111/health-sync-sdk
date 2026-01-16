/**
 * Fitbit API Client
 *
 * Handles all HTTP requests to Fitbit Web API
 * Features: rate limiting, automatic token refresh, retry logic
 */

import { RateLimitError, NetworkError, DataFetchError } from '@healthsync/core';
import type { FitbitAuth } from './fitbit-auth';
import type {
  FitbitActivityResponse,
  FitbitActivitySession,
  FitbitHeartRateResponse,
  FitbitIntradayHeartRate,
  FitbitSleepResponse,
  FitbitWeightResponse,
  FitbitUserProfile,
  FitbitApiError,
  FitbitRateLimitInfo,
} from './fitbit-types';

/**
 * API Client Configuration
 */
export interface FitbitAPIConfig {
  baseUrl?: string;
  timeout?: number;
  maxRetries?: number;
  retryDelay?: number;
}

/**
 * Rate Limiter - Tracks and enforces Fitbit's 150 requests/hour limit
 */
export class RateLimiter {
  private requestCount = 0;
  private resetTime: Date;
  private readonly limit = 150; // Fitbit limit: 150 requests/hour/user

  constructor() {
    // Reset time is at top of next hour
    this.resetTime = this.getNextHourReset();
  }

  /**
   * Check if we can make a request (under limit)
   */
  canMakeRequest(): boolean {
    this.checkReset();
    return this.requestCount < this.limit;
  }

  /**
   * Record a request
   */
  recordRequest(): void {
    this.checkReset();
    this.requestCount++;
  }

  /**
   * Get current rate limit info
   */
  getRateLimitInfo(): FitbitRateLimitInfo {
    this.checkReset();

    return {
      limit: this.limit,
      remaining: Math.max(0, this.limit - this.requestCount),
      resetAt: this.resetTime,
      isLimited: this.requestCount >= this.limit,
    };
  }

  /**
   * Update from response headers (if Fitbit provides them)
   */
  updateFromHeaders(headers: Headers): void {
    const remaining = headers.get('Fitbit-Rate-Limit-Remaining');
    const reset = headers.get('Fitbit-Rate-Limit-Reset');

    if (remaining !== null) {
      this.requestCount = this.limit - parseInt(remaining, 10);
    }

    if (reset !== null) {
      this.resetTime = new Date(parseInt(reset, 10) * 1000);
    }
  }

  /**
   * Check if limit should reset
   */
  private checkReset(): void {
    const now = new Date();
    if (now >= this.resetTime) {
      this.requestCount = 0;
      this.resetTime = this.getNextHourReset();
    }
  }

  /**
   * Get top of next hour
   */
  private getNextHourReset(): Date {
    const now = new Date();
    const next = new Date(now);
    next.setHours(now.getHours() + 1, 0, 0, 0);
    return next;
  }
}

/**
 * Request Queue - Queue requests when rate limited
 */
export class RequestQueue {
  private queue: Array<() => Promise<any>> = [];
  private processing = false;

  /**
   * Add request to queue
   */
  enqueue<T>(requestFn: () => Promise<T>): Promise<T> {
    return new Promise((resolve, reject) => {
      this.queue.push(async () => {
        try {
          const result = await requestFn();
          resolve(result);
        } catch (error) {
          reject(error);
        }
      });

      if (!this.processing) {
        this.processQueue();
      }
    });
  }

  /**
   * Process queued requests
   */
  private async processQueue(): Promise<void> {
    if (this.processing || this.queue.length === 0) {
      return;
    }

    this.processing = true;

    while (this.queue.length > 0) {
      const request = this.queue.shift();
      if (request) {
        await request();
        // Small delay between requests
        await new Promise(resolve => setTimeout(resolve, 100));
      }
    }

    this.processing = false;
  }
}

/**
 * Fitbit API Client
 */
export class FitbitAPI {
  private readonly auth: FitbitAuth;
  private readonly config: Required<FitbitAPIConfig>;
  private readonly rateLimiter: RateLimiter;
  private readonly requestQueue: RequestQueue;

  constructor(auth: FitbitAuth, config: FitbitAPIConfig = {}) {
    this.auth = auth;
    this.config = {
      baseUrl: config.baseUrl || 'https://api.fitbit.com',
      timeout: config.timeout || 30000,
      maxRetries: config.maxRetries || 3,
      retryDelay: config.retryDelay || 1000,
    };
    this.rateLimiter = new RateLimiter();
    this.requestQueue = new RequestQueue();
  }

  // ============================================================================
  // User Profile
  // ============================================================================

  /**
   * Get user profile
   */
  async getUserProfile(): Promise<FitbitUserProfile> {
    return this.request<FitbitUserProfile>('/1/user/-/profile.json');
  }

  // ============================================================================
  // Activity Endpoints
  // ============================================================================

  /**
   * Get daily activity summary
   */
  async getActivitySummary(date: string): Promise<any> {
    return this.request(`/1/user/-/activities/date/${date}.json`);
  }

  /**
   * Get activity time series
   * @param resource steps, distance, calories, floors, elevation, activeMinutes
   * @param startDate Format: yyyy-MM-dd
   * @param endDate Format: yyyy-MM-dd
   */
  async getActivityTimeSeries(
    resource: string,
    startDate: string,
    endDate: string
  ): Promise<FitbitActivityResponse> {
    return this.request<FitbitActivityResponse>(
      `/1/user/-/activities/${resource}/date/${startDate}/${endDate}.json`
    );
  }

  /**
   * Get activity logs (exercise sessions)
   */
  async getActivityLogs(
    afterDate: string,
    sort: 'asc' | 'desc' = 'asc',
    limit: number = 20,
    offset: number = 0
  ): Promise<{ activities: FitbitActivitySession[] }> {
    const params = new URLSearchParams({
      afterDate,
      sort,
      limit: limit.toString(),
      offset: offset.toString(),
    });

    return this.request(`/1/user/-/activities/list.json?${params.toString()}`);
  }

  // ============================================================================
  // Heart Rate Endpoints
  // ============================================================================

  /**
   * Get heart rate time series
   * @param date Format: yyyy-MM-dd
   * @param period 1d, 7d, 30d, 1w, 1m
   */
  async getHeartRateTimeSeries(
    date: string,
    period: '1d' | '7d' | '30d' | '1w' | '1m' = '1d'
  ): Promise<FitbitHeartRateResponse> {
    return this.request<FitbitHeartRateResponse>(
      `/1/user/-/activities/heart/date/${date}/${period}.json`
    );
  }

  /**
   * Get heart rate intraday data
   * @param date Format: yyyy-MM-dd
   * @param detailLevel 1sec or 1min
   */
  async getHeartRateIntraday(
    date: string,
    detailLevel: '1sec' | '1min' = '1min'
  ): Promise<FitbitIntradayHeartRate> {
    return this.request<FitbitIntradayHeartRate>(
      `/1/user/-/activities/heart/date/${date}/1d/${detailLevel}.json`
    );
  }

  /**
   * Get heart rate intraday by date range
   */
  async getHeartRateIntradayRange(
    startDate: string,
    endDate: string,
    detailLevel: '1sec' | '1min' = '1min'
  ): Promise<FitbitIntradayHeartRate> {
    return this.request<FitbitIntradayHeartRate>(
      `/1/user/-/activities/heart/date/${startDate}/${endDate}/${detailLevel}.json`
    );
  }

  // ============================================================================
  // Sleep Endpoints
  // ============================================================================

  /**
   * Get sleep logs
   * @param date Format: yyyy-MM-dd
   */
  async getSleepLogs(date: string): Promise<FitbitSleepResponse> {
    return this.request<FitbitSleepResponse>(`/1.2/user/-/sleep/date/${date}.json`);
  }

  /**
   * Get sleep logs by date range
   */
  async getSleepLogsRange(startDate: string, endDate: string): Promise<FitbitSleepResponse> {
    const params = new URLSearchParams({
      startDate,
      endDate,
    });

    return this.request<FitbitSleepResponse>(`/1.2/user/-/sleep/list.json?${params.toString()}`);
  }

  // ============================================================================
  // Body/Weight Endpoints
  // ============================================================================

  /**
   * Get weight logs
   * @param date Format: yyyy-MM-dd
   * @param period 1d, 7d, 30d, 1w, 1m
   */
  async getWeightLogs(
    date: string,
    period: '1d' | '7d' | '30d' | '1w' | '1m' = '1d'
  ): Promise<FitbitWeightResponse> {
    return this.request<FitbitWeightResponse>(
      `/1/user/-/body/log/weight/date/${date}/${period}.json`
    );
  }

  // ============================================================================
  // Advanced Health Metrics
  // ============================================================================

  /**
   * Get SpO2 (blood oxygen) data
   */
  async getSpO2(date: string): Promise<any> {
    return this.request(`/1/user/-/spo2/date/${date}/all.json`);
  }

  /**
   * Get HRV (heart rate variability) data
   */
  async getHRV(date: string): Promise<any> {
    return this.request(`/1/user/-/hrv/date/${date}/all.json`);
  }

  /**
   * Get breathing rate data
   */
  async getBreathingRate(date: string): Promise<any> {
    return this.request(`/1/user/-/br/date/${date}/all.json`);
  }

  /**
   * Get skin temperature data
   */
  async getTemperature(date: string): Promise<any> {
    return this.request(`/1/user/-/temp/skin/date/${date}/all.json`);
  }

  /**
   * Get VO2 Max (cardio fitness score)
   */
  async getVO2Max(date: string): Promise<any> {
    return this.request(`/1/user/-/cardioscore/date/${date}/all.json`);
  }

  // ============================================================================
  // Rate Limit Info
  // ============================================================================

  /**
   * Get current rate limit status
   */
  getRateLimitStatus(): FitbitRateLimitInfo {
    return this.rateLimiter.getRateLimitInfo();
  }

  // ============================================================================
  // Core Request Method
  // ============================================================================

  /**
   * Make HTTP request to Fitbit API
   * Handles: authentication, rate limiting, retries, error handling
   */
  private async request<T>(
    endpoint: string,
    options: RequestInit = {},
    retryCount = 0
  ): Promise<T> {
    // Check rate limit
    if (!this.rateLimiter.canMakeRequest()) {
      const limitInfo = this.rateLimiter.getRateLimitInfo();
      const waitMs = limitInfo.resetAt.getTime() - Date.now();

      throw new RateLimitError(
        `Rate limit exceeded. Resets at ${limitInfo.resetAt.toISOString()}`,
        waitMs,
        undefined,
        {
          limit: limitInfo.limit,
          remaining: limitInfo.remaining,
          resetAt: limitInfo.resetAt.toISOString(),
        }
      );
    }

    try {
      // Get valid access token (auto-refresh if needed)
      const accessToken = await this.auth.getValidAccessToken();

      // Build full URL
      const url = `${this.config.baseUrl}${endpoint}`;

      // Prepare headers
      const headers: Record<string, string> = {
        'Authorization': `Bearer ${accessToken}`,
        'Accept': 'application/json',
        ...((options.headers as Record<string, string>) || {}),
      };

      // Make request
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), this.config.timeout);

      const response = await fetch(url, {
        ...options,
        headers,
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      // Record request for rate limiting
      this.rateLimiter.recordRequest();

      // Update rate limit from headers
      this.rateLimiter.updateFromHeaders(response.headers);

      // Handle errors
      if (!response.ok) {
        await this.handleErrorResponse(response, endpoint, options, retryCount);
      }

      // Parse and return response
      const data = await response.json();
      return data as T;

    } catch (error: any) {
      // Handle timeout
      if (error.name === 'AbortError') {
        throw new NetworkError(
          `Request timeout after ${this.config.timeout}ms`,
          undefined,
          { timeout: this.config.timeout, endpoint }
        );
      }

      // Handle network errors
      if (error.message?.includes('fetch')) {
        throw new NetworkError(
          `Network error: ${error.message}`,
          error,
          { endpoint }
        );
      }

      // Rethrow if already our error type
      if (
        error instanceof RateLimitError ||
        error instanceof NetworkError ||
        error instanceof DataFetchError
      ) {
        throw error;
      }

      // Wrap unknown errors
      throw new DataFetchError(
        `Request failed: ${error.message}`,
        'fitbit',
        undefined,
        error,
        { endpoint }
      );
    }
  }

  /**
   * Handle error responses
   */
  private async handleErrorResponse(
    response: Response,
    endpoint: string,
    options: RequestInit,
    retryCount: number
  ): Promise<never> {
    const status = response.status;
    let errorData: FitbitApiError | null = null;

    try {
      errorData = await response.json();
    } catch {
      // Could not parse error response
    }

    const errorMessage = errorData?.errors?.[0]?.message || response.statusText;
    const errorType = errorData?.errors?.[0]?.errorType;

    // Handle specific status codes
    switch (status) {
      case 401:
        // Unauthorized - token expired or invalid
        // Auth module should have already refreshed, so this is a real auth failure
        throw new DataFetchError(
          `Authentication failed: ${errorMessage}`,
          'fitbit',
          undefined,
          undefined,
          {
            code: 'AUTHENTICATION_FAILED',
            statusCode: status,
            errorType,
            endpoint,
          }
        );

      case 403:
        // Forbidden - insufficient scope/permissions
        throw new DataFetchError(
          `Insufficient permissions: ${errorMessage}`,
          'fitbit',
          undefined,
          undefined,
          {
            code: 'INSUFFICIENT_SCOPE',
            statusCode: status,
            errorType,
            endpoint,
          }
        );

      case 429:
        // Rate limit exceeded
        const limitInfo = this.rateLimiter.getRateLimitInfo();
        const waitMs = limitInfo.resetAt.getTime() - Date.now();

        throw new RateLimitError(
          `Rate limit exceeded: ${errorMessage}`,
          waitMs,
          undefined,
          {
            limit: limitInfo.limit,
            remaining: limitInfo.remaining,
            resetAt: limitInfo.resetAt.toISOString(),
            endpoint,
          }
        );

      case 500:
      case 502:
      case 503:
      case 504:
        // Server errors - retry
        if (retryCount < this.config.maxRetries) {
          const delay = this.config.retryDelay * Math.pow(2, retryCount);
          await new Promise(resolve => setTimeout(resolve, delay));
          return this.request(endpoint, options, retryCount + 1);
        }

        throw new DataFetchError(
          `Server error: ${errorMessage}`,
          'fitbit',
          undefined,
          undefined,
          {
            code: 'SERVER_ERROR',
            statusCode: status,
            errorType,
            endpoint,
            retriesExhausted: true,
          }
        );

      default:
        throw new DataFetchError(
          `Request failed: ${errorMessage}`,
          'fitbit',
          undefined,
          undefined,
          {
            code: 'REQUEST_FAILED',
            statusCode: status,
            errorType,
            endpoint,
          }
        );
    }
  }
}
