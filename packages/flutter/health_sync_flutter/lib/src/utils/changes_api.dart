import 'dart:async';
import 'package:flutter/services.dart';
import '../models/data_type.dart';
import '../models/health_data.dart';
import 'sync_token_manager.dart';
import 'logger.dart';

/// Health Connect Changes API wrapper
///
/// Provides efficient incremental syncing using sync tokens.
/// Instead of reading entire history every time, only fetch changes since last sync.
///
/// Benefits:
/// - Faster sync times (only new data)
/// - Reduced API calls (less rate limiting)
/// - Lower battery usage
/// - Efficient for background sync
class ChangesApi {
  final MethodChannel _channel;
  final SyncTokenManager _tokenManager;

  ChangesApi({
    required MethodChannel channel,
    SyncTokenManager? tokenManager,
  })  : _channel = channel,
        _tokenManager = tokenManager ?? syncTokenManager;

  /// Get changes with automatic fallback to full sync if token fails
  ///
  /// This is the RECOMMENDED method to use. It automatically handles token
  /// validation and falls back to full sync if the token is corrupted or invalid.
  ///
  /// Example:
  /// ```dart
  /// final result = await changesApi.getChangesWithFallback(
  ///   DataType.steps,
  ///   fullSyncCallback: () async {
  ///     return await plugin.fetchData(DataQuery(
  ///       dataType: DataType.steps,
  ///       startDate: DateTime.now().subtract(Duration(days: 7)),
  ///       endDate: DateTime.now(),
  ///     ));
  ///   },
  /// );
  /// ```
  Future<ChangesResult> getChangesWithFallback(
    DataType dataType, {
    required Future<List<RawHealthData>> Function() fullSyncCallback,
    String? recordType,
  }) async {
    try {
      // Try incremental sync first
      final result = await getChanges(dataType, recordType: recordType);

      // Check if token was rejected (invalid/corrupted)
      if (result.error != null && _isTokenInvalidError(result.error!)) {
        logger.warning(
          'Sync token invalid for ${dataType.toValue()}, falling back to full sync',
          category: 'ChangesAPI',
          metadata: {
            'error': result.error,
            'action': 'Performing full sync and resetting token',
          },
        );

        // Reset token
        await resetSync(dataType);

        // Perform full sync
        final fullData = await fullSyncCallback();

        // Get new token for future incremental syncs
        await _getInitialToken(_getRecordType(dataType, recordType)).then((token) {
          if (token != null) {
            _tokenManager.saveTokenWithMetadata(
              dataType,
              token,
              lastSyncTime: DateTime.now(),
              recordCount: fullData.length,
            );
          }
        });

        return ChangesResult(
          changes: fullData,
          hasMore: false,
          nextToken: null,
          isInitialSync: false,
          usedFallback: true,
        );
      }

      return result;
    } catch (e, stackTrace) {
      logger.error(
        'Changes API failed, falling back to full sync',
        category: 'ChangesAPI',
        error: e,
        stackTrace: stackTrace,
      );

      // Reset token on failure
      await resetSync(dataType);

      // Fallback to full sync
      final fullData = await fullSyncCallback();

      // Fallback succeeded - no error in result
      return ChangesResult(
        changes: fullData,
        hasMore: false,
        nextToken: null,
        isInitialSync: false,
        usedFallback: true,
        // No error - fallback succeeded
      );
    }
  }

  /// Get changes for a data type since last sync
  ///
  /// On first call (no sync token), returns empty list and stores token for next call.
  /// On subsequent calls, returns only records added/modified since last sync.
  ///
  /// RECOMMENDED: Use `getChangesWithFallback()` instead for automatic error handling.
  ///
  /// Example:
  /// ```dart
  /// // First call: Returns empty, stores token
  /// final result1 = await changesApi.getChanges(DataType.steps);
  /// print('First sync: ${result1.changes.length} records'); // 0 records
  ///
  /// // Wait for new data...
  /// await Future.delayed(Duration(hours: 1));
  ///
  /// // Second call: Returns only new records since first call
  /// final result2 = await changesApi.getChanges(DataType.steps);
  /// print('New records: ${result2.changes.length}'); // Only new records
  /// ```
  Future<ChangesResult> getChanges(
    DataType dataType, {
    String? recordType,
    bool validateToken = true,
  }) async {
    await _tokenManager.initialize();

    final typeInfo = _getRecordType(dataType, recordType);

    logger.info(
      'Fetching changes for ${dataType.toValue()}',
      category: 'ChangesAPI',
    );

    // Get last sync token
    final lastToken = await _tokenManager.getToken(dataType);

    // Validate token if requested
    if (validateToken && lastToken != null) {
      final metadata = await _tokenManager.getTokenMetadata(dataType);
      if (metadata != null && _isTokenStale(metadata.lastSyncTime)) {
        logger.warning(
          'Sync token for ${dataType.toValue()} is stale (${metadata.lastSyncTime})',
          category: 'ChangesAPI',
          metadata: {
            'lastSync': metadata.lastSyncTime?.toIso8601String(),
            'age': DateTime.now().difference(metadata.lastSyncTime ?? DateTime.now()).inDays,
            'recommendation': 'Token is old but may still work. If sync fails, it will reset automatically.',
          },
        );
      }
    }

    if (lastToken == null) {
      // First sync - get initial token without data
      logger.info(
        'No sync token found for ${dataType.toValue()}, initializing...',
        category: 'ChangesAPI',
      );

      final newToken = await _getInitialToken(typeInfo);

      if (newToken != null) {
        await _tokenManager.saveTokenWithMetadata(
          dataType,
          newToken,
          lastSyncTime: DateTime.now(),
          recordCount: 0,
        );

        return ChangesResult(
          changes: [],
          hasMore: false,
          nextToken: newToken,
          isInitialSync: true,
        );
      } else {
        logger.warning(
          'Failed to get initial sync token for ${dataType.toValue()}',
          category: 'ChangesAPI',
        );

        return ChangesResult(
          changes: [],
          hasMore: false,
          nextToken: null,
          isInitialSync: true,
        );
      }
    }

    // Subsequent sync - get changes since last token
    try {
      final result = await _channel.invokeMethod(
        'getChanges',
        {
          'recordType': typeInfo,
          'token': lastToken,
        },
      );

      final resultMap = Map<String, dynamic>.from(result as Map);

      final changesList = resultMap['changes'] as List<dynamic>? ?? [];
      final changes = changesList.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return RawHealthData.fromJson(map);
      }).toList();

      final newToken = resultMap['nextToken'] as String?;
      final hasMore = resultMap['hasMore'] as bool? ?? false;

      // Save new token if provided
      if (newToken != null) {
        await _tokenManager.saveTokenWithMetadata(
          dataType,
          newToken,
          lastSyncTime: DateTime.now(),
          recordCount: changes.length,
        );
      }

      logger.info(
        'Fetched ${changes.length} changes for ${dataType.toValue()}',
        category: 'ChangesAPI',
        metadata: {
          'changeCount': changes.length,
          'hasMore': hasMore,
          'tokenUpdated': newToken != null,
        },
      );

      return ChangesResult(
        changes: changes,
        hasMore: hasMore,
        nextToken: newToken,
        isInitialSync: false,
      );
    } catch (e, stackTrace) {
      logger.error(
        'Failed to fetch changes for ${dataType.toValue()}',
        category: 'ChangesAPI',
        error: e,
        stackTrace: stackTrace,
      );

      // On error, don't update token - retry with same token next time
      return ChangesResult(
        changes: [],
        hasMore: false,
        nextToken: lastToken,
        isInitialSync: false,
        error: e.toString(),
      );
    }
  }

  /// Get changes for multiple data types
  ///
  /// Efficiently fetches changes for all requested types in sequence.
  Future<Map<DataType, ChangesResult>> getChangesForTypes(
    List<DataType> dataTypes,
  ) async {
    final results = <DataType, ChangesResult>{};

    for (final dataType in dataTypes) {
      try {
        final result = await getChanges(dataType);
        results[dataType] = result;
      } catch (e) {
        logger.error(
          'Failed to fetch changes for ${dataType.toValue()}',
          category: 'ChangesAPI',
          error: e,
        );

        // Continue with other types even if one fails
        results[dataType] = ChangesResult(
          changes: [],
          hasMore: false,
          nextToken: null,
          isInitialSync: false,
          error: e.toString(),
        );
      }
    }

    return results;
  }

  /// Get initial sync token without fetching data
  Future<String?> _getInitialToken(String recordType) async {
    try {
      final result = await _channel.invokeMethod(
        'getChangesToken',
        {'recordType': recordType},
      );

      return result as String?;
    } catch (e) {
      logger.error(
        'Failed to get initial token',
        category: 'ChangesAPI',
        error: e,
      );
      return null;
    }
  }

  /// Reset sync for a data type (forces full sync next time)
  Future<void> resetSync(DataType dataType) async {
    await _tokenManager.clearToken(dataType);

    logger.info(
      'Reset sync for ${dataType.toValue()}',
      category: 'ChangesAPI',
    );
  }

  /// Reset sync for all data types
  Future<void> resetAllSyncs() async {
    await _tokenManager.clearAllTokens();

    logger.info(
      'Reset all syncs',
      category: 'ChangesAPI',
    );
  }

  /// Check if a data type has been synced before
  Future<bool> hasBeenSynced(DataType dataType) async {
    return await _tokenManager.hasToken(dataType);
  }

  /// Get last sync time for a data type
  Future<DateTime?> getLastSyncTime(DataType dataType) async {
    final metadata = await _tokenManager.getTokenMetadata(dataType);
    return metadata?.lastSyncTime;
  }

  /// Get sync status for all data types
  /// Get sync status for a single data type
  Future<SyncStatus> getSyncStatus(DataType dataType) async {
    final hasToken = await _tokenManager.hasToken(dataType);
    final metadata = await _tokenManager.getTokenMetadata(dataType);
    final creationTime = await _tokenManager.getTokenCreationTime(dataType);

    Duration? tokenAge;
    if (creationTime != null) {
      tokenAge = DateTime.now().difference(creationTime);
    }

    return SyncStatus(
      dataType: dataType,
      hasBeenSynced: hasToken,
      hasToken: hasToken,
      lastSyncTime: metadata?.lastSyncTime,
      lastRecordCount: metadata?.recordCount,
      tokenAge: tokenAge,
    );
  }

  /// Get sync status for multiple data types
  Future<Map<DataType, SyncStatus>> getSyncStatusForTypes(
    List<DataType> dataTypes,
  ) async {
    final results = <DataType, SyncStatus>{};

    for (final dataType in dataTypes) {
      results[dataType] = await getSyncStatus(dataType);
    }

    return results;
  }

  /// Map DataType to Health Connect record type string
  String _getRecordType(DataType dataType, String? override) {
    if (override != null) return override;

    // Map to Health Connect record type
    // These should match the record types in health_connect_types.dart
    switch (dataType) {
      case DataType.steps:
        return 'Steps';
      case DataType.heartRate:
        return 'HeartRate';
      case DataType.restingHeartRate:
        return 'RestingHeartRate';
      case DataType.sleep:
        return 'SleepSession';
      case DataType.activity:
        return 'ExerciseSession';
      case DataType.calories:
        return 'TotalCaloriesBurned';
      case DataType.distance:
        return 'Distance';
      case DataType.bloodOxygen:
        return 'OxygenSaturation';
      case DataType.bloodPressure:
        return 'BloodPressure';
      case DataType.bodyTemperature:
        return 'BodyTemperature';
      case DataType.weight:
        return 'Weight';
      case DataType.height:
        return 'Height';
      case DataType.heartRateVariability:
        return 'HeartRateVariabilityRmssd';
      default:
        throw ArgumentError('Unsupported data type: ${dataType.toValue()}');
    }
  }

  /// Check if error indicates token is invalid/corrupted
  bool _isTokenInvalidError(String error) {
    final errorLower = error.toLowerCase();
    return errorLower.contains('invalid token') ||
        errorLower.contains('invalid_token') ||  // For PlatformException codes
        errorLower.contains('token is invalid') ||
        errorLower.contains('token expired') ||
        errorLower.contains('token not found') ||
        errorLower.contains('invalid sync token') ||
        errorLower.contains('token has been invalidated');
  }

  /// Check if token is stale (>30 days old)
  ///
  /// Stale tokens may still work but have higher chance of being invalid.
  bool _isTokenStale(DateTime? lastSyncTime) {
    if (lastSyncTime == null) return true;
    return DateTime.now().difference(lastSyncTime) > Duration(days: 30);
  }

  /// Validate sync token for a data type
  ///
  /// Checks if the token is valid, stale, or needs refresh.
  Future<TokenValidation> validateToken(DataType dataType) async {
    await _tokenManager.initialize();

    // Check if token exists
    final token = await _tokenManager.getToken(dataType);
    if (token == null) {
      return TokenValidation(
        isValid: false,
        isStale: false,
        reason: 'No token found for ${dataType.toValue()}',
      );
    }

    // Get token creation time
    final creationTime = await _tokenManager.getTokenCreationTime(dataType);
    if (creationTime == null) {
      // Token exists but no creation time - assume valid
      return TokenValidation(
        isValid: true,
        isStale: false,
      );
    }

    final tokenAge = DateTime.now().difference(creationTime);
    final isStale = tokenAge > Duration(days: 30);

    return TokenValidation(
      isValid: !isStale,
      isStale: isStale,
      tokenAge: tokenAge,
      reason: isStale ? 'Token is stale (${tokenAge.inDays} days old)' : null,
    );
  }
}

/// Result of a changes query
class ChangesResult {
  /// List of changed records
  final List<RawHealthData> changes;

  /// Whether there are more changes to fetch
  final bool hasMore;

  /// Token for next query (null if no more changes)
  final String? nextToken;

  /// Whether this is the first sync (initial token creation)
  final bool isInitialSync;

  /// Whether this sync used fallback to full sync
  ///
  /// If true, the token was invalid and full sync was performed.
  /// This is NOT an error - it's automatic recovery.
  final bool usedFallback;

  /// Error message if query failed
  final String? error;

  const ChangesResult({
    required this.changes,
    required this.hasMore,
    required this.nextToken,
    required this.isInitialSync,
    this.usedFallback = false,
    this.error,
  });

  /// Whether the query was successful
  bool get isSuccess => error == null;

  /// Whether this sync returned any data
  bool get hasChanges => changes.isNotEmpty;

  @override
  String toString() {
    return 'ChangesResult{'
        'changes: ${changes.length}, '
        'hasMore: $hasMore, '
        'isInitialSync: $isInitialSync, '
        'usedFallback: $usedFallback, '
        'error: $error'
        '}';
  }
}

/// Sync status for a data type
class SyncStatus {
  /// Data type
  final DataType dataType;

  /// Whether this type has been synced before
  final bool hasBeenSynced;

  /// Whether a sync token exists
  final bool? hasToken;

  /// When it was last synced
  final DateTime? lastSyncTime;

  /// Number of records in last sync
  final int? lastRecordCount;

  /// Age of the sync token
  final Duration? tokenAge;

  const SyncStatus({
    required this.dataType,
    required this.hasBeenSynced,
    this.hasToken,
    this.lastSyncTime,
    this.lastRecordCount,
    this.tokenAge,
  });

  /// Whether sync is stale (> 24 hours old)
  bool get isStale {
    if (lastSyncTime == null) return true;
    return DateTime.now().difference(lastSyncTime!) > Duration(hours: 24);
  }

  /// Duration since last sync
  Duration? get timeSinceSync {
    if (lastSyncTime == null) return null;
    return DateTime.now().difference(lastSyncTime!);
  }

  @override
  String toString() {
    return 'SyncStatus{'
        'type: ${dataType.toValue()}, '
        'synced: $hasBeenSynced, '
        'lastSync: $lastSyncTime, '
        'lastCount: $lastRecordCount'
        '}';
  }
}

/// Token validation result
class TokenValidation {
  /// Whether the token is valid
  final bool isValid;

  /// Whether the token is stale (>30 days old)
  final bool isStale;

  /// Age of the token
  final Duration? tokenAge;

  /// Reason for validation result
  final String? reason;

  const TokenValidation({
    required this.isValid,
    required this.isStale,
    this.tokenAge,
    this.reason,
  });

  /// Whether token should be refreshed
  bool get shouldRefresh => isStale || !isValid;

  @override
  String toString() {
    return 'TokenValidation{'
        'valid: $isValid, '
        'stale: $isStale, '
        'age: $tokenAge, '
        'reason: $reason'
        '}';
  }
}
