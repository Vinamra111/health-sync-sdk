# @healthsync/react-native

> React Native Health Connect integration for HealthSync SDK

[![npm version](https://img.shields.io/npm/v/@healthsync/react-native)](https://www.npmjs.com/package/@healthsync/react-native)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

## Features

- Android Health Connect integration
- Permission management
- 13+ health data types (steps, heart rate, sleep, etc.)
- TypeScript support
- Battle-tested Kotlin implementation

## Installation

```bash
npm install @healthsync/react-native @healthsync/core
```

## Setup

### 1. MainActivity (Required)

```java
// android/app/src/main/java/com/yourapp/MainActivity.java
import com.facebook.react.ReactFragmentActivity;

public class MainActivity extends ReactFragmentActivity {
  @Override
  protected String getMainComponentName() {
    return "YourApp";
  }
}
```

### 2. AndroidManifest.xml

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Health Connect Check -->
    <queries>
        <package android:name="com.google.android.apps.healthdata" />
    </queries>

    <!-- Permissions -->
    <uses-permission android:name="android.permission.health.READ_STEPS"/>
    <uses-permission android:name="android.permission.health.READ_HEART_RATE"/>
    <uses-permission android:name="android.permission.health.READ_SLEEP"/>
    <!-- Add other permissions as needed -->

    <application>
        <activity android:name=".MainActivity">
            <!-- Permission Rationale -->
            <intent-filter>
                <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />
            </intent-filter>
        </activity>
    </application>
</manifest>
```

### 3. build.gradle

```gradle
android {
    compileSdkVersion 36
    defaultConfig {
        minSdkVersion 26
        targetSdkVersion 36
    }
}
```

## Usage

```typescript
import { HealthConnectPlugin, DataType } from '@healthsync/react-native';

const plugin = new HealthConnectPlugin();

// Initialize
await plugin.initialize({});
await plugin.connect();

// Request permissions
await plugin.requestPermissions([
  HealthConnectPermission.READ_STEPS,
  HealthConnectPermission.READ_HEART_RATE
]);

// Fetch data
const data = await plugin.fetchData({
  dataType: DataType.STEPS,
  startDate: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString(),
  endDate: new Date().toISOString(),
  limit: 100
});
```

## Requirements

- React Native ≥ 0.60.0
- Android SDK 26+ (Android 8.0+)
- Health Connect app installed

## License

MIT - see [LICENSE](./LICENSE)

Copyright (c) 2025 HCL Healthcare Product Team

**[GitHub](https://github.com/Vinamra111/health-sync-sdk)** • **[Issues](https://github.com/Vinamra111/health-sync-sdk/issues)**

---

Made with ❤️ by the HCL Healthcare Product Team
