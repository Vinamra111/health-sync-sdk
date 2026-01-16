# Health Connect Permission Flow Diagrams

**Visual guide to permission request scenarios**

---

## Table of Contents

- [Auto-Request Flow](#auto-request-flow)
- [Manual Request Flow](#manual-request-flow)
- [Permission Denied Flow](#permission-denied-flow)
- [Just-In-Time Request Flow](#just-in-time-request-flow)
- [Multiple Data Types Flow](#multiple-data-types-flow)
- [Error Recovery Flow](#error-recovery-flow)
- [Settings Integration Flow](#settings-integration-flow)

---

## Auto-Request Flow

**Scenario:** App configured with `autoRequestPermissions: true`

```
┌────────────────────────────────────────────────────────────────┐
│                         App Startup                             │
└───────────────────────────┬────────────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────────────┐
│  const plugin = new HealthConnectPlugin({                      │
│    autoRequestPermissions: true                                │
│  });                                                           │
└───────────────────────────┬────────────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────────────┐
│  await plugin.initialize();                                    │
│  • Checks Health Connect availability                          │
│  • Initializes plugin state                                    │
└───────────────────────────┬────────────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────────────┐
│  await plugin.connect();                                       │
│  • Automatically requests all required permissions             │
│  • Shows system permission dialog                              │
└───────────────────────────┬────────────────────────────────────┘
                            │
                ┌───────────┴───────────┐
                │                       │
                ▼                       ▼
    ┌───────────────────┐   ┌───────────────────┐
    │  User Grants All  │   │  User Denies Some │
    └─────────┬─────────┘   └─────────┬─────────┘
              │                       │
              ▼                       ▼
┌────────────────────────┐ ┌────────────────────────┐
│ ConnectionResult       │ │ ConnectionResult       │
│ • success: true        │ │ • success: false       │
│ • message: "Connected" │ │ • message: "Denied"    │
└────────┬───────────────┘ └────────┬───────────────┘
         │                          │
         ▼                          ▼
┌─────────────────┐        ┌──────────────────────┐
│ Ready to Fetch  │        │ Request Permissions  │
│ Data            │        │ Manually             │
└─────────────────┘        └──────────────────────┘
```

**Code Example:**

```typescript
// Auto-request flow
const plugin = new HealthConnectPlugin({
  autoRequestPermissions: true,
});

await plugin.initialize();
const result = await plugin.connect();

if (result.success) {
  // All permissions granted - ready to fetch
  const data = await plugin.fetchData(query);
} else {
  // Some permissions denied - handle gracefully
  console.log('Permission issue:', result.message);
}
```

---

## Manual Request Flow

**Scenario:** App has full control over permission requests

```
┌────────────────────────────────────────────────────────────────┐
│                         App Startup                             │
└───────────────────────────┬────────────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────────────┐
│  const plugin = new HealthConnectPlugin({                      │
│    autoRequestPermissions: false  // Manual control            │
│  });                                                           │
└───────────────────────────┬────────────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────────────┐
│  await plugin.initialize();                                    │
└───────────────────────────┬────────────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────────────┐
│  await plugin.connect();                                       │
│  • Does NOT request permissions                                │
│  • Only checks Health Connect availability                     │
└───────────────────────────┬────────────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────────────┐
│  User Navigates to Feature                                     │
│  (e.g., "View My Steps")                                       │
└───────────────────────────┬────────────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────────────┐
│  const statuses = await plugin.checkPermissions([              │
│    HealthConnectPermission.READ_STEPS                          │
│  ]);                                                           │
└───────────────────────────┬────────────────────────────────────┘
                            │
                ┌───────────┴───────────┐
                │                       │
                ▼                       ▼
    ┌───────────────────┐   ┌───────────────────┐
    │  Already Granted  │   │  Not Granted      │
    └─────────┬─────────┘   └─────────┬─────────┘
              │                       │
              ▼                       ▼
    ┌──────────────┐     ┌──────────────────────────────┐
    │ Fetch Data   │     │ Show Rationale Dialog        │
    │              │     │ "We need steps to show..."   │
    └──────────────┘     └────────────┬─────────────────┘
                                      │
                                      ▼
                         ┌──────────────────────────────┐
                         │ await plugin.requestPermissions([│
                         │   HealthConnectPermission.READ_STEPS│
                         │ ]);                          │
                         └────────────┬─────────────────┘
                                      │
                         ┌────────────┴────────────┐
                         │                         │
                         ▼                         ▼
                 ┌──────────────┐         ┌──────────────┐
                 │ User Grants  │         │ User Denies  │
                 └──────┬───────┘         └──────┬───────┘
                        │                        │
                        ▼                        ▼
                ┌──────────────┐         ┌──────────────────┐
                │ Fetch Data   │         │ Show Alternative │
                │              │         │ UI/Message       │
                └──────────────┘         └──────────────────┘
```

**Code Example:**

```typescript
// Manual request flow
const plugin = new HealthConnectPlugin({
  autoRequestPermissions: false,
});

await plugin.initialize();
await plugin.connect();

// Later, when user clicks "View Steps"
async function viewSteps() {
  // 1. Check permission
  const statuses = await plugin.checkPermissions([
    HealthConnectPermission.READ_STEPS,
  ]);

  if (!statuses[0].granted) {
    // 2. Show rationale
    const shouldRequest = await showRationale(
      'We need access to your step data to show daily trends.'
    );

    if (!shouldRequest) {
      return; // User declined
    }

    // 3. Request permission
    const granted = await plugin.requestPermissions([
      HealthConnectPermission.READ_STEPS,
    ]);

    if (granted.length === 0) {
      // User denied - show alternative UI
      showDeniedMessage();
      return;
    }
  }

  // 4. Fetch data
  const data = await plugin.fetchData({
    dataType: DataType.STEPS,
    startDate: startDate,
    endDate: endDate,
  });

  displayData(data);
}
```

---

## Permission Denied Flow

**Scenario:** User denies permission - app handles gracefully

```
┌────────────────────────────────────────────────────────────────┐
│  User Clicks Feature Requiring Permission                      │
└───────────────────────────┬────────────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────────────┐
│  Check Permission Status                                       │
└───────────────────────────┬────────────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────────────┐
│  Permission Denied - Not Granted                               │
└───────────────────────────┬────────────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────────────┐
│  Show Rationale Dialog                                         │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │ Permission Needed                                        │ │
│  │                                                          │ │
│  │ We need steps data to:                                  │ │
│  │ • Track your daily activity                             │ │
│  │ • Show progress towards goals                           │ │
│  │ • Generate health insights                              │ │
│  │                                                          │ │
│  │         [Cancel]              [Grant Permission]        │ │
│  └──────────────────────────────────────────────────────────┘ │
└───────────────────────────┬────────────────────────────────────┘
                            │
                ┌───────────┴───────────┐
                │                       │
                ▼                       ▼
    ┌───────────────────┐   ┌───────────────────┐
    │  User Clicks      │   │  User Clicks      │
    │  "Cancel"         │   │  "Grant"          │
    └─────────┬─────────┘   └─────────┬─────────┘
              │                       │
              ▼                       ▼
┌──────────────────────┐  ┌──────────────────────┐
│ Show Alternative UI  │  │ Request Permission   │
│                      │  └─────────┬────────────┘
│ ┌──────────────────┐ │            │
│ │  Steps Data      │ │  ┌─────────┴──────────┐
│ │  Unavailable     │ │  │                    │
│ │                  │ │  ▼                    ▼
│ │  To enable:      │ │ ┌──────────┐  ┌──────────────┐
│ │  1. Open Settings│ │ │  Granted │  │  Denied      │
│ │  2. Allow access │ │ └────┬─────┘  └──────┬───────┘
│ │                  │ │      │                │
│ │  [Open Settings] │ │      ▼                ▼
│ └──────────────────┘ │ ┌────────┐    ┌──────────────┐
└──────────────────────┘ │ Fetch  │    │ Show Denied  │
                         │ Data   │    │ Message      │
                         └────────┘    │              │
                                       │ Retry Later  │
                                       └──────────────┘
```

**Code Example:**

```dart
Future<void> handleDeniedPermission() async {
  // Show rationale first
  final shouldRequest = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Permission Needed'),
      content: Text(
        'We need steps data to:\n'
        '• Track your daily activity\n'
        '• Show progress towards goals\n'
        '• Generate health insights'
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('Grant Permission'),
        ),
      ],
    ),
  );

  if (shouldRequest != true) {
    // User cancelled - show alternative UI
    showAlternativeUI();
    return;
  }

  // Request permission
  final granted = await healthConnect.requestPermissions([
    HealthConnectPermission.readSteps,
  ]);

  if (granted.isEmpty) {
    // Still denied - show how to enable in settings
    showDeniedDialog();
  } else {
    // Granted - fetch data
    fetchStepsData();
  }
}

void showAlternativeUI() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Steps Data Unavailable'),
      content: Text(
        'To enable step tracking:\n'
        '1. Open Health Connect settings\n'
        '2. Allow access to steps data'
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            // Open Health Connect settings
          },
          child: Text('Open Settings'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Later'),
        ),
      ],
    ),
  );
}
```

---

## Just-In-Time Request Flow

**Scenario:** Request permissions only when feature is accessed

```
┌────────────────────────────────────────────────────────────────┐
│                      App Home Screen                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │  View Steps  │  │ Heart Rate   │  │    Sleep     │         │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘         │
└─────────┼──────────────────┼──────────────────┼─────────────────┘
          │                  │                  │
          │ Click            │ Click            │ Click
          │                  │                  │
          ▼                  ▼                  ▼
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐
│ Steps Feature    │ │ Heart Rate       │ │ Sleep Feature    │
│                  │ │ Feature          │ │                  │
│ Check READ_STEPS │ │ Check READ_HR    │ │ Check READ_SLEEP │
└────────┬─────────┘ └────────┬─────────┘ └────────┬─────────┘
         │                    │                    │
         ▼                    ▼                    ▼
    ┌─────────┐          ┌─────────┐          ┌─────────┐
    │ Granted?│          │ Granted?│          │ Granted?│
    └────┬────┘          └────┬────┘          └────┬────┘
         │                    │                    │
    NO   │                NO  │                NO  │
         ▼                    ▼                    ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│ Request         │  │ Request         │  │ Request         │
│ READ_STEPS      │  │ READ_HEART_RATE │  │ READ_SLEEP      │
│                 │  │                 │  │                 │
│ "Show daily     │  │ "Monitor your   │  │ "Track sleep    │
│ activity"       │  │ heart health"   │  │ patterns"       │
└────────┬────────┘  └────────┬────────┘  └────────┬────────┘
         │                    │                    │
    Granted                Granted              Granted
         │                    │                    │
         ▼                    ▼                    ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│ Fetch & Display │  │ Fetch & Display │  │ Fetch & Display │
│ Steps Data      │  │ Heart Rate Data │  │ Sleep Data      │
└─────────────────┘  └─────────────────┘  └─────────────────┘

Benefits:
✅ User understands context
✅ Only requests what's needed
✅ Better approval rates
✅ Granular control
```

**Code Example:**

```typescript
// Just-in-time pattern
class HealthDataManager {
  private plugin: HealthConnectPlugin;

  async viewSteps() {
    await this.ensurePermissionAndFetch(
      HealthConnectPermission.READ_STEPS,
      DataType.STEPS,
      'Show your daily activity trends'
    );
  }

  async viewHeartRate() {
    await this.ensurePermissionAndFetch(
      HealthConnectPermission.READ_HEART_RATE,
      DataType.HEART_RATE,
      'Monitor your heart health'
    );
  }

  async viewSleep() {
    await this.ensurePermissionAndFetch(
      HealthConnectPermission.READ_SLEEP,
      DataType.SLEEP,
      'Track your sleep patterns'
    );
  }

  private async ensurePermissionAndFetch(
    permission: HealthConnectPermission,
    dataType: DataType,
    rationale: string,
  ) {
    // Check permission
    const statuses = await this.plugin.checkPermissions([permission]);

    if (!statuses[0].granted) {
      // Show rationale
      const shouldRequest = await this.showRationale(rationale);

      if (!shouldRequest) {
        return;
      }

      // Request permission
      const granted = await this.plugin.requestPermissions([permission]);

      if (granted.length === 0) {
        this.showDeniedMessage();
        return;
      }
    }

    // Fetch data
    const data = await this.plugin.fetchData({
      dataType,
      startDate: this.getStartDate(),
      endDate: new Date().toISOString(),
    });

    this.displayData(data);
  }
}
```

---

## Multiple Data Types Flow

**Scenario:** Feature requires multiple permissions

```
┌────────────────────────────────────────────────────────────────┐
│  User Clicks "View Workout Summary"                            │
│  (Requires: Steps, Heart Rate, Calories, Distance)             │
└───────────────────────────┬────────────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────────────┐
│  Check Multiple Permissions                                    │
│  • READ_STEPS                                                  │
│  • READ_HEART_RATE                                             │
│  • READ_TOTAL_CALORIES_BURNED                                  │
│  • READ_DISTANCE                                               │
└───────────────────────────┬────────────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────────────┐
│  Permission Status Check Results                               │
└───────────────────────────┬────────────────────────────────────┘
                            │
         ┌──────────────────┼──────────────────┐
         │                  │                  │
         ▼                  ▼                  ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│ All Granted     │ │ Some Granted    │ │ None Granted    │
└────────┬────────┘ └────────┬────────┘ └────────┬────────┘
         │                   │                   │
         │                   ▼                   │
         │      ┌───────────────────────┐        │
         │      │ Request Missing Only: │        │
         │      │ • READ_HEART_RATE     │        │
         │      │ • READ_DISTANCE       │        │
         │      └─────────┬─────────────┘        │
         │                │                      │
         └────────────────┼──────────────────────┘
                          │
                          ▼
         ┌────────────────────────────────┐
         │ Request Permissions (Batch)    │
         │                                │
         │ ┌────────────────────────────┐ │
         │ │ Grant Access To:           │ │
         │ │ ☑ Steps                    │ │
         │ │ ☑ Heart Rate               │ │
         │ │ ☑ Calories                 │ │
         │ │ ☑ Distance                 │ │
         │ │                            │ │
         │ │   [Deny]      [Allow]      │ │
         │ └────────────────────────────┘ │
         └────────────┬───────────────────┘
                      │
         ┌────────────┴────────────┐
         │                         │
         ▼                         ▼
┌─────────────────┐       ┌─────────────────┐
│ All Granted     │       │ Some Denied     │
└────────┬────────┘       └────────┬────────┘
         │                         │
         ▼                         ▼
┌──────────────────┐    ┌──────────────────────┐
│ Fetch All Data   │    │ Fetch Partial Data   │
│                  │    │                      │
│ • Steps: ✅      │    │ • Steps: ✅          │
│ • Heart Rate: ✅ │    │ • Heart Rate: ❌     │
│ • Calories: ✅   │    │ • Calories: ✅       │
│ • Distance: ✅   │    │ • Distance: ❌       │
│                  │    │                      │
│ Show Complete    │    │ Show Partial Summary │
│ Workout Summary  │    │ + "Grant more        │
│                  │    │   permissions"       │
└──────────────────┘    └──────────────────────┘
```

**Code Example:**

```typescript
async function showWorkoutSummary() {
  const requiredPermissions = [
    HealthConnectPermission.READ_STEPS,
    HealthConnectPermission.READ_HEART_RATE,
    HealthConnectPermission.READ_TOTAL_CALORIES_BURNED,
    HealthConnectPermission.READ_DISTANCE,
  ];

  // Check all permissions
  const statuses = await plugin.checkPermissions(requiredPermissions);

  // Separate granted and denied
  const granted = statuses.filter(s => s.granted);
  const denied = statuses.filter(s => !s.granted);

  // Request missing permissions
  if (denied.length > 0) {
    const newlyGranted = await plugin.requestPermissions(
      denied.map(s => s.permission)
    );

    if (newlyGranted.length < denied.length) {
      // Some still denied - show partial summary
      showPartialSummary(granted.map(s => s.permission));
      return;
    }
  }

  // Fetch all data types
  const [steps, heartRate, calories, distance] = await Promise.all([
    plugin.fetchData({ dataType: DataType.STEPS, ...dateRange }),
    plugin.fetchData({ dataType: DataType.HEART_RATE, ...dateRange }),
    plugin.fetchData({ dataType: DataType.CALORIES, ...dateRange }),
    plugin.fetchData({ dataType: DataType.DISTANCE, ...dateRange }),
  ]);

  // Display complete workout summary
  displayWorkoutSummary({ steps, heartRate, calories, distance });
}

function showPartialSummary(grantedPermissions: HealthConnectPermission[]) {
  // Fetch only granted data types
  const availableData = {};

  for (const permission of grantedPermissions) {
    const dataType = permissionToDataType(permission);
    availableData[dataType] = await plugin.fetchData({
      dataType,
      ...dateRange,
    });
  }

  // Show partial summary with upgrade prompt
  displayPartialSummary(availableData, {
    message: 'Grant more permissions for complete workout insights',
    onUpgrade: () => showWorkoutSummary(), // Retry
  });
}
```

---

## Error Recovery Flow

**Scenario:** Handle permission errors during data fetch

```
┌────────────────────────────────────────────────────────────────┐
│  Fetch Data Request                                            │
│  fetchData({ dataType: DataType.STEPS, ... })                 │
└───────────────────────────┬────────────────────────────────────┘
                            │
                            ▼
┌────────────────────────────────────────────────────────────────┐
│  Plugin Checks Permission Before Fetch                         │
└───────────────────────────┬────────────────────────────────────┘
                            │
                ┌───────────┴───────────┐
                │                       │
                ▼                       ▼
    ┌───────────────────┐   ┌───────────────────────────┐
    │  Permission OK    │   │  Permission Missing       │
    └─────────┬─────────┘   └─────────┬─────────────────┘
              │                       │
              ▼                       ▼
    ┌──────────────┐      ┌────────────────────────────┐
    │ Fetch Data   │      │ Throw AuthenticationError  │
    │ Success      │      │ "Missing permissions..."   │
    └──────┬───────┘      └─────────┬──────────────────┘
           │                        │
           ▼                        ▼
    ┌──────────────┐      ┌────────────────────────────┐
    │ Return Data  │      │ Catch in App Code          │
    └──────────────┘      └─────────┬──────────────────┘
                                    │
                                    ▼
                      ┌──────────────────────────────┐
                      │ Error Recovery Strategy      │
                      └──────────┬───────────────────┘
                                 │
         ┌───────────────────────┼───────────────────────┐
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│ Strategy 1:     │  │ Strategy 2:     │  │ Strategy 3:     │
│ Immediate       │  │ Show Rationale  │  │ Alternative UI  │
│ Request         │  │ Then Request    │  │ No Retry        │
└────────┬────────┘  └────────┬────────┘  └────────┬────────┘
         │                    │                    │
         ▼                    ▼                    ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│ Request         │  │ User Decides    │  │ Show Message:   │
│ Permission      │  │ To Grant        │  │ "Enable in      │
│ Automatically   │  │                 │  │  Settings"      │
└────────┬────────┘  └────────┬────────┘  └─────────────────┘
         │                    │
         │                    │
         └────────┬───────────┘
                  │
                  ▼
         ┌────────────────┐
         │ Retry Fetch    │
         └────────┬───────┘
                  │
      ┌───────────┴───────────┐
      │                       │
      ▼                       ▼
┌─────────────┐      ┌─────────────────┐
│ Success     │      │ Still Denied    │
│ Return Data │      │ Give Up         │
└─────────────┘      └─────────────────┘
```

**Code Example:**

```typescript
// Strategy 1: Immediate Request
async function fetchWithAutoRequest(query: DataQuery) {
  try {
    return await plugin.fetchData(query);
  } catch (error) {
    if (error instanceof HealthSyncAuthenticationError) {
      // Auto-request permission
      const permission = getPermissionForDataType(query.dataType);
      await plugin.requestPermissions([permission]);

      // Retry once
      return await plugin.fetchData(query);
    }
    throw error;
  }
}

// Strategy 2: Show Rationale First
async function fetchWithRationale(query: DataQuery) {
  try {
    return await plugin.fetchData(query);
  } catch (error) {
    if (error instanceof HealthSyncAuthenticationError) {
      // Show rationale dialog
      const shouldRequest = await showRationale(
        `We need ${query.dataType} data to show your health insights.`
      );

      if (shouldRequest) {
        const permission = getPermissionForDataType(query.dataType);
        await plugin.requestPermissions([permission]);

        // Retry
        return await plugin.fetchData(query);
      }
    }
    throw error;
  }
}

// Strategy 3: Alternative UI
async function fetchWithFallback(query: DataQuery) {
  try {
    return await plugin.fetchData(query);
  } catch (error) {
    if (error instanceof HealthSyncAuthenticationError) {
      // Don't retry - show alternative UI
      showAlternativeUI({
        message: `${query.dataType} data is unavailable`,
        action: 'Enable in Health Connect settings',
      });
      return [];
    }
    throw error;
  }
}
```

---

## Settings Integration Flow

**Scenario:** Permission management in app settings

```
┌────────────────────────────────────────────────────────────────┐
│                      App Settings Screen                        │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Health Permissions                                      │   │
│  │                                                         │   │
│  │ ☑ Steps                    [Granted]                   │   │
│  │ ☑ Heart Rate               [Granted]                   │   │
│  │ ☐ Sleep                    [Not Granted]  [Request]    │   │
│  │ ☐ Blood Pressure           [Not Granted]  [Request]    │   │
│  │ ☑ Distance                 [Granted]                   │   │
│  │                                                         │   │
│  │ [Refresh Status]  [Open Health Connect Settings]       │   │
│  └─────────────────────────────────────────────────────────┘   │
└───────────────────────────┬────────────────────────────────────┘
                            │
            ┌───────────────┼───────────────┐
            │               │               │
            ▼               ▼               ▼
  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
  │ User Clicks  │ │ User Clicks  │ │ User Clicks  │
  │ [Request]    │ │ [Refresh]    │ │ [Open HC]    │
  └──────┬───────┘ └──────┬───────┘ └──────┬───────┘
         │                │                │
         ▼                ▼                ▼
┌─────────────────┐ ┌──────────────┐ ┌────────────────┐
│ Request Single  │ │ Check All    │ │ Launch Health  │
│ Permission      │ │ Permissions  │ │ Connect App    │
└────────┬────────┘ └──────┬───────┘ └────────────────┘
         │                 │
         ▼                 ▼
┌─────────────────┐ ┌──────────────┐
│ Update UI       │ │ Update UI    │
│ Status          │ │ All Statuses │
└─────────────────┘ └──────────────┘

User Flow:
1. Navigate to Settings
2. See current permission status
3. Request missing permissions
4. Or open Health Connect to manage
5. Refresh to see updated status
```

**Code Example:**

```dart
class HealthPermissionsSettings extends StatefulWidget {
  @override
  _HealthPermissionsSettingsState createState() =>
      _HealthPermissionsSettingsState();
}

class _HealthPermissionsSettingsState
    extends State<HealthPermissionsSettings> {
  final _healthConnect = HealthConnectPlugin();
  Map<HealthConnectPermission, bool> _permissionStatus = {};

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    final allPermissions = HealthConnectPermission.values;
    final statuses = await _healthConnect.checkPermissions(allPermissions);

    setState(() {
      _permissionStatus = {
        for (var status in statuses)
          status.permission: status.granted
      };
    });
  }

  Future<void> _requestPermission(HealthConnectPermission permission) async {
    final granted = await _healthConnect.requestPermissions([permission]);

    setState(() {
      _permissionStatus[permission] = granted.contains(permission);
    });

    if (granted.isEmpty) {
      _showDeniedSnackBar(permission);
    }
  }

  void _openHealthConnect() {
    // Launch Health Connect app settings
    // Implementation depends on platform
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Health Permissions')),
      body: ListView(
        children: [
          // Group 1: Basic Metrics
          _buildSection('Basic Metrics', [
            HealthConnectPermission.readSteps,
            HealthConnectPermission.readHeartRate,
            HealthConnectPermission.readDistance,
          ]),

          // Group 2: Sleep
          _buildSection('Sleep', [
            HealthConnectPermission.readSleep,
          ]),

          // Group 3: Vitals
          _buildSection('Vitals', [
            HealthConnectPermission.readBloodPressure,
            HealthConnectPermission.readOxygenSaturation,
            HealthConnectPermission.readBodyTemperature,
          ]),

          // Actions
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: _loadPermissions,
                  child: Text('Refresh Status'),
                ),
                SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _openHealthConnect,
                  child: Text('Open Health Connect Settings'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<HealthConnectPermission> permissions) {
    return Card(
      margin: EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ...permissions.map((permission) {
            final granted = _permissionStatus[permission] ?? false;
            return ListTile(
              leading: Icon(
                granted ? Icons.check_circle : Icons.cancel,
                color: granted ? Colors.green : Colors.grey,
              ),
              title: Text(_getPermissionName(permission)),
              subtitle: Text(granted ? 'Granted' : 'Not Granted'),
              trailing: granted
                  ? null
                  : ElevatedButton(
                      onPressed: () => _requestPermission(permission),
                      child: Text('Request'),
                    ),
            );
          }).toList(),
        ],
      ),
    );
  }

  String _getPermissionName(HealthConnectPermission permission) {
    return permission.toString().split('.').last.replaceAll('read', '');
  }

  void _showDeniedSnackBar(HealthConnectPermission permission) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Permission denied. Enable in Health Connect settings.'),
        action: SnackBarAction(
          label: 'Open',
          onPressed: _openHealthConnect,
        ),
      ),
    );
  }
}
```

---

## Summary

### Permission Flow Patterns

| Pattern | When to Use | User Experience |
|---------|-------------|-----------------|
| **Auto-Request** | Simple apps with clear purpose | Shows dialog immediately on connect |
| **Manual Request** | Complex apps with multiple features | Full control over timing |
| **Just-In-Time** | Feature-rich apps | Permission per feature access |
| **Batch Request** | Related permissions | Single dialog for group |
| **Error Recovery** | Robust apps | Graceful permission denial handling |
| **Settings Integration** | All apps | Central permission management |

### Best Flow Selection

```
Simple App (1-2 data types)
└─► Auto-Request Flow

Complex App (many features)
└─► Manual + Just-In-Time Flow

Health Dashboard (all data types)
└─► Batch Request + Settings Flow

Critical Feature App
└─► Just-In-Time + Error Recovery Flow
```

---

**Related Documentation**:
- [Permission Request Flow Guide](permission-request-flow.md)
- [Permission Quick Reference](permission-quick-reference.md)
