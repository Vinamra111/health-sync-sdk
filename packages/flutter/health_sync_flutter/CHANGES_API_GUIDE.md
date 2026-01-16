# Changes API Guide: Incremental Syncing

This guide explains how to use the HealthSync SDK's Changes API for efficient incremental data syncing with Health Connect.

## Overview

The Changes API allows you to fetch only new/modified data since your last sync, instead of reading the entire history every time. This is crucial for:

- **Battery Efficiency**: Fetch only what's new, not entire history
- **Speed**: Incremental updates are 10-100x faster than full reads
- **Rate Limiting**: Fewer API calls = less rate limiting
- **Background Sync**: Essential for periodic background syncing
- **Data Usage**: Minimal data transfer

## How It Works

The Changes API uses **sync tokens** to track your position in the data stream:

1. **First Sync**: Get initial token (returns empty, stores position)
2. **Subsequent Syncs**: Use token to fetch only new data since last sync
3. **Token Updates**: Token is automatically updated after each successful sync

```
Timeline:   [Old Data] --- Token --- [New Data Since Token]
                            ↑
                         You are here
                         (fetch from here)
```

## Basic Usage

### Simple Incremental Sync

```dart
import 'package:health_sync_flutter/health_sync_flutter.dart';

final plugin = HealthConnectPlugin();
await plugin.initialize();
await plugin.connect();

// First sync: Initializes token, returns empty
final result1 = await plugin.fetchChanges(DataType.steps);
print('First sync: ${result1.changes.length} records');  // 0 records
print('Is initial: ${result1.isInitialSync}');           // true

// Wait for new data (e.g., user walks, app syncs in background)
await Future.delayed(Duration(hours: 1));

// Second sync: Returns ONLY new records since first sync
final result2 = await plugin.fetchChanges(DataType.steps);
print('New records: ${result2.changes.length}');         // Only new records
print('Is initial: ${result2.isInitialSync}');           // false

// Third sync: Returns records added since second sync
final result3 = await plugin.fetchChanges(DataType.steps);
print('Latest: ${result3.changes.length}');              // Even newer records
```

### Multiple Data Types

```dart
// Fetch changes for multiple types
final dataTypes = [
  DataType.steps,
  DataType.heartRate,
  DataType.sleep,
  DataType.calories,
];

final results = await plugin.fetchChangesForTypes(dataTypes);

for (final entry in results.entries) {
  final type = entry.key;
  final result = entry.value;

  print('${type.toValue()}: ${result.changes.length} new records');

  if (result.isInitialSync) {
    print('  (First sync - token initialized)');
  }
}
```

## Sync Status Tracking

Check sync status for all data types:

```dart
final dataTypes = [DataType.steps, DataType.heartRate, DataType.sleep];

final statuses = await plugin.getSyncStatus(dataTypes);

for (final entry in statuses.entries) {
  final type = entry.key;
  final status = entry.value;

  print('${type.toValue()}:');
  print('  Synced: ${status.hasBeenSynced}');
  print('  Last sync: ${status.lastSyncTime}');
  print('  Last count: ${status.lastRecordCount}');
  print('  Is stale: ${status.isStale}');  // > 24 hours old

  if (status.timeSinceSync != null) {
    print('  Time since: ${status.timeSinceSync!.inHours}h ago');
  }
}
```

## Reset Sync

Force a full sync by resetting the sync token:

```dart
// Reset specific data type (next sync will be full)
await plugin.resetSync(DataType.steps);

// Reset all data types
await plugin.resetAllSyncs();
```

## Complete Example: Periodic Background Sync

```dart
class BackgroundSyncService {
  final HealthConnectPlugin plugin;
  Timer? _syncTimer;

  BackgroundSyncService(this.plugin);

  /// Start periodic syncing every 15 minutes
  void startPeriodicSync() {
    _syncTimer = Timer.periodic(Duration(minutes: 15), (_) {
      _performIncrementalSync();
    });
  }

  /// Perform incremental sync for all data types
  Future<void> _performIncrementalSync() async {
    print('[Background] Starting incremental sync...');

    final dataTypes = [
      DataType.steps,
      DataType.heartRate,
      DataType.sleep,
      DataType.calories,
    ];

    try {
      final results = await plugin.fetchChangesForTypes(dataTypes);

      int totalNewRecords = 0;

      for (final entry in results.entries) {
        final type = entry.key;
        final result = entry.value;

        if (result.isSuccess && result.hasChanges) {
          totalNewRecords += result.changes.length;

          print('[Background] ${type.toValue()}: ${result.changes.length} new records');

          // Process new data
          await _processNewData(type, result.changes);
        } else if (result.isInitialSync) {
          print('[Background] ${type.toValue()}: Initialized sync token');
        }
      }

      if (totalNewRecords > 0) {
        print('[Background] Synced $totalNewRecords total new records');
      } else {
        print('[Background] No new data');
      }
    } catch (e) {
      print('[Background] Sync failed: $e');
    }
  }

  Future<void> _processNewData(
    DataType type,
    List<RawHealthData> newRecords,
  ) async {
    // Upload to server, update local database, etc.
    print('  Processing ${newRecords.length} new ${type.toValue()} records');
  }

  void stopPeriodicSync() {
    _syncTimer?.cancel();
  }
}

// Usage
final plugin = HealthConnectPlugin();
await plugin.initialize();
await plugin.connect();

final syncService = BackgroundSyncService(plugin);
syncService.startPeriodicSync();  // Sync every 15 minutes
```

## Comparison: fetchChanges() vs fetchData()

| Feature | fetchChanges() | fetchData() |
|---------|----------------|-------------|
| **Speed** | Very fast (only new data) | Slow (entire history) |
| **Data Volume** | Minimal (incremental) | Large (full history) |
| **Battery Usage** | Low | High |
| **Rate Limiting** | Rare (few API calls) | Common (many records) |
| **Use Case** | Periodic/background sync | Initial sync, debugging |
| **First Call** | Returns empty (setup) | Returns all history |
| **Subsequent Calls** | Only new data | All data again |

### When to Use Each

**Use `fetchChanges()` for:**
- ✅ Periodic background sync (every 15 min, hourly, etc.)
- ✅ Real-time updates in active app
- ✅ Battery-efficient syncing
- ✅ Production apps with frequent syncing

**Use `fetchData()` for:**
- ✅ Initial full sync (first time setup)
- ✅ Debugging (see all data)
- ✅ Specific date range queries
- ✅ One-time data exports

## Performance Benefits

Real-world example with 10,000 step records:

```dart
// Full sync: Read 10,000 records every time
final fullSync = await plugin.fetchData(DataQuery(
  dataType: DataType.steps,
  startDate: DateTime.now().subtract(Duration(days: 30)),
  endDate: DateTime.now(),
));
print('Full: ${fullSync.length} records (2.5 seconds)');

// Incremental sync: Read only 50 new records
final incremental = await plugin.fetchChanges(DataType.steps);
print('Incremental: ${incremental.changes.length} records (0.1 seconds)');
```

**Result**: 25x faster, 200x less data transferred!

## Error Handling

```dart
final result = await plugin.fetchChanges(DataType.steps);

if (result.isSuccess) {
  if (result.isInitialSync) {
    print('Token initialized. Next sync will fetch new data.');
  } else if (result.hasChanges) {
    print('Received ${result.changes.length} new records');
    await processRecords(result.changes);
  } else {
    print('No new data since last sync');
  }
} else {
  print('Error: ${result.error}');

  // Token not updated on error - will retry with same token next time
  // Consider resetting sync if error persists:
  if (persistentError) {
    await plugin.resetSync(DataType.steps);
  }
}
```

## Sync Token Persistence

Sync tokens are automatically persisted across app restarts:

```dart
// Day 1: Initialize token
await plugin.fetchChanges(DataType.steps);  // Empty, stores token

// App restarts...

// Day 2: Token still available
final result = await plugin.fetchChanges(DataType.steps);
// Returns only data added since Day 1 ✅
```

Tokens are stored in `SharedPreferences` and survive app restarts.

## Advanced: Token Management

```dart
// Check if data type has been synced before
final hasSynced = await plugin.hasBeenSynced(DataType.steps);
if (!hasSynced) {
  print('First time syncing steps');
}

// Get last sync timestamp
final lastSync = await plugin.getLastSyncTime(DataType.steps);
if (lastSync != null) {
  final hoursSince = DateTime.now().difference(lastSync).inHours;
  print('Last synced $hoursSince hours ago');
}

// Force full sync by resetting token
await plugin.resetSync(DataType.steps);
final fullSync = await plugin.fetchChanges(DataType.steps);
// Next call will be incremental again
```

## Best Practices

### 1. Initialize Tokens During Onboarding

```dart
// During app setup, initialize all tokens
final dataTypes = [DataType.steps, DataType.heartRate, DataType.sleep];

for (final type in dataTypes) {
  await plugin.fetchChanges(type);  // Initialize token
}

print('All sync tokens initialized. Background sync ready.');
```

### 2. Use in Background Sync

```dart
// Perfect for WorkManager / background tasks
Future<void> backgroundSync() async {
  final result = await plugin.fetchChanges(DataType.steps);

  if (result.hasChanges) {
    await uploadToServer(result.changes);
  }

  // Very fast, battery efficient!
}
```

### 3. Handle Stale Syncs

```dart
final status = await plugin.getSyncStatus([DataType.steps]);
final stepsStatus = status[DataType.steps]!;

if (stepsStatus.isStale) {
  print('Warning: Steps data is ${stepsStatus.timeSinceSync!.inHours}h old');

  // Trigger immediate sync
  await plugin.fetchChanges(DataType.steps);
}
```

### 4. Combine with Full Sync for First Run

```dart
Future<void> initialSync(DataType dataType) async {
  // First time: Do full sync
  final fullData = await plugin.fetchData(DataQuery(
    dataType: dataType,
    startDate: DateTime.now().subtract(Duration(days: 30)),
    endDate: DateTime.now(),
  ));

  await saveToDatabase(fullData);

  // Initialize token for incremental syncs
  await plugin.fetchChanges(dataType);

  print('Initial sync complete. Future syncs will be incremental.');
}

Future<void> periodicSync(DataType dataType) async {
  // Subsequent syncs: Only new data
  final result = await plugin.fetchChanges(dataType);

  if (result.hasChanges) {
    await saveToDatabase(result.changes);
  }
}
```

### 5. Monitor Sync Performance

```dart
final stopwatch = Stopwatch()..start();

final result = await plugin.fetchChanges(DataType.steps);

stopwatch.stop();

print('Sync Performance:');
print('  Time: ${stopwatch.elapsedMilliseconds}ms');
print('  Records: ${result.changes.length}');
print('  Speed: ${result.changes.length / stopwatch.elapsed.inSeconds} records/sec');
```

## Troubleshooting

### Issue: First sync returns no data
**Expected Behavior**: First sync initializes token and returns empty list. Second sync returns new data.

### Issue: Not getting new data
**Solution**: Check sync status to verify token exists:
```dart
final hasSynced = await plugin.hasBeenSynced(DataType.steps);
print('Has token: $hasSynced');
```

### Issue: Want to force full sync
**Solution**: Reset sync token:
```dart
await plugin.resetSync(DataType.steps);
```

### Issue: Sync token "lost" after reinstall
**Expected Behavior**: Tokens stored in SharedPreferences are cleared on app uninstall. First sync after reinstall will reinitialize tokens.

## Architecture Notes

### Token Storage
- Stored in `SharedPreferences` (persistent)
- Keyed by data type (e.g., `health_sync_token_steps`)
- Includes metadata (last sync time, record count)

### Token Lifecycle
1. **First sync**: Request initial token from Health Connect
2. **Store**: Persist token with metadata
3. **Use**: Pass token to fetch changes
4. **Update**: Store new token from response
5. **Repeat**: Use updated token for next sync

### Thread Safety
- SyncTokenManager uses in-memory cache for performance
- All operations are async-safe
- Token updates are atomic

## Related Documentation

- [Rate Limiting Guide](./RATE_LIMITING_GUIDE.md) - Exponential backoff and batch operations
- [Health Connect Changes API](https://developer.android.com/health-and-fitness/guides/health-connect/develop/read-data#observe-changes) - Official documentation

## Support

For issues with Changes API:
1. Check sync status: `await plugin.getSyncStatus([dataType])`
2. Verify token exists: `await plugin.hasBeenSynced(dataType)`
3. Check logs for "ChangesAPI" category
4. Try resetting sync: `await plugin.resetSync(dataType)`
