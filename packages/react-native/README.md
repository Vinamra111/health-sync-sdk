# @healthsync/react-native

> React Native Health Connect integration for HealthSync SDK

[![npm version](https://img.shields.io/npm/v/@healthsync/react-native)](https://www.npmjs.com/package/@healthsync/react-native)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![React Native](https://img.shields.io/badge/React%20Native-0.60+-green)](https://reactnative.dev/)

## Features

- ✅ Android Health Connect integration
- ✅ Permission management
- ✅ Data fetching for 13+ health data types
- ✅ TypeScript support
- ✅ Reuses battle-tested Kotlin code from Flutter implementation

## Supported Data Types

- Steps
- Heart Rate
- Resting Heart Rate
- Sleep
- Activity/Exercise
- Calories (Active & Total)
- Distance
- Blood Oxygen
- Blood Pressure
- Body Temperature
- Weight
- Height
- Heart Rate Variability

## Installation

```bash
npm install @healthsync/react-native @healthsync/core
```

### Android Setup

#### 1. Update MainActivity

Your `MainActivity` **must** extend `ReactFragmentActivity`:

```java
// android/app/src/main/java/com/yourapp/MainActivity.java
import com.facebook.react.ReactFragmentActivity; // CHANGE THIS

public class MainActivity extends ReactFragmentActivity { // CHANGE THIS
  @Override
  protected String getMainComponentName() {
    return "YourApp";
  }
}
```

#### 2. Update AndroidManifest.xml

Add Health Connect permissions and configuration:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- Check whether Health Connect is installed -->
    <queries>
        <package android:name="com.google.android.apps.healthdata" />
        <intent>
            <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />
        </intent>
    </queries>

    <!-- Health Connect Permissions -->
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
        <activity android:name=".MainActivity">
            <!-- Main launcher -->
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>

            <!-- Health Connect permission rationale (Android 13 and below) -->
            <intent-filter>
                <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />
            </intent-filter>

            <!-- Health Connect permission usage (Android 14+) -->
            <intent-filter>
                <action android:name="android.intent.action.VIEW_PERMISSION_USAGE"/>
                <category android:name="android.intent.category.HEALTH_PERMISSIONS"/>
            </intent-filter>
        </activity>
    </application>
</manifest>
```

#### 3. Update build.gradle

Ensure your app's `android/app/build.gradle` has:

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

### Basic Example

```typescript
import React, { useEffect, useState } from 'react';
import { View, Button, Text } from 'react-native';
import {
  HealthConnectPlugin,
  DataType,
  HealthConnectPermission,
} from '@healthsync/react-native';

export default function App() {
  const [plugin] = useState(() => new HealthConnectPlugin());
  const [isConnected, setIsConnected] = useState(false);
  const [stepsData, setStepsData] = useState([]);

  useEffect(() => {
    initializePlugin();
  }, []);

  const initializePlugin = async () => {
    try {
      await plugin.initialize({});
      const result = await plugin.connect();
      setIsConnected(result.success);
    } catch (error) {
      console.error('Failed to initialize:', error);
    }
  };

  const requestPermissions = async () => {
    try {
      const granted = await plugin.requestPermissions([
        HealthConnectPermission.READ_STEPS,
        HealthConnectPermission.READ_HEART_RATE,
        HealthConnectPermission.READ_SLEEP,
      ]);
      console.log('Granted permissions:', granted);
    } catch (error) {
      console.error('Permission request failed:', error);
    }
  };

  const fetchSteps = async () => {
    try {
      const endDate = new Date();
      const startDate = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000); // Last 7 days

      const data = await plugin.fetchData({
        dataType: DataType.STEPS,
        startDate: startDate.toISOString(),
        endDate: endDate.toISOString(),
        limit: 100,
      });

      setStepsData(data);
      console.log('Steps data:', data);
    } catch (error) {
      console.error('Failed to fetch steps:', error);
    }
  };

  return (
    <View style={{ padding: 20 }}>
      <Text>Status: {isConnected ? 'Connected' : 'Disconnected'}</Text>

      <Button title="Request Permissions" onPress={requestPermissions} />
      <Button title="Fetch Steps" onPress={fetchSteps} />

      <Text>Steps records: {stepsData.length}</Text>
    </View>
  );
}
```

### With HealthSync SDK

```typescript
import { HealthSyncSDK } from '@healthsync/core';
import { HealthConnectPlugin, DataType } from '@healthsync/react-native';

const sdk = new HealthSyncSDK();
const healthConnect = new HealthConnectPlugin();

// Register plugin
await sdk.registerPlugin(healthConnect);

// Connect and fetch data
await healthConnect.connect();

const normalizedData = await sdk.fetchData({
  dataType: DataType.STEPS,
  startDate: startDate.toISOString(),
  endDate: endDate.toISOString(),
});

// Data is automatically normalized to UnifiedHealthData format
console.log(normalizedData);
```

## Important Notes

### MainActivity Must Extend ReactFragmentActivity

The permission request uses `ActivityResultLauncher` which requires `ComponentActivity`. If your MainActivity doesn't extend `ReactFragmentActivity`, you'll get this error:

```
Activity must extend ComponentActivity. Ensure MainActivity extends ReactFragmentActivity.
```

### Date Formatting

The plugin automatically handles timezone formatting. JavaScript `Date.toISOString()` always includes the 'Z' timezone suffix, which is required by Kotlin's `Instant.parse()`:

```typescript
// ✅ CORRECT - toISOString() automatically includes 'Z'
const date = new Date();
const isoString = date.toISOString(); // "2025-12-31T15:53:13.406Z"

// This matches our Flutter v2.1 fix
```

## API

### HealthConnectPlugin

#### Methods

- `initialize(config)` - Initialize the plugin
- `connect()` - Connect to Health Connect
- `disconnect()` - Disconnect
- `isConnected()` - Check connection status
- `fetchData(query)` - Fetch health data
- `checkPermissions(permissions)` - Check permission status (via bridge)
- `requestPermissions(permissions)` - Request permissions (via bridge)

### Permissions

Use `HealthConnectPermission` enum:

```typescript
HealthConnectPermission.READ_STEPS
HealthConnectPermission.READ_HEART_RATE
HealthConnectPermission.READ_SLEEP
HealthConnectPermission.READ_DISTANCE
HealthConnectPermission.READ_EXERCISE
// ... and more
```

## Requirements

- React Native >= 0.60.0
- Android minSdkVersion 26 (Android 8.0+)
- Android compileSdkVersion 36
- Health Connect app installed on device

## License

MIT License - see [LICENSE](./LICENSE) for details.

Copyright (c) 2025 HCL Healthcare Product Team

## Support

- **Documentation**: [GitHub](https://github.com/Vinamra111/health-sync-sdk/tree/main/packages/react-native)
- **Issues**: [Report Issue](https://github.com/Vinamra111/health-sync-sdk/issues)
- **Changelog**: [CHANGELOG.md](./CHANGELOG.md)

## Related Packages

- [`@healthsync/core`](https://www.npmjs.com/package/@healthsync/core) - Core SDK with data normalization
- [`health_sync_flutter`](https://pub.dev/packages/health_sync_flutter) - Flutter Health Connect plugin

---

Made with ❤️ by the HCL Healthcare Product Team
