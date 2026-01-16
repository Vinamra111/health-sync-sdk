# Conflict Detection Guide: Double-Count Detector

This guide explains how to use the HealthSync SDK's Conflict Detector to identify and resolve double-counting issues from multiple data sources.

## Overview

The Conflict Detector identifies when multiple apps (Samsung Health, Google Fit, Fitbit, etc.) are writing the same health data to Health Connect, which can cause:

- **Inflated Counts**: Steps/calories counted multiple times
- **Sync Loops**: Apps copying data back and forth infinitely
- **Inaccurate Analytics**: Dashboards showing 2x-3x actual values
- **User Confusion**: "Why do I have 40,000 steps today?"

## The Problem

**Scenario**: User has both Samsung Health and Google Fit installed

```
Samsung Health: Tracks 10,000 steps
       ↓
Health Connect: Stores 10,000 steps
       ↓
Google Fit: Reads 10,000 steps, writes them back
       ↓
Health Connect: Now has 20,000 steps (DUPLICATE!)
       ↓
Samsung Health: Reads 20,000 steps, writes them back
       ↓
Health Connect: Now has 30,000 steps (SYNC LOOP!)
```

**Result**: User sees 30,000+ steps instead of actual 10,000 steps.

## The Solution

The Conflict Detector:
1. Analyzes which apps are writing data
2. Calculates conflict severity
3. Provides actionable recommendations
4. Alerts users to disable duplicate trackers

## Quick Start

### Detect Conflicts for One Data Type

```dart
import 'package:health_sync_flutter/health_sync_flutter.dart';

final plugin = HealthConnectPlugin();
await plugin.initialize();
await plugin.connect();

// Detect conflicts for steps data
final result = await plugin.detectConflicts(
  dataType: DataType.steps,
  startTime: DateTime.now().subtract(Duration(days: 7)),
  endTime: DateTime.now(),
);

if (result.hasConflicts) {
  print('⚠ WARNING: Multiple apps detected!');
  print('Sources: ${result.sources.map((s) => s.displayName).join(", ")}');
  print('Recommendation: ${result.conflicts.first.recommendation}');

  // Show warning to user
  showWarningDialog(result);
}
```

### Detect Conflicts for Multiple Types

```dart
// Check multiple data types at once
final summary = await plugin.detectConflictsForTypes(
  dataTypes: [
    DataType.steps,
    DataType.heartRate,
    DataType.sleep,
    DataType.calories,
  ],
);

print('Total conflicts: ${summary.totalConflicts}');

if (summary.hasHighSeverityConflicts) {
  print('⚠ HIGH RISK: ${summary.allHighSeverityConflicts.length} critical conflicts');

  for (final conflict in summary.allHighSeverityConflicts) {
    print('${conflict.dataType.toValue()}: ${conflict.recommendation}');
  }
}
```

## Understanding Results

### Data Source Info

```dart
for (final source in result.sources) {
  print('App: ${source.displayName}');
  print('  Records: ${source.recordCount}');
  print('  Percentage: ${source.percentage.toStringAsFixed(1)}%');
  print('  System App: ${source.isSystemApp}');
  print('  Device: ${source.deviceModel}');
}
```

**Example Output:**
```
App: Samsung Health
  Records: 5,234
  Percentage: 55.2%
  System App: true
  Device: Galaxy S23

App: Google Fit
  Records: 4,245
  Percentage: 44.8%
  System App: true
  Device: Galaxy S23
```

### Conflict Types

| Type | Description | Example |
|------|-------------|---------|
| **multipleWriters** | Multiple apps tracking same data | Samsung Health + Google Fit both tracking steps |
| **syncLoop** | Apps copying data back and forth | Similar record counts (90%+ match) across sources |
| **multipleDevices** | Same app on multiple devices | Google Fit on phone + watch |
| **manualVsAutomatic** | Manual entries competing with auto-tracking | User logs steps, watch also tracks |

```dart
switch (conflict.type) {
  case ConflictType.multipleWriters:
    print('Multiple apps are tracking ${dataType.toValue()}');
    break;
  case ConflictType.syncLoop:
    print('CRITICAL: Sync loop detected! Data being duplicated');
    break;
  case ConflictType.multipleDevices:
    print('Same app running on multiple devices');
    break;
  case ConflictType.manualVsAutomatic:
    print('Manual entries conflict with automatic tracking');
    break;
}
```

### Severity Levels

| Severity | Range | Meaning | Action Required |
|----------|-------|---------|-----------------|
| **HIGH** | 0.7 - 1.0 | Critical conflict, likely sync loop | Immediate action required |
| **MEDIUM** | 0.4 - 0.7 | Significant overlap, definite double-counting | User should be warned |
| **LOW** | 0.0 - 0.4 | Minor overlap, may be intentional | Monitor but no action needed |

```dart
if (conflict.isHighSeverity) {
  showCriticalAlert('Multiple apps causing sync loop!');
} else if (conflict.isMediumSeverity) {
  showWarning('Multiple apps may cause double-counting');
} else if (conflict.isLowSeverity) {
  logInfo('Minor conflict detected, monitoring...');
}
```

## User Warnings

### Generate Warning Message

```dart
final warning = HealthConnectPlugin.getConflictWarning(result);
print(warning);
```

**Example Warnings:**

**High Severity:**
```
⚠️ HIGH RISK: Multiple apps (Samsung Health, Google Fit, Fitbit) are writing
steps data. This may cause significantly inflated counts and sync loops.
```

**Medium Severity:**
```
⚠️ WARNING: Multiple apps (Samsung Health, Google Fit) are writing steps data.
This may cause double-counting.
```

**Low Severity:**
```
ℹ️ INFO: Multiple apps detected but conflict severity is low.
```

### Show Warning Dialog

```dart
if (result.hasConflicts) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('⚠ Multiple Tracking Apps Detected'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(HealthConnectPlugin.getConflictWarning(result)),
          SizedBox(height: 16),
          Text('Apps detected:'),
          ...result.sources.map((s) =>
            Text('• ${s.displayName} (${s.recordCount} records)')
          ),
          SizedBox(height: 16),
          Text(
            result.conflicts.first.recommendation,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('OK'),
        ),
        ElevatedButton(
          onPressed: () {
            // Open settings to disable conflicting apps
            _openHealthConnectSettings();
          },
          child: Text('Open Settings'),
        ),
      ],
    ),
  );
}
```

## Detailed Reports

### Generate Full Report

```dart
final report = HealthConnectPlugin.generateConflictReport(result);
print(report);

// Or save to file
await File('conflict_report.txt').writeAsString(report);
```

**Example Report:**
```
Conflict Detection Report
Data Type: steps
Period: 2025-01-06 to 2025-01-13
Total Records: 9,479

Data Sources (2):
  • Samsung Health
    Records: 5,234 (55.2%)
    System App: true
    Device: Samsung Galaxy S23

  • Google Fit
    Records: 4,245 (44.8%)
    System App: true
    Device: Samsung Galaxy S23

Conflicts Detected: 1

Conflict:
  Type: multipleWriters
  Severity: 0.68 (MEDIUM)
  Recommendation: Multiple apps detected: Samsung Health and Google Fit.
  Disable steps tracking in one app to avoid double-counting.
```

## Complete Example

```dart
class HealthDashboard extends StatefulWidget {
  @override
  _HealthDashboardState createState() => _HealthDashboardState();
}

class _HealthDashboardState extends State<HealthDashboard> {
  final _plugin = HealthConnectPlugin();
  ConflictSummary? _conflictSummary;
  bool _showWarnings = false;

  @override
  void initState() {
    super.initState();
    _checkForConflicts();
  }

  Future<void> _checkForConflicts() async {
    await _plugin.initialize();
    await _plugin.connect();

    final summary = await _plugin.detectConflictsForTypes(
      dataTypes: [
        DataType.steps,
        DataType.heartRate,
        DataType.sleep,
        DataType.calories,
      ],
    );

    setState(() {
      _conflictSummary = summary;
      _showWarnings = summary.hasAnyConflicts;
    });

    // Show critical warnings immediately
    if (summary.hasHighSeverityConflicts) {
      _showCriticalWarning();
    }
  }

  void _showCriticalWarning() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Critical Data Conflict'),
          ],
        ),
        content: Text(
          'Multiple apps are syncing the same health data, causing inflated counts. '
          'Please disable duplicate tracking in Health Connect settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openHealthConnectSettings();
            },
            child: Text('Fix Now'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }

  void _openHealthConnectSettings() {
    // Open Health Connect settings
    // (Implementation depends on platform)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Health Dashboard'),
        actions: [
          if (_showWarnings)
            IconButton(
              icon: Icon(Icons.warning, color: Colors.orange),
              onPressed: _showConflictDetails,
            ),
        ],
      ),
      body: _buildDashboard(),
    );
  }

  Widget _buildDashboard() {
    if (_conflictSummary == null) {
      return Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        // Conflict warning banner
        if (_conflictSummary!.hasAnyConflicts)
          _buildWarningBanner(),

        // Data cards
        _buildStepsCard(),
        _buildHeartRateCard(),
        _buildSleepCard(),
      ],
    );
  }

  Widget _buildWarningBanner() {
    final conflicts = _conflictSummary!.totalConflicts;
    final severity = _conflictSummary!.hasHighSeverityConflicts
        ? 'HIGH'
        : 'MEDIUM';

    return Card(
      color: Colors.orange.shade50,
      margin: EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: Icon(Icons.warning, color: Colors.orange),
        title: Text('$conflicts Data Conflicts Detected'),
        subtitle: Text('Severity: $severity - Tap for details'),
        trailing: Icon(Icons.arrow_forward),
        onTap: _showConflictDetails,
      ),
    );
  }

  void _showConflictDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConflictDetailsPage(
          summary: _conflictSummary!,
        ),
      ),
    );
  }

  // ... dashboard implementation
}
```

## Best Practices

### 1. Check on App Launch

```dart
class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _performConflictCheck();
  }

  Future<void> _performConflictCheck() async {
    final summary = await healthPlugin.detectConflictsForTypes(
      dataTypes: [DataType.steps, DataType.heartRate, DataType.sleep],
    );

    if (summary.hasHighSeverityConflicts) {
      // Show warning immediately
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showConflictWarning(summary);
      });
    }
  }
}
```

### 2. Periodic Background Checks

```dart
// Check for conflicts during background sync
@pragma('vm:entry-point')
void backgroundDispatcher() {
  createBackgroundSyncDispatcher(
    onComplete: (result) async {
      // After syncing, check for conflicts
      final plugin = HealthConnectPlugin();
      await plugin.initialize();

      final conflicts = await plugin.detectConflicts(
        dataType: DataType.steps,
      );

      if (conflicts.hasConflicts) {
        // Send notification
        await showNotification(
          'Multiple apps tracking steps detected',
          'Tap to resolve',
        );
      }
    },
  );
}
```

### 3. Show Warnings Before Analytics

```dart
Future<void> showStepsDashboard() async {
  // Always check for conflicts before showing data
  final conflicts = await healthPlugin.detectConflicts(
    dataType: DataType.steps,
  );

  if (conflicts.hasConflicts) {
    // Show disclaimer
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Data Quality Warning'),
        content: Text(
          'Multiple apps are tracking steps. '
          'Displayed counts may be inflated.',
        ),
      ),
    );
  }

  // Then show dashboard
  _showDashboard();
}
```

### 4. Guide Users to Fix

```dart
void showResolutionGuide(ConflictDetectionResult result) {
  final primary = result.primarySource;
  final others = result.secondarySources;

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('How to Fix'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Keep tracking in: ${primary?.displayName}'),
          Text('(Most data: ${primary?.recordCount} records)\n'),
          Text('Disable tracking in:'),
          ...others.map((s) => Text('• ${s.displayName}')),
          SizedBox(height: 16),
          Text(
            'Steps:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text('1. Open Health Connect app'),
          Text('2. Go to App Permissions'),
          Text('3. Disable ${result.dataType.toValue()} for:'),
          ...others.map((s) => Text('   • ${s.displayName}')),
        ],
      ),
    ),
  );
}
```

## Troubleshooting

### Issue: No conflicts detected but counts seem high
**Solution**: Extend time period or check manually
```dart
// Check longer period
await plugin.detectConflicts(
  dataType: DataType.steps,
  startTime: DateTime.now().subtract(Duration(days: 30)),
  endTime: DateTime.now(),
);
```

### Issue: False positive (conflict reported but intentional)
**Solution**: Check if multiple devices or legitimate use case

### Issue: Sync loop not detected
**Solution**: Check if severity calculation identifies it
```dart
if (conflict.type == ConflictType.syncLoop) {
  // Sync loop confirmed
}
```

## Performance

- **Fast**: Analyzes in <1 second for typical datasets
- **Efficient**: Only reads metadata, not full records
- **Cached**: Results can be cached for dashboard display

## Related Documentation

- [Aggregate Data Guide](./AGGREGATE_DATA_GUIDE.md) - For accurate totals
- [Changes API Guide](./CHANGES_API_GUIDE.md) - For incremental sync
- [Background Sync Guide](./BACKGROUND_SYNC_GUIDE.md) - For periodic checks

## Support

For issues with conflict detection:
1. Check if multiple apps are actually installed
2. Verify data exists for time period
3. Review detected sources in result
4. Check logs for "ConflictDetection" category
