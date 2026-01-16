# Health Connect Permission Request Flow

**Complete guide to permission management in HealthSync SDK**

---

## Table of Contents

- [Overview](#overview)
- [Permission Types](#permission-types)
- [Permission States](#permission-states)
- [TypeScript/JavaScript Flow](#typescriptjavascript-flow)
- [Flutter/Dart Flow](#flutterdart-flow)
- [Best Practices](#best-practices)
- [Common Patterns](#common-patterns)
- [Troubleshooting](#troubleshooting)

---

## Overview

Health Connect uses a permission-based system to protect user health data. Apps must:

1. **Declare permissions** in AndroidManifest.xml
2. **Request permissions** at runtime
3. **Check permission status** before accessing data
4. **Handle permission denial** gracefully

### Permission Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     App Initialization                       │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│              Check Health Connect Availability               │
│  • Not installed → Prompt user to install                   │
│  • Not supported → Show error                               │
│  • Installed → Continue                                      │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                  Connect to Health Connect                   │
│  Automatically checks and requests permissions               │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                   Check Permission Status                    │
│  • All granted → fetchData()                                │
│  • Some denied → Request specific permissions               │
│  • All denied → Show rationale and request                  │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                     Fetch Health Data                        │
│  Permission checked before each data type access             │
└─────────────────────────────────────────────────────────────┘
```

---

## Permission Types

Health Connect has **13 read permissions** for different data types:

### Core Permissions

| Permission | Data Type | Description |
|------------|-----------|-------------|
| `READ_STEPS` | Steps | Daily step count |
| `READ_HEART_RATE` | Heart Rate | Instantaneous heart rate |
| `READ_SLEEP` | Sleep | Sleep sessions and stages |
| `READ_DISTANCE` | Distance | Distance traveled |
| `READ_EXERCISE` | Activity/Exercise | Exercise sessions |

### Calorie Permissions

| Permission | Data Type | Description |
|------------|-----------|-------------|
| `READ_TOTAL_CALORIES_BURNED` | Calories (Total) | Total calories burned |
| `READ_ACTIVE_CALORIES_BURNED` | Calories (Active) | Active calories burned |

### Vital Signs Permissions

| Permission | Data Type | Description |
|------------|-----------|-------------|
| `READ_OXYGEN_SATURATION` | Blood Oxygen | SpO2 percentage |
| `READ_BLOOD_PRESSURE` | Blood Pressure | Systolic/diastolic pressure |
| `READ_BODY_TEMPERATURE` | Body Temperature | Temperature readings |
| `READ_HEART_RATE_VARIABILITY` | HRV | Heart rate variability |

### Body Metrics Permissions

| Permission | Data Type | Description |
|------------|-----------|-------------|
| `READ_WEIGHT` | Weight | Body weight measurements |
| `READ_HEIGHT` | Height | Height measurements |

---

## Permission States

Each permission can be in one of three states:

### 1. **Granted** ✅
- User has explicitly granted the permission
- App can read data of this type
- Permission persists until revoked by user

### 2. **Denied** ❌
- User has explicitly denied the permission
- App cannot read data of this type
- Can be requested again (user can change decision)

### 3. **Not Determined** ❓
- Permission has never been requested
- Initial state for all permissions
- First request will show permission dialog

---

## TypeScript/JavaScript Flow

### 1. Declare Permissions in AndroidManifest.xml

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Declare all permissions your app needs -->
    <uses-permission android:name="android.permission.health.READ_STEPS"/>
    <uses-permission android:name="android.permission.health.READ_HEART_RATE"/>
    <uses-permission android:name="android.permission.health.READ_SLEEP"/>
    <!-- Add more as needed -->

    <application>
        <!-- Activity alias for permission rationale -->
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

### 2. Initialize Plugin

```typescript
import { HealthConnectPlugin, HealthConnectConfig } from 'health-sync-sdk';

const plugin = new HealthConnectPlugin({
  autoRequestPermissions: true,  // Auto-request on connect()
  batchSize: 1000,
});

await plugin.initialize();
```

### 3. Connect (Auto-Request Permissions)

```typescript
const result = await plugin.connect();

if (result.success) {
  console.log('Connected with permissions');
  // Permissions have been requested and granted
} else {
  console.log('Connection failed:', result.message);
  // User denied permissions or Health Connect unavailable
}
```

### 4. Manual Permission Check

```typescript
import { HealthConnectPermission } from 'health-sync-sdk';

const statuses = await plugin.checkPermissions([
  HealthConnectPermission.READ_STEPS,
  HealthConnectPermission.READ_HEART_RATE,
]);

statuses.forEach(status => {
  console.log(`${status.permission}: ${status.granted ? 'granted' : 'denied'}`);
});
```

### 5. Manual Permission Request

```typescript
const granted = await plugin.requestPermissions([
  HealthConnectPermission.READ_STEPS,
  HealthConnectPermission.READ_HEART_RATE,
  HealthConnectPermission.READ_SLEEP,
]);

console.log(`Granted ${granted.length} permissions`);
```

### 6. Check Permission Before Data Fetch

```typescript
import { DataType, DataQuery } from 'health-sync-sdk';

try {
  const data = await plugin.fetchData({
    dataType: DataType.STEPS,
    startDate: '2024-01-15T00:00:00Z',
    endDate: '2024-01-15T23:59:59Z',
  });

  console.log(`Fetched ${data.length} records`);
} catch (error) {
  if (error instanceof HealthSyncAuthenticationError) {
    console.log('Permission denied for steps data');

    // Request permission and retry
    await plugin.requestPermissions([HealthConnectPermission.READ_STEPS]);
    const data = await plugin.fetchData(query);
  }
}
```

### Complete TypeScript Example

```typescript
import {
  HealthConnectPlugin,
  HealthConnectPermission,
  DataType,
  HealthSyncAuthenticationError,
} from 'health-sync-sdk';

async function setupHealthConnect() {
  const plugin = new HealthConnectPlugin({
    autoRequestPermissions: true,
  });

  // Step 1: Initialize
  await plugin.initialize();
  console.log('Plugin initialized');

  // Step 2: Connect (auto-requests permissions)
  const connectResult = await plugin.connect();

  if (!connectResult.success) {
    console.error('Failed to connect:', connectResult.message);
    return;
  }

  console.log('Connected to Health Connect');

  // Step 3: Check which permissions were granted
  const allPermissions = [
    HealthConnectPermission.READ_STEPS,
    HealthConnectPermission.READ_HEART_RATE,
    HealthConnectPermission.READ_SLEEP,
  ];

  const statuses = await plugin.checkPermissions(allPermissions);
  const granted = statuses.filter(s => s.granted);
  const denied = statuses.filter(s => !s.granted);

  console.log(`Granted: ${granted.length}/${allPermissions.length}`);

  // Step 4: Request denied permissions
  if (denied.length > 0) {
    console.log('Requesting additional permissions...');
    const newlyGranted = await plugin.requestPermissions(
      denied.map(s => s.permission)
    );
    console.log(`Granted ${newlyGranted.length} additional permissions`);
  }

  // Step 5: Fetch data with error handling
  try {
    const steps = await plugin.fetchData({
      dataType: DataType.STEPS,
      startDate: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString(),
      endDate: new Date().toISOString(),
    });

    console.log(`Fetched ${steps.length} step records`);
  } catch (error) {
    if (error instanceof HealthSyncAuthenticationError) {
      console.log('Steps permission denied. Please grant permission.');
    } else {
      console.error('Error fetching data:', error);
    }
  }
}

setupHealthConnect();
```

---

## Flutter/Dart Flow

### 1. Declare Permissions in AndroidManifest.xml

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
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

### 2. Initialize Plugin

```dart
import 'package:health_sync_flutter/health_sync_flutter.dart';

final healthConnect = HealthConnectPlugin(
  config: HealthConnectConfig(
    autoRequestPermissions: true,  // Auto-request on connect()
    batchSize: 1000,
  ),
);

await healthConnect.initialize();
```

### 3. Connect (Auto-Request Permissions)

```dart
final result = await healthConnect.connect();

if (result.success) {
  print('Connected with permissions');
} else {
  print('Connection failed: ${result.message}');
}
```

### 4. Manual Permission Check

```dart
final statuses = await healthConnect.checkPermissions([
  HealthConnectPermission.readSteps,
  HealthConnectPermission.readHeartRate,
  HealthConnectPermission.readSleep,
]);

for (var status in statuses) {
  print('${status.permission}: ${status.granted ? "granted" : "denied"}');
}
```

### 5. Manual Permission Request

```dart
final granted = await healthConnect.requestPermissions([
  HealthConnectPermission.readSteps,
  HealthConnectPermission.readHeartRate,
  HealthConnectPermission.readSleep,
]);

print('Granted ${granted.length} permissions');
```

### 6. Check Permission Before Data Fetch

```dart
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

  // Request permission and retry
  await healthConnect.requestPermissions([
    HealthConnectPermission.readSteps,
  ]);

  final data = await healthConnect.fetchData(query);
}
```

### Complete Flutter Example

```dart
import 'package:flutter/material.dart';
import 'package:health_sync_flutter/health_sync_flutter.dart';

class HealthPermissionsPage extends StatefulWidget {
  @override
  _HealthPermissionsPageState createState() => _HealthPermissionsPageState();
}

class _HealthPermissionsPageState extends State<HealthPermissionsPage> {
  final _healthConnect = HealthConnectPlugin(
    config: HealthConnectConfig(
      autoRequestPermissions: true,
    ),
  );

  Map<HealthConnectPermission, bool> _permissionStatus = {};
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _setupHealthConnect();
  }

  Future<void> _setupHealthConnect() async {
    try {
      // Step 1: Initialize
      await _healthConnect.initialize();
      print('Plugin initialized');

      // Step 2: Connect (auto-requests permissions)
      final connectResult = await _healthConnect.connect();

      setState(() {
        _isConnected = connectResult.success;
      });

      if (!connectResult.success) {
        _showError('Failed to connect: ${connectResult.message}');
        return;
      }

      // Step 3: Check permission status
      await _checkPermissions();
    } catch (e) {
      _showError('Setup error: $e');
    }
  }

  Future<void> _checkPermissions() async {
    final permissions = [
      HealthConnectPermission.readSteps,
      HealthConnectPermission.readHeartRate,
      HealthConnectPermission.readSleep,
      HealthConnectPermission.readDistance,
      HealthConnectPermission.readExercise,
    ];

    final statuses = await _healthConnect.checkPermissions(permissions);

    setState(() {
      _permissionStatus = {
        for (var status in statuses)
          status.permission: status.granted
      };
    });

    final granted = statuses.where((s) => s.granted).length;
    print('Granted: $granted/${permissions.length}');
  }

  Future<void> _requestPermission(HealthConnectPermission permission) async {
    try {
      final granted = await _healthConnect.requestPermissions([permission]);

      if (granted.contains(permission)) {
        setState(() {
          _permissionStatus[permission] = true;
        });
        _showSuccess('Permission granted');
      } else {
        _showError('Permission denied');
      }
    } catch (e) {
      _showError('Error requesting permission: $e');
    }
  }

  Future<void> _requestAllPermissions() async {
    final deniedPermissions = _permissionStatus.entries
        .where((e) => !e.value)
        .map((e) => e.key)
        .toList();

    if (deniedPermissions.isEmpty) {
      _showSuccess('All permissions already granted');
      return;
    }

    try {
      final granted = await _healthConnect.requestPermissions(deniedPermissions);

      setState(() {
        for (var permission in granted) {
          _permissionStatus[permission] = true;
        }
      });

      _showSuccess('Granted ${granted.length} permissions');
    } catch (e) {
      _showError('Error requesting permissions: $e');
    }
  }

  Future<void> _fetchData() async {
    if (!_isConnected) {
      _showError('Please connect first');
      return;
    }

    try {
      final data = await _healthConnect.fetchData(
        DataQuery(
          dataType: DataType.steps,
          startDate: DateTime.now().subtract(Duration(days: 7)),
          endDate: DateTime.now(),
        ),
      );

      _showSuccess('Fetched ${data.length} step records');
    } on HealthSyncAuthenticationError catch (e) {
      _showError('Permission denied: $e');

      // Offer to request permission
      final shouldRequest = await _showPermissionDialog();
      if (shouldRequest) {
        await _requestPermission(HealthConnectPermission.readSteps);
      }
    } catch (e) {
      _showError('Error fetching data: $e');
    }
  }

  Future<bool> _showPermissionDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Permission Required'),
        content: Text('Steps permission is required to fetch step data. Grant permission?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Grant'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Health Permissions'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection Status
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      _isConnected ? Icons.check_circle : Icons.cancel,
                      color: _isConnected ? Colors.green : Colors.grey,
                    ),
                    SizedBox(width: 8),
                    Text(
                      _isConnected ? 'Connected' : 'Not Connected',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Permission List
            Text(
              'Permissions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: _permissionStatus.entries.map((entry) {
                  return ListTile(
                    leading: Icon(
                      entry.value ? Icons.check_circle : Icons.cancel,
                      color: entry.value ? Colors.green : Colors.red,
                    ),
                    title: Text(entry.key.toString().split('.').last),
                    subtitle: Text(entry.value ? 'Granted' : 'Denied'),
                    trailing: entry.value
                        ? null
                        : ElevatedButton(
                            onPressed: () => _requestPermission(entry.key),
                            child: Text('Request'),
                          ),
                  );
                }).toList(),
              ),
            ),

            // Action Buttons
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _requestAllPermissions,
              child: Text('Request All Permissions'),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: _fetchData,
              child: Text('Fetch Steps Data'),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## Best Practices

### 1. Request Permissions Just-In-Time

**DON'T** request all permissions on app startup:
```dart
// ❌ Bad - Overwhelming for users
await plugin.requestPermissions([
  HealthConnectPermission.readSteps,
  HealthConnectPermission.readHeartRate,
  HealthConnectPermission.readSleep,
  // ... all 13 permissions
]);
```

**DO** request permissions when needed:
```dart
// ✅ Good - Only when user accesses the feature
void onViewStepsClicked() async {
  await plugin.requestPermissions([
    HealthConnectPermission.readSteps,
  ]);

  fetchStepsData();
}
```

### 2. Provide Clear Rationale

**DON'T** request permissions without context:
```dart
// ❌ Bad - No explanation
await plugin.requestPermissions([...]);
```

**DO** explain why you need permissions:
```dart
// ✅ Good - Clear rationale
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('Permission Needed'),
    content: Text(
      'We need access to your step data to show your daily activity trends '
      'and help you reach your fitness goals.'
    ),
    actions: [
      TextButton(
        onPressed: () async {
          Navigator.pop(context);
          await plugin.requestPermissions([
            HealthConnectPermission.readSteps,
          ]);
        },
        child: Text('Grant Permission'),
      ),
    ],
  ),
);
```

### 3. Handle Permission Denial Gracefully

```dart
try {
  final data = await plugin.fetchData(query);
} on HealthSyncAuthenticationError {
  // Show alternative UI or explanation
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Permission Required'),
      content: Text(
        'Step data is required for this feature. '
        'You can grant permission in Health Connect settings.'
      ),
      actions: [
        TextButton(
          onPressed: () => openHealthConnectSettings(),
          child: Text('Open Settings'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
      ],
    ),
  );
}
```

### 4. Use Auto-Request Wisely

```typescript
// For simple apps - auto-request is convenient
const plugin = new HealthConnectPlugin({
  autoRequestPermissions: true,  // ✅ Shows permission dialog on connect()
});

// For complex apps - manual control is better
const plugin = new HealthConnectPlugin({
  autoRequestPermissions: false,  // ✅ Manual control per feature
});

// Request only what you need
await plugin.requestPermissions([
  HealthConnectPermission.READ_STEPS,
]);
```

### 5. Check Permissions Before Fetching

```typescript
async function fetchStepsData() {
  // Always check first
  const statuses = await plugin.checkPermissions([
    HealthConnectPermission.READ_STEPS,
  ]);

  if (!statuses[0].granted) {
    // Request permission
    await plugin.requestPermissions([
      HealthConnectPermission.READ_STEPS,
    ]);
  }

  // Now safe to fetch
  const data = await plugin.fetchData({
    dataType: DataType.STEPS,
    startDate: startDate,
    endDate: endDate,
  });
}
```

### 6. Cache Permission Status

```typescript
class PermissionManager {
  private permissionCache = new Map<HealthConnectPermission, boolean>();
  private cacheExpiry = 5 * 60 * 1000; // 5 minutes
  private lastCheck = 0;

  async hasPermission(permission: HealthConnectPermission): Promise<boolean> {
    // Check cache first
    const now = Date.now();
    if (now - this.lastCheck < this.cacheExpiry) {
      const cached = this.permissionCache.get(permission);
      if (cached !== undefined) {
        return cached;
      }
    }

    // Check actual permission
    const statuses = await plugin.checkPermissions([permission]);
    const granted = statuses[0].granted;

    // Update cache
    this.permissionCache.set(permission, granted);
    this.lastCheck = now;

    return granted;
  }

  clearCache() {
    this.permissionCache.clear();
    this.lastCheck = 0;
  }
}
```

### 7. Batch Permission Requests

**DON'T** request one at a time:
```dart
// ❌ Bad - Shows 3 separate dialogs
await plugin.requestPermissions([HealthConnectPermission.readSteps]);
await plugin.requestPermissions([HealthConnectPermission.readHeartRate]);
await plugin.requestPermissions([HealthConnectPermission.readSleep]);
```

**DO** request related permissions together:
```dart
// ✅ Good - Single dialog with all related permissions
await plugin.requestPermissions([
  HealthConnectPermission.readSteps,
  HealthConnectPermission.readHeartRate,
  HealthConnectPermission.readSleep,
]);
```

---

## Common Patterns

### Pattern 1: Progressive Permission Request

Request permissions as user explores features:

```typescript
class HealthDataManager {
  private plugin: HealthConnectPlugin;

  async fetchSteps() {
    await this.ensurePermission(HealthConnectPermission.READ_STEPS);
    return await this.plugin.fetchData({
      dataType: DataType.STEPS,
      startDate: this.getStartDate(),
      endDate: new Date().toISOString(),
    });
  }

  async fetchHeartRate() {
    await this.ensurePermission(HealthConnectPermission.READ_HEART_RATE);
    return await this.plugin.fetchData({
      dataType: DataType.HEART_RATE,
      startDate: this.getStartDate(),
      endDate: new Date().toISOString(),
    });
  }

  private async ensurePermission(permission: HealthConnectPermission) {
    const statuses = await this.plugin.checkPermissions([permission]);

    if (!statuses[0].granted) {
      await this.plugin.requestPermissions([permission]);
    }
  }

  private getStartDate(): string {
    return new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();
  }
}
```

### Pattern 2: Permission Groups

Group related permissions:

```dart
class PermissionGroups {
  static const List<HealthConnectPermission> basic = [
    HealthConnectPermission.readSteps,
    HealthConnectPermission.readHeartRate,
  ];

  static const List<HealthConnectPermission> sleep = [
    HealthConnectPermission.readSleep,
  ];

  static const List<HealthConnectPermission> vitals = [
    HealthConnectPermission.readBloodPressure,
    HealthConnectPermission.readOxygenSaturation,
    HealthConnectPermission.readBodyTemperature,
  ];

  static const List<HealthConnectPermission> all = [
    ...basic,
    ...sleep,
    ...vitals,
  ];
}

// Usage
await healthConnect.requestPermissions(PermissionGroups.basic);
```

### Pattern 3: Permission Status UI

Show permission status in settings:

```dart
class PermissionSettingsWidget extends StatefulWidget {
  @override
  _PermissionSettingsWidgetState createState() =>
      _PermissionSettingsWidgetState();
}

class _PermissionSettingsWidgetState extends State<PermissionSettingsWidget> {
  Map<HealthConnectPermission, PermissionStatus> _statuses = {};

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final healthConnect = HealthConnectPlugin();

    final statuses = await healthConnect.checkPermissions(
      HealthConnectPermission.values,
    );

    setState(() {
      _statuses = {
        for (var status in statuses)
          status.permission: status
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        _buildPermissionSection('Basic Metrics', PermissionGroups.basic),
        _buildPermissionSection('Sleep', PermissionGroups.sleep),
        _buildPermissionSection('Vitals', PermissionGroups.vitals),
      ],
    );
  }

  Widget _buildPermissionSection(
    String title,
    List<HealthConnectPermission> permissions,
  ) {
    return Card(
      margin: EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ...permissions.map((permission) {
            final status = _statuses[permission];
            return SwitchListTile(
              title: Text(_getPermissionName(permission)),
              value: status?.granted ?? false,
              onChanged: (value) async {
                if (value) {
                  await _requestPermission(permission);
                } else {
                  _showRevokeDialog(permission);
                }
              },
            );
          }).toList(),
        ],
      ),
    );
  }

  Future<void> _requestPermission(HealthConnectPermission permission) async {
    final healthConnect = HealthConnectPlugin();
    await healthConnect.requestPermissions([permission]);
    await _loadPermissions();
  }

  void _showRevokeDialog(HealthConnectPermission permission) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Revoke Permission'),
        content: Text(
          'To revoke this permission, please open Health Connect settings.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Open Health Connect settings
            },
            child: Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  String _getPermissionName(HealthConnectPermission permission) {
    return permission.toString().split('.').last.replaceAll('read', '');
  }
}
```

### Pattern 4: Retry with Permission Request

```typescript
async function fetchDataWithRetry<T>(
  fetchFn: () => Promise<T>,
  requiredPermissions: HealthConnectPermission[],
  maxRetries: number = 1,
): Promise<T> {
  let retries = 0;

  while (retries <= maxRetries) {
    try {
      return await fetchFn();
    } catch (error) {
      if (error instanceof HealthSyncAuthenticationError && retries < maxRetries) {
        // Request permissions and retry
        await plugin.requestPermissions(requiredPermissions);
        retries++;
      } else {
        throw error;
      }
    }
  }

  throw new Error('Max retries exceeded');
}

// Usage
const steps = await fetchDataWithRetry(
  () => plugin.fetchData({
    dataType: DataType.STEPS,
    startDate: startDate,
    endDate: endDate,
  }),
  [HealthConnectPermission.READ_STEPS],
);
```

---

## Troubleshooting

### Issue 1: Permission Dialog Not Showing

**Problem**: `requestPermissions()` returns immediately without showing dialog

**Causes**:
- Permission not declared in AndroidManifest.xml
- Health Connect not installed
- Permission already granted/denied

**Solution**:
```typescript
// Check availability first
const availability = await plugin.checkAvailability();
if (availability !== HealthConnectAvailability.INSTALLED) {
  console.error('Health Connect not available:', availability);
  return;
}

// Verify permission is in manifest
const statuses = await plugin.checkPermissions([permission]);
console.log('Current status:', statuses[0]);

// Request permission
const granted = await plugin.requestPermissions([permission]);
console.log('Granted:', granted);
```

### Issue 2: Permission Denied After Granting

**Problem**: Permission shows as denied even after user granted it

**Causes**:
- Permission cache not updated
- Different permission requested than checked
- Health Connect app revoked permission

**Solution**:
```dart
// Force fresh check
final statuses = await healthConnect.checkPermissions(
  [HealthConnectPermission.readSteps],
);

print('Fresh status: ${statuses[0].granted}');

// If still denied, check Health Connect app settings
if (!statuses[0].granted) {
  // Open Health Connect to verify
  print('Please check Health Connect app permissions');
}
```

### Issue 3: "Missing permissions" Error

**Problem**: `AuthenticationError: Missing permissions for steps`

**Causes**:
- Permission not granted
- Permission not in AndroidManifest.xml
- Type map missing permission entry

**Solution**:
```typescript
// 1. Check manifest
// Ensure: <uses-permission android:name="android.permission.health.READ_STEPS"/>

// 2. Check permission status
const statuses = await plugin.checkPermissions([
  HealthConnectPermission.READ_STEPS,
]);

if (!statuses[0].granted) {
  // 3. Request permission
  await plugin.requestPermissions([
    HealthConnectPermission.READ_STEPS,
  ]);
}

// 4. Verify type map
import { HEALTH_CONNECT_TYPE_MAP } from 'health-sync-sdk';
console.log(HEALTH_CONNECT_TYPE_MAP[DataType.STEPS]);
// Should show: { recordType: 'Steps', permissions: ['READ_STEPS'] }
```

### Issue 4: Permissions Lost After App Update

**Problem**: Permissions need to be re-granted after app update

**Causes**:
- New permissions added to manifest
- compileSdkVersion or targetSdkVersion changed
- Health Connect app updated

**Solution**:
```typescript
// Check and re-request on app start
async function ensurePermissions() {
  const requiredPermissions = [
    HealthConnectPermission.READ_STEPS,
    HealthConnectPermission.READ_HEART_RATE,
    // ... all required permissions
  ];

  const statuses = await plugin.checkPermissions(requiredPermissions);
  const denied = statuses.filter(s => !s.granted);

  if (denied.length > 0) {
    console.log(`Re-requesting ${denied.length} permissions`);
    await plugin.requestPermissions(
      denied.map(s => s.permission)
    );
  }
}
```

### Issue 5: "Permission permanently denied"

**Problem**: User denied permission and selected "Don't ask again"

**Causes**:
- User denied permission multiple times
- User selected "Don't ask again" option

**Solution**:
```dart
// Can't request again - must direct to settings
void handlePermanentDenial() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Permission Required'),
      content: Text(
        'This permission was previously denied. '
        'Please enable it in Health Connect settings to use this feature.'
      ),
      actions: [
        TextButton(
          onPressed: () async {
            // Open Health Connect settings
            // await healthConnect.openSettings();
            Navigator.pop(context);
          },
          child: Text('Open Settings'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
      ],
    ),
  );
}
```

---

## Summary

### Key Takeaways

1. **Always declare permissions** in AndroidManifest.xml
2. **Request just-in-time** - only when feature is used
3. **Provide clear rationale** - explain why you need permission
4. **Handle denial gracefully** - show alternative UI or guide to settings
5. **Check before fetching** - verify permission before data access
6. **Batch related requests** - group permissions that go together
7. **Cache permission status** - avoid excessive checks

### Permission Flow Checklist

- [ ] Permissions declared in AndroidManifest.xml
- [ ] Activity alias configured for permission rationale
- [ ] Health Connect availability checked
- [ ] Plugin initialized before use
- [ ] Permissions requested at appropriate time
- [ ] Permission status checked before data fetch
- [ ] Authentication errors handled gracefully
- [ ] User can access settings to manage permissions
- [ ] Permission requests include clear rationale
- [ ] Denied permissions don't break app functionality

---

**Related Documentation**:
- [Flutter Installation Guide](flutter-installation-guide.md)
- [Health Connect Bridge Guide](health-connect-bridge-guide.md)
- [Flutter Plugin README](../packages/flutter/health_sync_flutter/README.md)
