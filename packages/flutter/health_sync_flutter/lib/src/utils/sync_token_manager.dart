import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/data_type.dart';
import 'logger.dart';

/// Manages sync tokens for incremental data fetching
///
/// Sync tokens are used by Health Connect's Changes API to efficiently
/// fetch only new data since the last sync, avoiding full history reads.
class SyncTokenManager {
  static const String _keyPrefix = 'health_sync_token_';

  /// Shared preferences instance
  SharedPreferences? _prefs;

  /// In-memory cache of sync tokens
  final Map<String, String> _tokenCache = {};

  /// Whether the manager has been initialized
  bool _initialized = false;

  /// Initialize the sync token manager
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;

      logger.info('SyncTokenManager initialized', category: 'SyncTokens');
    } catch (e, stackTrace) {
      logger.error(
        'Failed to initialize SyncTokenManager',
        category: 'SyncTokens',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get sync token for a data type
  ///
  /// Returns null if no token exists (first sync).
  Future<String?> getToken(DataType dataType) async {
    await _ensureInitialized();

    final key = _makeKey(dataType);

    // Check in-memory cache first
    if (_tokenCache.containsKey(key)) {
      return _tokenCache[key];
    }

    // Load from persistent storage
    final token = _prefs?.getString(key);

    if (token != null) {
      _tokenCache[key] = token;
      logger.debug(
        'Loaded sync token for ${dataType.toValue()}',
        category: 'SyncTokens',
      );
    }

    return token;
  }

  /// Save sync token for a data type
  Future<void> saveToken(DataType dataType, String token) async {
    await _ensureInitialized();

    final key = _makeKey(dataType);

    // Update in-memory cache
    _tokenCache[key] = token;

    // Persist to storage
    await _prefs?.setString(key, token);

    // Save creation time
    final creationTimeKey = '${key}_creation_time';
    await _prefs?.setString(
      creationTimeKey,
      DateTime.now().toIso8601String(),
    );

    logger.debug(
      'Saved sync token for ${dataType.toValue()}',
      category: 'SyncTokens',
      metadata: {'tokenLength': token.length},
    );
  }

  /// Clear sync token for a data type (forces full sync next time)
  Future<void> clearToken(DataType dataType) async {
    await _ensureInitialized();

    final key = _makeKey(dataType);

    // Remove from cache
    _tokenCache.remove(key);

    // Remove from persistent storage
    await _prefs?.remove(key);

    logger.info(
      'Cleared sync token for ${dataType.toValue()}',
      category: 'SyncTokens',
    );
  }

  /// Clear all sync tokens (forces full sync for all data types)
  Future<void> clearAllTokens() async {
    await _ensureInitialized();

    // Clear in-memory cache
    _tokenCache.clear();

    // Clear all tokens from persistent storage
    final keys = _prefs?.getKeys().where((k) => k.startsWith(_keyPrefix)) ?? [];
    for (final key in keys) {
      await _prefs?.remove(key);
    }

    logger.info(
      'Cleared all sync tokens (${keys.length} tokens)',
      category: 'SyncTokens',
    );
  }

  /// Check if a sync token exists for a data type
  Future<bool> hasToken(DataType dataType) async {
    final token = await getToken(dataType);
    return token != null;
  }

  /// Get all stored sync tokens
  Future<Map<DataType, String>> getAllTokens() async {
    await _ensureInitialized();

    final result = <DataType, String>{};

    final keys = _prefs?.getKeys().where((k) => k.startsWith(_keyPrefix)) ?? [];

    for (final key in keys) {
      final token = _prefs?.getString(key);
      if (token != null) {
        try {
          final dataTypeValue = key.substring(_keyPrefix.length);
          final dataType = DataTypeExtension.fromValue(dataTypeValue);
          result[dataType] = token;
        } catch (e) {
          logger.warning(
            'Invalid data type in sync token key: $key',
            category: 'SyncTokens',
          );
        }
      }
    }

    return result;
  }

  /// Get sync token metadata (for debugging)
  Future<SyncTokenMetadata?> getTokenMetadata(DataType dataType) async {
    final token = await getToken(dataType);
    if (token == null) return null;

    final metadataKey = '${_makeKey(dataType)}_metadata';
    final metadataJson = _prefs?.getString(metadataKey);

    if (metadataJson != null) {
      try {
        return SyncTokenMetadata.fromJson(
          jsonDecode(metadataJson) as Map<String, dynamic>,
        );
      } catch (e) {
        logger.warning(
          'Failed to parse token metadata for ${dataType.toValue()}',
          category: 'SyncTokens',
        );
      }
    }

    return null;
  }

  /// Get token creation time
  Future<DateTime?> getTokenCreationTime(DataType dataType) async {
    await _ensureInitialized();

    final creationTimeKey = '${_makeKey(dataType)}_creation_time';
    final timeString = _prefs?.getString(creationTimeKey);

    if (timeString != null) {
      try {
        return DateTime.parse(timeString);
      } catch (e) {
        logger.warning(
          'Failed to parse token creation time for ${dataType.toValue()}',
          category: 'SyncTokens',
        );
      }
    }

    return null;
  }

  /// Save sync token with metadata
  Future<void> saveTokenWithMetadata(
    DataType dataType,
    String token, {
    DateTime? lastSyncTime,
    int? recordCount,
  }) async {
    await saveToken(dataType, token);

    final metadata = SyncTokenMetadata(
      lastSyncTime: lastSyncTime ?? DateTime.now(),
      recordCount: recordCount,
    );

    final metadataKey = '${_makeKey(dataType)}_metadata';
    await _prefs?.setString(metadataKey, jsonEncode(metadata.toJson()));
  }

  /// Make storage key for a data type
  String _makeKey(DataType dataType) {
    return '$_keyPrefix${dataType.toValue()}';
  }

  /// Ensure manager is initialized
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  /// Dispose and clear in-memory cache
  void dispose() {
    _tokenCache.clear();
    _initialized = false;
  }
}

/// Metadata about a sync token
class SyncTokenMetadata {
  /// When the token was last used
  final DateTime lastSyncTime;

  /// Number of records fetched in last sync
  final int? recordCount;

  const SyncTokenMetadata({
    required this.lastSyncTime,
    this.recordCount,
  });

  Map<String, dynamic> toJson() {
    return {
      'lastSyncTime': lastSyncTime.toIso8601String(),
      if (recordCount != null) 'recordCount': recordCount,
    };
  }

  factory SyncTokenMetadata.fromJson(Map<String, dynamic> json) {
    return SyncTokenMetadata(
      lastSyncTime: DateTime.parse(json['lastSyncTime'] as String),
      recordCount: json['recordCount'] as int?,
    );
  }
}

/// Global sync token manager instance
final syncTokenManager = SyncTokenManager();
