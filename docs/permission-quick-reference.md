# Health Connect Permissions - Quick Reference

**Print this page for quick permission management**

---

## 📋 13 Health Connect Permissions

| Permission | Data Type | Manifest Declaration |
|------------|-----------|----------------------|
| `READ_STEPS` | Steps | `android.permission.health.READ_STEPS` |
| `READ_HEART_RATE` | Heart Rate | `android.permission.health.READ_HEART_RATE` |
| `READ_SLEEP` | Sleep | `android.permission.health.READ_SLEEP` |
| `READ_DISTANCE` | Distance | `android.permission.health.READ_DISTANCE` |
| `READ_EXERCISE` | Activity | `android.permission.health.READ_EXERCISE` |
| `READ_TOTAL_CALORIES_BURNED` | Calories | `android.permission.health.READ_TOTAL_CALORIES_BURNED` |
| `READ_ACTIVE_CALORIES_BURNED` | Active Cal | `android.permission.health.READ_ACTIVE_CALORIES_BURNED` |
| `READ_OXYGEN_SATURATION` | SpO2 | `android.permission.health.READ_OXYGEN_SATURATION` |
| `READ_BLOOD_PRESSURE` | BP | `android.permission.health.READ_BLOOD_PRESSURE` |
| `READ_BODY_TEMPERATURE` | Temp | `android.permission.health.READ_BODY_TEMPERATURE` |
| `READ_WEIGHT` | Weight | `android.permission.health.READ_WEIGHT` |
| `READ_HEIGHT` | Height | `android.permission.health.READ_HEIGHT` |
| `READ_HEART_RATE_VARIABILITY` | HRV | `android.permission.health.READ_HEART_RATE_VARIABILITY` |

---

## 🔧 AndroidManifest.xml Setup

**Add before `<application>`:**

```xml
<!-- Core permissions -->
<uses-permission android:name="android.permission.health.READ_STEPS"/>
<uses-permission android:name="android.permission.health.READ_HEART_RATE"/>
<uses-permission android:name="android.permission.health.READ_SLEEP"/>
<uses-permission android:name="android.permission.health.READ_DISTANCE"/>
<uses-permission android:name="android.permission.health.READ_EXERCISE"/>

<!-- Calorie permissions -->
<uses-permission android:name="android.permission.health.READ_TOTAL_CALORIES_BURNED"/>
<uses-permission android:name="android.permission.health.READ_ACTIVE_CALORIES_BURNED"/>

<!-- Vital signs -->
<uses-permission android:name="android.permission.health.READ_OXYGEN_SATURATION"/>
<uses-permission android:name="android.permission.health.READ_BLOOD_PRESSURE"/>
<uses-permission android:name="android.permission.health.READ_BODY_TEMPERATURE"/>
<uses-permission android:name="android.permission.health.READ_HEART_RATE_VARIABILITY"/>

<!-- Body metrics -->
<uses-permission android:name="android.permission.health.READ_WEIGHT"/>
<uses-permission android:name="android.permission.health.READ_HEIGHT"/>
```

**Add inside `<application>`:**

```xml
<activity-alias
    android:name="ViewPermissionUsageActivity"
    android:exported="true"
    android:targetActivity=".MainActivity"
    android:permission="android.permission.START_VIEW_PERMISSION_USAGE">
    <intent-filter>
        <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />
    </intent-filter>
</activity-alias>
```

---

## 📱 TypeScript Quick Examples

### Auto-Request on Connect

```typescript
import { HealthConnectPlugin } from 'health-sync-sdk';

const plugin = new HealthConnectPlugin({
  autoRequestPermissions: true,
});

await plugin.initialize();
const result = await plugin.connect(); // Shows permission dialog
```

### Manual Permission Request

```typescript
import { HealthConnectPermission } from 'health-sync-sdk';

// Request specific permissions
const granted = await plugin.requestPermissions([
  HealthConnectPermission.READ_STEPS,
  HealthConnectPermission.READ_HEART_RATE,
]);

console.log(`Granted: ${granted.length}`);
```

### Check Permission Status

```typescript
const statuses = await plugin.checkPermissions([
  HealthConnectPermission.READ_STEPS,
]);

if (statuses[0].granted) {
  // Fetch data
} else {
  // Request permission
  await plugin.requestPermissions([
    HealthConnectPermission.READ_STEPS,
  ]);
}
```

### Fetch with Error Handling

```typescript
import { HealthSyncAuthenticationError } from 'health-sync-sdk';

try {
  const data = await plugin.fetchData({
    dataType: DataType.STEPS,
    startDate: '2024-01-15T00:00:00Z',
    endDate: '2024-01-15T23:59:59Z',
  });
} catch (error) {
  if (error instanceof HealthSyncAuthenticationError) {
    // Permission denied - request it
    await plugin.requestPermissions([
      HealthConnectPermission.READ_STEPS,
    ]);
  }
}
```

---

## 📱 Flutter Quick Examples

### Auto-Request on Connect

```dart
import 'package:health_sync_flutter/health_sync_flutter.dart';

final healthConnect = HealthConnectPlugin(
  config: HealthConnectConfig(
    autoRequestPermissions: true,
  ),
);

await healthConnect.initialize();
final result = await healthConnect.connect(); // Shows permission dialog
```

### Manual Permission Request

```dart
final granted = await healthConnect.requestPermissions([
  HealthConnectPermission.readSteps,
  HealthConnectPermission.readHeartRate,
]);

print('Granted: ${granted.length}');
```

### Check Permission Status

```dart
final statuses = await healthConnect.checkPermissions([
  HealthConnectPermission.readSteps,
]);

if (statuses[0].granted) {
  // Fetch data
} else {
  // Request permission
  await healthConnect.requestPermissions([
    HealthConnectPermission.readSteps,
  ]);
}
```

### Fetch with Error Handling

```dart
try {
  final data = await healthConnect.fetchData(
    DataQuery(
      dataType: DataType.steps,
      startDate: DateTime.now().subtract(Duration(days: 7)),
      endDate: DateTime.now(),
    ),
  );
} on HealthSyncAuthenticationError catch (e) {
  // Permission denied - request it
  await healthConnect.requestPermissions([
    HealthConnectPermission.readSteps,
  ]);
}
```

---

## 🎯 Permission States

| State | Meaning | Action |
|-------|---------|--------|
| ✅ **Granted** | User approved | Can read data |
| ❌ **Denied** | User rejected | Request again or show rationale |
| ❓ **Not Determined** | Never asked | Request permission |

---

## 🔄 Permission Flow

```
1. Declare in AndroidManifest.xml
        ↓
2. Initialize plugin
        ↓
3. Connect (optional auto-request)
        ↓
4. Check permission status
        ↓
5. Request if needed
        ↓
6. Fetch data
```

---

## ✅ Best Practices

| ✅ DO | ❌ DON'T |
|-------|----------|
| Request just-in-time | Request all on startup |
| Provide clear rationale | Request without explanation |
| Handle denial gracefully | Break app if denied |
| Batch related permissions | Request one-by-one |
| Check before fetching | Assume permission granted |
| Cache permission status | Check every time |

---

## 🐛 Common Issues

| Issue | Solution |
|-------|----------|
| Dialog not showing | Check manifest, verify Health Connect installed |
| Permission denied after granting | Clear cache, check Health Connect app |
| "Missing permissions" error | Verify manifest declaration, check type map |
| Permissions lost after update | Re-request on app start |
| "Permanently denied" | Direct user to Health Connect settings |

---

## 📋 Permission Groups

### Basic Metrics
```typescript
[
  HealthConnectPermission.READ_STEPS,
  HealthConnectPermission.READ_HEART_RATE,
]
```

### Sleep
```typescript
[
  HealthConnectPermission.READ_SLEEP,
]
```

### Vitals
```typescript
[
  HealthConnectPermission.READ_BLOOD_PRESSURE,
  HealthConnectPermission.READ_OXYGEN_SATURATION,
  HealthConnectPermission.READ_BODY_TEMPERATURE,
  HealthConnectPermission.READ_HEART_RATE_VARIABILITY,
]
```

### Body Metrics
```typescript
[
  HealthConnectPermission.READ_WEIGHT,
  HealthConnectPermission.READ_HEIGHT,
]
```

---

## 🔍 Verification Commands

```bash
# Check permissions in manifest
cat android/app/src/main/AndroidManifest.xml | grep "health.READ"

# Check Health Connect availability (adb)
adb shell pm list packages | grep healthconnect

# Check app permissions (adb)
adb shell dumpsys package com.yourapp | grep "android.permission.health"
```

---

## 📚 TypeScript Permission Enum

```typescript
enum HealthConnectPermission {
  READ_STEPS = 'android.permission.health.READ_STEPS',
  READ_HEART_RATE = 'android.permission.health.READ_HEART_RATE',
  READ_SLEEP = 'android.permission.health.READ_SLEEP',
  READ_DISTANCE = 'android.permission.health.READ_DISTANCE',
  READ_EXERCISE = 'android.permission.health.READ_EXERCISE',
  READ_TOTAL_CALORIES_BURNED = 'android.permission.health.READ_TOTAL_CALORIES_BURNED',
  READ_ACTIVE_CALORIES_BURNED = 'android.permission.health.READ_ACTIVE_CALORIES_BURNED',
  READ_OXYGEN_SATURATION = 'android.permission.health.READ_OXYGEN_SATURATION',
  READ_BLOOD_PRESSURE = 'android.permission.health.READ_BLOOD_PRESSURE',
  READ_BODY_TEMPERATURE = 'android.permission.health.READ_BODY_TEMPERATURE',
  READ_WEIGHT = 'android.permission.health.READ_WEIGHT',
  READ_HEIGHT = 'android.permission.health.READ_HEIGHT',
  READ_HEART_RATE_VARIABILITY = 'android.permission.health.READ_HEART_RATE_VARIABILITY',
}
```

---

## 📚 Flutter Permission Enum

```dart
enum HealthConnectPermission {
  readSteps,
  readHeartRate,
  readSleep,
  readDistance,
  readExercise,
  readTotalCaloriesBurned,
  readActiveCaloriesBurned,
  readOxygenSaturation,
  readBloodPressure,
  readBodyTemperature,
  readWeight,
  readHeight,
  readHeartRateVariability,
}
```

---

## 🎯 Complete Example (TypeScript)

```typescript
import {
  HealthConnectPlugin,
  HealthConnectPermission,
  DataType,
  HealthSyncAuthenticationError,
} from 'health-sync-sdk';

async function setup() {
  // 1. Initialize
  const plugin = new HealthConnectPlugin({
    autoRequestPermissions: true,
  });
  await plugin.initialize();

  // 2. Connect (auto-requests)
  await plugin.connect();

  // 3. Check permissions
  const statuses = await plugin.checkPermissions([
    HealthConnectPermission.READ_STEPS,
  ]);

  // 4. Request if needed
  if (!statuses[0].granted) {
    await plugin.requestPermissions([
      HealthConnectPermission.READ_STEPS,
    ]);
  }

  // 5. Fetch data
  try {
    const data = await plugin.fetchData({
      dataType: DataType.STEPS,
      startDate: '2024-01-15T00:00:00Z',
      endDate: '2024-01-15T23:59:59Z',
    });
    console.log(`Fetched ${data.length} records`);
  } catch (error) {
    if (error instanceof HealthSyncAuthenticationError) {
      console.log('Permission denied');
    }
  }
}
```

---

## 🎯 Complete Example (Flutter)

```dart
import 'package:health_sync_flutter/health_sync_flutter.dart';

Future<void> setup() async {
  // 1. Initialize
  final healthConnect = HealthConnectPlugin(
    config: HealthConnectConfig(
      autoRequestPermissions: true,
    ),
  );
  await healthConnect.initialize();

  // 2. Connect (auto-requests)
  await healthConnect.connect();

  // 3. Check permissions
  final statuses = await healthConnect.checkPermissions([
    HealthConnectPermission.readSteps,
  ]);

  // 4. Request if needed
  if (!statuses[0].granted) {
    await healthConnect.requestPermissions([
      HealthConnectPermission.readSteps,
    ]);
  }

  // 5. Fetch data
  try {
    final data = await healthConnect.fetchData(
      DataQuery(
        dataType: DataType.steps,
        startDate: DateTime.now().subtract(Duration(days: 7)),
        endDate: DateTime.now(),
      ),
    );
    print('Fetched ${data.length} records');
  } on HealthSyncAuthenticationError catch (e) {
    print('Permission denied: $e');
  }
}
```

---

**Last Updated:** January 2026

**Full Documentation:** [Permission Request Flow Guide](permission-request-flow.md)
