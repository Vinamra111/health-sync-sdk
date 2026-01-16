import 'dart:async';
import 'package:health_sync_flutter/health_sync_flutter.dart';

/// Example: Incremental Syncing with Changes API
///
/// Demonstrates efficient data syncing that only fetches new records
/// since the last sync, instead of reading entire history every time.
void main() async {
  // Example 1: Basic incremental sync
  await basicIncrementalSync();

  // Example 2: Multi-type incremental sync
  await multiTypeIncrementalSync();

  // Example 3: Sync status monitoring
  await syncStatusExample();

  // Example 4: Periodic background sync
  await periodicSyncExample();

  // Example 5: Full sync vs incremental comparison
  await performanceComparisonExample();
}

/// Example 1: Basic incremental sync
Future<void> basicIncrementalSync() async {
  print('=== Example 1: Basic Incremental Sync ===\n');

  final plugin = HealthConnectPlugin();
  await plugin.initialize();
  await plugin.connect();

  // First sync: Initialize token (returns empty)
  print('First sync: Initializing token...');
  final result1 = await plugin.fetchChanges(DataType.steps);

  print('  Records: ${result1.changes.length}');
  print('  Is initial: ${result1.isInitialSync}');
  print('  Token stored: ${result1.nextToken != null}\n');

  // Simulate time passing / new data arriving
  print('Waiting for new data...');
  await Future.delayed(Duration(seconds: 2));

  // Second sync: Fetch only new records
  print('\nSecond sync: Fetching new records...');
  final result2 = await plugin.fetchChanges(DataType.steps);

  print('  Records: ${result2.changes.length}');
  print('  Is initial: ${result2.isInitialSync}');

  if (result2.hasChanges) {
    print('  New records found!');
    for (final record in result2.changes.take(3)) {
      print('    - ${record.timestamp}: ${record.raw}');
    }
  } else {
    print('  No new records since last sync');
  }

  print('');
}

/// Example 2: Multi-type incremental sync
Future<void> multiTypeIncrementalSync() async {
  print('=== Example 2: Multi-Type Incremental Sync ===\n');

  final plugin = HealthConnectPlugin();
  await plugin.initialize();
  await plugin.connect();

  final dataTypes = [
    DataType.steps,
    DataType.heartRate,
    DataType.sleep,
    DataType.calories,
  ];

  // Fetch changes for all types
  print('Fetching changes for ${dataTypes.length} data types...\n');

  final results = await plugin.fetchChangesForTypes(dataTypes);

  // Process results
  for (final entry in results.entries) {
    final type = entry.key;
    final result = entry.value;

    print('${type.toValue()}:');

    if (result.isSuccess) {
      if (result.isInitialSync) {
        print('  ✓ Token initialized');
      } else if (result.hasChanges) {
        print('  ✓ ${result.changes.length} new records');
      } else {
        print('  ✓ No new data');
      }
    } else {
      print('  ✗ Error: ${result.error}');
    }
  }

  print('');
}

/// Example 3: Sync status monitoring
Future<void> syncStatusExample() async {
  print('=== Example 3: Sync Status Monitoring ===\n');

  final plugin = HealthConnectPlugin();
  await plugin.initialize();
  await plugin.connect();

  final dataTypes = [
    DataType.steps,
    DataType.heartRate,
    DataType.sleep,
  ];

  // Get sync status for all types
  final statuses = await plugin.getSyncStatus(dataTypes);

  print('Sync Status Report:\n');

  for (final entry in statuses.entries) {
    final type = entry.key;
    final status = entry.value;

    print('${type.toValue()}:');
    print('  Synced: ${status.hasBeenSynced}');

    if (status.hasBeenSynced) {
      print('  Last sync: ${status.lastSyncTime}');
      print('  Last count: ${status.lastRecordCount ?? 0} records');

      if (status.timeSinceSync != null) {
        final hours = status.timeSinceSync!.inHours;
        final minutes = status.timeSinceSync!.inMinutes % 60;
        print('  Time since: ${hours}h ${minutes}m');
      }

      if (status.isStale) {
        print('  ⚠ Status: STALE (>24h old)');
      } else {
        print('  ✓ Status: FRESH');
      }
    } else {
      print('  Status: NEVER SYNCED');
    }

    print('');
  }

  // Check individual sync status
  final hasStepsSync = await plugin.hasBeenSynced(DataType.steps);
  final lastStepsSync = await plugin.getLastSyncTime(DataType.steps);

  print('Quick Check:');
  print('  Steps synced: $hasStepsSync');
  print('  Last steps sync: $lastStepsSync');

  print('');
}

/// Example 4: Periodic background sync
Future<void> periodicSyncExample() async {
  print('=== Example 4: Periodic Background Sync ===\n');

  final plugin = HealthConnectPlugin();
  await plugin.initialize();
  await plugin.connect();

  // Initialize tokens for all types (run once during app setup)
  print('Initializing sync tokens...');

  final dataTypes = [
    DataType.steps,
    DataType.heartRate,
    DataType.sleep,
    DataType.calories,
  ];

  for (final type in dataTypes) {
    final hasToken = await plugin.hasBeenSynced(type);
    if (!hasToken) {
      await plugin.fetchChanges(type);
      print('  ✓ Initialized ${type.toValue()}');
    } else {
      print('  ✓ ${type.toValue()} already initialized');
    }
  }

  print('\nStarting periodic sync (every 5 seconds for demo)...\n');

  // Simulate periodic sync
  var syncCount = 0;
  final timer = Timer.periodic(Duration(seconds: 5), (_) async {
    syncCount++;
    print('[Sync #$syncCount at ${DateTime.now().toIso8601String()}]');

    final results = await plugin.fetchChangesForTypes(dataTypes);

    var totalNewRecords = 0;

    for (final entry in results.entries) {
      final type = entry.key;
      final result = entry.value;

      if (result.hasChanges) {
        totalNewRecords += result.changes.length;
        print('  ${type.toValue()}: ${result.changes.length} new records');
      }
    }

    if (totalNewRecords > 0) {
      print('  Total: $totalNewRecords new records synced');
    } else {
      print('  No new data');
    }

    print('');
  });

  // Run for 30 seconds then stop
  await Future.delayed(Duration(seconds: 30));
  timer.cancel();

  print('Periodic sync stopped.\n');
}

/// Example 5: Performance comparison
Future<void> performanceComparisonExample() async {
  print('=== Example 5: Performance Comparison ===\n');

  final plugin = HealthConnectPlugin();
  await plugin.initialize();
  await plugin.connect();

  // Full sync (entire history)
  print('Full Sync (fetchData):');
  final fullStopwatch = Stopwatch()..start();

  final fullData = await plugin.fetchData(DataQuery(
    dataType: DataType.steps,
    startDate: DateTime.now().subtract(Duration(days: 30)),
    endDate: DateTime.now(),
  ));

  fullStopwatch.stop();

  print('  Time: ${fullStopwatch.elapsedMilliseconds}ms');
  print('  Records: ${fullData.length}');
  print('  Speed: ${fullData.length / (fullStopwatch.elapsedMilliseconds / 1000)} records/sec');

  // Initialize incremental sync
  await plugin.fetchChanges(DataType.steps);

  // Wait for some new data
  await Future.delayed(Duration(seconds: 1));

  // Incremental sync (only new data)
  print('\nIncremental Sync (fetchChanges):');
  final incrementalStopwatch = Stopwatch()..start();

  final incrementalResult = await plugin.fetchChanges(DataType.steps);

  incrementalStopwatch.stop();

  print('  Time: ${incrementalStopwatch.elapsedMilliseconds}ms');
  print('  Records: ${incrementalResult.changes.length}');
  if (incrementalResult.hasChanges) {
    print('  Speed: ${incrementalResult.changes.length / (incrementalStopwatch.elapsedMilliseconds / 1000)} records/sec');
  }

  // Calculate improvement
  if (fullStopwatch.elapsedMilliseconds > 0) {
    final speedup = fullStopwatch.elapsedMilliseconds / incrementalStopwatch.elapsedMilliseconds;
    print('\nPerformance:');
    print('  Incremental is ${speedup.toStringAsFixed(1)}x faster!');
  }

  print('');
}

/// Advanced Example: Smart sync strategy
class SmartSyncManager {
  final HealthConnectPlugin plugin;
  Timer? _syncTimer;

  SmartSyncManager(this.plugin);

  /// Start intelligent periodic syncing
  Future<void> startSmartSync() async {
    // Check which types need syncing
    final dataTypes = [
      DataType.steps,
      DataType.heartRate,
      DataType.sleep,
      DataType.calories,
    ];

    final statuses = await plugin.getSyncStatus(dataTypes);

    // Initialize tokens for types that haven't been synced
    for (final entry in statuses.entries) {
      if (!entry.value.hasBeenSynced) {
        print('Initializing ${entry.key.toValue()}...');
        await plugin.fetchChanges(entry.key);
      }
    }

    // Start periodic sync with adaptive interval
    _startAdaptiveSync(dataTypes);
  }

  void _startAdaptiveSync(List<DataType> dataTypes) {
    _syncTimer = Timer.periodic(Duration(minutes: 15), (_) async {
      await _performSmartSync(dataTypes);
    });
  }

  Future<void> _performSmartSync(List<DataType> dataTypes) async {
    print('[Smart Sync] ${DateTime.now()}');

    // Get current sync status
    final statuses = await plugin.getSyncStatus(dataTypes);

    // Prioritize stale syncs
    final staleTypes = statuses.entries
        .where((e) => e.value.isStale)
        .map((e) => e.key)
        .toList();

    if (staleTypes.isNotEmpty) {
      print('  Priority sync for ${staleTypes.length} stale types');

      for (final type in staleTypes) {
        final result = await plugin.fetchChanges(type);
        if (result.hasChanges) {
          print('  ${type.toValue()}: ${result.changes.length} records');
        }
      }
    }

    // Sync remaining types
    final freshTypes = dataTypes.where((t) => !staleTypes.contains(t)).toList();

    final results = await plugin.fetchChangesForTypes(freshTypes);

    var totalNew = staleTypes.length;
    for (final result in results.values) {
      if (result.hasChanges) totalNew += result.changes.length;
    }

    if (totalNew > 0) {
      print('  Synced $totalNew total new records');
    } else {
      print('  No new data');
    }
  }

  void stop() {
    _syncTimer?.cancel();
  }
}

/// Advanced Example: Reset and recovery
Future<void> resetAndRecoveryExample() async {
  print('=== Advanced: Reset and Recovery ===\n');

  final plugin = HealthConnectPlugin();
  await plugin.initialize();
  await plugin.connect();

  // Reset specific data type
  print('Resetting steps sync...');
  await plugin.resetSync(DataType.steps);

  // Next sync will be initial (returns empty, stores new token)
  final result1 = await plugin.fetchChanges(DataType.steps);
  print('After reset: isInitialSync = ${result1.isInitialSync}\n');

  // Reset all syncs
  print('Resetting all syncs...');
  await plugin.resetAllSyncs();

  // All next syncs will be initial
  final dataTypes = [DataType.steps, DataType.heartRate, DataType.sleep];

  for (final type in dataTypes) {
    final result = await plugin.fetchChanges(type);
    print('${type.toValue()}: isInitialSync = ${result.isInitialSync}');
  }

  print('');
}
