import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'models/cache_entry.dart';

/// SQLite database for health data caching
class CacheDatabase {
  static const String _databaseName = 'health_sync_cache.db';
  static const int _databaseVersion = 1;

  // Table names
  static const String _tableHealthData = 'health_data_cache';
  static const String _tableMetadata = 'cache_metadata';

  Database? _database;

  /// Get database instance (singleton pattern)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize database
  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create database tables
  Future<void> _onCreate(Database db, int version) async {
    // Health data cache table
    await db.execute('''
      CREATE TABLE $_tableHealthData (
        id TEXT PRIMARY KEY,
        data_type TEXT NOT NULL,
        value REAL NOT NULL,
        unit TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        source TEXT NOT NULL,
        metadata TEXT,
        cached_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL
      )
    ''');

    // Create indexes for faster queries
    await db.execute('''
      CREATE INDEX idx_data_type ON $_tableHealthData(data_type)
    ''');

    await db.execute('''
      CREATE INDEX idx_timestamp ON $_tableHealthData(timestamp)
    ''');

    await db.execute('''
      CREATE INDEX idx_expires_at ON $_tableHealthData(expires_at)
    ''');

    await db.execute('''
      CREATE INDEX idx_source ON $_tableHealthData(source)
    ''');

    // Composite index for common query pattern
    await db.execute('''
      CREATE INDEX idx_type_timestamp ON $_tableHealthData(data_type, timestamp)
    ''');

    // Cache metadata table for statistics
    await db.execute('''
      CREATE TABLE $_tableMetadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Initialize metadata
    await db.insert(_tableMetadata, {
      'key': 'total_hits',
      'value': '0',
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    });

    await db.insert(_tableMetadata, {
      'key': 'total_misses',
      'value': '0',
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    });

    await db.insert(_tableMetadata, {
      'key': 'created_at',
      'value': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Upgrade database schema
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle schema migrations in future versions
    if (oldVersion < 2) {
      // Example: add new column in version 2
      // await db.execute('ALTER TABLE $_tableHealthData ADD COLUMN new_field TEXT');
    }
  }

  /// Insert cache entry
  Future<void> insert(CacheEntry entry) async {
    final db = await database;
    await db.insert(
      _tableHealthData,
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Insert multiple cache entries (batch operation)
  Future<void> insertBatch(List<CacheEntry> entries) async {
    if (entries.isEmpty) return;

    final db = await database;
    final batch = db.batch();

    for (final entry in entries) {
      batch.insert(
        _tableHealthData,
        entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
  }

  /// Query cache entries by data type and time range
  Future<List<CacheEntry>> query({
    required String dataType,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final db = await database;

    final results = await db.query(
      _tableHealthData,
      where: 'data_type = ? AND timestamp >= ? AND timestamp <= ? AND expires_at > ?',
      whereArgs: [
        dataType,
        startTime.millisecondsSinceEpoch,
        endTime.millisecondsSinceEpoch,
        DateTime.now().millisecondsSinceEpoch, // Only valid entries
      ],
      orderBy: 'timestamp ASC',
    );

    return results.map((map) => CacheEntry.fromMap(map)).toList();
  }

  /// Query all entries for a data type (no time filter)
  Future<List<CacheEntry>> queryByType(String dataType) async {
    final db = await database;

    final results = await db.query(
      _tableHealthData,
      where: 'data_type = ? AND expires_at > ?',
      whereArgs: [
        dataType,
        DateTime.now().millisecondsSinceEpoch,
      ],
      orderBy: 'timestamp DESC',
    );

    return results.map((map) => CacheEntry.fromMap(map)).toList();
  }

  /// Get cache entry by ID
  Future<CacheEntry?> getById(String id) async {
    final db = await database;

    final results = await db.query(
      _tableHealthData,
      where: 'id = ? AND expires_at > ?',
      whereArgs: [id, DateTime.now().millisecondsSinceEpoch],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return CacheEntry.fromMap(results.first);
  }

  /// Delete cache entries by data type
  Future<int> deleteByType(String dataType) async {
    final db = await database;
    return await db.delete(
      _tableHealthData,
      where: 'data_type = ?',
      whereArgs: [dataType],
    );
  }

  /// Delete cache entries in time range
  Future<int> deleteByTimeRange({
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final db = await database;
    return await db.delete(
      _tableHealthData,
      where: 'timestamp >= ? AND timestamp <= ?',
      whereArgs: [
        startTime.millisecondsSinceEpoch,
        endTime.millisecondsSinceEpoch,
      ],
    );
  }

  /// Delete expired cache entries
  Future<int> deleteExpired() async {
    final db = await database;
    return await db.delete(
      _tableHealthData,
      where: 'expires_at <= ?',
      whereArgs: [DateTime.now().millisecondsSinceEpoch],
    );
  }

  /// Delete all cache entries
  Future<int> deleteAll() async {
    final db = await database;
    return await db.delete(_tableHealthData);
  }

  /// Get count of cache entries
  Future<int> count({String? dataType}) async {
    final db = await database;

    if (dataType != null) {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $_tableHealthData WHERE data_type = ?',
        [dataType],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } else {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $_tableHealthData',
      );
      return Sqflite.firstIntValue(result) ?? 0;
    }
  }

  /// Get count of valid (non-expired) entries
  Future<int> countValid({String? dataType}) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (dataType != null) {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $_tableHealthData '
        'WHERE data_type = ? AND expires_at > ?',
        [dataType, now],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    } else {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $_tableHealthData WHERE expires_at > ?',
        [now],
      );
      return Sqflite.firstIntValue(result) ?? 0;
    }
  }

  /// Get count of expired entries
  Future<int> countExpired() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableHealthData WHERE expires_at <= ?',
      [DateTime.now().millisecondsSinceEpoch],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get cache size in bytes (approximate)
  Future<int> getCacheSizeBytes() async {
    final db = await database;
    final result = await db.rawQuery('SELECT page_count * page_size as size FROM pragma_page_count(), pragma_page_size()');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get entries by data type breakdown
  Future<Map<String, int>> getEntriesByType() async {
    final db = await database;
    final results = await db.rawQuery(
      'SELECT data_type, COUNT(*) as count FROM $_tableHealthData '
      'WHERE expires_at > ? GROUP BY data_type',
      [DateTime.now().millisecondsSinceEpoch],
    );

    final Map<String, int> breakdown = {};
    for (final row in results) {
      breakdown[row['data_type'] as String] = row['count'] as int;
    }
    return breakdown;
  }

  /// Get oldest entry timestamp
  Future<DateTime?> getOldestEntryTime() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT MIN(timestamp) as oldest FROM $_tableHealthData WHERE expires_at > ?',
      [DateTime.now().millisecondsSinceEpoch],
    );

    final timestamp = Sqflite.firstIntValue(result);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  /// Get newest entry timestamp
  Future<DateTime?> getNewestEntryTime() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT MAX(timestamp) as newest FROM $_tableHealthData WHERE expires_at > ?',
      [DateTime.now().millisecondsSinceEpoch],
    );

    final timestamp = Sqflite.firstIntValue(result);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  /// Update metadata value
  Future<void> updateMetadata(String key, String value) async {
    final db = await database;
    await db.insert(
      _tableMetadata,
      {
        'key': key,
        'value': value,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get metadata value
  Future<String?> getMetadata(String key) async {
    final db = await database;
    final results = await db.query(
      _tableMetadata,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return results.first['value'] as String?;
  }

  /// Increment hit counter
  Future<void> incrementHits() async {
    final current = await getMetadata('total_hits');
    final newValue = (int.tryParse(current ?? '0') ?? 0) + 1;
    await updateMetadata('total_hits', newValue.toString());
  }

  /// Increment miss counter
  Future<void> incrementMisses() async {
    final current = await getMetadata('total_misses');
    final newValue = (int.tryParse(current ?? '0') ?? 0) + 1;
    await updateMetadata('total_misses', newValue.toString());
  }

  /// Get total hits
  Future<int> getTotalHits() async {
    final value = await getMetadata('total_hits');
    return int.tryParse(value ?? '0') ?? 0;
  }

  /// Get total misses
  Future<int> getTotalMisses() async {
    final value = await getMetadata('total_misses');
    return int.tryParse(value ?? '0') ?? 0;
  }

  /// Close database connection
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  /// Vacuum database to reclaim space
  Future<void> vacuum() async {
    final db = await database;
    await db.execute('VACUUM');
  }
}
