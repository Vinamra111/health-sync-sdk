/**
 * Cache Manager
 *
 * High-level cache orchestration with TTL, invalidation strategies,
 * and multi-layer caching support.
 *
 * @module cache/cache-manager
 */

import { DataType, HealthSource, AnyHealthData } from '../models/unified-data';
import { Logger, LogLevel } from '../types/config';
import {
  ICacheProvider,
  CacheEntry,
  CacheKey,
  CacheStats,
  generateCacheKey,
} from './cache-provider';
import { MemoryCacheProvider } from './memory-cache';

/**
 * Cache manager configuration
 *
 * @interface CacheManagerConfig
 */
export interface CacheManagerConfig {
  /** Enable caching */
  enabled?: boolean;

  /** Default TTL in milliseconds */
  defaultTTL?: number;

  /** TTL per data type (overrides default) */
  ttlByDataType?: Partial<Record<DataType, number>>;

  /** Maximum entries for memory cache */
  maxMemoryEntries?: number;

  /** Enable automatic cleanup */
  autoCleanup?: boolean;

  /** Cleanup interval in milliseconds */
  cleanupInterval?: number;

  /** Logger instance */
  logger?: Logger;

  /** External cache provider (L2) */
  externalProvider?: ICacheProvider;
}

/**
 * Default cache configuration
 */
const DEFAULT_CONFIG: Required<Omit<CacheManagerConfig, 'externalProvider' | 'logger'>> = {
  enabled: true,
  defaultTTL: 30 * 60 * 1000, // 30 minutes
  ttlByDataType: {
    [DataType.STEPS]: 60 * 60 * 1000, // 1 hour
    [DataType.HEART_RATE]: 30 * 60 * 1000, // 30 minutes
    [DataType.SLEEP]: 24 * 60 * 60 * 1000, // 24 hours
    [DataType.WEIGHT]: 24 * 60 * 60 * 1000, // 24 hours
  },
  maxMemoryEntries: 1000,
  autoCleanup: true,
  cleanupInterval: 5 * 60 * 1000, // 5 minutes
};

/**
 * Cache Manager
 *
 * Manages multi-layer caching with automatic TTL and invalidation.
 *
 * @class CacheManager
 */
export class CacheManager {
  private config: Required<Omit<CacheManagerConfig, 'externalProvider' | 'logger'>>;
  private logger: Logger | undefined;
  private memoryCache: ICacheProvider;
  private externalCache: ICacheProvider | undefined;
  private cleanupTimer: NodeJS.Timeout | undefined;

  /**
   * Create cache manager
   *
   * @param {CacheManagerConfig} [config] - Cache configuration
   */
  constructor(config: CacheManagerConfig = {}) {
    this.config = {
      ...DEFAULT_CONFIG,
      ...config,
      ttlByDataType: {
        ...DEFAULT_CONFIG.ttlByDataType,
        ...config.ttlByDataType,
      },
    };

    this.logger = config.logger;
    this.memoryCache = new MemoryCacheProvider(this.config.maxMemoryEntries);
    this.externalCache = config.externalProvider;

    if (this.config.autoCleanup) {
      this.startAutoCleanup();
    }
  }

  /**
   * Get cached data
   *
   * Checks memory cache first (L1), then external cache (L2) if available.
   *
   * @param {CacheKey} key - Cache key
   * @returns {Promise<AnyHealthData[] | null>} Cached data or null
   */
  async get(key: CacheKey): Promise<AnyHealthData[] | null> {
    if (!this.config.enabled) {
      return null;
    }

    const cacheKey = generateCacheKey(key);

    // Try memory cache first (L1)
    let entry = await this.memoryCache.get(cacheKey);

    if (entry) {
      this.log(LogLevel.DEBUG, `Cache hit (L1): ${cacheKey}`);
      return entry.data as AnyHealthData[];
    }

    // Try external cache (L2)
    if (this.externalCache) {
      entry = await this.externalCache.get(cacheKey);

      if (entry) {
        this.log(LogLevel.DEBUG, `Cache hit (L2): ${cacheKey}`);

        // Promote to memory cache
        await this.memoryCache.set(cacheKey, entry);

        return entry.data as AnyHealthData[];
      }
    }

    this.log(LogLevel.DEBUG, `Cache miss: ${cacheKey}`);
    return null;
  }

  /**
   * Set cached data
   *
   * Stores in both memory cache (L1) and external cache (L2) if available.
   *
   * @param {CacheKey} key - Cache key
   * @param {AnyHealthData[]} data - Data to cache
   * @param {number} [ttl] - TTL in milliseconds (overrides default)
   * @param {string[]} [tags] - Tags for invalidation
   * @returns {Promise<void>}
   */
  async set(
    key: CacheKey,
    data: AnyHealthData[],
    ttl?: number,
    tags?: string[]
  ): Promise<void> {
    if (!this.config.enabled) {
      return;
    }

    const cacheKey = generateCacheKey(key);
    const effectiveTTL = this.getTTL(key.dataType, ttl);
    const now = Date.now();

    const entry: CacheEntry = {
      data,
      cachedAt: now,
      expiresAt: now + effectiveTTL,
      source: key.source,
      dataType: key.dataType,
    };

    if (tags !== undefined) {
      entry.tags = tags;
    }

    // Store in memory cache (L1)
    await this.memoryCache.set(cacheKey, entry);

    // Store in external cache (L2)
    if (this.externalCache) {
      await this.externalCache.set(cacheKey, entry);
    }

    this.log(LogLevel.DEBUG, `Cached data: ${cacheKey} (TTL: ${effectiveTTL}ms)`);
  }

  /**
   * Delete cached data
   *
   * @param {CacheKey} key - Cache key
   * @returns {Promise<boolean>} True if deleted from any cache
   */
  async delete(key: CacheKey): Promise<boolean> {
    const cacheKey = generateCacheKey(key);

    const deleted1 = await this.memoryCache.delete(cacheKey);
    const deleted2 = this.externalCache
      ? await this.externalCache.delete(cacheKey)
      : false;

    if (deleted1 || deleted2) {
      this.log(LogLevel.DEBUG, `Deleted from cache: ${cacheKey}`);
    }

    return deleted1 || deleted2;
  }

  /**
   * Clear all caches
   *
   * @returns {Promise<void>}
   */
  async clear(): Promise<void> {
    await this.memoryCache.clear();

    if (this.externalCache) {
      await this.externalCache.clear();
    }

    this.log(LogLevel.INFO, 'Cleared all caches');
  }

  /**
   * Invalidate cache entries by source
   *
   * @param {HealthSource} source - Source to invalidate
   * @returns {Promise<number>} Number of entries invalidated
   */
  async invalidateBySource(source: HealthSource): Promise<number> {
    let count = 0;

    count += await this.memoryCache.invalidateBySource(source);

    if (this.externalCache) {
      count += await this.externalCache.invalidateBySource(source);
    }

    this.log(LogLevel.INFO, `Invalidated ${count} entries for source: ${source}`);

    return count;
  }

  /**
   * Invalidate cache entries by data type
   *
   * @param {DataType} dataType - Data type to invalidate
   * @returns {Promise<number>} Number of entries invalidated
   */
  async invalidateByDataType(dataType: DataType): Promise<number> {
    const tags = [`dataType:${dataType}`];
    let count = 0;

    count += await this.memoryCache.invalidateByTags(tags);

    if (this.externalCache) {
      count += await this.externalCache.invalidateByTags(tags);
    }

    this.log(LogLevel.INFO, `Invalidated ${count} entries for data type: ${dataType}`);

    return count;
  }

  /**
   * Invalidate cache entries by tags
   *
   * @param {string[]} tags - Tags to invalidate
   * @returns {Promise<number>} Number of entries invalidated
   */
  async invalidateByTags(tags: string[]): Promise<number> {
    let count = 0;

    count += await this.memoryCache.invalidateByTags(tags);

    if (this.externalCache) {
      count += await this.externalCache.invalidateByTags(tags);
    }

    this.log(LogLevel.INFO, `Invalidated ${count} entries by tags: ${tags.join(', ')}`);

    return count;
  }

  /**
   * Cleanup expired entries
   *
   * @returns {Promise<number>} Number of entries cleaned up
   */
  async cleanup(): Promise<number> {
    let count = 0;

    count += await this.memoryCache.cleanup();

    if (this.externalCache) {
      count += await this.externalCache.cleanup();
    }

    if (count > 0) {
      this.log(LogLevel.DEBUG, `Cleaned up ${count} expired cache entries`);
    }

    return count;
  }

  /**
   * Get cache statistics
   *
   * @returns {Promise<{ memory: CacheStats; external?: CacheStats }>} Cache stats
   */
  async stats(): Promise<{ memory: CacheStats; external?: CacheStats }> {
    const memory = await this.memoryCache.stats();

    const result: { memory: CacheStats; external?: CacheStats } = { memory };

    if (this.externalCache) {
      result.external = await this.externalCache.stats();
    }

    return result;
  }

  /**
   * Dispose cache manager
   *
   * Stops cleanup timer and clears caches.
   *
   * @returns {Promise<void>}
   */
  async dispose(): Promise<void> {
    this.stopAutoCleanup();
    await this.clear();
    this.log(LogLevel.INFO, 'Cache manager disposed');
  }

  /**
   * Get TTL for data type
   *
   * @param {DataType} dataType - Data type
   * @param {number} [override] - Override TTL
   * @returns {number} TTL in milliseconds
   * @private
   */
  private getTTL(dataType: DataType, override?: number): number {
    if (override !== undefined) {
      return override;
    }

    return this.config.ttlByDataType[dataType] ?? this.config.defaultTTL;
  }

  /**
   * Start automatic cleanup
   *
   * @private
   */
  private startAutoCleanup(): void {
    this.cleanupTimer = setInterval(() => {
      this.cleanup().catch(err => {
        this.log(LogLevel.ERROR, `Auto cleanup error: ${err}`);
      });
    }, this.config.cleanupInterval);

    // Prevent timer from keeping process alive
    if (this.cleanupTimer.unref) {
      this.cleanupTimer.unref();
    }
  }

  /**
   * Stop automatic cleanup
   *
   * @private
   */
  private stopAutoCleanup(): void {
    if (this.cleanupTimer) {
      clearInterval(this.cleanupTimer);
      this.cleanupTimer = undefined;
    }
  }

  /**
   * Log message
   *
   * @param {LogLevel} level - Log level
   * @param {string} message - Log message
   * @private
   */
  private log(level: LogLevel, message: string): void {
    if (!this.logger) {
      return;
    }

    const msg = `[CacheManager] ${message}`;

    switch (level) {
      case LogLevel.DEBUG:
        this.logger.debug(msg);
        break;
      case LogLevel.INFO:
        this.logger.info(msg);
        break;
      case LogLevel.WARN:
        this.logger.warn(msg);
        break;
      case LogLevel.ERROR:
        this.logger.error(msg);
        break;
    }
  }
}
