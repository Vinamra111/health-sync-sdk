## Background Sync Guide

This guide explains how to use the HealthSync SDK's Background Sync feature for battery-efficient periodic syncing using Android WorkManager.

## Overview

Background Sync automatically syncs health data in the background at regular intervals, even when your app is closed. This is essential for:

- **Always-Current Data**: Keep health data synced 24/7
- **Battery Efficient**: Uses WorkManager for optimal scheduling
- **Incremental Updates**: Only fetches new data (via Changes API)
- **Constraint-Based**: Sync only when charging, on WiFi, etc.
- **Reliable**: Survives app restarts and device reboots

## How It Works

```
App Closed → WorkManager → Background Task → Sync Health Data → Store/Upload
     ↓          (System)        (Isolate)         (Changes API)      (Your logic)
  (Closed)    (Schedules)    (Runs in BG)      (Fast, efficient)
```

WorkManager guarantees your sync tasks run even if:
- App is closed
- Device reboots
- System is under memory pressure
- Battery saver is active

## Quick Start

### 1. Initialize in `main()`

```dart
import 'package:health_sync_flutter/health_sync_flutter.dart';

// Top-level dispatcher function (must be top-level, not in a class)
@pragma('vm:entry-point')
void backgroundSyncDispatcher() {
  backgroundSyncCallbackDispatcher();
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize background sync service
  backgroundSyncService.initialize(
    callbackDispatcher: backgroundSyncDispatcher,
    isInDebugMode: false,  // Set to true for detailed logs
  );

  runApp(MyApp());
}
```

### 2. Schedule Periodic Sync

```dart
// Schedule sync every 30 minutes
await backgroundSyncService.schedulePeriodicSync(
  config: BackgroundSyncConfig.balanced(
    dataTypes: [
      DataType.steps,
      DataType.heartRate,
      DataType.sleep,
      DataType.calories,
    ],
    frequency: Duration(minutes: 30),
  ),
);

print('Background sync scheduled!');
```

### 3. That's It!

Your app will now sync health data every 30 minutes in the background, even when closed.

## Configuration Presets

### Conservative (Best Battery Life)

```dart
// Syncs every 1 hour, only when charging + WiFi
await backgroundSyncService.schedulePeriodicSync(
  config: BackgroundSyncConfig.conservative(
    dataTypes: [DataType.steps, DataType.heartRate],
    frequency: Duration(hours: 1),
  ),
);
```

**Constraints:**
- Requires charging: ✅
- Requires WiFi: ✅
- Requires battery not low: ✅
- Uses incremental sync: ✅

### Balanced (Recommended)

```dart
// Syncs every 30 minutes, normal battery usage
await backgroundSyncService.schedulePeriodicSync(
  config: BackgroundSyncConfig.balanced(
    dataTypes: [DataType.steps, DataType.heartRate, DataType.sleep],
    frequency: Duration(minutes: 30),
  ),
);
```

**Constraints:**
- Requires charging: ❌
- Requires WiFi: ❌
- Requires battery not low: ✅
- Uses incremental sync: ✅

### Aggressive (Frequent Updates)

```dart
// Syncs every 15 minutes (minimum allowed), higher battery usage
await backgroundSyncService.schedulePeriodicSync(
  config: BackgroundSyncConfig.aggressive(
    dataTypes: [DataType.steps, DataType.heartRate, DataType.sleep, DataType.calories],
    frequency: Duration(minutes: 15),
  ),
);
```

**Constraints:**
- Requires charging: ❌
- Requires WiFi: ❌
- Requires battery not low: ❌
- Uses incremental sync: ✅

## Custom Configuration

```dart
await backgroundSyncService.schedulePeriodicSync(
  config: BackgroundSyncConfig(
    dataTypes: [DataType.steps, DataType.heartRate],
    frequency: Duration(minutes: 45),
    useIncrementalSync: true,         // Use Changes API (recommended)
    requiresCharging: false,           // Don't wait for charging
    requiresWiFi: true,                // Only sync on WiFi
    requiresDeviceIdle: false,         // Don't wait for idle
    requiresBatteryNotLow: true,       // Wait for battery > 15%
    requiresStorageNotLow: true,       // Wait for storage > 15%
    taskTag: 'myCustomSyncTask',       // Custom task identifier
  ),
);
```

## Frequency Constraints

**Minimum Frequency**: 15 minutes (Android restriction)

```dart
// ✅ Valid: 15 minutes or more
Duration(minutes: 15)  // OK
Duration(minutes: 30)  // OK
Duration(hours: 1)     // OK

// ❌ Invalid: Less than 15 minutes
Duration(minutes: 10)  // ERROR: Throws ArgumentError
Duration(minutes: 5)   // ERROR: Throws ArgumentError
```

**Note**: WorkManager doesn't guarantee exact timing. Actual sync may occur within a few minutes of scheduled time.

## Processing Synced Data

### Option 1: Custom Dispatcher (Recommended)

Create a custom dispatcher to process synced data:

```dart
@pragma('vm:entry-point')
void myCustomDispatcher() {
  createBackgroundSyncDispatcher(
    onSync: (dataType, records) async {
      // Called for each data type synced
      print('Synced ${dataType.toValue()}: ${records.length} records');

      // Upload to server
      await uploadToServer(dataType, records);

      // Or save to local database
      await saveToDatabase(dataType, records);
    },
    onComplete: (result) async {
      // Called when all data types complete
      print('Background sync completed!');
      print('Total records: ${result.totalRecords}');
      print('Duration: ${result.duration.inSeconds}s');

      // Send notification
      await showNotification('Synced ${result.totalRecords} records');
    },
    onFailed: (error) async {
      // Called if sync fails
      print('Sync failed: $error');
      await logError(error);
    },
  );
}

void main() {
  backgroundSyncService.initialize(
    callbackDispatcher: myCustomDispatcher,  // Use custom dispatcher
  );
  runApp(MyApp());
}
```

### Option 2: Handle in Config Callbacks

```dart
await backgroundSyncService.schedulePeriodicSync(
  config: BackgroundSyncConfig.balanced(
    dataTypes: [DataType.steps, DataType.heartRate],
    onDataSynced: (dataType, records) async {
      // Process each data type
      await uploadToServer(dataType, records);
    },
  ),
);
```

## Management

### Check if Scheduled

```dart
final isScheduled = await backgroundSyncService.isScheduled();
if (isScheduled) {
  print('Background sync is active');
} else {
  print('Background sync is not scheduled');
}
```

### Get Sync Info

```dart
final info = await backgroundSyncService.getSyncInfo();
if (info != null) {
  print('Scheduled: ${info.isScheduled}');
  print('Frequency: ${info.config.frequency.inMinutes} minutes');
  print('Data types: ${info.config.dataTypes.length}');
  print('Incremental: ${info.config.useIncrementalSync}');
}
```

### Update Configuration

```dart
// Cancel existing and schedule new
await backgroundSyncService.cancelPeriodicSync();

await backgroundSyncService.schedulePeriodicSync(
  config: BackgroundSyncConfig.aggressive(
    dataTypes: [DataType.steps, DataType.heartRate, DataType.sleep],
  ),
);
```

### Cancel Sync

```dart
// Cancel all background sync tasks
await backgroundSyncService.cancelPeriodicSync();

print('Background sync cancelled');
```

## One-Time Sync

For immediate background sync (not periodic):

```dart
// Sync now (or after delay)
await backgroundSyncService.scheduleOneTimeSync(
  config: BackgroundSyncConfig(
    dataTypes: [DataType.steps],
  ),
  delay: Duration(seconds: 5),  // Optional delay
);
```

Use cases:
- User manually triggers sync
- App detects stale data
- Response to push notification

## Complete Example

```dart
import 'package:flutter/material.dart';
import 'package:health_sync_flutter/health_sync_flutter.dart';

// Background dispatcher (must be top-level)
@pragma('vm:entry-point')
void myBackgroundDispatcher() {
  createBackgroundSyncDispatcher(
    onSync: (dataType, records) async {
      print('[Background] Synced ${dataType.toValue()}: ${records.length} records');

      // Your custom logic
      // - Upload to server
      // - Save to database
      // - Update analytics
    },
    onComplete: (result) async {
      print('[Background] Sync complete: ${result.totalRecords} records in ${result.duration.inSeconds}s');
    },
    onFailed: (error) async {
      print('[Background] Sync failed: $error');
    },
  );
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize background sync
  backgroundSyncService.initialize(
    callbackDispatcher: myBackgroundDispatcher,
    isInDebugMode: true,  // Enable debug logs
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isScheduled = false;

  @override
  void initState() {
    super.initState();
    _checkSyncStatus();
  }

  Future<void> _checkSyncStatus() async {
    final isScheduled = await backgroundSyncService.isScheduled();
    setState(() {
      _isScheduled = isScheduled;
    });
  }

  Future<void> _startBackgroundSync() async {
    await backgroundSyncService.schedulePeriodicSync(
      config: BackgroundSyncConfig.balanced(
        dataTypes: [
          DataType.steps,
          DataType.heartRate,
          DataType.sleep,
        ],
        frequency: Duration(minutes: 30),
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Background sync started (every 30 min)')),
    );

    await _checkSyncStatus();
  }

  Future<void> _stopBackgroundSync() async {
    await backgroundSyncService.cancelPeriodicSync();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Background sync stopped')),
    );

    await _checkSyncStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Background Sync Example'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Background Sync Status',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              _isScheduled ? '✓ Active' : '✗ Not Active',
              style: TextStyle(
                fontSize: 24,
                color: _isScheduled ? Colors.green : Colors.red,
              ),
            ),
            SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isScheduled ? null : _startBackgroundSync,
              child: Text('Start Background Sync'),
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: _isScheduled ? _stopBackgroundSync : null,
              child: Text('Stop Background Sync'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}
```

## Best Practices

### 1. Use Incremental Sync

```dart
// ✅ Good: Uses Changes API (fast, efficient)
BackgroundSyncConfig(
  useIncrementalSync: true,  // Default
  dataTypes: [DataType.steps],
)

// ❌ Bad: Full sync every time (slow, battery drain)
BackgroundSyncConfig(
  useIncrementalSync: false,
  dataTypes: [DataType.steps],
)
```

### 2. Choose Appropriate Frequency

```dart
// ✅ Good: Balance updates vs battery
Duration(minutes: 30)  // Balanced
Duration(hours: 1)     // Conservative

// ⚠ Caution: High battery usage
Duration(minutes: 15)  // Minimum allowed
```

### 3. Use Constraints Wisely

```dart
// ✅ Good: For non-critical data
BackgroundSyncConfig(
  requiresCharging: true,   // Only when charging
  requiresWiFi: true,       // Only on WiFi
)

// ✅ Good: For critical real-time data
BackgroundSyncConfig(
  requiresCharging: false,  // Anytime
  requiresBatteryNotLow: true,  // But not if battery low
)
```

### 4. Initialize Only Once

```dart
// ✅ Good: Initialize in main()
void main() {
  backgroundSyncService.initialize(...);
  runApp(MyApp());
}

// ❌ Bad: Don't initialize multiple times
void myFunction() {
  backgroundSyncService.initialize(...);  // ERROR: Already initialized
}
```

### 5. Handle Errors Gracefully

```dart
createBackgroundSyncDispatcher(
  onSync: (dataType, records) async {
    try {
      await uploadToServer(dataType, records);
    } catch (e) {
      // Don't throw - log and continue
      print('Upload failed: $e');
      await saveForLater(dataType, records);
    }
  },
  onFailed: (error) async {
    // Retry later or notify user
    await scheduleRetry();
  },
);
```

## Troubleshooting

### Issue: Background sync not running
**Solutions:**
1. Check battery optimization settings (disable for your app)
2. Verify frequency is ≥ 15 minutes
3. Check constraints (WiFi, charging, etc.)
4. Enable debug mode to see logs

### Issue: "Already initialized" error
**Solution:** Only call `initialize()` once in `main()`

### Issue: Dispatcher not called
**Solutions:**
1. Ensure dispatcher is top-level function (not class method)
2. Add `@pragma('vm:entry-point')` annotation
3. Check WorkManager logs in Logcat

### Issue: Sync stops after app update
**Expected:** WorkManager tasks survive updates. Re-schedule to be safe.

### Issue: High battery usage
**Solutions:**
1. Increase frequency (30 min → 1 hour)
2. Add constraints (requiresCharging, requiresWiFi)
3. Use incremental sync instead of full sync

## Debugging

### Enable Debug Mode

```dart
backgroundSyncService.initialize(
  callbackDispatcher: myDispatcher,
  isInDebugMode: true,  // Enable detailed logs
);
```

### View Logs in Android Studio

```
Logcat filter: "BackgroundSync"
```

### Test Background Sync

```dart
// Trigger immediate one-time sync for testing
await backgroundSyncService.scheduleOneTimeSync(
  config: BackgroundSyncConfig(
    dataTypes: [DataType.steps],
  ),
  delay: Duration(seconds: 5),
);
```

## Performance

| Configuration | Battery Impact | Update Frequency | Use Case |
|---------------|----------------|------------------|----------|
| **Conservative** | Minimal | Every 1-2 hours | Non-critical tracking |
| **Balanced** | Low | Every 30-45 min | Standard apps |
| **Aggressive** | Moderate | Every 15-20 min | Real-time tracking |

**Incremental vs Full Sync:**

| Metric | Incremental (Changes API) | Full Sync |
|--------|---------------------------|-----------|
| **Data Transfer** | Only new records | All records |
| **Battery Usage** | Minimal | High |
| **Time** | <1 second | 2-5 seconds |
| **Recommended** | ✅ Yes | ❌ Avoid |

## Android Configuration

WorkManager is automatically configured by the SDK. No additional AndroidManifest.xml changes needed.

## Related Documentation

- [Changes API Guide](./CHANGES_API_GUIDE.md) - Incremental syncing
- [Rate Limiting Guide](./RATE_LIMITING_GUIDE.md) - Exponential backoff
- [WorkManager Documentation](https://developer.android.com/topic/libraries/architecture/workmanager) - Official Android docs

## Support

For issues with background sync:
1. Check battery optimization settings
2. Verify constraints are met
3. Review WorkManager logs in Logcat
4. Enable debug mode for detailed logs
5. Test with one-time sync first
