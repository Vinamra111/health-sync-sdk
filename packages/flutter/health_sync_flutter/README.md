# health_sync_flutter

> Flutter plugin for HealthSync SDK - Universal health data integration with Health Connect support

[![pub package](https://img.shields.io/pub/v/health_sync_flutter.svg)](https://pub.dev/packages/health_sync_flutter)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue)](https://flutter.dev/)

## Features

✅ **Health Connect Onboarding** - Enterprise-grade onboarding system handling the "stub" reality
✅ **Android Health Connect Integration** - Full support for Health Connect API on Android 14+
✅ **Incremental Sync** - Changes API with automatic fallback to full sync
✅ **Aggregate Data** - Efficient aggregate queries with validation
✅ **Background Sync** - Reliable background synchronization with WorkManager
✅ **Conflict Resolution** - Automatic duplicate detection and conflict resolution
✅ **Type-Safe API** - Fully typed Dart API for health data
✅ **13+ Data Types** - Steps, heart rate, sleep, activity, and more
✅ **Device Optimization** - OEM-specific optimizations for 10+ manufacturers
✅ **100+ Tests** - Comprehensive test coverage

## 🎯 NEW: Health Connect Onboarding System

The package now includes an enterprise-grade onboarding system that handles the Health Connect "stub" reality on Android 14/15 devices. This system:

- **Detects Stub State**: Automatically identifies when Health Connect is a non-functional stub
- **Guides Updates**: Provides device-specific instructions for updating from Play Store
- **Handles Update Loop Bug**: Mitigates the 10-second status caching issue with retry logic
- **OEM Intelligence**: Built-in knowledge of 10+ manufacturers (Nothing, OnePlus, Samsung, etc.)
- **Native Step Tracking**: Detects Android 14/15 native step counting capability
- **Reactive UI**: Stream-based state management for real-time updates

### Quick Onboarding Example

```dart
import 'package:health_sync_flutter/src/onboarding/onboarding.dart';

final service = HealthConnectOnboardingService();

// Check and initialize with reactive streams
service.stateStream.listen((state) {
  print('Onboarding state: ${state.displayName}');
});

service.resultStream.listen((result) {
  if (result.requiresSdkUpdate) {
    // Show "Update Health Connect" button
    await service.openPlayStore();
  } else if (result.isComplete) {
    // Ready to use Health Connect!
  }
});

await service.checkAndInitialize(
  requiredPermissions: ['Steps', 'HeartRate'],
);
```

See [Onboarding Guide](#health-connect-onboarding) for complete documentation.

## Supported Data Types

- ✅ Steps
- ✅ Heart Rate
- ✅ Resting Heart Rate
- ✅ Sleep
- ✅ Activity/Exercise
- ✅ Calories
- ✅ Distance
- ✅ Blood Oxygen (SpO2)
- ✅ Blood Pressure
- ✅ Body Temperature
- ✅ Weight
- ✅ Height
- ✅ Heart Rate Variability (HRV)

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  health_sync_flutter: ^1.0.0
```

Run:

```bash
flutter pub get
```

## Android Setup

### 1. Update `android/app/build.gradle`

```gradle
android {
    compileSdkVersion 34 // Android 14

    defaultConfig {
        minSdkVersion 26  // Minimum for Health Connect
        targetSdkVersion 34
    }
}

dependencies {
    implementation "androidx.health.connect:connect-client:1.1.0-alpha07"
}
```

### 2. Add Permissions to `AndroidManifest.xml`

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Health Connect permissions -->
    <uses-permission android:name="android.permission.health.READ_STEPS"/>
    <uses-permission android:name="android.permission.health.READ_HEART_RATE"/>
    <uses-permission android:name="android.permission.health.READ_SLEEP"/>
    <uses-permission android:name="android.permission.health.READ_DISTANCE"/>
    <uses-permission android:name="android.permission.health.READ_EXERCISE"/>
    <uses-permission android:name="android.permission.health.READ_TOTAL_CALORIES_BURNED"/>
    <uses-permission android:name="android.permission.health.READ_ACTIVE_CALORIES_BURNED"/>
    <uses-permission android:name="android.permission.health.READ_OXYGEN_SATURATION"/>
    <uses-permission android:name="android.permission.health.READ_BLOOD_PRESSURE"/>
    <uses-permission android:name="android.permission.health.READ_BODY_TEMPERATURE"/>
    <uses-permission android:name="android.permission.health.READ_WEIGHT"/>
    <uses-permission android:name="android.permission.health.READ_HEIGHT"/>
    <uses-permission android:name="android.permission.health.READ_HEART_RATE_VARIABILITY"/>

    <application>
        <!-- Health Connect intent filter -->
        <activity-alias
            android:name="ViewPermissionUsageActivity"
            android:exported="true"
            android:targetActivity=".MainActivity"
            android:permission="android.permission.START_VIEW_PERMISSION_USAGE">
            <intent-filter>
                <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />
            </intent-filter>
        </activity-alias>
    </application>
</manifest>
```

## Usage

### Basic Example

```dart
import 'package:health_sync_flutter/health_sync_flutter.dart';

// Create plugin instance
final healthConnect = HealthConnectPlugin();

// Initialize
await healthConnect.initialize();

// Connect
final result = await healthConnect.connect();

if (result.success) {
  print('Connected!');

  // Fetch steps data
  final steps = await healthConnect.fetchData(
    DataQuery(
      dataType: DataType.steps,
      startDate: DateTime.now().subtract(Duration(days: 7)),
      endDate: DateTime.now(),
    ),
  );

  print('Fetched ${steps.length} step records');
}
```

### Complete Example

```dart
import 'package:flutter/material.dart';
import 'package:health_sync_flutter/health_sync_flutter.dart';

class HealthPage extends StatefulWidget {
  @override
  _HealthPageState createState() => _HealthPageState();
}

class _HealthPageState extends State<HealthPage> {
  final _healthConnect = HealthConnectPlugin(
    config: HealthConnectConfig(
      autoRequestPermissions: true,
      batchSize: 1000,
    ),
  );

  List<RawHealthData> _data = [];
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Initialize the plugin
      await _healthConnect.initialize();

      // Connect to Health Connect
      final result = await _healthConnect.connect();

      setState(() {
        _isConnected = result.success;
      });

      if (result.success) {
        _fetchHealthData();
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  Future<void> _fetchHealthData() async {
    try {
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: 7));

      final data = await _healthConnect.fetchData(
        DataQuery(
          dataType: DataType.steps,
          startDate: startDate,
          endDate: endDate,
          limit: 100,
        ),
      );

      setState(() {
        _data = data;
      });
    } catch (e) {
      if (e is HealthSyncAuthenticationError) {
        print('Permission error: $e');
        // Handle permission error
      } else if (e is HealthSyncConnectionError) {
        print('Connection error: $e');
        // Handle connection error
      } else {
        print('Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Health Data')),
      body: ListView.builder(
        itemCount: _data.length,
        itemBuilder: (context, index) {
          final record = _data[index];
          return ListTile(
            title: Text(record.sourceDataType),
            subtitle: Text(record.timestamp.toString()),
          );
        },
      ),
    );
  }
}
```

## API Reference

### HealthConnectPlugin

#### Constructor

```dart
HealthConnectPlugin({
  HealthConnectConfig? config,
})
```

#### Methods

**initialize()**
```dart
Future<void> initialize()
```
Initialize the plugin. Must be called before any other methods.

**connect()**
```dart
Future<ConnectionResult> connect()
```
Connect to Health Connect and request permissions if needed.

**disconnect()**
```dart
Future<void> disconnect()
```
Disconnect from Health Connect.

**isConnected()**
```dart
Future<bool> isConnected()
```
Check if currently connected.

**fetchData()**
```dart
Future<List<RawHealthData>> fetchData(DataQuery query)
```
Fetch health data based on the query parameters.

**checkPermissions()**
```dart
Future<List<PermissionStatus>> checkPermissions(
  List<HealthConnectPermission> permissions
)
```
Check status of specific permissions.

**requestPermissions()**
```dart
Future<List<HealthConnectPermission>> requestPermissions(
  List<HealthConnectPermission> permissions
)
```
Request specific permissions from the user.

### DataQuery

```dart
DataQuery({
  required DataType dataType,
  required DateTime startDate,
  required DateTime endDate,
  int? limit,
  int? offset,
})
```

### RawHealthData

```dart
class RawHealthData {
  final String sourceDataType;
  final HealthSource source;
  final DateTime timestamp;
  final DateTime? endTimestamp;
  final Map<String, dynamic> raw;
  final String? sourceId;
}
```

### Error Types

- `HealthSyncError` - Base error class
- `HealthSyncConnectionError` - Connection-related errors
- `HealthSyncAuthenticationError` - Permission/auth errors
- `HealthSyncDataFetchError` - Data fetching errors
- `HealthSyncConfigurationError` - Configuration errors

## Error Handling

```dart
try {
  final data = await healthConnect.fetchData(query);
} on HealthSyncConnectionError catch (e) {
  print('Not connected: $e');
  // Try reconnecting
  await healthConnect.connect();
} on HealthSyncAuthenticationError catch (e) {
  print('Permission denied: $e');
  // Request permissions
  await healthConnect.requestPermissions([...]);
} on HealthSyncDataFetchError catch (e) {
  print('Failed to fetch data: $e');
  // Handle fetch error
} catch (e) {
  print('Unknown error: $e');
}
```

## Pagination

```dart
Future<List<RawHealthData>> fetchAllData(DataType dataType) async {
  final allRecords = <RawHealthData>[];
  const pageSize = 100;
  var offset = 0;

  while (true) {
    final batch = await healthConnect.fetchData(
      DataQuery(
        dataType: dataType,
        startDate: startDate,
        endDate: endDate,
        limit: pageSize,
        offset: offset,
      ),
    );

    if (batch.isEmpty) break;

    allRecords.addAll(batch);
    offset += pageSize;
  }

  return allRecords;
}
```

## Platform Support

| Platform | Support |
|----------|---------|
| Android  | ✅ (14+) |
| iOS      | 🔜 Coming soon |
| Web      | ❌ |
| macOS    | ❌ |
| Windows  | ❌ |
| Linux    | ❌ |

## Health Connect Onboarding

The onboarding system handles the "stub" reality where Health Connect may be pre-installed as a non-functional placeholder on Android 14/15 devices.

### Complete Onboarding Example

```dart
import 'package:health_sync_flutter/src/onboarding/onboarding.dart';
import 'package:flutter/material.dart';

class HealthConnectOnboardingPage extends StatefulWidget {
  @override
  _HealthConnectOnboardingPageState createState() =>
      _HealthConnectOnboardingPageState();
}

class _HealthConnectOnboardingPageState
    extends State<HealthConnectOnboardingPage> {
  final _onboardingService = HealthConnectOnboardingService();
  OnboardingResult? _currentResult;

  @override
  void initState() {
    super.initState();

    // Listen to state and result streams
    _onboardingService.stateStream.listen((state) {
      print('State: ${state.displayName}');
    });

    _onboardingService.resultStream.listen((result) {
      setState(() => _currentResult = result);
    });

    // Start onboarding
    _checkAndInitialize();
  }

  Future<void> _checkAndInitialize() async {
    await _onboardingService.checkAndInitialize(
      requiredPermissions: ['Steps', 'HeartRate', 'Sleep'],
      checkNativeStepTracking: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentResult == null) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Health Connect Setup')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // State indicator
            Text(
              _currentResult!.state.displayName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 16),

            // Progress indicator
            LinearProgressIndicator(value: _currentResult!.progress),
            SizedBox(height: 24),

            // User guidance
            Text(
              _currentResult!.getStatusMessage(),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 32),

            // Action button
            if (_currentResult!.requiresUserAction) ...[
              ElevatedButton(
                onPressed: _handleAction,
                child: Text(_currentResult!.getActionLabel() ?? 'Continue'),
              ),
            ],

            // Diagnostic info (for debugging)
            if (_currentResult!.deviceProfile != null) ...[
              SizedBox(height: 24),
              ExpansionTile(
                title: Text('Device Info'),
                children: [
                  Text(_currentResult!.deviceProfile!.getSetupGuidance()),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction() async {
    if (_currentResult!.requiresSdkUpdate || _currentResult!.requiresSdkInstall) {
      // Open Play Store
      await _onboardingService.openPlayStore();

      // Wait for user to return and verify
      await _onboardingService.verifyAfterUpdate();
    } else if (_currentResult!.requiresPermissions) {
      // Request permissions
      await _onboardingService.requestPermissions(
        _currentResult!.requestedPermissions!,
      );
    } else if (_currentResult!.canRetry) {
      // Retry
      await _onboardingService.retryManually();
    }
  }

  @override
  void dispose() {
    _onboardingService.dispose();
    super.dispose();
  }
}
```

### Onboarding Features

#### Automatic Stub Detection
```dart
final service = HealthConnectOnboardingService();
final result = await service.checkAndInitialize();

if (result.requiresSdkUpdate) {
  // Health Connect is a stub - needs Play Store update
  print('Please update Health Connect');
  await service.openPlayStore();
}
```

#### Device-Specific Optimization
```dart
// Service automatically detects device manufacturer and optimizes
final deviceProfile = result.deviceProfile;

print('Manufacturer: ${deviceProfile?.manufacturer}');
print('Stub Risk: ${deviceProfile?.stubRiskLevel}');
print('Retry Strategy: ${deviceProfile?.recommendedRetryCount} attempts');

if (deviceProfile?.hasUpdateLoopBug == true) {
  print('This device has the update loop bug - will retry automatically');
}
```

#### Verification After Update
```dart
// After user updates Health Connect from Play Store
await service.openPlayStore();

// Verify with automatic retry (handles update loop bug)
final result = await service.verifyAfterUpdate(
  requiredPermissions: ['Steps', 'HeartRate'],
);

if (result.isSdkAvailable) {
  print('Health Connect is now ready!');
}
```

#### Native Step Tracking Detection
```dart
final result = await service.checkAndInitialize(
  checkNativeStepTracking: true,
);

if (result.deviceProfile?.hasNativeStepTracking == true) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Native Step Tracking Available'),
      content: Text(
        'Your device can track steps automatically without additional apps!'
      ),
    ),
  );
}
```

#### Diagnostic Reporting
```dart
// Get detailed diagnostic report
final report = await service.getDiagnosticReport();
print(report);

// Output includes:
// - SDK status and version
// - Device manufacturer and model
// - Stub risk assessment
// - Retry attempts and strategies
// - Permission status
// - Error messages (if any)
```

### Supported Manufacturers

The onboarding system has built-in intelligence for these manufacturers:

| Manufacturer | Stub Risk | Update Loop Bug | Retry Strategy |
|--------------|-----------|-----------------|----------------|
| Nothing | High (95%) | Yes | 8 retries × 2s |
| OnePlus | High (90%) | Yes | 8 retries × 2s |
| Motorola | High (85%) | No | 5 retries × 2s |
| Samsung | Medium (40%) | No | 5 retries × 1s |
| Xiaomi | Medium (45%) | No | 5 retries × 1s |
| Google Pixel | Low (<5%) | No | 5 retries × 1s |
| + 10 more... | | | |

## Requirements

- Flutter: >=3.0.0
- Dart: >=3.0.0
- Android: minSdkVersion 26, targetSdkVersion 34
- Health Connect app installed on device

## Troubleshooting

### "Health Connect not available"
- Ensure device is running Android 14+
- Install Health Connect from Play Store
- Check app has required permissions

### "Permission denied"
- Check AndroidManifest.xml has all required permissions
- Call `requestPermissions()` to show permission dialog
- Ensure user granted permissions in Health Connect app

### "No data returned"
- Verify Health Connect has data for the date range
- Check permissions are granted
- Ensure record type is correct

## Example App

See the [example](example/) directory for a complete working app.

## License

MIT License - see [LICENSE](./LICENSE) for details.

Copyright (c) 2025 HCL Healthcare Product Team

## Support

- **Documentation**: [GitHub](https://github.com/Vinamra111/health-sync-sdk/tree/main/packages/flutter/health_sync_flutter)
- **Issues**: [Report Issue](https://github.com/Vinamra111/health-sync-sdk/issues)
- **Pub.dev**: [Package Page](https://pub.dev/packages/health_sync_flutter)
- **Changelog**: [CHANGELOG.md](./CHANGELOG.md)

## Related Packages

- [`@healthsync/core`](https://www.npmjs.com/package/@healthsync/core) - Core TypeScript SDK
- [`@healthsync/react-native`](https://www.npmjs.com/package/@healthsync/react-native) - React Native integration

## Contributing

Contributions are welcome! Please read our [Contributing Guide](../../CONTRIBUTING.md) for details.

---

Made with ❤️ by the HCL Healthcare Product Team
