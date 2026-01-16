/**
 * In-Memory Cache Provider
 *
 * Fast, session-only cache using LRU eviction strategy.
 * Implements the ICacheProvider interface with in-memory Map storage.
 *
 * @module cache/memory-cache
 */

import { HealthSource } from '../models/unified-data';
import { ICacheProvider, CacheEntry, CacheStats, parseCacheKey } from './cache-provider';

/**
 * LRU Cache Node
 *
 * @interface LRUNode
 * @private
 */
interface LRUNode {
  key: string;
  entry: CacheEntry;
  prev: LRUNode | null;
  next: LRUNode | null;
}

/**
 * In-Memory Cache Provider with LRU Eviction
 *
 * @class MemoryCacheProvider
 * @implements {ICacheProvider}
 */
export class MemoryCacheProvider implements ICacheProvider {
  private cache: Map<string, LRUNode> = new Map();
  private head: LRUNode | null = null;
  private tail: LRUNode | null = null;
  private maxSize: number;
  private hits = 0;
  private misses = 0;
  private evictions = 0;

  /**
   * Create memory cache provider
   *
   * @param {number} [maxSize=1000] - Maximum number of entries
   */
  constructor(maxSize: number = 1000) {
    this.maxSize = maxSize;
  }

  /**
   * Get cached data by key
   *
   * @param {string} key - Cache key
   * @returns {Promise<CacheEntry | null>} Cached entry or null if not found/expired
   */
  async get(key: string): Promise<CacheEntry | null> {
    const node = this.cache.get(key);

    if (!node) {
      this.misses++;
      return null;
    }

    // Check if expired
    if (Date.now() > node.entry.expiresAt) {
      await this.delete(key);
      this.misses++;
      return null;
    }

    // Move to front (most recently used)
    this.moveToFront(node);
    this.hits++;

    return node.entry;
  }

  /**
   * Set cache entry
   *
   * @param {string} key - Cache key
   * @param {CacheEntry} entry - Cache entry
   * @returns {Promise<void>}
   */
  async set(key: string, entry: CacheEntry): Promise<void> {
    // Update existing entry
    const existingNode = this.cache.get(key);
    if (existingNode) {
      existingNode.entry = entry;
      this.moveToFront(existingNode);
      return;
    }

    // Create new node
    const newNode: LRUNode = {
      key,
      entry,
      prev: null,
      next: null,
    };

    // Add to front
    this.addToFront(newNode);
    this.cache.set(key, newNode);

    // Evict LRU if over capacity
    if (this.cache.size > this.maxSize) {
      await this.evictLRU();
    }
  }

  /**
   * Delete cache entry
   *
   * @param {string} key - Cache key
   * @returns {Promise<boolean>} True if deleted, false if not found
   */
  async delete(key: string): Promise<boolean> {
    const node = this.cache.get(key);

    if (!node) {
      return false;
    }

    this.removeNode(node);
    this.cache.delete(key);

    return true;
  }

  /**
   * Clear all cache entries
   *
   * @returns {Promise<void>}
   */
  async clear(): Promise<void> {
    this.cache.clear();
    this.head = null;
    this.tail = null;
    this.hits = 0;
    this.misses = 0;
    this.evictions = 0;
  }

  /**
   * Check if key exists in cache
   *
   * @param {string} key - Cache key
   * @returns {Promise<boolean>} True if exists and not expired
   */
  async has(key: string): Promise<boolean> {
    const entry = await this.get(key);
    return entry !== null;
  }

  /**
   * Get all keys in cache
   *
   * @returns {Promise<string[]>} Array of cache keys
   */
  async keys(): Promise<string[]> {
    return Array.from(this.cache.keys());
  }

  /**
   * Get cache statistics
   *
   * @returns {Promise<CacheStats>} Cache statistics
   */
  async stats(): Promise<CacheStats> {
    const total = this.hits + this.misses;
    const hitRate = total > 0 ? this.hits / total : 0;

    // Estimate size (rough approximation)
    let sizeBytes = 0;
    for (const node of this.cache.values()) {
      sizeBytes += JSON.stringify(node.entry.data).length;
    }

    return {
      entries: this.cache.size,
      sizeBytes,
      hits: this.hits,
      misses: this.misses,
      hitRate,
      evictions: this.evictions,
    };
  }

  /**
   * Invalidate entries by tags
   *
   * @param {string[]} tags - Tags to invalidate
   * @returns {Promise<number>} Number of entries invalidated
   */
  async invalidateByTags(tags: string[]): Promise<number> {
    let count = 0;
    const keysToDelete: string[] = [];

    for (const [key, node] of this.cache.entries()) {
      const entryTags = node.entry.tags ?? [];
      if (tags.some(tag => entryTags.includes(tag))) {
        keysToDelete.push(key);
      }
    }

    for (const key of keysToDelete) {
      if (await this.delete(key)) {
        count++;
      }
    }

    return count;
  }

  /**
   * Invalidate entries by source
   *
   * @param {HealthSource} source - Source to invalidate
   * @returns {Promise<number>} Number of entries invalidated
   */
  async invalidateBySource(source: HealthSource): Promise<number> {
    let count = 0;
    const keysToDelete: string[] = [];

    for (const [key, _node] of this.cache.entries()) {
      // Parse key to get source
      const parsedKey = parseCacheKey(key);
      if (parsedKey && parsedKey.source === source) {
        keysToDelete.push(key);
      }
    }

    for (const key of keysToDelete) {
      if (await this.delete(key)) {
        count++;
      }
    }

    return count;
  }

  /**
   * Cleanup expired entries
   *
   * @returns {Promise<number>} Number of entries cleaned up
   */
  async cleanup(): Promise<number> {
    let count = 0;
    const now = Date.now();
    const keysToDelete: string[] = [];

    for (const [key, node] of this.cache.entries()) {
      if (now > node.entry.expiresAt) {
        keysToDelete.push(key);
      }
    }

    for (const key of keysToDelete) {
      if (await this.delete(key)) {
        count++;
      }
    }

    return count;
  }

  /**
   * Move node to front of LRU list (most recently used)
   *
   * @param {LRUNode} node - Node to move
   * @private
   */
  private moveToFront(node: LRUNode): void {
    if (node === this.head) {
      return;
    }

    this.removeNode(node);
    this.addToFront(node);
  }

  /**
   * Add node to front of LRU list
   *
   * @param {LRUNode} node - Node to add
   * @private
   */
  private addToFront(node: LRUNode): void {
    node.next = this.head;
    node.prev = null;

    if (this.head) {
      this.head.prev = node;
    }

    this.head = node;

    if (!this.tail) {
      this.tail = node;
    }
  }

  /**
   * Remove node from LRU list
   *
   * @param {LRUNode} node - Node to remove
   * @private
   */
  private removeNode(node: LRUNode): void {
    if (node.prev) {
      node.prev.next = node.next;
    } else {
      this.head = node.next;
    }

    if (node.next) {
      node.next.prev = node.prev;
    } else {
      this.tail = node.prev;
    }

    node.prev = null;
    node.next = null;
  }

  /**
   * Evict least recently used entry
   *
   * @returns {Promise<void>}
   * @private
   */
  private async evictLRU(): Promise<void> {
    if (!this.tail) {
      return;
    }

    const lruKey = this.tail.key;
    await this.delete(lruKey);
    this.evictions++;
  }
}
