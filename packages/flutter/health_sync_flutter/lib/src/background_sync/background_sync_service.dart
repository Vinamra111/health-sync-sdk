import 'dart:async';
import 'package:workmanager/workmanager.dart';
import '../models/data_type.dart';
import '../utils/logger.dart';
import 'background_sync_config.dart';
import 'background_sync_stats.dart';
import 'device_info.dart';

/// Background sync service using WorkManager
///
/// Schedules and manages periodic background syncing of health data.
/// Uses Android WorkManager for battery-efficient background tasks.
///
/// IMPORTANT: Background sync reliability depends on device manufacturer.
/// Use `checkCompatibility()` to assess device-specific reliability.
class BackgroundSyncService {
  /// Whether the service has been initialized
  bool _initialized = false;

  /// Current sync configuration
  BackgroundSyncConfig? _config;

  /// Failure notification callback
  ///
  /// Called when background sync fails.
  /// Use this to show notifications or log errors.
  void Function(String error, DateTime timestamp)? onFailure;

  /// Success notification callback
  ///
  /// Called when background sync succeeds.
  /// Use this for analytics or debugging.
  void Function(DateTime timestamp)? onSuccess;

  /// Get current configuration
  BackgroundSyncConfig? get config => _config;

  /// Initialize the background sync service
  ///
  /// Must be called once during app initialization before using background sync.
  /// The callbackDispatcher handles background execution.
  ///
  /// Example:
  /// ```dart
  /// void main() {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///
  ///   // Initialize background sync
  ///   BackgroundSyncService().initialize(
  ///     callbackDispatcher: backgroundSyncDispatcher,
  ///   );
  ///
  ///   runApp(MyApp());
  /// }
  /// ```
  Future<void> initialize({
    required Function callbackDispatcher,
    bool isInDebugMode = false,
  }) async {
    if (_initialized) {
      logger.warning(
        'BackgroundSyncService already initialized',
        category: 'BackgroundSync',
      );
      return;
    }

    try {
      await Workmanager().initialize(
        callbackDispatcher,
        isInDebugMode: isInDebugMode,
      );

      _initialized = true;

      logger.info(
        'BackgroundSyncService initialized',
        category: 'BackgroundSync',
        metadata: {'debugMode': isInDebugMode},
      );
    } catch (e, stackTrace) {
      logger.error(
        'Failed to initialize BackgroundSyncService',
        category: 'BackgroundSync',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Schedule periodic background sync
  ///
  /// Registers a periodic task with WorkManager to sync health data in background.
  /// Minimum frequency is 15 minutes per Android restrictions.
  ///
  /// Example:
  /// ```dart
  /// final service = BackgroundSyncService();
  /// await service.schedulePeriodicSync(
  ///   config: BackgroundSyncConfig.balanced(
  ///     dataTypes: [DataType.steps, DataType.heartRate],
  ///     frequency: Duration(minutes: 30),
  ///   ),
  /// );
  /// ```
  Future<void> schedulePeriodicSync({
    required BackgroundSyncConfig config,
  }) async {
    _ensureInitialized();

    if (!config.enabled) {
      logger.info(
        'Background sync is disabled in config',
        category: 'BackgroundSync',
      );
      return;
    }

    // Validate frequency (minimum 15 minutes per Android restrictions)
    if (config.frequency.inMinutes < 15) {
      throw ArgumentError(
        'Background sync frequency must be at least 15 minutes (Android restriction). '
        'Requested: ${config.frequency.inMinutes} minutes.',
      );
    }

    _config = config;

    try {
      // Cancel existing tasks first
      await cancelPeriodicSync(taskTag: config.taskTag);

      // Build constraints
      final constraints = Constraints(
        networkType: config.requiresWiFi
            ? NetworkType.unmetered
            : NetworkType.connected,
        requiresCharging: config.requiresCharging,
        requiresDeviceIdle: config.requiresDeviceIdle,
        requiresBatteryNotLow: config.requiresBatteryNotLow,
        requiresStorageNotLow: config.requiresStorageNotLow,
      );

      // Register periodic task
      await Workmanager().registerPeriodicTask(
        config.taskTag,
        config.taskTag,
        frequency: config.frequency,
        constraints: constraints,
        initialDelay: Duration(seconds: 10), // Start after 10 seconds
        existingWorkPolicy: ExistingWorkPolicy.replace,
        inputData: {
          'dataTypes': config.dataTypes.map((t) => t.toValue()).toList(),
          'useIncrementalSync': config.useIncrementalSync,
        },
      );

      logger.info(
        'Scheduled periodic background sync',
        category: 'BackgroundSync',
        metadata: {
          'frequency': config.frequency.inMinutes,
          'dataTypes': config.dataTypes.map((t) => t.toValue()).toList(),
          'incremental': config.useIncrementalSync,
          'requiresCharging': config.requiresCharging,
          'requiresWiFi': config.requiresWiFi,
        },
      );
    } catch (e, stackTrace) {
      logger.error(
        'Failed to schedule periodic sync',
        category: 'BackgroundSync',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Schedule one-time background sync
  ///
  /// Runs a single background sync immediately (or with optional delay).
  ///
  /// Example:
  /// ```dart
  /// await service.scheduleOneTimeSync(
  ///   config: BackgroundSyncConfig(
  ///     dataTypes: [DataType.steps],
  ///   ),
  ///   delay: Duration(seconds: 5),
  /// );
  /// ```
  Future<void> scheduleOneTimeSync({
    required BackgroundSyncConfig config,
    Duration? delay,
  }) async {
    _ensureInitialized();

    final taskName = '${config.taskTag}_oneTime';

    try {
      final constraints = Constraints(
        networkType: config.requiresWiFi
            ? NetworkType.unmetered
            : NetworkType.connected,
        requiresCharging: config.requiresCharging,
        requiresDeviceIdle: config.requiresDeviceIdle,
        requiresBatteryNotLow: config.requiresBatteryNotLow,
        requiresStorageNotLow: config.requiresStorageNotLow,
      );

      await Workmanager().registerOneOffTask(
        taskName,
        config.taskTag,
        initialDelay: delay ?? Duration.zero,
        constraints: constraints,
        inputData: {
          'dataTypes': config.dataTypes.map((t) => t.toValue()).toList(),
          'useIncrementalSync': config.useIncrementalSync,
          'oneTime': true,
        },
      );

      logger.info(
        'Scheduled one-time background sync',
        category: 'BackgroundSync',
        metadata: {
          'delay': delay?.inSeconds ?? 0,
          'dataTypes': config.dataTypes.map((t) => t.toValue()).toList(),
        },
      );
    } catch (e, stackTrace) {
      logger.error(
        'Failed to schedule one-time sync',
        category: 'BackgroundSync',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Cancel periodic background sync
  ///
  /// Stops all scheduled background sync tasks.
  Future<void> cancelPeriodicSync({String? taskTag}) async {
    _ensureInitialized();

    try {
      if (taskTag != null) {
        await Workmanager().cancelByUniqueName(taskTag);
        logger.info(
          'Cancelled background sync task',
          category: 'BackgroundSync',
          metadata: {'taskTag': taskTag},
        );
      } else {
        await Workmanager().cancelAll();
        logger.info(
          'Cancelled all background sync tasks',
          category: 'BackgroundSync',
        );
      }

      _config = null;
    } catch (e, stackTrace) {
      logger.error(
        'Failed to cancel background sync',
        category: 'BackgroundSync',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Check if background sync is currently scheduled
  Future<bool> isScheduled({String? taskTag}) async {
    _ensureInitialized();

    try {
      // Note: WorkManager doesn't provide a direct way to check if a task is scheduled
      // This is a best-effort check based on our internal state
      if (taskTag != null) {
        return _config?.taskTag == taskTag && _config?.enabled == true;
      }
      return _config != null && _config!.enabled;
    } catch (e) {
      logger.warning(
        'Failed to check sync schedule status',
        category: 'BackgroundSync',
      );
      return false;
    }
  }

  /// Get info about scheduled sync
  Future<BackgroundSyncInfo?> getSyncInfo() async {
    if (_config == null) return null;

    return BackgroundSyncInfo(
      isScheduled: await isScheduled(),
      config: _config!,
      lastScheduledTime: DateTime.now(), // Note: WorkManager doesn't expose this
    );
  }

  /// Check device compatibility for background sync
  ///
  /// Returns compatibility assessment for the current device.
  /// Use this to warn users if background sync may not work reliably.
  ///
  /// Example:
  /// ```dart
  /// final compat = backgroundSyncService.checkCompatibility();
  /// if (compat.level == 'low') {
  ///   showDialog(
  ///     title: 'Background Sync May Not Work',
  ///     content: compat.warning,
  ///   );
  /// }
  /// ```
  DeviceCompatibility checkCompatibility() {
    final manufacturer = DeviceInfo.getManufacturer();
    final level = DeviceInfo.getBackgroundSyncCompatibility(manufacturer);
    final isAggressive = DeviceInfo.isAggressiveBatteryManager(manufacturer);
    final warning = DeviceInfo.getBatteryOptimizationWarning(manufacturer);
    final recommendedFrequency = DeviceInfo.getRecommendedSyncFrequency(manufacturer);

    return DeviceCompatibility(
      manufacturer: manufacturer,
      level: level,
      isAggressiveBatteryManager: isAggressive,
      warning: warning,
      recommendedFrequency: recommendedFrequency,
      shouldRequireCharging: DeviceInfo.shouldRequireCharging(manufacturer),
      shouldRequireWiFi: DeviceInfo.shouldRequireWiFi(manufacturer),
    );
  }

  /// Get execution statistics
  ///
  /// Returns statistics about background sync execution history.
  /// Use this to monitor reliability and identify issues.
  ///
  /// Example:
  /// ```dart
  /// final stats = await backgroundSyncService.getExecutionStats();
  /// if (!stats.isHealthy) {
  ///   print('Background sync not working reliably');
  ///   print(stats.getReport());
  /// }
  /// ```
  Future<BackgroundSyncStats> getExecutionStats({String? taskTag}) async {
    final tag = taskTag ?? _config?.taskTag ?? 'healthSync';
    return await BackgroundSyncStats.load(tag);
  }

  /// Reset execution statistics
  ///
  /// Clears all stored statistics for the task.
  Future<void> resetStats({String? taskTag}) async {
    final tag = taskTag ?? _config?.taskTag ?? 'healthSync';
    final stats = BackgroundSyncStats();
    await stats.save(tag);

    logger.info(
      'Reset background sync statistics',
      category: 'BackgroundSync',
      metadata: {'taskTag': tag},
    );
  }

  /// Record successful execution
  ///
  /// Should be called from background task handler after successful sync.
  /// This is internal - called by BackgroundSyncHandler.
  Future<void> recordSuccess({
    required String taskTag,
    DateTime? scheduledTime,
  }) async {
    final stats = await BackgroundSyncStats.load(taskTag);
    final executionTime = DateTime.now();

    Duration? delay;
    if (scheduledTime != null) {
      delay = executionTime.difference(scheduledTime);
    }

    stats.recordSuccess(
      executionTime: executionTime,
      delay: delay,
    );

    await stats.save(taskTag);

    // Call success callback if provided
    onSuccess?.call(executionTime);

    logger.info(
      'Background sync succeeded',
      category: 'BackgroundSync',
      metadata: {
        'taskTag': taskTag,
        'delay': delay?.inMinutes,
        'successRate': '${(stats.successRate * 100).toStringAsFixed(1)}%',
      },
    );
  }

  /// Record failed execution
  ///
  /// Should be called from background task handler after failed sync.
  /// This is internal - called by BackgroundSyncHandler.
  Future<void> recordFailure({
    required String taskTag,
    required String reason,
  }) async {
    final stats = await BackgroundSyncStats.load(taskTag);
    final executionTime = DateTime.now();

    stats.recordFailure(
      executionTime: executionTime,
      reason: reason,
    );

    await stats.save(taskTag);

    // Call failure callback if provided
    onFailure?.call(reason, executionTime);

    logger.error(
      'Background sync failed',
      category: 'BackgroundSync',
      metadata: {
        'taskTag': taskTag,
        'reason': reason,
        'successRate': '${(stats.successRate * 100).toStringAsFixed(1)}%',
      },
    );

    // Warn if sync appears stuck
    if (stats.appearsStuck) {
      logger.warning(
        'Background sync appears stuck (>24h since last success)',
        category: 'BackgroundSync',
        metadata: {
          'taskTag': taskTag,
          'lastSuccess': stats.lastSuccessfulExecution?.toIso8601String(),
          'recommendation': 'Check device battery optimization settings or disable background sync',
        },
      );
    }
  }

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'BackgroundSyncService not initialized. Call initialize() first.',
      );
    }
  }
}

/// Device compatibility assessment for background sync
class DeviceCompatibility {
  /// Device manufacturer
  final String manufacturer;

  /// Compatibility level: 'high', 'medium', 'low'
  final String level;

  /// Whether manufacturer is known to kill background tasks
  final bool isAggressiveBatteryManager;

  /// Warning message for user (null if no warning needed)
  final String? warning;

  /// Recommended sync frequency for this device
  final Duration recommendedFrequency;

  /// Whether charging should be required
  final bool shouldRequireCharging;

  /// Whether WiFi should be required
  final bool shouldRequireWiFi;

  const DeviceCompatibility({
    required this.manufacturer,
    required this.level,
    required this.isAggressiveBatteryManager,
    this.warning,
    required this.recommendedFrequency,
    required this.shouldRequireCharging,
    required this.shouldRequireWiFi,
  });

  /// Whether background sync is likely to work reliably
  bool get isReliable => level == 'high';

  /// Whether user should be warned about compatibility
  bool get shouldWarnUser => level == 'low' || isAggressiveBatteryManager;

  @override
  String toString() {
    return 'DeviceCompatibility{'
        'manufacturer: $manufacturer, '
        'level: $level, '
        'reliable: $isReliable'
        '}';
  }
}

/// Information about scheduled background sync
class BackgroundSyncInfo {
  final bool isScheduled;
  final BackgroundSyncConfig config;
  final DateTime lastScheduledTime;

  const BackgroundSyncInfo({
    required this.isScheduled,
    required this.config,
    required this.lastScheduledTime,
  });

  @override
  String toString() {
    return 'BackgroundSyncInfo{'
        'scheduled: $isScheduled, '
        'frequency: ${config.frequency.inMinutes}min, '
        'types: ${config.dataTypes.length}'
        '}';
  }
}

/// Global background sync service instance
final backgroundSyncService = BackgroundSyncService();
