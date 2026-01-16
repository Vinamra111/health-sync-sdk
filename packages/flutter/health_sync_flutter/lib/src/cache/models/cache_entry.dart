/// Cache entry model for storing health data locally
class CacheEntry {
  final String id;
  final String dataType;
  final double value;
  final String unit;
  final DateTime timestamp;
  final String source;
  final Map<String, dynamic>? metadata;
  final DateTime cachedAt;
  final DateTime expiresAt;

  CacheEntry({
    required this.id,
    required this.dataType,
    required this.value,
    required this.unit,
    required this.timestamp,
    required this.source,
    this.metadata,
    required this.cachedAt,
    required this.expiresAt,
  });

  /// Convert to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'data_type': dataType,
      'value': value,
      'unit': unit,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'source': source,
      'metadata': metadata != null ? _encodeMetadata(metadata!) : null,
      'cached_at': cachedAt.millisecondsSinceEpoch,
      'expires_at': expiresAt.millisecondsSinceEpoch,
    };
  }

  /// Create from database map
  factory CacheEntry.fromMap(Map<String, dynamic> map) {
    return CacheEntry(
      id: map['id'] as String,
      dataType: map['data_type'] as String,
      value: map['value'] as double,
      unit: map['unit'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      source: map['source'] as String,
      metadata: map['metadata'] != null
          ? _decodeMetadata(map['metadata'] as String)
          : null,
      cachedAt: DateTime.fromMillisecondsSinceEpoch(map['cached_at'] as int),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(map['expires_at'] as int),
    );
  }

  /// Check if cache entry is expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Get age of cache entry in seconds
  int get ageInSeconds => DateTime.now().difference(cachedAt).inSeconds;

  /// Encode metadata as JSON string
  static String _encodeMetadata(Map<String, dynamic> metadata) {
    // Simple JSON encoding - in production, use dart:convert
    return metadata.entries
        .map((e) => '"${e.key}":"${e.value}"')
        .join(',');
  }

  /// Decode metadata from JSON string
  static Map<String, dynamic> _decodeMetadata(String encoded) {
    // Simple JSON decoding - in production, use dart:convert
    final Map<String, dynamic> result = {};
    final pairs = encoded.split(',');
    for (final pair in pairs) {
      final parts = pair.replaceAll('"', '').split(':');
      if (parts.length == 2) {
        result[parts[0]] = parts[1];
      }
    }
    return result;
  }

  @override
  String toString() {
    return 'CacheEntry{id: $id, dataType: $dataType, value: $value, '
        'timestamp: $timestamp, age: ${ageInSeconds}s, expired: $isExpired}';
  }
}

/// Cache statistics model
class CacheStats {
  final int totalEntries;
  final int expiredEntries;
  final int validEntries;
  final Map<String, int> entriesByType;
  final double hitRate;
  final double missRate;
  final int totalHits;
  final int totalMisses;
  final int totalQueries;
  final int cacheSizeBytes;
  final DateTime oldestEntry;
  final DateTime newestEntry;

  CacheStats({
    required this.totalEntries,
    required this.expiredEntries,
    required this.validEntries,
    required this.entriesByType,
    required this.hitRate,
    required this.missRate,
    required this.totalHits,
    required this.totalMisses,
    required this.totalQueries,
    required this.cacheSizeBytes,
    required this.oldestEntry,
    required this.newestEntry,
  });

  @override
  String toString() {
    return 'CacheStats{\n'
        '  Total Entries: $totalEntries\n'
        '  Valid: $validEntries, Expired: $expiredEntries\n'
        '  Hit Rate: ${(hitRate * 100).toStringAsFixed(1)}%\n'
        '  Miss Rate: ${(missRate * 100).toStringAsFixed(1)}%\n'
        '  Total Queries: $totalQueries (Hits: $totalHits, Misses: $totalMisses)\n'
        '  Cache Size: ${(cacheSizeBytes / 1024).toStringAsFixed(2)} KB\n'
        '  Age Range: ${newestEntry.difference(oldestEntry).inHours}h\n'
        '}';
  }
}

/// Cache configuration
class CacheConfig {
  /// Time-to-live for cache entries (default: 5 minutes)
  final Duration ttl;

  /// Maximum cache size in bytes (default: 50 MB)
  final int maxSizeBytes;

  /// Maximum number of entries per data type (default: 10000)
  final int maxEntriesPerType;

  /// Whether to auto-cleanup expired entries (default: true)
  final bool autoCleanup;

  /// Auto-cleanup interval (default: 1 hour)
  final Duration cleanupInterval;

  /// Whether to prefetch data in background (default: false)
  final bool enablePrefetch;

  /// Prefetch interval (default: 30 minutes)
  final Duration prefetchInterval;

  const CacheConfig({
    this.ttl = const Duration(minutes: 5),
    this.maxSizeBytes = 50 * 1024 * 1024, // 50 MB
    this.maxEntriesPerType = 10000,
    this.autoCleanup = true,
    this.cleanupInterval = const Duration(hours: 1),
    this.enablePrefetch = false,
    this.prefetchInterval = const Duration(minutes: 30),
  });

  /// Development config - shorter TTL, more frequent cleanup
  factory CacheConfig.development() {
    return const CacheConfig(
      ttl: Duration(minutes: 1),
      maxSizeBytes: 10 * 1024 * 1024, // 10 MB
      maxEntriesPerType: 1000,
      autoCleanup: true,
      cleanupInterval: Duration(minutes: 5),
      enablePrefetch: false,
    );
  }

  /// Production config - longer TTL, optimized for performance
  factory CacheConfig.production() {
    return const CacheConfig(
      ttl: Duration(minutes: 15),
      maxSizeBytes: 100 * 1024 * 1024, // 100 MB
      maxEntriesPerType: 50000,
      autoCleanup: true,
      cleanupInterval: Duration(hours: 2),
      enablePrefetch: true,
      prefetchInterval: Duration(minutes: 30),
    );
  }

  /// Aggressive caching - long TTL, large cache
  factory CacheConfig.aggressive() {
    return const CacheConfig(
      ttl: Duration(hours: 1),
      maxSizeBytes: 200 * 1024 * 1024, // 200 MB
      maxEntriesPerType: 100000,
      autoCleanup: true,
      cleanupInterval: Duration(hours: 6),
      enablePrefetch: true,
      prefetchInterval: Duration(minutes: 15),
    );
  }

  /// Minimal caching - short TTL, small cache
  factory CacheConfig.minimal() {
    return const CacheConfig(
      ttl: Duration(seconds: 30),
      maxSizeBytes: 5 * 1024 * 1024, // 5 MB
      maxEntriesPerType: 500,
      autoCleanup: true,
      cleanupInterval: Duration(minutes: 10),
      enablePrefetch: false,
    );
  }
}
