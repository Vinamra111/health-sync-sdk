/**
 * Memory Cache Tests
 *
 * Tests for in-memory LRU cache implementation
 */

import { MemoryCacheProvider } from '../../src/cache/memory-cache';
import { CacheEntry } from '../../src/cache/cache-provider';
import { HealthSource, DataType } from '../../src/models/unified-data';

describe('MemoryCacheProvider', () => {
  let cache: MemoryCacheProvider;

  beforeEach(() => {
    cache = new MemoryCacheProvider(3); // Small size for testing LRU
  });

  afterEach(async () => {
    await cache.clear();
  });

  describe('Basic Operations', () => {
    it('should set and get cache entry', async () => {
      const entry: CacheEntry = {
        data: { test: 'data' },
        cachedAt: Date.now(),
        expiresAt: Date.now() + 60000,
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
      };

      await cache.set('test-key', entry);
      const result = await cache.get('test-key');

      expect(result).toEqual(entry);
    });

    it('should return null for non-existent key', async () => {
      const result = await cache.get('non-existent');
      expect(result).toBeNull();
    });

    it('should delete cache entry', async () => {
      const entry: CacheEntry = {
        data: { test: 'data' },
        cachedAt: Date.now(),
        expiresAt: Date.now() + 60000,
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
      };

      await cache.set('test-key', entry);
      const deleted = await cache.delete('test-key');
      const result = await cache.get('test-key');

      expect(deleted).toBe(true);
      expect(result).toBeNull();
    });

    it('should return false when deleting non-existent key', async () => {
      const deleted = await cache.delete('non-existent');
      expect(deleted).toBe(false);
    });

    it('should check if key exists', async () => {
      const entry: CacheEntry = {
        data: { test: 'data' },
        cachedAt: Date.now(),
        expiresAt: Date.now() + 60000,
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
      };

      await cache.set('test-key', entry);

      expect(await cache.has('test-key')).toBe(true);
      expect(await cache.has('non-existent')).toBe(false);
    });

    it('should return all keys', async () => {
      const entry: CacheEntry = {
        data: { test: 'data' },
        cachedAt: Date.now(),
        expiresAt: Date.now() + 60000,
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
      };

      await cache.set('key1', entry);
      await cache.set('key2', entry);
      await cache.set('key3', entry);

      const keys = await cache.keys();
      expect(keys).toHaveLength(3);
      expect(keys).toContain('key1');
      expect(keys).toContain('key2');
      expect(keys).toContain('key3');
    });

    it('should clear all entries', async () => {
      const entry: CacheEntry = {
        data: { test: 'data' },
        cachedAt: Date.now(),
        expiresAt: Date.now() + 60000,
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
      };

      await cache.set('key1', entry);
      await cache.set('key2', entry);
      await cache.clear();

      expect(await cache.keys()).toHaveLength(0);
    });
  });

  describe('Expiration', () => {
    it('should return null for expired entry', async () => {
      const entry: CacheEntry = {
        data: { test: 'data' },
        cachedAt: Date.now(),
        expiresAt: Date.now() - 1000, // Expired
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
      };

      await cache.set('test-key', entry);
      const result = await cache.get('test-key');

      expect(result).toBeNull();
    });

    it('should cleanup expired entries', async () => {
      const expiredEntry: CacheEntry = {
        data: { test: 'expired' },
        cachedAt: Date.now(),
        expiresAt: Date.now() - 1000,
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
      };

      const validEntry: CacheEntry = {
        data: { test: 'valid' },
        cachedAt: Date.now(),
        expiresAt: Date.now() + 60000,
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
      };

      await cache.set('expired', expiredEntry);
      await cache.set('valid', validEntry);

      const cleaned = await cache.cleanup();

      expect(cleaned).toBe(1);
      expect(await cache.has('expired')).toBe(false);
      expect(await cache.has('valid')).toBe(true);
    });
  });

  describe('LRU Eviction', () => {
    it('should evict least recently used entry when capacity exceeded', async () => {
      const entry: CacheEntry = {
        data: { test: 'data' },
        cachedAt: Date.now(),
        expiresAt: Date.now() + 60000,
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
      };

      // Fill cache to capacity (3)
      await cache.set('key1', entry);
      await cache.set('key2', entry);
      await cache.set('key3', entry);

      // Add one more - should evict key1
      await cache.set('key4', entry);

      expect(await cache.has('key1')).toBe(false);
      expect(await cache.has('key2')).toBe(true);
      expect(await cache.has('key3')).toBe(true);
      expect(await cache.has('key4')).toBe(true);
    });

    it('should update LRU order on access', async () => {
      const entry: CacheEntry = {
        data: { test: 'data' },
        cachedAt: Date.now(),
        expiresAt: Date.now() + 60000,
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
      };

      await cache.set('key1', entry);
      await cache.set('key2', entry);
      await cache.set('key3', entry);

      // Access key1 - moves it to front
      await cache.get('key1');

      // Add one more - should evict key2 (now LRU)
      await cache.set('key4', entry);

      expect(await cache.has('key1')).toBe(true);
      expect(await cache.has('key2')).toBe(false);
      expect(await cache.has('key3')).toBe(true);
      expect(await cache.has('key4')).toBe(true);
    });

    it('should update existing entry without eviction', async () => {
      const entry1: CacheEntry = {
        data: { version: 1 },
        cachedAt: Date.now(),
        expiresAt: Date.now() + 60000,
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
      };

      const entry2: CacheEntry = {
        data: { version: 2 },
        cachedAt: Date.now(),
        expiresAt: Date.now() + 60000,
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
      };

      await cache.set('key1', entry1);
      await cache.set('key1', entry2);

      const result = await cache.get('key1');
      expect(result?.data).toEqual({ version: 2 });
    });
  });

  describe('Invalidation', () => {
    it('should invalidate entries by tags', async () => {
      const entry1: CacheEntry = {
        data: { test: 'data1' },
        cachedAt: Date.now(),
        expiresAt: Date.now() + 60000,
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
        tags: ['user:123', 'type:steps'],
      };

      const entry2: CacheEntry = {
        data: { test: 'data2' },
        cachedAt: Date.now(),
        expiresAt: Date.now() + 60000,
        source: HealthSource.FITBIT,
        dataType: DataType.HEART_RATE,
        tags: ['user:123', 'type:heart'],
      };

      const entry3: CacheEntry = {
        data: { test: 'data3' },
        cachedAt: Date.now(),
        expiresAt: Date.now() + 60000,
        source: HealthSource.GARMIN,
        dataType: DataType.STEPS,
        tags: ['user:456', 'type:steps'],
      };

      await cache.set('key1', entry1);
      await cache.set('key2', entry2);
      await cache.set('key3', entry3);

      const invalidated = await cache.invalidateByTags(['user:123']);

      expect(invalidated).toBe(2);
      expect(await cache.has('key1')).toBe(false);
      expect(await cache.has('key2')).toBe(false);
      expect(await cache.has('key3')).toBe(true);
    });

    it('should invalidate entries by source', async () => {
      const fitbitEntry: CacheEntry = {
        data: { test: 'fitbit' },
        cachedAt: Date.now(),
        expiresAt: Date.now() + 60000,
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
      };

      const garminEntry: CacheEntry = {
        data: { test: 'garmin' },
        cachedAt: Date.now(),
        expiresAt: Date.now() + 60000,
        source: HealthSource.GARMIN,
        dataType: DataType.STEPS,
      };

      await cache.set(`${HealthSource.FITBIT}:${DataType.STEPS}:2024-01-01:2024-01-02`, fitbitEntry);
      await cache.set(`${HealthSource.GARMIN}:${DataType.STEPS}:2024-01-01:2024-01-02`, garminEntry);

      const invalidated = await cache.invalidateBySource(HealthSource.FITBIT);

      expect(invalidated).toBe(1);
      expect(await cache.has(`${HealthSource.FITBIT}:${DataType.STEPS}:2024-01-01:2024-01-02`)).toBe(false);
      expect(await cache.has(`${HealthSource.GARMIN}:${DataType.STEPS}:2024-01-01:2024-01-02`)).toBe(true);
    });
  });

  describe('Statistics', () => {
    it('should track cache statistics', async () => {
      const entry: CacheEntry = {
        data: { test: 'data' },
        cachedAt: Date.now(),
        expiresAt: Date.now() + 60000,
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
      };

      await cache.set('key1', entry);

      // Hit
      await cache.get('key1');

      // Miss
      await cache.get('non-existent');

      const stats = await cache.stats();

      expect(stats.entries).toBe(1);
      expect(stats.hits).toBe(1);
      expect(stats.misses).toBe(1);
      expect(stats.hitRate).toBe(0.5);
      expect(stats.evictions).toBe(0);
    });

    it('should track evictions', async () => {
      const entry: CacheEntry = {
        data: { test: 'data' },
        cachedAt: Date.now(),
        expiresAt: Date.now() + 60000,
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
      };

      await cache.set('key1', entry);
      await cache.set('key2', entry);
      await cache.set('key3', entry);
      await cache.set('key4', entry); // Triggers eviction

      const stats = await cache.stats();
      expect(stats.evictions).toBe(1);
    });
  });
});
