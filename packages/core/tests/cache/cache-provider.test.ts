/**
 * Cache Provider Utilities Tests
 *
 * Tests for cache key generation and parsing
 */

import { generateCacheKey, parseCacheKey, CacheKey } from '../../src/cache/cache-provider';
import { HealthSource, DataType } from '../../src/models/unified-data';

describe('Cache Provider Utilities', () => {
  describe('generateCacheKey', () => {
    it('should generate cache key without params', () => {
      const key: CacheKey = {
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
        startDate: '2024-01-01',
        endDate: '2024-01-02',
      };

      const result = generateCacheKey(key);

      expect(result).toBe('fitbit:steps:2024-01-01:2024-01-02');
    });

    it('should generate cache key with params', () => {
      const key: CacheKey = {
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
        startDate: '2024-01-01',
        endDate: '2024-01-02',
        params: {
          limit: 10,
          offset: 0,
        },
      };

      const result = generateCacheKey(key);

      expect(result).toContain('fitbit:steps:2024-01-01:2024-01-02?');
      expect(result).toContain('limit=10');
      expect(result).toContain('offset=0');
    });

    it('should generate consistent keys for same params in different order', () => {
      const key1: CacheKey = {
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
        startDate: '2024-01-01',
        endDate: '2024-01-02',
        params: {
          limit: 10,
          offset: 0,
        },
      };

      const key2: CacheKey = {
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
        startDate: '2024-01-01',
        endDate: '2024-01-02',
        params: {
          offset: 0,
          limit: 10,
        },
      };

      const result1 = generateCacheKey(key1);
      const result2 = generateCacheKey(key2);

      expect(result1).toBe(result2);
    });

    it('should handle empty params object', () => {
      const key: CacheKey = {
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
        startDate: '2024-01-01',
        endDate: '2024-01-02',
        params: {},
      };

      const result = generateCacheKey(key);

      expect(result).toBe('fitbit:steps:2024-01-01:2024-01-02');
    });

    it('should handle complex param values', () => {
      const key: CacheKey = {
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
        startDate: '2024-01-01',
        endDate: '2024-01-02',
        params: {
          filter: { userId: 123, active: true },
          tags: ['tag1', 'tag2'],
        },
      };

      const result = generateCacheKey(key);

      expect(result).toContain('fitbit:steps:2024-01-01:2024-01-02?');
      expect(result).toContain('filter=');
      expect(result).toContain('tags=');
    });
  });

  describe('parseCacheKey', () => {
    it('should parse cache key without params', () => {
      const keyString = 'fitbit:steps:2024-01-01:2024-01-02';
      const result = parseCacheKey(keyString);

      expect(result).toEqual({
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
        startDate: '2024-01-01',
        endDate: '2024-01-02',
      });
    });

    it('should parse cache key with params', () => {
      const keyString = 'fitbit:steps:2024-01-01:2024-01-02?limit=10&offset=0';
      const result = parseCacheKey(keyString);

      expect(result).toEqual({
        source: HealthSource.FITBIT,
        dataType: DataType.STEPS,
        startDate: '2024-01-01',
        endDate: '2024-01-02',
        params: {
          limit: 10,
          offset: 0,
        },
      });
    });

    it('should return null for invalid key format', () => {
      const invalidKeys = [
        'invalid',
        'fitbit:steps',
        'fitbit',
        '',
        'fitbit:steps:2024-01-01', // Missing endDate
      ];

      invalidKeys.forEach(key => {
        expect(parseCacheKey(key)).toBeNull();
      });
    });

    it('should handle malformed params gracefully', () => {
      const keyString = 'fitbit:steps:2024-01-01:2024-01-02?invalid-param';
      const result = parseCacheKey(keyString);

      // Should still parse the base key
      expect(result).not.toBeNull();
      expect(result?.source).toBe(HealthSource.FITBIT);
    });

    it('should roundtrip generate and parse', () => {
      const originalKey: CacheKey = {
        source: HealthSource.GARMIN,
        dataType: DataType.HEART_RATE,
        startDate: '2024-01-01',
        endDate: '2024-01-02',
        params: {
          limit: 100,
          sortOrder: 'desc',
        },
      };

      const keyString = generateCacheKey(originalKey);
      const parsedKey = parseCacheKey(keyString);

      expect(parsedKey).toEqual(originalKey);
    });
  });
});
