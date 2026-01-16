import 'dart:io';
import 'package:flutter/foundation.dart';

/// Device information for background sync optimization
///
/// Provides manufacturer detection to identify devices with
/// aggressive battery management that may kill background tasks.
class DeviceInfo {
  /// Get device manufacturer
  static String getManufacturer() {
    if (!kIsWeb && Platform.isAndroid) {
      // This would typically come from device_info_plus package
      // For now, return 'unknown'
      return 'unknown';
    }
    return 'unknown';
  }

  /// Check if manufacturer is known to kill background tasks aggressively
  static bool isAggressiveBatteryManager(String manufacturer) {
    final aggressiveManufacturers = [
      'xiaomi',
      'huawei',
      'oppo',
      'vivo',
      'oneplus',
      'realme',
      'asus',
      'wiko',
      'lenovo',
    ];

    return aggressiveManufacturers.contains(manufacturer.toLowerCase().trim());
  }

  /// Get battery optimization warning for manufacturer
  static String? getBatteryOptimizationWarning(String manufacturer) {
    if (!isAggressiveBatteryManager(manufacturer)) {
      return null;
    }

    return getManufacturerSpecificInstructions(manufacturer);
  }

  /// Get manufacturer-specific instructions for whitelisting app
  static String getManufacturerSpecificInstructions(String manufacturer) {
    final mfg = manufacturer.toLowerCase().trim();

    if (mfg.contains('xiaomi')) {
      return '''
Xiaomi MIUI battery optimization:

MIUI aggressively kills background tasks. To ensure background sync works:

1. Open Settings
2. Go to Battery & Performance
3. Choose Battery
4. App battery usage
5. Find this app
6. Select "No restrictions"
7. Go back to Settings > Apps > Manage apps
8. Find this app, tap "Autostart"
9. Enable autostart for this app

Without these settings, background sync will not work on MIUI devices.
''';
    } else if (mfg.contains('huawei')) {
      return '''
Huawei EMUI Battery Optimization:

EMUI kills background tasks aggressively. To ensure background sync works:

1. Open Settings
2. Go to Battery > App launch
3. Find this app
4. Disable "Manage automatically"
5. Enable:
   - Auto-launch
   - Secondary launch
   - Run in background
6. Go to Settings > Apps
7. Find this app > Battery
8. Set to "No restrictions"

Background sync may still be unreliable on Huawei devices even with these settings.
''';
    } else if (mfg.contains('oppo') || mfg.contains('realme')) {
      return '''
OPPO/Realme ColorOS Battery Optimization:

ColorOS kills background tasks. To ensure background sync works:

1. Open Settings
2. Go to Battery > Power saving mode
3. Turn OFF power saving mode
4. Go to Settings > Apps & Notifications > App Optimization
5. Find this app
6. Disable App Optimization for this app
7. Go to Settings > Apps
8. Find this app, enable "Allow background activity"
9. Go to Settings > Privacy > Autostart
10. Enable autostart for this app

Background sync requires these settings on ColorOS devices.
''';
    } else if (mfg.contains('vivo')) {
      return '''
Vivo FuntouchOS Battery Optimization:

FuntouchOS restricts background tasks. To ensure background sync works:

1. Open Settings
2. Go to Battery > Background power consumption management
3. Find this app
4. Enable "Allow high power consumption in background"
5. Go to Settings > More settings > App permissions
6. Enable "Autostart" for this app
7. Enable "Background activity" for this app

These settings are required for background sync on Vivo devices.
''';
    } else if (mfg.contains('oneplus')) {
      return '''
OnePlus OxygenOS Battery Optimization:

OxygenOS may restrict background tasks. To ensure background sync works:

1. Open Settings
2. Go to Battery > Battery optimization
3. Find this app
4. Select "Don't optimize"
5. (Optional) Go to Settings > Apps
6. Find this app > Advanced > Battery
7. Enable "Background activity"

Background sync should work after these settings on OnePlus devices.
''';
    } else {
      return '''
This device (${manufacturer}) may restrict background tasks.

To ensure background sync works, check your Battery optimization settings:

1. Open Settings
2. Go to Battery optimization settings or Power management
3. Find this app
4. Disable battery optimization for this app
5. Enable background activity
6. (If available) Enable autostart

Check your device manufacturer's documentation for specific steps.
''';
    }
  }

  /// Get compatibility level for background sync
  ///
  /// Returns:
  /// - 'high': Background sync should work reliably
  /// - 'medium': Background sync may work with configuration
  /// - 'low': Background sync unlikely to work reliably
  static String getBackgroundSyncCompatibility(String manufacturer) {
    final mfg = manufacturer.toLowerCase();

    // High compatibility manufacturers
    if (mfg.contains('google') ||
        mfg.contains('samsung') ||
        mfg.contains('motorola') ||
        mfg.contains('nokia') ||
        mfg.contains('sony')) {
      return 'high';
    }

    // Low compatibility (aggressive battery management)
    if (isAggressiveBatteryManager(mfg)) {
      return 'low';
    }

    // Medium compatibility (works with configuration)
    if (mfg.contains('lg')) {
      return 'medium';
    }

    // Unknown manufacturer - assume medium
    return 'medium';
  }

  /// Get recommended background sync frequency for device
  ///
  /// More aggressive manufacturers should use longer intervals
  /// to avoid being killed.
  static Duration getRecommendedSyncFrequency(String manufacturer) {
    final compatibility = getBackgroundSyncCompatibility(manufacturer);

    switch (compatibility) {
      case 'high':
        return Duration(minutes: 15); // Minimum allowed by Android
      case 'medium':
        return Duration(minutes: 30);
      case 'low':
        return Duration(hours: 1); // Very conservative
      default:
        return Duration(minutes: 30);
    }
  }

  /// Check if device should enable battery-intensive constraints
  ///
  /// Devices with good compatibility can sync on battery.
  /// Aggressive manufacturers should only sync when charging.
  static bool shouldRequireCharging(String manufacturer) {
    final compatibility = getBackgroundSyncCompatibility(manufacturer);
    return compatibility == 'low';
  }

  /// Check if device should require WiFi
  ///
  /// Aggressive manufacturers should use WiFi-only to avoid being killed.
  static bool shouldRequireWiFi(String manufacturer) {
    final compatibility = getBackgroundSyncCompatibility(manufacturer);
    return compatibility == 'low';
  }
}
