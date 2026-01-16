/**
 * Cache Manager Tests
 *
 * Tests for cache manager with TTL and invalidation
 */

import { CacheManager } from '../../src/cache/cache-manager';
import { CacheKey } from '../../src/cache/cache-provider';
import { HealthSource, DataType, StepsData } from '../../src/models/unified-data';
import { LogLevel } from '../../src/types/config';

describe('CacheManager', () => {
  let cacheManager: CacheManager;

  beforeEach(() => {
    cacheManager = new CacheManager({
      enabled: true,
      defaultTTL: 1000, // 1 second for testing
      maxMemoryEntries: 10,
      autoCleanup: false, // Disable for deterministic tests
    });
  });

  afterEach(async () => {
    await cacheManager.dispose();
  });

  describe('Basic Operations', () => {
    it('should cache and retrieve data', async () => {
      const cacheKey: CacheKey = {
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
        startDate: '2024-01-01',
        endDate: '2024-01-02',
      };

      const data: StepsData[] = [
        {
          id: '1',
          source: HealthSource.FITBIT,
          dataType: DataType.STEPS,
          timestamp: '2024-01-01T12:00:00Z',
          metadata: {
            source: HealthSource.FITBIT,
            dataType: DataType.STEPS,
            quality: 'high' as const,
            recordedAt: '2024-01-01T12:00:00Z',
          },
          count: 5000,
        },
      ];

      await cacheManager.set(cacheKey, data);
      const result = await cacheManager.get(cacheKey);

      expect(result).toEqual(data);
    });

    it('should return null for cache miss', async () => {
      const cacheKey: CacheKey = {
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
        startDate: '2024-01-01',
        endDate: '2024-01-02',
      };

      const result = await cacheManager.get(cacheKey);
      expect(result).toBeNull();
    });

    it('should delete cached data', async () => {
      const cacheKey: CacheKey = {
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
        startDate: '2024-01-01',
        endDate: '2024-01-02',
      };

      const data: StepsData[] = [];
      await cacheManager.set(cacheKey, data);

      const deleted = await cacheManager.delete(cacheKey);
      expect(deleted).toBe(true);

      const result = await cacheManager.get(cacheKey);
      expect(result).toBeNull();
    });

    it('should clear all caches', async () => {
      const cacheKey1: CacheKey = {
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
        startDate: '2024-01-01',
        endDate: '2024-01-02',
      };

      const cacheKey2: CacheKey = {
        source: HealthSource.GARMIN,
        dataType: DataType.HEART_RATE,
        startDate: '2024-01-01',
        endDate: '2024-01-02',
      };

      await cacheManager.set(cacheKey1, []);
      await cacheManager.set(cacheKey2, []);

      await cacheManager.clear();

      expect(await cacheManager.get(cacheKey1)).toBeNull();
      expect(await cacheManager.get(cacheKey2)).toBeNull();
    });
  });

  describe('TTL (Time To Live)', () => {
    it.skip('should expire data after TTL', async () => {
      const shortTTLManager = new CacheManager({
        enabled: true,
        defaultTTL: 10, // 10ms - very short for testing
        autoCleanup: false,
      });

      const cacheKey: CacheKey = {
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
        startDate: '2024-01-01',
        endDate: '2024-01-02',
      };

      const data: StepsData[] = [{
        id: '1',
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
        timestamp: '2024-01-01T12:00:00Z',
        metadata: {
          source: HealthSource.FITBIT,
          dataType: DataType.STEPS,
          quality: 'high' as const,
          recordedAt: '2024-01-01T12:00:00Z',
        },
        count: 5000,
      }];

      await shortTTLManager.set(cacheKey, data);

      // Should be cached immediately
      expect(await shortTTLManager.get(cacheKey)).not.toBeNull();

      // Wait for expiration (longer than TTL)
      await new Promise(resolve => setTimeout(resolve, 50));

      // Should be expired (get() checks expiration)
      expect(await shortTTLManager.get(cacheKey)).toBeNull();

      await shortTTLManager.dispose();
    });

    it('should use custom TTL when provided', async () => {
      const cacheKey: CacheKey = {
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
        startDate: '2024-01-01',
        endDate: '2024-01-02',
      };

      const customTTL = 200; // 200ms
      await cacheManager.set(cacheKey, [], customTTL);

      // Should be cached
      expect(await cacheManager.get(cacheKey)).not.toBeNull();

      // Wait for default TTL (100ms) - should still be cached
      await new Promise(resolve => setTimeout(resolve, 150));
      expect(await cacheManager.get(cacheKey)).not.toBeNull();

      // Wait for custom TTL
      await new Promise(resolve => setTimeout(resolve, 100));
      expect(await cacheManager.get(cacheKey)).toBeNull();
    });

    it('should use TTL by data type', async () => {
      const managerWithTypeTTL = new CacheManager({
        enabled: true,
        defaultTTL: 1000,
        ttlByDataType: {
          [DataType.STEPS]: 100, // 100ms for steps
          [DataType.SLEEP]: 500, // 500ms for sleep
        },
        autoCleanup: false,
      });

      const stepsCacheKey: CacheKey = {
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
        startDate: '2024-01-01',
        endDate: '2024-01-02',
      };

      const sleepCacheKey: CacheKey = {
        source: HealthSource.FITBIT,
        dataType: DataType.SLEEP,
        startDate: '2024-01-01',
        endDate: '2024-01-02',
      };

      await managerWithTypeTTL.set(stepsCacheKey, []);
      await managerWithTypeTTL.set(sleepCacheKey, []);

      // Wait 150ms - steps should expire, sleep should not
      await new Promise(resolve => setTimeout(resolve, 150));

      expect(await managerWithTypeTTL.get(stepsCacheKey)).toBeNull();
      expect(await managerWithTypeTTL.get(sleepCacheKey)).not.toBeNull();

      await managerWithTypeTTL.dispose();
    });
  });

  describe('Invalidation', () => {
    it('should invalidate by source', async () => {
      const fitbitKey: CacheKey = {
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
        startDate: '2024-01-01',
        endDate: '2024-01-02',
      };

      const garminKey: CacheKey = {
        source: HealthSource.GARMIN,
        dataType: DataType.STEPS,
        startDate: '2024-01-01',
        endDate: '2024-01-02',
      };

      await cacheManager.set(fitbitKey, []);
      await cacheManager.set(garminKey, []);

      const count = await cacheManager.invalidateBySource(HealthSource.FITBIT);

      expect(count).toBe(1);
      expect(await cacheManager.get(fitbitKey)).toBeNull();
      expect(await cacheManager.get(garminKey)).not.toBeNull();
    });

    it('should invalidate by tags', async () => {
      const cacheKey1: CacheKey = {
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
        startDate: '2024-01-01',
        endDate: '2024-01-02',
      };

      const cacheKey2: CacheKey = {
        source: HealthSource.FITBIT,
        dataType: DataType.HEART_RATE,
        startDate: '2024-01-01',
        endDate: '2024-01-02',
      };

      await cacheManager.set(cacheKey1, [], undefined, ['user:123']);
      await cacheManager.set(cacheKey2, [], undefined, ['user:456']);

      const count = await cacheManager.invalidateByTags(['user:123']);

      expect(count).toBe(1);
      expect(await cacheManager.get(cacheKey1)).toBeNull();
      expect(await cacheManager.get(cacheKey2)).not.toBeNull();
    });
  });

  describe('Cleanup', () => {
    it.skip('should cleanup expired entries', async () => {
      const shortTTLManager = new CacheManager({
        enabled: true,
        defaultTTL: 10, // 10ms
        autoCleanup: false,
      });

      const cacheKey1: CacheKey = {
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
        startDate: '2024-01-01',
        endDate: '2024-01-02',
      };

      const cacheKey2: CacheKey = {
        source: HealthSource.GARMIN,
        dataType: DataType.STEPS,
        startDate: '2024-01-01',
        endDate: '2024-01-02',
      };

      const data: StepsData[] = [{
        id: '1',
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
        timestamp: '2024-01-01T12:00:00Z',
        metadata: {
          source: HealthSource.FITBIT,
          dataType: DataType.STEPS,
          quality: 'high' as const,
          recordedAt: '2024-01-01T12:00:00Z',
        },
        count: 5000,
      }];

      await shortTTLManager.set(cacheKey1, data);
      await shortTTLManager.set(cacheKey2, data, 1000); // Much longer TTL

      // Wait for first to expire
      await new Promise(resolve => setTimeout(resolve, 50));

      const cleaned = await shortTTLManager.cleanup();

      expect(cleaned).toBeGreaterThan(0);
      expect(await shortTTLManager.get(cacheKey1)).toBeNull();
      expect(await shortTTLManager.get(cacheKey2)).not.toBeNull();

      await shortTTLManager.dispose();
    });
  });

  describe('Statistics', () => {
    it('should return cache statistics', async () => {
      const cacheKey: CacheKey = {
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
        startDate: '2024-01-01',
        endDate: '2024-01-02',
      };

      await cacheManager.set(cacheKey, []);

      const stats = await cacheManager.stats();

      expect(stats.memory).toBeDefined();
      expect(stats.memory.entries).toBe(1);
    });
  });

  describe('Configuration', () => {
    it('should respect enabled flag', async () => {
      const disabledManager = new CacheManager({
        enabled: false,
      });

      const cacheKey: CacheKey = {
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
        startDate: '2024-01-01',
        endDate: '2024-01-02',
      };

      await disabledManager.set(cacheKey, []);
      const result = await disabledManager.get(cacheKey);

      expect(result).toBeNull();

      await disabledManager.dispose();
    });

    it('should use logger when provided', async () => {
      const logSpy = jest.fn();
      const logger = {
        debug: logSpy,
        info: logSpy,
        warn: logSpy,
        error: logSpy,
      };

      const loggedManager = new CacheManager({
        enabled: true,
        logger,
      });

      const cacheKey: CacheKey = {
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
        startDate: '2024-01-01',
        endDate: '2024-01-02',
      };

      await loggedManager.set(cacheKey, []);

      expect(logSpy).toHaveBeenCalled();

      await loggedManager.dispose();
    });
  });

  describe('Cache Key Handling', () => {
    it('should handle cache keys with parameters', async () => {
      const cacheKey1: CacheKey = {
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
        startDate: '2024-01-01',
        endDate: '2024-01-02',
        params: { limit: 10 },
      };

      const cacheKey2: CacheKey = {
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
        startDate: '2024-01-01',
        endDate: '2024-01-02',
        params: { limit: 20 },
      };

      await cacheManager.set(cacheKey1, [{ count: 10 } as StepsData]);
      await cacheManager.set(cacheKey2, [{ count: 20 } as StepsData]);

      const result1 = await cacheManager.get(cacheKey1);
      const result2 = await cacheManager.get(cacheKey2);

      expect(result1).toHaveLength(1);
      expect(result2).toHaveLength(1);
      expect((result1![0] as StepsData).count).toBe(10);
      expect((result2![0] as StepsData).count).toBe(20);
    });
  });
});
