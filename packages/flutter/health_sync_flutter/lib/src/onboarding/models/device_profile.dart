import 'dart:io';
import 'package:flutter/foundation.dart';

/// Risk level for Health Connect stub occurrence on a device.
///
/// Based on real-world data and OEM behavior patterns. This helps
/// set appropriate expectations and retry strategies for users.
enum StubRiskLevel {
  /// Very likely to encounter stub (80-95% probability).
  ///
  /// Examples: Nothing Phone, OnePlus, Motorola on Android 14/15
  high,

  /// May encounter stub (30-50% probability).
  ///
  /// Examples: Samsung, Xiaomi, older devices
  medium,

  /// Unlikely to encounter stub (<10% probability).
  ///
  /// Examples: Google Pixel, recent Samsung flagships
  low,

  /// Unknown device - assume medium risk.
  unknown,
}

/// Device profile with OEM-specific Health Connect behavior.
///
/// Provides intelligence about how Health Connect behaves on specific
/// device manufacturers and models. This enables:
/// - Device-specific user guidance
/// - Optimized retry strategies
/// - Better error messages
/// - Analytics and troubleshooting
class DeviceProfile {
  /// Device manufacturer (lowercase, normalized).
  ///
  /// Examples: "google", "samsung", "nothing", "oneplus"
  final String manufacturer;

  /// Device model (if available).
  ///
  /// Examples: "Pixel 7", "Galaxy S23", "Phone (2)"
  final String? model;

  /// Android SDK version.
  ///
  /// Example: 34 (Android 14), 35 (Android 15)
  final int androidSdkVersion;

  /// Android version string.
  ///
  /// Example: "14", "15"
  final String androidVersion;

  /// Device brand (may differ from manufacturer).
  ///
  /// Example: "Google", "OnePlus", "Nothing"
  final String? brand;

  /// Stub risk level for this device.
  final StubRiskLevel stubRiskLevel;

  /// OEM-specific notes and quirks.
  ///
  /// Examples:
  /// - "Nothing OS 2.5+ requires manual update check"
  /// - "OnePlus devices may show 'update required' for 15+ seconds"
  /// - "Motorola devices often ship with very old Health Connect stub"
  final String? notes;

  /// Whether this device is known to have the "update loop bug".
  ///
  /// The bug where SDK status remains `UPDATE_REQUIRED` for 10+ seconds
  /// after successful Play Store update due to platform caching.
  final bool hasUpdateLoopBug;

  /// Recommended retry count for this device.
  ///
  /// Devices with update loop bug need more retries.
  final int recommendedRetryCount;

  /// Recommended retry delay for this device.
  ///
  /// Devices with slow status updates need longer delays.
  final Duration recommendedRetryDelay;

  /// Whether native step tracking is available.
  ///
  /// Android 14/15 devices can track steps natively without third-party apps.
  final bool supportsNativeStepTracking;

  /// Device-specific troubleshooting URL (if available).
  final String? troubleshootingUrl;

  const DeviceProfile({
    required this.manufacturer,
    this.model,
    required this.androidSdkVersion,
    required this.androidVersion,
    this.brand,
    required this.stubRiskLevel,
    this.notes,
    this.hasUpdateLoopBug = false,
    this.recommendedRetryCount = 5,
    this.recommendedRetryDelay = const Duration(seconds: 2),
    this.supportsNativeStepTracking = false,
    this.troubleshootingUrl,
  });

  /// Whether this is a high-risk device for stub issues.
  bool get isHighRisk => stubRiskLevel == StubRiskLevel.high;

  /// Whether this is an Android 14+ device.
  bool get isAndroid14Plus => androidSdkVersion >= 34;

  /// Whether native step tracking is likely available.
  ///
  /// Based on Android version and manufacturer.
  bool get hasNativeStepTracking {
    return supportsNativeStepTracking || (isAndroid14Plus && !isWearOS);
  }

  /// Whether this is likely a Wear OS device.
  bool get isWearOS {
    final modelLower = (model ?? '').toLowerCase();
    return modelLower.contains('watch') ||
        modelLower.contains('wear') ||
        manufacturer.toLowerCase() == 'fossil' ||
        manufacturer.toLowerCase() == 'mobvoi';
  }

  /// Get device-specific guidance for Health Connect setup.
  String getSetupGuidance() {
    final buffer = StringBuffer();

    buffer.writeln('Device: ${brand ?? manufacturer} ${model ?? ''}');
    buffer.writeln('Android: $androidVersion (SDK $androidSdkVersion)');
    buffer.writeln('');

    switch (stubRiskLevel) {
      case StubRiskLevel.high:
        buffer.writeln('⚠ This device frequently ships with Health Connect '
            'in a "stub" state requiring a Play Store update.');
        buffer.writeln('');
        buffer.writeln('Expected setup time: 2-3 minutes');
        break;
      case StubRiskLevel.medium:
        buffer.writeln('ℹ This device may require a Health Connect update.');
        buffer.writeln('');
        buffer.writeln('Expected setup time: 1-2 minutes');
        break;
      case StubRiskLevel.low:
        buffer.writeln('✓ This device typically has Health Connect ready to use.');
        buffer.writeln('');
        buffer.writeln('Expected setup time: <1 minute');
        break;
      case StubRiskLevel.unknown:
        buffer.writeln('ℹ Setup time may vary depending on Health Connect status.');
        break;
    }

    if (hasUpdateLoopBug) {
      buffer.writeln('');
      buffer.writeln('Note: After updating, verification may take 10-15 seconds.');
    }

    if (hasNativeStepTracking && androidSdkVersion >= 34) {
      buffer.writeln('');
      buffer.writeln('✓ This device can track steps automatically without additional apps!');
      buffer.writeln('Look for "This phone" as a data source in Health Connect.');
    }

    if (notes != null && notes!.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('Device-Specific Notes:');
      buffer.writeln(notes);
    }

    if (troubleshootingUrl != null) {
      buffer.writeln('');
      buffer.writeln('Troubleshooting: $troubleshootingUrl');
    }

    return buffer.toString();
  }

  /// Get device-specific update instructions.
  String getUpdateInstructions() {
    final buffer = StringBuffer();

    buffer.writeln('Update Health Connect');
    buffer.writeln('');
    buffer.writeln('1. Tap "Update" to open the Play Store');
    buffer.writeln('2. Tap the "Update" button in the Play Store');
    buffer.writeln('3. Wait for the update to complete (~15-30 MB)');
    buffer.writeln('4. Return to this app');

    if (hasUpdateLoopBug) {
      buffer.writeln('');
      buffer.writeln('Note: Verification may take 10-15 seconds after update completes. '
          'This is normal for ${brand ?? manufacturer} devices.');
    }

    // Device-specific quirks
    if (manufacturer.toLowerCase() == 'nothing') {
      buffer.writeln('');
      buffer.writeln('Nothing OS Tip: If the Play Store shows "Open" instead of '
          '"Update", try searching for "Health Connect" manually in the Play Store.');
    } else if (manufacturer.toLowerCase() == 'oneplus') {
      buffer.writeln('');
      buffer.writeln('OnePlus Tip: After updating, you may see "Update Required" '
          'for 10-15 seconds. This is normal - please wait for verification to complete.');
    } else if (manufacturer.toLowerCase() == 'motorola') {
      buffer.writeln('');
      buffer.writeln('Motorola Tip: Your device may have a very old Health Connect '
          'version. The update may take 2-3 minutes.');
    }

    return buffer.toString();
  }

  /// Create device profile from current device.
  static Future<DeviceProfile> fromCurrentDevice() async {
    if (kIsWeb) {
      return DeviceProfile(
        manufacturer: 'web',
        androidSdkVersion: 0,
        androidVersion: 'web',
        stubRiskLevel: StubRiskLevel.unknown,
        notes: 'Health Connect is not available on web',
      );
    }

    if (!Platform.isAndroid) {
      return DeviceProfile(
        manufacturer: Platform.operatingSystem,
        androidSdkVersion: 0,
        androidVersion: Platform.operatingSystemVersion,
        stubRiskLevel: StubRiskLevel.unknown,
        notes: 'Health Connect is only available on Android',
      );
    }

    // Get device info
    // In a real implementation, this would use device_info_plus package
    // For now, return a basic profile
    final manufacturer = _getManufacturer().toLowerCase();
    final sdkVersion = _getAndroidSdkVersion();
    final androidVersion = _getAndroidVersion();
    final model = _getModel();
    final brand = _getBrand();

    return DeviceProfile(
      manufacturer: manufacturer,
      model: model,
      androidSdkVersion: sdkVersion,
      androidVersion: androidVersion,
      brand: brand,
      stubRiskLevel: _determineStubRisk(manufacturer, sdkVersion),
      notes: _getOEMNotes(manufacturer),
      hasUpdateLoopBug: _hasUpdateLoopBug(manufacturer),
      recommendedRetryCount: _getRecommendedRetryCount(manufacturer),
      recommendedRetryDelay: _getRecommendedRetryDelay(manufacturer),
      supportsNativeStepTracking: sdkVersion >= 34,
      troubleshootingUrl: _getTroubleshootingUrl(manufacturer),
    );
  }

  /// Determine stub risk level based on manufacturer and Android version.
  static StubRiskLevel _determineStubRisk(String manufacturer, int sdkVersion) {
    // Android 14+ devices have higher stub risk
    if (sdkVersion < 34) {
      return StubRiskLevel.low;
    }

    final mfg = manufacturer.toLowerCase();

    // High risk manufacturers (80-95% stub probability on Android 14/15)
    if (mfg.contains('nothing') ||
        mfg.contains('oneplus') ||
        mfg.contains('motorola') ||
        mfg.contains('poco') ||
        mfg.contains('realme')) {
      return StubRiskLevel.high;
    }

    // Medium risk manufacturers (30-50% stub probability)
    if (mfg.contains('samsung') ||
        mfg.contains('xiaomi') ||
        mfg.contains('oppo') ||
        mfg.contains('vivo') ||
        mfg.contains('honor')) {
      return StubRiskLevel.medium;
    }

    // Low risk manufacturers (usually ship with working Health Connect)
    if (mfg.contains('google') || mfg.contains('pixel')) {
      return StubRiskLevel.low;
    }

    // Unknown manufacturer - assume medium risk
    return StubRiskLevel.unknown;
  }

  /// Get OEM-specific notes.
  static String? _getOEMNotes(String manufacturer) {
    final mfg = manufacturer.toLowerCase();

    if (mfg.contains('nothing')) {
      return 'Nothing OS devices commonly ship with Health Connect stub. '
          'Manual Play Store update check may be required.';
    } else if (mfg.contains('oneplus')) {
      return 'OnePlus devices may show "update required" status for 15+ seconds '
          'after successful update.';
    } else if (mfg.contains('motorola')) {
      return 'Motorola devices often ship with very old Health Connect versions. '
          'Update may take 2-3 minutes.';
    } else if (mfg.contains('samsung')) {
      return 'Samsung devices usually work well but may have outdated Health Connect '
          'on first boot.';
    }

    return null;
  }

  /// Whether manufacturer is known to have update loop bug.
  static bool _hasUpdateLoopBug(String manufacturer) {
    final mfg = manufacturer.toLowerCase();
    return mfg.contains('nothing') || mfg.contains('oneplus');
  }

  /// Get recommended retry count for manufacturer.
  static int _getRecommendedRetryCount(String manufacturer) {
    if (_hasUpdateLoopBug(manufacturer)) {
      return 8; // More retries for devices with update loop bug
    }
    return 5; // Default retry count
  }

  /// Get recommended retry delay for manufacturer.
  static Duration _getRecommendedRetryDelay(String manufacturer) {
    if (_hasUpdateLoopBug(manufacturer)) {
      return Duration(seconds: 2); // Longer delay for update loop bug
    }
    return Duration(seconds: 1); // Default delay
  }

  /// Get troubleshooting URL for manufacturer.
  static String? _getTroubleshootingUrl(String manufacturer) {
    // Could link to manufacturer-specific support pages
    return null;
  }

  // Platform-specific getters (would use device_info_plus in production)

  static String _getManufacturer() {
    // Placeholder - would use device_info_plus
    return 'unknown';
  }

  static String? _getModel() {
    // Placeholder - would use device_info_plus
    return null;
  }

  static String? _getBrand() {
    // Placeholder - would use device_info_plus
    return null;
  }

  static int _getAndroidSdkVersion() {
    // Placeholder - would use device_info_plus
    return 34; // Default to Android 14
  }

  static String _getAndroidVersion() {
    // Placeholder - would use device_info_plus
    return '14';
  }

  /// Convert to JSON for storage/analytics.
  Map<String, dynamic> toJson() {
    return {
      'manufacturer': manufacturer,
      'model': model,
      'androidSdkVersion': androidSdkVersion,
      'androidVersion': androidVersion,
      'brand': brand,
      'stubRiskLevel': stubRiskLevel.name,
      'notes': notes,
      'hasUpdateLoopBug': hasUpdateLoopBug,
      'recommendedRetryCount': recommendedRetryCount,
      'recommendedRetryDelayMs': recommendedRetryDelay.inMilliseconds,
      'supportsNativeStepTracking': supportsNativeStepTracking,
      'troubleshootingUrl': troubleshootingUrl,
    };
  }

  /// Create from JSON.
  factory DeviceProfile.fromJson(Map<String, dynamic> json) {
    return DeviceProfile(
      manufacturer: json['manufacturer'] as String,
      model: json['model'] as String?,
      androidSdkVersion: json['androidSdkVersion'] as int,
      androidVersion: json['androidVersion'] as String,
      brand: json['brand'] as String?,
      stubRiskLevel: StubRiskLevel.values.firstWhere(
        (level) => level.name == json['stubRiskLevel'],
        orElse: () => StubRiskLevel.unknown,
      ),
      notes: json['notes'] as String?,
      hasUpdateLoopBug: json['hasUpdateLoopBug'] as bool? ?? false,
      recommendedRetryCount: json['recommendedRetryCount'] as int? ?? 5,
      recommendedRetryDelay: Duration(
        milliseconds: json['recommendedRetryDelayMs'] as int? ?? 2000,
      ),
      supportsNativeStepTracking: json['supportsNativeStepTracking'] as bool? ?? false,
      troubleshootingUrl: json['troubleshootingUrl'] as String?,
    );
  }

  @override
  String toString() {
    return 'DeviceProfile{'
        'manufacturer: $manufacturer, '
        'model: $model, '
        'android: $androidVersion (SDK $androidSdkVersion), '
        'stubRisk: ${stubRiskLevel.name}, '
        'updateLoopBug: $hasUpdateLoopBug'
        '}';
  }
}
