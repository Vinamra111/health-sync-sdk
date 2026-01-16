# health_sync_flutter

> Flutter plugin for HealthSync SDK - Health Connect integration with enterprise onboarding

[![pub.dev](https://img.shields.io/pub/v/health_sync_flutter)](https://pub.dev/packages/health_sync_flutter)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

## Features

- **Enterprise Onboarding System** - Handles Health Connect stub detection & update loop bugs
- **13+ Health Data Types** - Steps, heart rate, sleep, activity, and more
- **OEM Intelligence** - Built-in knowledge for 10+ manufacturers (Samsung, OnePlus, Xiaomi, etc.)
- **Native Step Tracking** - Detects Android 14/15 native step counting
- **Background Sync** - Device-specific optimization with retry strategies
- **117+ Tests** - Production-ready with comprehensive test coverage

## Installation

```yaml
dependencies:
  health_sync_flutter: ^1.0.1
```

```bash
flutter pub get
```

## Quick Start

```dart
import 'package:health_sync_flutter/health_sync_flutter.dart';

final plugin = HealthConnectPlugin();

// Check availability
final available = await plugin.isHealthConnectAvailable();

// Request permissions
final permissions = await plugin.requestPermissions([
  HealthPermission.readSteps,
  HealthPermission.readHeartRate,
]);

// Fetch data
final steps = await plugin.readStepData(
  startDate: DateTime.now().subtract(Duration(days: 7)),
  endDate: DateTime.now(),
);
```

## Onboarding System

Handle Health Connect "stub" reality on Android 14/15:

```dart
import 'package:health_sync_flutter/health_sync_flutter.dart';

final onboarding = HealthConnectOnboardingService();

// Start onboarding
onboarding.stateStream.listen((result) {
  switch (result.state) {
    case OnboardingState.checkingInstallation:
      // Show loading
      break;
    case OnboardingState.stubDetected:
      // Show "Update Health Connect" with device-specific instructions
      showUpdateDialog(result.userGuidance, result.playStoreUri);
      break;
    case OnboardingState.waitingForUpdate:
      // Show retry UI - handles 10s caching bug automatically
      break;
    case OnboardingState.complete:
      // Proceed to request permissions
      break;
    case OnboardingState.failed:
      // Show error with troubleshooting
      break;
  }
});

await onboarding.startOnboarding();
```

### Device Compatibility

| Manufacturer | Stub Risk | Update Loop Bug | Retry Strategy |
|--------------|-----------|-----------------|----------------|
| Nothing | 95% | Yes | 8 retries × 2s |
| OnePlus | 90% | Yes | 8 retries × 2s |
| Samsung | 40% | No | 5 retries × 1s |
| Google Pixel | <5% | No | 5 retries × 1s |

## Android Setup

### AndroidManifest.xml

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.health.READ_STEPS"/>
    <uses-permission android:name="android.permission.health.READ_HEART_RATE"/>
    <uses-permission android:name="android.permission.health.READ_SLEEP"/>
    <!-- Add permissions for other data types -->

    <queries>
        <package android:name="com.google.android.apps.healthdata" />
    </queries>

    <application>
        <activity android:name=".MainActivity">
            <!-- Health Connect intents -->
            <intent-filter>
                <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />
            </intent-filter>
        </activity>
    </application>
</manifest>
```

### build.gradle

```gradle
android {
    compileSdkVersion 36
    defaultConfig {
        minSdkVersion 26
        targetSdkVersion 36
    }
}
```

## Available Data Types

- Steps, Distance, Calories (Active & Total)
- Heart Rate, Resting Heart Rate, HRV
- Sleep (with stages)
- Exercise/Activity
- Blood Oxygen, Blood Pressure
- Body Temperature, Weight, Height

## Background Sync

```dart
import 'package:health_sync_flutter/health_sync_flutter.dart';

final syncService = BackgroundSyncService();

// Check device compatibility
final compatibility = await syncService.checkCompatibility();
print('Sync reliability: ${compatibility.level}'); // high/medium/low

// Setup background sync
await syncService.setupBackgroundSync(
  frequency: compatibility.recommendedSyncFrequency,
  requiresCharging: compatibility.shouldRequireCharging,
);
```

## Requirements

- Flutter SDK ≥ 3.0.0
- Android SDK 26+ (Android 8.0+)
- Kotlin 1.9+

## License

MIT - see [LICENSE](./LICENSE)

Copyright (c) 2025 HCL Healthcare Product Team

## Related Packages

- [`@healthsync/core`](https://www.npmjs.com/package/@healthsync/core) - Core TypeScript SDK
- [`@healthsync/react-native`](https://www.npmjs.com/package/@healthsync/react-native) - React Native integration

**[GitHub](https://github.com/Vinamra111/health-sync-sdk)** • **[Issues](https://github.com/Vinamra111/health-sync-sdk/issues)** • **[Pub.dev](https://pub.dev/packages/health_sync_flutter)**

---

Made with ❤️ by the HCL Healthcare Product Team
