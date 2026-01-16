import 'dart:async';
import 'package:flutter/services.dart';
import '../../models/connection_status.dart';
import '../../models/data_type.dart';
import '../../models/health_data.dart';
import '../../types/data_query.dart';
import '../../types/errors.dart';
import '../../utils/logger.dart';
import '../../utils/permission_tracker.dart';
import '../../utils/batch_writer.dart';
import '../../utils/rate_limiter.dart';
import '../../utils/changes_api.dart';
import '../../utils/sync_token_manager.dart';
import '../../utils/aggregate_reader.dart';
import '../../models/aggregate_data.dart';
import '../../conflict_detection/conflict_detector.dart';
import '../../conflict_detection/data_source_info.dart';
import 'health_connect_types.dart';

/// Health Connect Plugin for Flutter
///
/// Provides access to Android Health Connect data through a unified API.
class HealthConnectPlugin {
  static const MethodChannel _channel =
      MethodChannel('health_sync_flutter/health_connect');

  /// Plugin ID
  static const String id = 'health-connect';

  /// Plugin name
  static const String name = 'Health Connect';

  /// Plugin version
  static const String version = '1.0.0';

  /// Supported data types
  static const List<DataType> supportedDataTypes = [
    DataType.steps,
    DataType.heartRate,
    DataType.restingHeartRate,
    DataType.sleep,
    DataType.activity,
    DataType.calories,
    DataType.distance,
    DataType.bloodOxygen,
    DataType.bloodPressure,
    DataType.bodyTemperature,
    DataType.weight,
    DataType.height,
    DataType.heartRateVariability,
  ];

  /// Whether plugin requires authentication
  static const bool requiresAuthentication = false;

  /// Whether plugin is cloud-based
  static const bool isCloudBased = false;

  /// Current connection status
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;

  /// Get current connection status
  ConnectionStatus get connectionStatus => _connectionStatus;

  /// Plugin configuration
  final HealthConnectConfig config;

  /// Rate limiter for API calls
  final RateLimiter rateLimiter;

  /// Batch writer for bulk operations
  final BatchWriter batchWriter;

  /// Changes API for incremental syncing
  late final ChangesApi changesApi;

  /// Sync token manager
  final SyncTokenManager syncTokenManager;

  /// Aggregate data reader
  late final AggregateReader aggregateReader;

  /// Create Health Connect plugin instance
  HealthConnectPlugin({
    HealthConnectConfig? config,
    RateLimiter? rateLimiter,
    SyncTokenManager? syncTokenManager,
  }) : config = config ?? const HealthConnectConfig(),
       rateLimiter = rateLimiter ?? RateLimiterConfig.conservative,
       batchWriter = BatchWriter(rateLimiter: rateLimiter),
       syncTokenManager = syncTokenManager ?? SyncTokenManager() {
    changesApi = ChangesApi(
      channel: _channel,
      tokenManager: this.syncTokenManager,
    );
    aggregateReader = AggregateReader(
      channel: _channel,
      rateLimiter: this.rateLimiter,
    );
  }

  /// Initialize the plugin
  Future<void> initialize() async {
    logger.info('Initializing Health Connect plugin', category: 'HealthConnect');

    try {
      final availability = await checkAvailability();

      logger.info(
        'Health Connect availability: ${availability.toValue()}',
        category: 'HealthConnect',
        metadata: {'availability': availability.toValue()},
      );

      if (availability != HealthConnectAvailability.installed) {
        logger.error(
          'Health Connect not installed',
          category: 'HealthConnect',
          metadata: {'availability': availability.toValue()},
        );
        throw HealthSyncConnectionError(
          'Health Connect is $availability. Please install Health Connect from Google Play Store.',
        );
      }

      // Initialize sync token manager
      await syncTokenManager.initialize();

      logger.info('Health Connect plugin initialized successfully', category: 'HealthConnect');
    } catch (e, stackTrace) {
      logger.error(
        'Failed to initialize Health Connect plugin',
        category: 'HealthConnect',
        error: e,
        stackTrace: stackTrace,
      );
      throw HealthSyncConnectionError('Failed to initialize: $e');
    }
  }

  /// Check Health Connect availability
  Future<HealthConnectAvailability> checkAvailability() async {
    try {
      final String result =
          await _channel.invokeMethod('checkAvailability') ?? 'not_supported';
      return HealthConnectAvailabilityExtension.fromValue(result);
    } catch (e) {
      return HealthConnectAvailability.notSupported;
    }
  }

  /// Connect to Health Connect
  Future<ConnectionResult> connect() async {
    try {
      _connectionStatus = ConnectionStatus.connecting;

      // Check availability
      final availability = await checkAvailability();

      if (availability != HealthConnectAvailability.installed) {
        _connectionStatus = ConnectionStatus.error;
        return ConnectionResult(
          success: false,
          message: 'Health Connect is ${availability.toValue()}',
        );
      }

      // Request permissions if auto-request is enabled
      if (config.autoRequestPermissions) {
        final allPermissions = _getAllRequiredPermissions();
        final permissionStatuses = await checkPermissions(allPermissions);

        final missingPermissions = permissionStatuses
            .where((p) => !p.granted)
            .map((p) => p.permission)
            .toList();

        if (missingPermissions.isNotEmpty) {
          await requestPermissions(missingPermissions);
        }
      }

      _connectionStatus = ConnectionStatus.connected;

      return ConnectionResult(
        success: true,
        message: 'Successfully connected to Health Connect',
      );
    } catch (e) {
      _connectionStatus = ConnectionStatus.error;
      return ConnectionResult(
        success: false,
        message: 'Connection failed: $e',
      );
    }
  }

  /// Disconnect from Health Connect
  Future<void> disconnect() async {
    _connectionStatus = ConnectionStatus.disconnected;
  }

  /// Check if connected
  Future<bool> isConnected() async {
    return _connectionStatus == ConnectionStatus.connected;
  }

  /// Get connection status
  Future<ConnectionStatus> getConnectionStatus() async {
    return _connectionStatus;
  }

  /// Check permissions
  Future<List<PermissionStatus>> checkPermissions(
    List<HealthConnectPermission> permissions,
  ) async {
    logger.debug(
      'Checking ${permissions.length} permissions',
      category: 'Permissions',
      metadata: {
        'permissions': permissions.map((p) => p.toValue()).toList(),
      },
    );

    try {
      final List<dynamic> result = await _channel.invokeMethod(
        'checkPermissions',
        {'permissions': permissions.map((p) => p.toValue()).toList()},
      );

      final statuses = result.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return PermissionStatus.fromJson(map);
      }).toList();

      // Log denied permissions
      final denied = statuses.where((s) => !s.granted).toList();
      if (denied.isNotEmpty) {
        logger.info(
          'Found ${denied.length} denied permissions',
          category: 'Permissions',
          metadata: {
            'deniedPermissions': denied.map((s) => s.permission.toValue()).toList(),
          },
        );
      }

      return statuses;
    } catch (e, stackTrace) {
      logger.error(
        'Failed to check permissions',
        category: 'Permissions',
        error: e,
        stackTrace: stackTrace,
        metadata: {
          'permissionCount': permissions.length,
        },
      );
      throw HealthSyncError('Failed to check permissions: $e');
    }
  }

  /// Request permissions
  Future<List<HealthConnectPermission>> requestPermissions(
    List<HealthConnectPermission> permissions,
  ) async {
    logger.info(
      'Requesting ${permissions.length} permissions',
      category: 'Permissions',
      metadata: {
        'permissions': permissions.map((p) => p.toValue()).toList(),
      },
    );

    final requestTimestamp = DateTime.now();

    try {
      // Request permissions from native side
      final List<dynamic> result = await _channel.invokeMethod(
        'requestPermissions',
        {'permissions': permissions.map((p) => p.toValue()).toList()},
      );

      final grantedPermissions = result
          .map((p) => HealthConnectPermissionExtension.fromValue(p as String))
          .toList();

      // Check which permissions were actually granted
      final checkResult = await checkPermissions(permissions);
      final actuallyGranted = checkResult
          .where((s) => s.granted)
          .map((s) => s.permission)
          .toSet();

      // Track each permission result
      for (final permission in permissions) {
        final wasGranted = actuallyGranted.contains(permission);

        final result = PermissionRequestResult(
          permission: permission,
          granted: wasGranted,
          failureReason: wasGranted ? null : _determineFailureReason(permission),
          errorMessage: wasGranted ? null : 'User denied permission',
          timestamp: requestTimestamp,
        );

        permissionTracker.trackPermissionRequest(result);

        // Log individual failures with detailed information
        if (!wasGranted) {
          logger.warning(
            'Permission denied',
            category: 'Permissions',
            metadata: {
              'permission': permission.toValue(),
              'failureReason': result.failureReason?.name ?? 'unknown',
              'userMessage': _getUserFriendlyMessage(permission),
              'recommendedAction': _getRecommendedAction(permission),
            },
          );
        }
      }

      final deniedCount = permissions.length - actuallyGranted.length;
      if (deniedCount > 0) {
        logger.warning(
          'Permission request completed with ${deniedCount} denials',
          category: 'Permissions',
          metadata: {
            'requested': permissions.length,
            'granted': actuallyGranted.length,
            'denied': deniedCount,
            'deniedPermissions': permissions
                .where((p) => !actuallyGranted.contains(p))
                .map((p) => p.toValue())
                .toList(),
          },
        );
      } else {
        logger.info(
          'All ${permissions.length} permissions granted successfully!',
          category: 'Permissions',
        );
      }

      return grantedPermissions;
    } on PlatformException catch (e) {
      // Handle specific error codes from native side
      logger.error(
        'Platform exception during permission request',
        category: 'Permissions',
        error: e,
        metadata: {
          'code': e.code,
          'message': e.message,
          'details': e.details,
        },
      );

      switch (e.code) {
        case 'CONCURRENT_REQUEST':
          throw HealthSyncError(
            'Another permission request is in progress. ${e.message ?? "Please wait and try again."}',
          );

        case 'TIMEOUT':
          throw HealthSyncError(
            'Permission request timed out after ${e.details?['timeoutSeconds'] ?? 60} seconds. ${e.details?['suggestion'] ?? "Please try again."}',
          );

        case 'NO_VALID_PERMISSIONS':
          throw HealthSyncError(
            'None of the requested permissions are supported by this device. ${e.message ?? ""}',
          );

        default:
          // For other platform exceptions, track and rethrow
          for (final permission in permissions) {
            permissionTracker.trackPermissionRequest(
              PermissionRequestResult(
                permission: permission,
                granted: false,
                failureReason: PermissionFailureReason.systemError,
                errorMessage: '${e.code}: ${e.message}',
                timestamp: requestTimestamp,
              ),
            );
          }
          throw HealthSyncError('Platform error: ${e.code} - ${e.message}');
      }
    } catch (e, stackTrace) {
      logger.critical(
        'Critical error requesting permissions',
        category: 'Permissions',
        error: e,
        stackTrace: stackTrace,
        metadata: {
          'permissionCount': permissions.length,
          'permissions': permissions.map((p) => p.toValue()).toList(),
        },
      );

      // Track all as system errors
      for (final permission in permissions) {
        permissionTracker.trackPermissionRequest(
          PermissionRequestResult(
            permission: permission,
            granted: false,
            failureReason: PermissionFailureReason.systemError,
            errorMessage: e.toString(),
            timestamp: requestTimestamp,
          ),
        );
      }

      throw HealthSyncError('Failed to request permissions: $e');
    }
  }

  /// Determine failure reason for a permission
  PermissionFailureReason _determineFailureReason(HealthConnectPermission permission) {
    // In a real implementation, you might check device capabilities, OS version, etc.
    // For now, we assume it's user denial
    return PermissionFailureReason.userDenied;
  }

  /// Get user-friendly message for permission denial
  String _getUserFriendlyMessage(HealthConnectPermission permission) {
    final permName = permission.toString().split('.').last.replaceAll('read', '');
    return 'Access to $permName data was denied. This may limit app functionality.';
  }

  /// Get recommended action for permission denial
  String _getRecommendedAction(HealthConnectPermission permission) {
    return 'Go to Settings > Apps > Health Connect > Permissions to enable ${permission.toString().split('.').last}';
  }

  /// Fetch health data with automatic rate limiting
  Future<List<RawHealthData>> fetchData(DataQuery query) async {
    if (_connectionStatus != ConnectionStatus.connected) {
      throw HealthSyncConnectionError('Not connected to Health Connect');
    }

    // Check if data type is supported
    final typeInfo = healthConnectTypeMap[query.dataType];

    if (typeInfo == null || typeInfo.recordType == null) {
      throw HealthSyncDataFetchError(
        'Data type ${query.dataType.toValue()} is not supported by Health Connect',
      );
    }

    // Check permissions
    final hasPermission = await _hasPermissionsForDataType(query.dataType);

    if (!hasPermission) {
      throw HealthSyncAuthenticationError(
        'Missing permissions for ${query.dataType.toValue()}',
      );
    }

    // Wrap in rate limiter for automatic retry on rate limit errors
    return await rateLimiter.execute(
      () => _fetchDataInternal(query, typeInfo),
      operationName: 'Fetch ${query.dataType.toValue()}',
    );
  }

  /// Internal fetch implementation (without rate limiting wrapper)
  Future<List<RawHealthData>> _fetchDataInternal(
    DataQuery query,
    HealthConnectTypeInfo typeInfo,
  ) async {
    try {
      final List<dynamic> result = await _channel.invokeMethod(
        'readRecords',
        {
          'recordType': typeInfo.recordType,
          // CRITICAL: Convert to UTC and include 'Z' suffix for Kotlin Instant.parse()
          // Dart's toIso8601String() on local DateTime omits timezone, causing parse errors
          // Local DateTime: "2025-12-31T15:53:13.406697" (NO timezone) ❌
          // UTC DateTime:   "2025-12-31T15:53:13.406697Z" (with Z) ✅
          'startTime': query.startDate.toUtc().toIso8601String(),
          'endTime': query.endDate.toUtc().toIso8601String(),
          if (query.limit != null) 'limit': query.limit,
          if (query.offset != null) 'offset': query.offset,
        },
      );

      final rawData = result.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return RawHealthData.fromJson(map);
      }).toList();

      // Apply fraud prevention filters
      final filteredData = _applyFraudPrevention(rawData, query.dataType);

      logger.info(
        'Fetched ${rawData.length} records, ${filteredData.length} after fraud filtering',
        category: 'HealthConnect',
        metadata: {
          'dataType': query.dataType.toValue(),
          'originalCount': rawData.length,
          'filteredCount': filteredData.length,
          'removedCount': rawData.length - filteredData.length,
        },
      );

      return filteredData;
    } catch (e) {
      throw HealthSyncDataFetchError('Failed to fetch data: $e');
    }
  }

  /// Insert health records with automatic batching and rate limiting
  ///
  /// Automatically splits large datasets into 1000-record batches and retries on rate limits.
  ///
  /// Example:
  /// ```dart
  /// final result = await plugin.insertRecords(
  ///   dataType: DataType.steps,
  ///   records: largeStepsList,
  ///   onProgress: (progress) {
  ///     print('Progress: ${progress.progressPercent}%');
  ///   },
  /// );
  /// print('Written ${result.successfulRecords}/${result.totalRecords} records');
  /// ```
  Future<BatchWriteResult> insertRecords({
    required DataType dataType,
    required List<Map<String, dynamic>> records,
    void Function(BatchProgress)? onProgress,
  }) async {
    if (_connectionStatus != ConnectionStatus.connected) {
      throw HealthSyncConnectionError('Not connected to Health Connect');
    }

    // Check if data type is supported
    final typeInfo = healthConnectTypeMap[dataType];

    if (typeInfo == null || typeInfo.recordType == null) {
      throw HealthSyncDataFetchError(
        'Data type ${dataType.toValue()} is not supported by Health Connect',
      );
    }

    // Check write permissions
    final hasPermission = await _hasWritePermissionsForDataType(dataType);

    if (!hasPermission) {
      throw HealthSyncAuthenticationError(
        'Missing write permissions for ${dataType.toValue()}',
      );
    }

    logger.info(
      'Starting batch insert: ${records.length} ${dataType.toValue()} records',
      category: 'HealthConnect',
      metadata: {
        'dataType': dataType.toValue(),
        'recordCount': records.length,
      },
    );

    // Use BatchWriter for automatic chunking and rate limiting
    final result = await batchWriter.writeBatch<Map<String, dynamic>>(
      records: records,
      writeFunction: (batch) => _insertRecordsBatch(dataType, typeInfo, batch),
      operationName: 'Insert ${dataType.toValue()}',
      onProgress: onProgress,
    );

    logger.info(
      'Batch insert completed: ${result.successfulRecords}/${result.totalRecords} records written',
      category: 'HealthConnect',
      metadata: {
        'dataType': dataType.toValue(),
        'totalRecords': result.totalRecords,
        'successful': result.successfulRecords,
        'failed': result.failedRecords,
        'duration': result.duration.inMilliseconds,
      },
    );

    return result;
  }

  /// Internal batch insert implementation
  Future<void> _insertRecordsBatch(
    DataType dataType,
    HealthConnectTypeInfo typeInfo,
    List<Map<String, dynamic>> batch,
  ) async {
    try {
      await _channel.invokeMethod(
        'insertRecords',
        {
          'recordType': typeInfo.recordType,
          'records': batch,
        },
      );
    } catch (e) {
      logger.error(
        'Failed to insert batch of ${batch.length} records',
        category: 'HealthConnect',
        error: e,
        metadata: {
          'dataType': dataType.toValue(),
          'batchSize': batch.length,
        },
      );
      rethrow;
    }
  }

  /// Check if has write permissions for data type
  Future<bool> _hasWritePermissionsForDataType(DataType dataType) async {
    final typeInfo = healthConnectTypeMap[dataType];

    if (typeInfo == null) {
      return true;
    }

    // For write operations, we need both read and write permissions
    final writePermissions = typeInfo.permissions
        .where((p) => p.toString().contains('write'))
        .toList();

    if (writePermissions.isEmpty) {
      // If no specific write permissions, check read permissions
      return await _hasPermissionsForDataType(dataType);
    }

    final statuses = await checkPermissions(writePermissions);
    return statuses.every((s) => s.granted);
  }

  /// Apply fraud prevention filters to health data
  List<RawHealthData> _applyFraudPrevention(
    List<RawHealthData> data,
    DataType dataType,
  ) {
    var filtered = data;
    int manualEntriesRemoved = 0;
    int unknownSourcesRemoved = 0;
    int anomaliesRemoved = 0;

    // Filter manual entries ONLY for Steps (fraud prevention)
    // Other data types (sleep, weight, blood pressure, etc.) keep manual entries as legitimate data
    if (config.fraudPrevention.filterManualSteps && dataType == DataType.steps) {
      final beforeCount = filtered.length;
      filtered = filtered.where((record) {
        final recordingMethod = _extractRecordingMethod(record);
        return recordingMethod != RecordingMethod.manualEntry;
      }).toList();
      manualEntriesRemoved = beforeCount - filtered.length;

      if (manualEntriesRemoved > 0) {
        logger.info(
          'Filtered out $manualEntriesRemoved manually entered STEPS (fraud prevention)',
          category: 'FraudPrevention',
          metadata: {'dataType': dataType.toValue()},
        );
      }
    } else if (dataType != DataType.steps) {
      // For non-step data types, log manual entries but don't filter them
      final manualEntries = filtered.where((record) {
        final recordingMethod = _extractRecordingMethod(record);
        return recordingMethod == RecordingMethod.manualEntry;
      }).length;

      if (manualEntries > 0) {
        logger.info(
          'Found $manualEntries manual entries for ${dataType.toValue()} (keeping as legitimate data)',
          category: 'FraudPrevention',
          metadata: {'dataType': dataType.toValue(), 'manualCount': manualEntries},
        );
      }
    }

    // Filter unknown sources if enabled
    if (config.fraudPrevention.filterUnknownSources) {
      final beforeCount = filtered.length;
      filtered = filtered.where((record) {
        final recordingMethod = _extractRecordingMethod(record);
        return recordingMethod != RecordingMethod.unknown;
      }).toList();
      unknownSourcesRemoved = beforeCount - filtered.length;

      if (unknownSourcesRemoved > 0) {
        logger.info(
          'Filtered out $unknownSourcesRemoved unknown source records',
          category: 'FraudPrevention',
          metadata: {'dataType': dataType.toValue()},
        );
      }
    }

    // Apply anomaly detection if enabled
    if (config.fraudPrevention.enableAnomalyDetection) {
      final beforeCount = filtered.length;
      filtered = filtered.where((record) {
        return !_isAnomaly(record, dataType);
      }).toList();
      anomaliesRemoved = beforeCount - filtered.length;

      if (anomaliesRemoved > 0) {
        logger.warning(
          'Filtered out $anomaliesRemoved anomalous records',
          category: 'FraudPrevention',
          metadata: {
            'dataType': dataType.toValue(),
            'anomaliesRemoved': anomaliesRemoved,
          },
        );
      }
    }

    // Log summary if any records were filtered
    final totalRemoved = manualEntriesRemoved + unknownSourcesRemoved + anomaliesRemoved;
    if (totalRemoved > 0) {
      logger.info(
        'Fraud prevention summary: removed $totalRemoved records',
        category: 'FraudPrevention',
        metadata: {
          'dataType': dataType.toValue(),
          'manualEntriesRemoved': manualEntriesRemoved,
          'unknownSourcesRemoved': unknownSourcesRemoved,
          'anomaliesRemoved': anomaliesRemoved,
          'originalCount': data.length,
          'finalCount': filtered.length,
        },
      );
    }

    return filtered;
  }

  /// Extract recording method from health data metadata
  RecordingMethod _extractRecordingMethod(RawHealthData data) {
    try {
      // Health Connect stores recordingMethod in metadata
      final metadata = data.raw['metadata'] as Map<String, dynamic>?;
      if (metadata == null) {
        return RecordingMethod.unknown;
      }

      final recordingMethodValue = metadata['recordingMethod'] as String?;
      if (recordingMethodValue == null) {
        return RecordingMethod.unknown;
      }

      return RecordingMethodExtension.fromValue(recordingMethodValue);
    } catch (e) {
      logger.debug(
        'Failed to extract recording method: ${e.toString()}',
        category: 'FraudPrevention',
      );
      return RecordingMethod.unknown;
    }
  }

  /// Get data source information from health data
  /// Returns a map with app package name, app name, and device info if available
  static Map<String, String?> getDataSource(RawHealthData data) {
    try {
      final metadata = data.raw['metadata'] as Map<String, dynamic>?;
      final dataOrigin = metadata?['dataOrigin'] as Map<String, dynamic>?;

      return {
        'packageName': dataOrigin?['packageName'] as String?,
        'appName': dataOrigin?['appName'] as String?,
        'deviceManufacturer': metadata?['device']?['manufacturer'] as String?,
        'deviceModel': metadata?['device']?['model'] as String?,
        'deviceType': metadata?['device']?['type'] as String?,
      };
    } catch (e) {
      return {
        'packageName': null,
        'appName': null,
        'deviceManufacturer': null,
        'deviceModel': null,
        'deviceType': null,
      };
    }
  }

  /// Get recording method from health data
  /// Public method to expose recording method to app developers
  static RecordingMethod getRecordingMethod(RawHealthData data) {
    try {
      final metadata = data.raw['metadata'] as Map<String, dynamic>?;
      if (metadata == null) {
        return RecordingMethod.unknown;
      }

      final recordingMethodValue = metadata['recordingMethod'] as String?;
      if (recordingMethodValue == null) {
        return RecordingMethod.unknown;
      }

      return RecordingMethodExtension.fromValue(recordingMethodValue);
    } catch (e) {
      return RecordingMethod.unknown;
    }
  }

  /// Check if data was manually entered
  static bool isManualEntry(RawHealthData data) {
    return getRecordingMethod(data) == RecordingMethod.manualEntry;
  }

  /// Check if data was automatically recorded by a device
  static bool isAutomaticallyRecorded(RawHealthData data) {
    return getRecordingMethod(data) == RecordingMethod.automaticallyRecorded;
  }

  /// Check if a health data record is anomalous
  bool _isAnomaly(RawHealthData data, DataType dataType) {
    try {
      switch (dataType) {
        case DataType.steps:
          return _isStepsAnomaly(data);
        case DataType.heartRate:
        case DataType.restingHeartRate:
          return _isHeartRateAnomaly(data);
        default:
          // No anomaly detection for other data types yet
          return false;
      }
    } catch (e) {
      logger.debug(
        'Error during anomaly detection: ${e.toString()}',
        category: 'FraudPrevention',
      );
      // If we can't determine, assume it's valid
      return false;
    }
  }

  /// Check if steps count is anomalous
  /// Implements Tier 1 Fraud Detection (Temporal Analysis)
  bool _isStepsAnomaly(RawHealthData data) {
    try {
      final count = data.raw['count'] as int?;
      if (count == null) return false;

      // Check if exceeds maximum daily steps
      if (count > config.fraudPrevention.maxDailySteps) {
        logger.warning(
          'Detected anomalous step count: $count (max: ${config.fraudPrevention.maxDailySteps})',
          category: 'FraudPrevention',
          metadata: {
            'count': count,
            'max': config.fraudPrevention.maxDailySteps,
            'timestamp': data.timestamp.toIso8601String(),
          },
        );
        return true;
      }

      // Check for duration-based anomalies
      if (data.endTimestamp != null) {
        final duration = data.endTimestamp!.difference(data.timestamp);
        final durationMinutes = duration.inMinutes;

        // Tier 1.1: Burst Detection (Shake Detection)
        // Detects rapid step accumulation typical of phone shaking
        // IMPORTANT: Only flags if BOTH count is high AND rate is impossible
        // This prevents false positives for legitimate running/treadmill
        if (config.fraudPrevention.enableBurstDetection &&
            durationMinutes > 0 &&
            durationMinutes <= config.fraudPrevention.burstWindowMinutes) {

          final stepsPerMinute = count / durationMinutes;

          // Only flag if count is high AND rate exceeds 250 spm (truly impossible)
          // Normal running: 100-120 spm, Fast running: 160-180 spm, Elite sprint: 180-200 spm
          // Shaking: 300+ spm
          if (count >= config.fraudPrevention.burstThreshold && stepsPerMinute > 250) {
            logger.warning(
              'Detected burst anomaly: $count steps in $durationMinutes minutes ($stepsPerMinute spm)',
              category: 'FraudPrevention',
              metadata: {
                'fraudType': 'burst',
                'count': count,
                'durationMinutes': durationMinutes,
                'stepsPerMinute': stepsPerMinute,
                'threshold': config.fraudPrevention.burstThreshold,
                'timestamp': data.timestamp.toIso8601String(),
              },
            );
            return true;
          }
        }

        // Tier 1.2: Impossible Pace Detection
        // Detects sustained pace exceeding human capability
        // Threshold set conservatively to NEVER flag legitimate activities:
        // - Running: 100-180 spm ✅ ALLOWED
        // - Treadmill: 160-180 spm ✅ ALLOWED
        // - Stairs: 140-180 spm ✅ ALLOWED
        // - Elite sprint: 180-200 spm ✅ ALLOWED
        // Only flags truly impossible rates (250+ spm = shaking)
        if (durationMinutes > 0) {
          final stepsPerMinute = count / durationMinutes;

          if (stepsPerMinute > config.fraudPrevention.maxStepsPerMinute) {
            logger.warning(
              'Detected impossible pace: $stepsPerMinute spm (max: ${config.fraudPrevention.maxStepsPerMinute})',
              category: 'FraudPrevention',
              metadata: {
                'fraudType': 'impossiblePace',
                'stepsPerMinute': stepsPerMinute,
                'count': count,
                'durationMinutes': durationMinutes,
                'maxAllowed': config.fraudPrevention.maxStepsPerMinute,
              },
            );
            return true;
          }
        }

        // Keep legacy hours-based check for very long duration records
        final durationHours = duration.inHours;
        if (durationHours > 0) {
          final stepsPerHour = count / durationHours;
          // Maximum humanly possible is ~20,000 steps/hour (very fast running)
          if (stepsPerHour > 20000) {
            logger.warning(
              'Detected impossible steps per hour: $stepsPerHour',
              category: 'FraudPrevention',
              metadata: {
                'fraudType': 'hourlyRate',
                'stepsPerHour': stepsPerHour,
                'count': count,
                'durationHours': durationHours,
              },
            );
            return true;
          }
        }
      }

      // Tier 1.3: Midnight Activity Anomaly Detection
      // Flags unusual activity during typical sleep hours (12am-5am)
      // IMPORTANT: This has high false positive rate for:
      // - Night shift workers
      // - Early morning runners (4-5am)
      // - Insomniacs who exercise at night
      // Consider disabling if user reports false positives
      if (config.fraudPrevention.enableMidnightFlagging) {
        final hour = data.timestamp.hour;
        final isInMidnightWindow = hour >= config.fraudPrevention.midnightStartHour &&
                                    hour < config.fraudPrevention.midnightEndHour;

        // Only flag if both: midnight window AND high count AND impossibly high pace
        // This reduces false positives for legitimate night runners/workers
        if (isInMidnightWindow &&
            count > config.fraudPrevention.midnightStepsThreshold &&
            data.endTimestamp != null) {
          final duration = data.endTimestamp!.difference(data.timestamp);
          final durationMinutes = duration.inMinutes;

          // Only flag if the pace is also suspicious (>180 spm)
          // Legitimate night walk/run would be <180 spm
          if (durationMinutes > 0) {
            final stepsPerMinute = count / durationMinutes;
            if (stepsPerMinute > 180) {
              logger.warning(
                'Detected midnight activity anomaly: $count steps at ${hour}:00 ($stepsPerMinute spm)',
                category: 'FraudPrevention',
                metadata: {
                  'fraudType': 'midnightActivity',
                  'count': count,
                  'hour': hour,
                  'stepsPerMinute': stepsPerMinute,
                  'threshold': config.fraudPrevention.midnightStepsThreshold,
                  'timestamp': data.timestamp.toIso8601String(),
                },
              );
              return true;
            }
          }
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Check if heart rate is anomalous
  bool _isHeartRateAnomaly(RawHealthData data) {
    try {
      // Heart rate might be stored in different fields
      final bpm = (data.raw['beatsPerMinute'] ?? data.raw['value']) as int?;
      if (bpm == null) return false;

      final min = config.fraudPrevention.minHeartRate;
      final max = config.fraudPrevention.maxHeartRate;

      if (bpm < min || bpm > max) {
        logger.warning(
          'Detected anomalous heart rate: $bpm (range: $min-$max)',
          category: 'FraudPrevention',
          metadata: {
            'bpm': bpm,
            'min': min,
            'max': max,
            'timestamp': data.timestamp.toIso8601String(),
          },
        );
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Fetch only new/changed data since last sync (incremental sync)
  ///
  /// This is much more efficient than fetchData() for periodic syncing:
  /// - Only fetches new records since last sync
  /// - Avoids reading entire history every time
  /// - Reduces API calls and rate limiting
  /// - Lower battery usage
  ///
  /// On first call, initializes sync token and returns empty list.
  /// On subsequent calls, returns only records added/changed since last sync.
  ///
  /// Example:
  /// ```dart
  /// // First sync: Returns empty, stores token
  /// final result1 = await plugin.fetchChanges(DataType.steps);
  /// print('First: ${result1.changes.length} records'); // 0
  ///
  /// // Wait for new data...
  /// await Future.delayed(Duration(hours: 1));
  ///
  /// // Second sync: Returns only new records
  /// final result2 = await plugin.fetchChanges(DataType.steps);
  /// print('New: ${result2.changes.length}'); // Only new records
  /// ```
  Future<ChangesResult> fetchChanges(DataType dataType) async {
    if (_connectionStatus != ConnectionStatus.connected) {
      throw HealthSyncConnectionError('Not connected to Health Connect');
    }

    // Check if data type is supported
    final typeInfo = healthConnectTypeMap[dataType];

    if (typeInfo == null || typeInfo.recordType == null) {
      throw HealthSyncDataFetchError(
        'Data type ${dataType.toValue()} is not supported by Health Connect',
      );
    }

    // Check permissions
    final hasPermission = await _hasPermissionsForDataType(dataType);

    if (!hasPermission) {
      throw HealthSyncAuthenticationError(
        'Missing permissions for ${dataType.toValue()}',
      );
    }

    // Use Changes API with rate limiting
    return await rateLimiter.execute(
      () => changesApi.getChanges(dataType, recordType: typeInfo.recordType),
      operationName: 'Fetch changes ${dataType.toValue()}',
    );
  }

  /// Fetch changes for multiple data types
  ///
  /// Efficiently fetches incremental updates for all requested types.
  Future<Map<DataType, ChangesResult>> fetchChangesForTypes(
    List<DataType> dataTypes,
  ) async {
    if (_connectionStatus != ConnectionStatus.connected) {
      throw HealthSyncConnectionError('Not connected to Health Connect');
    }

    final results = <DataType, ChangesResult>{};

    for (final dataType in dataTypes) {
      try {
        final result = await fetchChanges(dataType);
        results[dataType] = result;
      } catch (e) {
        logger.error(
          'Failed to fetch changes for ${dataType.toValue()}',
          category: 'HealthConnect',
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

  /// Reset sync for a data type (forces full sync next time)
  Future<void> resetSync(DataType dataType) async {
    await changesApi.resetSync(dataType);
  }

  /// Reset sync for all data types
  Future<void> resetAllSyncs() async {
    await changesApi.resetAllSyncs();
  }

  /// Check if a data type has been synced before
  Future<bool> hasBeenSynced(DataType dataType) async {
    return await changesApi.hasBeenSynced(dataType);
  }

  /// Get last sync time for a data type
  Future<DateTime?> getLastSyncTime(DataType dataType) async {
    return await changesApi.getLastSyncTime(dataType);
  }

  /// Get sync status for multiple data types
  Future<Map<DataType, SyncStatus>> getSyncStatus(
    List<DataType> dataTypes,
  ) async {
    return await changesApi.getSyncStatusForTypes(dataTypes);
  }

  /// Read aggregate data (e.g., total steps, average heart rate)
  ///
  /// Uses Health Connect's native aggregate API for accurate, deduplicated results.
  /// This is much more efficient than fetching all records and calculating manually.
  ///
  /// Benefits:
  /// - Automatic deduplication (respects device priority)
  /// - 100x faster than manual calculation
  /// - System-level accuracy
  /// - Handles overlapping data sources correctly
  ///
  /// Example:
  /// ```dart
  /// // Get total steps for last 7 days
  /// final result = await plugin.readAggregate(
  ///   AggregateQuery(
  ///     dataType: DataType.steps,
  ///     startTime: DateTime.now().subtract(Duration(days: 7)),
  ///     endTime: DateTime.now(),
  ///   ),
  /// );
  /// print('Total steps: ${result.sumValue}');
  /// ```
  Future<AggregateData> readAggregate(AggregateQuery query) async {
    if (_connectionStatus != ConnectionStatus.connected) {
      throw HealthSyncConnectionError('Not connected to Health Connect');
    }

    // Check permissions
    final hasPermission = await _hasPermissionsForDataType(query.dataType);

    if (!hasPermission) {
      throw HealthSyncAuthenticationError(
        'Missing permissions for ${query.dataType.toValue()}',
      );
    }

    return await aggregateReader.readAggregate(query);
  }

  /// Read aggregate data with time bucketing (daily, hourly, etc.)
  ///
  /// Returns a list of aggregates, one per time bucket.
  ///
  /// Example:
  /// ```dart
  /// // Get daily step totals for last 7 days
  /// final dailySteps = await plugin.readAggregateWithBuckets(
  ///   AggregateQuery.daily(
  ///     dataType: DataType.steps,
  ///     startDate: DateTime.now().subtract(Duration(days: 7)),
  ///     endDate: DateTime.now(),
  ///   ),
  /// );
  ///
  /// for (final day in dailySteps) {
  ///   print('${day.startTime.day}/${day.startTime.month}: ${day.sumValue} steps');
  /// }
  /// ```
  Future<List<AggregateData>> readAggregateWithBuckets(
    AggregateQuery query,
  ) async {
    if (_connectionStatus != ConnectionStatus.connected) {
      throw HealthSyncConnectionError('Not connected to Health Connect');
    }

    // Check permissions
    final hasPermission = await _hasPermissionsForDataType(query.dataType);

    if (!hasPermission) {
      throw HealthSyncAuthenticationError(
        'Missing permissions for ${query.dataType.toValue()}',
      );
    }

    return await aggregateReader.readAggregateWithBuckets(query);
  }

  /// Read aggregates for multiple data types
  ///
  /// Efficiently reads totals for multiple types in one call.
  ///
  /// Example:
  /// ```dart
  /// final aggregates = await plugin.readAggregatesForTypes(
  ///   [DataType.steps, DataType.calories, DataType.distance],
  ///   startTime: DateTime.now().subtract(Duration(days: 1)),
  ///   endTime: DateTime.now(),
  /// );
  ///
  /// print('Steps: ${aggregates[DataType.steps]?.sumValue}');
  /// print('Calories: ${aggregates[DataType.calories]?.sumValue}');
  /// ```
  Future<Map<DataType, AggregateData>> readAggregatesForTypes(
    List<DataType> dataTypes, {
    required DateTime startTime,
    required DateTime endTime,
    bool includeBreakdown = false,
  }) async {
    if (_connectionStatus != ConnectionStatus.connected) {
      throw HealthSyncConnectionError('Not connected to Health Connect');
    }

    return await aggregateReader.readAggregatesForTypes(
      dataTypes,
      startTime: startTime,
      endTime: endTime,
      includeBreakdown: includeBreakdown,
    );
  }

  /// Calculate statistics from bucketed aggregate data
  ///
  /// Returns summary statistics (total, average, min, max, daily average).
  ///
  /// Example:
  /// ```dart
  /// final stats = await plugin.calculateAggregateStats(
  ///   AggregateQuery.daily(
  ///     dataType: DataType.steps,
  ///     startDate: DateTime.now().subtract(Duration(days: 30)),
  ///     endDate: DateTime.now(),
  ///   ),
  /// );
  ///
  /// print('30-day stats:');
  /// print('  Total: ${stats.total}');
  /// print('  Daily avg: ${stats.dailyAverage}');
  /// print('  Range: ${stats.minimum} - ${stats.maximum}');
  /// ```
  Future<AggregateStats> calculateAggregateStats(
    AggregateQuery query,
  ) async {
    if (_connectionStatus != ConnectionStatus.connected) {
      throw HealthSyncConnectionError('Not connected to Health Connect');
    }

    // Check permissions
    final hasPermission = await _hasPermissionsForDataType(query.dataType);

    if (!hasPermission) {
      throw HealthSyncAuthenticationError(
        'Missing permissions for ${query.dataType.toValue()}',
      );
    }

    return await aggregateReader.calculateStats(query);
  }

  /// Detect conflicts from multiple data sources (double-counting)
  ///
  /// Analyzes which apps are writing health data and identifies potential conflicts.
  /// Essential for detecting when multiple apps (Samsung Health, Google Fit, etc.)
  /// are tracking the same data, causing inflated counts.
  ///
  /// Example:
  /// ```dart
  /// final result = await plugin.detectConflicts(
  ///   dataType: DataType.steps,
  ///   startTime: DateTime.now().subtract(Duration(days: 7)),
  ///   endTime: DateTime.now(),
  /// );
  ///
  /// if (result.hasConflicts) {
  ///   print('⚠ Warning: Multiple apps writing steps data');
  ///   print('Sources: ${result.sources.map((s) => s.displayName).join(", ")}');
  ///   print('Recommendation: ${result.conflicts.first.recommendation}');
  /// }
  /// ```
  Future<ConflictDetectionResult> detectConflicts({
    required DataType dataType,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    if (_connectionStatus != ConnectionStatus.connected) {
      throw HealthSyncConnectionError('Not connected to Health Connect');
    }

    return await ConflictDetector.detectConflicts(
      plugin: this,
      dataType: dataType,
      startTime: startTime ?? DateTime.now().subtract(Duration(days: 7)),
      endTime: endTime ?? DateTime.now(),
    );
  }

  /// Detect conflicts across multiple data types
  ///
  /// Returns a summary of conflicts for all requested data types.
  ///
  /// Example:
  /// ```dart
  /// final summary = await plugin.detectConflictsForTypes(
  ///   dataTypes: [DataType.steps, DataType.heartRate, DataType.sleep],
  /// );
  ///
  /// print('Total conflicts: ${summary.totalConflicts}');
  /// print('Types with conflicts: ${summary.typesWithConflicts.map((t) => t.toValue()).join(", ")}');
  ///
  /// for (final conflict in summary.allHighSeverityConflicts) {
  ///   print('HIGH: ${conflict.recommendation}');
  /// }
  /// ```
  Future<ConflictSummary> detectConflictsForTypes({
    required List<DataType> dataTypes,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    if (_connectionStatus != ConnectionStatus.connected) {
      throw HealthSyncConnectionError('Not connected to Health Connect');
    }

    return await ConflictDetector.detectConflictsForTypes(
      plugin: this,
      dataTypes: dataTypes,
      startTime: startTime ?? DateTime.now().subtract(Duration(days: 7)),
      endTime: endTime ?? DateTime.now(),
    );
  }

  /// Get warning message for detected conflicts
  ///
  /// Returns a user-friendly warning message based on conflict severity.
  static String getConflictWarning(ConflictDetectionResult result) {
    return ConflictDetector.getWarningMessage(result);
  }

  /// Generate detailed conflict report
  ///
  /// Returns a formatted text report of data sources and conflicts.
  static String generateConflictReport(ConflictDetectionResult result) {
    return ConflictDetector.generateReport(result);
  }

  /// Dispose plugin resources
  Future<void> dispose() async {
    _connectionStatus = ConnectionStatus.disconnected;
    syncTokenManager.dispose();
  }

  // Helper methods

  List<HealthConnectPermission> _getAllRequiredPermissions() {
    final permissions = <HealthConnectPermission>{};

    for (final dataType in supportedDataTypes) {
      final typeInfo = healthConnectTypeMap[dataType];
      if (typeInfo != null) {
        permissions.addAll(typeInfo.permissions);
      }
    }

    return permissions.toList();
  }

  Future<bool> _hasPermissionsForDataType(DataType dataType) async {
    final typeInfo = healthConnectTypeMap[dataType];

    if (typeInfo == null || typeInfo.permissions.isEmpty) {
      return true;
    }

    final statuses = await checkPermissions(typeInfo.permissions);

    return statuses.every((s) => s.granted);
  }
}

/// Connection result
class ConnectionResult {
  /// Whether connection was successful
  final bool success;

  /// Human-readable message
  final String message;

  /// Error details if failed
  final Object? error;

  const ConnectionResult({
    required this.success,
    required this.message,
    this.error,
  });
}
