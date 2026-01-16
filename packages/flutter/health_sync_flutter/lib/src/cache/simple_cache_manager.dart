import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/health_data.dart';
import '../models/data_type.dart';

/// Simplified cache manager for RawHealthData
class SimpleCacheManager {
  Database? _database;
  final Duration ttl;

  SimpleCacheManager({
    this.ttl = const Duration(minutes: 15),
  });

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'health_cache.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cache (
            key TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            cached_at INTEGER NOT NULL,
            expires_at INTEGER NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_expires ON cache(expires_at)');
      },
    );
  }

  String _makeKey(DataType type, DateTime start, DateTime end) {
    return '${type.name}_${start.millisecondsSinceEpoch}_${end.millisecondsSinceEpoch}';
  }

  Future<List<RawHealthData>?> get({
    required DataType type,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    try {
      final db = await database;
      final key = _makeKey(type, startTime, endTime);
      final now = DateTime.now().millisecondsSinceEpoch;

      final results = await db.query(
        'cache',
        where: 'key = ? AND expires_at > ?',
        whereArgs: [key, now],
      );

      if (results.isEmpty) {
        debugPrint('[Cache] MISS: $key');
        return null;
      }

      debugPrint('[Cache] HIT: $key');
      final jsonStr = results.first['data'] as String;
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      return jsonList.map((json) => RawHealthData.fromJson(json)).toList();
    } catch (e) {
      debugPrint('[Cache] Error reading: $e');
      return null;
    }
  }

  Future<void> put({
    required DataType type,
    required DateTime startTime,
    required DateTime endTime,
    required List<RawHealthData> data,
  }) async {
    try {
      final db = await database;
      final key = _makeKey(type, startTime, endTime);
      final now = DateTime.now();
      final expiresAt = now.add(ttl);

      final jsonList = data.map((item) => item.toJson()).toList();
      final jsonStr = jsonEncode(jsonList);

      await db.insert(
        'cache',
        {
          'key': key,
          'data': jsonStr,
          'cached_at': now.millisecondsSinceEpoch,
          'expires_at': expiresAt.millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      debugPrint('[Cache] Stored ${data.length} items for $key');
    } catch (e) {
      debugPrint('[Cache] Error writing: $e');
    }
  }

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('cache');
    debugPrint('[Cache] Cleared all');
  }

  Future<void> removeExpired() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final count = await db.delete(
      'cache',
      where: 'expires_at <= ?',
      whereArgs: [now],
    );
    debugPrint('[Cache] Removed $count expired entries');
  }

  Future<void> dispose() async {
    await _database?.close();
    _database = null;
  }
}
