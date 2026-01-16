import 'dart:async';
import 'package:workmanager/workmanager.dart';
import '../models/data_type.dart';
import '../plugins/health_connect/health_connect_plugin.dart';
import '../utils/logger.dart';
import '../types/data_query.dart';
import 'background_sync_config.dart';

/// Background sync handler
///
/// Processes background sync tasks when triggered by WorkManager.
/// This runs in an isolate separate from the main app.
class BackgroundSyncHandler {
  /// Execute a background sync task
  ///
  /// Called by WorkManager when a scheduled task runs.
  /// Returns true if task completed successfully.
  static Future<bool> executeSync({
    required Map<String, dynamic> inputData,
    required HealthConnectPlugin plugin,
    BackgroundSyncConfig? config,
  }) async {
    final startTime = DateTime.now();

    try {
      logger.info(
        'Background sync started',
        category: 'BackgroundSync',
        metadata: {'inputData': inputData},
      );

      // Parse input data
      final dataTypesRaw = inputData['dataTypes'] as List<dynamic>?;
      final useIncrementalSync = inputData['useIncrementalSync'] as bool? ?? true;

      if (dataTypesRaw == null || dataTypesRaw.isEmpty) {
        logger.warning(
          'No data types specified for background sync',
          category: 'BackgroundSync',
        );
        return false;
      }

      final dataTypes = dataTypesRaw
          .map((t) => DataTypeExtension.fromValue(t as String))
          .toList();

      // Initialize plugin
      await plugin.initialize();
      await plugin.connect();

      // Perform sync for each data type
      final recordCounts = <DataType, int>{};

      for (final dataType in dataTypes) {
        try {
          final records = useIncrementalSync
              ? await _performIncrementalSync(plugin, dataType)
              : await _performFullSync(plugin, dataType);

          recordCounts[dataType] = records;

          logger.info(
            'Synced ${dataType.toValue()}: $records records',
            category: 'BackgroundSync',
          );

          // Call onDataSynced callback if provided
          if (config?.onDataSynced != null) {
            await config!.onDataSynced!(dataType, []);
          }
        } catch (e) {
          logger.error(
            'Failed to sync ${dataType.toValue()}',
            category: 'BackgroundSync',
            error: e,
          );
          // Continue with other types even if one fails
          recordCounts[dataType] = 0;
        }
      }

      final endTime = DateTime.now();

      // Create result
      final result = BackgroundSyncResult(
        startTime: startTime,
        endTime: endTime,
        dataTypes: dataTypes,
        recordCounts: recordCounts,
        success: true,
        wasIncremental: useIncrementalSync,
      );

      logger.info(
        'Background sync completed successfully',
        category: 'BackgroundSync',
        metadata: {
          'duration': result.duration.inSeconds,
          'totalRecords': result.totalRecords,
        },
      );

      // Call onSyncComplete callback if provided
      if (config?.onSyncComplete != null) {
        await config!.onSyncComplete!(result);
      }

      return true;
    } catch (e, stackTrace) {
      logger.error(
        'Background sync failed',
        category: 'BackgroundSync',
        error: e,
        stackTrace: stackTrace,
      );

      // Call onSyncFailed callback if provided
      if (config?.onSyncFailed != null) {
        await config!.onSyncFailed!(e.toString());
      }

      return false;
    }
  }

  /// Perform incremental sync using Changes API
  static Future<int> _performIncrementalSync(
    HealthConnectPlugin plugin,
    DataType dataType,
  ) async {
    final result = await plugin.fetchChanges(dataType);

    if (result.isSuccess && result.hasChanges) {
      return result.changes.length;
    }

    return 0;
  }

  /// Perform full sync (read all data for last 24 hours)
  static Future<int> _performFullSync(
    HealthConnectPlugin plugin,
    DataType dataType,
  ) async {
    final data = await plugin.fetchData(
      DataQuery(
        dataType: dataType,
        startDate: DateTime.now().subtract(Duration(hours: 24)),
        endDate: DateTime.now(),
      ),
    );

    return data.length;
  }
}

/// Default background callback dispatcher
///
/// This is called by WorkManager in the background isolate.
/// It must be a top-level function (not a class method).
///
/// Example usage:
/// ```dart
/// void main() {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   BackgroundSyncService().initialize(
///     callbackDispatcher: backgroundSyncCallbackDispatcher,
///   );
///
///   runApp(MyApp());
/// }
/// ```
@pragma('vm:entry-point')
void backgroundSyncCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      logger.info(
        'Background task triggered',
        category: 'BackgroundSync',
        metadata: {
          'taskName': taskName,
          'inputData': inputData,
        },
      );

      // Create plugin instance for background execution
      final plugin = HealthConnectPlugin();

      // Execute sync
      final success = await BackgroundSyncHandler.executeSync(
        inputData: inputData ?? {},
        plugin: plugin,
      );

      logger.info(
        'Background task completed',
        category: 'BackgroundSync',
        metadata: {'success': success},
      );

      return success;
    } catch (e, stackTrace) {
      logger.error(
        'Background task failed',
        category: 'BackgroundSync',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  });
}

/// Helper for creating custom callback dispatchers
///
/// Use this to create a custom dispatcher with your own logic:
///
/// ```dart
/// @pragma('vm:entry-point')
/// void myCustomDispatcher() {
///   createBackgroundSyncDispatcher(
///     onSync: (dataType, records) async {
///       // Custom logic: upload to server, save to database, etc.
///       await uploadToServer(dataType, records);
///     },
///     onComplete: (result) async {
///       // Custom completion logic
///       print('Sync completed: ${result.totalRecords} records');
///     },
///   );
/// }
/// ```
void createBackgroundSyncDispatcher({
  Future<void> Function(DataType, List<dynamic>)? onSync,
  Future<void> Function(BackgroundSyncResult)? onComplete,
  Future<void> Function(String)? onFailed,
}) {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      final plugin = HealthConnectPlugin();

      final config = onSync != null || onComplete != null || onFailed != null
          ? BackgroundSyncConfig(
              dataTypes: [], // Will be overridden by inputData
              onDataSynced: onSync,
              onSyncComplete: onComplete,
              onSyncFailed: onFailed,
            )
          : null;

      final success = await BackgroundSyncHandler.executeSync(
        inputData: inputData ?? {},
        plugin: plugin,
        config: config,
      );

      return success;
    } catch (e, stackTrace) {
      logger.error(
        'Custom dispatcher failed',
        category: 'BackgroundSync',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  });
}
