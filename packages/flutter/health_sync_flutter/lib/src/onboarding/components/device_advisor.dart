import '../models/device_profile.dart';
import '../models/sdk_status.dart';
import 'retry_orchestrator.dart';

/// Provides device-specific guidance and optimization for Health Connect onboarding.
///
/// This component uses the OEM database (built into [DeviceProfile]) to provide
/// tailored advice, retry strategies, and troubleshooting steps based on the
/// user's specific device manufacturer and model.
///
/// **Key Features:**
/// - Device risk assessment
/// - OEM-specific setup instructions
/// - Optimized retry strategies per device
/// - Native step tracking detection
/// - Troubleshooting guidance
class DeviceAdvisor {
  /// Current device profile.
  DeviceProfile? _deviceProfile;

  /// Get or create device profile.
  Future<DeviceProfile> getDeviceProfile() async {
    _deviceProfile ??= await DeviceProfile.fromCurrentDevice();
    return _deviceProfile!;
  }

  /// Get device-specific retry strategy for Health Connect verification.
  ///
  /// Returns optimized [RetryStrategy] based on device manufacturer.
  /// Devices known to have the "update loop bug" get more retries with longer delays.
  ///
  /// **Example:**
  /// ```dart
  /// final advisor = DeviceAdvisor();
  /// final strategy = await advisor.getRetryStrategy();
  /// // Nothing Phone: 8 retries × 2s = 16s total
  /// // Google Pixel: 5 retries × 1s = 5s total
  /// ```
  Future<RetryStrategy> getRetryStrategy() async {
    final profile = await getDeviceProfile();

    if (profile.hasUpdateLoopBug) {
      // Devices with update loop bug need exponential backoff with longer delays
      return RetryStrategy.exponential(
        maxAttempts: profile.recommendedRetryCount,
        initialDelay: profile.recommendedRetryDelay,
        maxDelay: Duration(seconds: 16),
        addJitter: true,
      );
    } else if (profile.isHighRisk) {
      // High risk devices get linear retry with moderate delays
      return RetryStrategy.linear(
        maxAttempts: profile.recommendedRetryCount,
        delay: profile.recommendedRetryDelay,
      );
    } else {
      // Low/medium risk devices get standard retry
      return RetryStrategy.linear(
        maxAttempts: 5,
        delay: Duration(seconds: 1),
      );
    }
  }

  /// Get device-specific setup guidance message.
  ///
  /// Returns a user-friendly message tailored to the device's characteristics.
  ///
  /// **Example:**
  /// ```dart
  /// final guidance = await advisor.getSetupGuidance();
  /// // "⚠ Nothing Phone devices commonly require a Health Connect update.
  /// //  Expected setup time: 2-3 minutes"
  /// ```
  Future<String> getSetupGuidance() async {
    final profile = await getDeviceProfile();
    return profile.getSetupGuidance();
  }

  /// Get device-specific update instructions.
  ///
  /// Returns step-by-step instructions optimized for the device's OEM.
  ///
  /// **Example:**
  /// ```dart
  /// final instructions = await advisor.getUpdateInstructions();
  /// // "1. Tap 'Update' to open the Play Store
  /// //  2. Tap the 'Update' button...
  /// //  Note: OnePlus devices may show 'Update Required' for 10-15 seconds..."
  /// ```
  Future<String> getUpdateInstructions() async {
    final profile = await getDeviceProfile();
    return profile.getUpdateInstructions();
  }

  /// Assess stub risk level for current device.
  ///
  /// Returns [StubRiskLevel] indicating likelihood of encountering stub state.
  ///
  /// **Example:**
  /// ```dart
  /// final riskLevel = await advisor.assessStubRisk();
  /// if (riskLevel == StubRiskLevel.high) {
  ///   // Proactively show update guidance
  /// }
  /// ```
  Future<StubRiskLevel> assessStubRisk() async {
    final profile = await getDeviceProfile();
    return profile.stubRiskLevel;
  }

  /// Check if device supports native step tracking.
  ///
  /// Android 14/15 devices can track steps without third-party apps.
  /// Returns true if native tracking is available.
  ///
  /// **Example:**
  /// ```dart
  /// if (await advisor.supportsNativeStepTracking()) {
  ///   showMessage('Your phone can track steps automatically!');
  /// }
  /// ```
  Future<bool> supportsNativeStepTracking() async {
    final profile = await getDeviceProfile();
    return profile.hasNativeStepTracking;
  }

  /// Get estimated setup time based on device and SDK status.
  ///
  /// Returns estimated [Duration] for onboarding completion.
  ///
  /// **Parameters:**
  /// - [sdkStatus]: Current SDK status (affects estimate)
  ///
  /// **Example:**
  /// ```dart
  /// final estimatedTime = await advisor.getEstimatedSetupTime(currentStatus);
  /// // High-risk device + update required = 2-3 minutes
  /// // Low-risk device + SDK ready = <1 minute
  /// ```
  Future<Duration> getEstimatedSetupTime(SdkStatus sdkStatus) async {
    final profile = await getDeviceProfile();

    if (sdkStatus.isAvailable) {
      // SDK ready - just need permissions
      return Duration(seconds: 30);
    }

    if (sdkStatus.requiresInstall) {
      // Full installation required
      return Duration(minutes: 3);
    }

    if (sdkStatus.requiresUpdate) {
      // Update required
      switch (profile.stubRiskLevel) {
        case StubRiskLevel.high:
          return Duration(minutes: 3); // Conservative estimate
        case StubRiskLevel.medium:
          return Duration(minutes: 2);
        case StubRiskLevel.low:
        case StubRiskLevel.unknown:
          return Duration(minutes: 1);
      }
    }

    return Duration(minutes: 2); // Default estimate
  }

  /// Get device-specific troubleshooting advice.
  ///
  /// Returns guidance for common issues on this device.
  ///
  /// **Parameters:**
  /// - [sdkStatus]: Current SDK status
  /// - [errorMessage]: Optional error message to provide context
  ///
  /// **Example:**
  /// ```dart
  /// final advice = await advisor.getTroubleshootingAdvice(
  ///   status,
  ///   errorMessage: 'Health Connect still shows update required',
  /// );
  /// ```
  Future<String> getTroubleshootingAdvice({
    required SdkStatus sdkStatus,
    String? errorMessage,
  }) async {
    final profile = await getDeviceProfile();
    final buffer = StringBuffer();

    buffer.writeln('Troubleshooting for ${profile.manufacturer}');
    buffer.writeln('');

    // Generic advice based on SDK status
    if (sdkStatus.requiresUpdate) {
      buffer.writeln('Health Connect requires an update:');
      buffer.writeln('');
      buffer.writeln('1. Ensure you have a stable internet connection');
      buffer.writeln('2. Open the Play Store and search for "Health Connect"');
      buffer.writeln('3. If you see "Open" instead of "Update", '
          'try clearing Play Store cache');
      buffer.writeln('4. After updating, return to this app');
      buffer.writeln('');

      if (profile.hasUpdateLoopBug) {
        buffer.writeln('Note: ${profile.manufacturer} devices may show '
            '"Update Required" for 10-15 seconds after updating. '
            'This is normal - please wait for verification to complete.');
        buffer.writeln('');
      }
    } else if (sdkStatus.requiresInstall) {
      buffer.writeln('Health Connect is not installed:');
      buffer.writeln('');
      buffer.writeln('1. Open the Play Store');
      buffer.writeln('2. Search for "Health Connect"');
      buffer.writeln('3. Install the app (it\'s free)');
      buffer.writeln('4. Return to this app');
      buffer.writeln('');
    } else if (sdkStatus.isUnknown) {
      buffer.writeln('Unable to determine Health Connect status:');
      buffer.writeln('');
      buffer.writeln('This may indicate:');
      buffer.writeln('- Temporary connectivity issue');
      buffer.writeln('- Play Services needs updating');
      buffer.writeln('- Device compatibility issue');
      buffer.writeln('');
      buffer.writeln('Try:');
      buffer.writeln('1. Restart the app');
      buffer.writeln('2. Check for system updates');
      buffer.writeln('3. Update Google Play Services');
      buffer.writeln('');
    }

    // Add device-specific notes
    if (profile.notes != null && profile.notes!.isNotEmpty) {
      buffer.writeln('Device-Specific Guidance:');
      buffer.writeln(profile.notes);
      buffer.writeln('');
    }

    // Add troubleshooting URL if available
    if (profile.troubleshootingUrl != null) {
      buffer.writeln('For more help:');
      buffer.writeln(profile.troubleshootingUrl);
      buffer.writeln('');
    }

    return buffer.toString();
  }

  /// Check if device likely needs special handling.
  ///
  /// Returns true if device has known quirks requiring special attention.
  ///
  /// **Example:**
  /// ```dart
  /// if (await advisor.needsSpecialHandling()) {
  ///   // Show detailed guidance upfront
  ///   showDetailedSetupInstructions();
  /// }
  /// ```
  Future<bool> needsSpecialHandling() async {
    final profile = await getDeviceProfile();
    return profile.hasUpdateLoopBug || profile.isHighRisk;
  }

  /// Get recommended polling interval for status checks during verification.
  ///
  /// Returns optimal [Duration] between status checks based on device.
  /// Devices with slower status updates get longer intervals.
  ///
  /// **Example:**
  /// ```dart
  /// final interval = await advisor.getRecommendedPollingInterval();
  /// // Nothing Phone: 2 seconds
  /// // Google Pixel: 1 second
  /// ```
  Future<Duration> getRecommendedPollingInterval() async {
    final profile = await getDeviceProfile();

    if (profile.hasUpdateLoopBug) {
      return Duration(seconds: 2); // Slower polling for devices with caching issues
    }

    return Duration(seconds: 1); // Default polling interval
  }

  /// Get device compatibility report.
  ///
  /// Returns comprehensive report about device's Health Connect compatibility.
  ///
  /// **Example:**
  /// ```dart
  /// final report = await advisor.getCompatibilityReport();
  /// print(report);
  /// // Device: Nothing Phone (2)
  /// // Android: 14 (SDK 34)
  /// // Stub Risk: High (80-95% probability)
  /// // Update Loop Bug: Yes
  /// // Native Step Tracking: Yes
  /// // ...
  /// ```
  Future<String> getCompatibilityReport() async {
    final profile = await getDeviceProfile();
    final buffer = StringBuffer();

    buffer.writeln('Health Connect Compatibility Report');
    buffer.writeln('=' * 50);
    buffer.writeln('');

    buffer.writeln('Device Information:');
    buffer.writeln('  Manufacturer: ${profile.manufacturer}');
    if (profile.brand != null) {
      buffer.writeln('  Brand: ${profile.brand}');
    }
    if (profile.model != null) {
      buffer.writeln('  Model: ${profile.model}');
    }
    buffer.writeln('  Android: ${profile.androidVersion} (SDK ${profile.androidSdkVersion})');
    buffer.writeln('');

    buffer.writeln('Health Connect Risk Assessment:');
    buffer.writeln('  Stub Risk Level: ${profile.stubRiskLevel.name}');

    String riskDescription;
    switch (profile.stubRiskLevel) {
      case StubRiskLevel.high:
        riskDescription = '80-95% probability of encountering stub state';
        break;
      case StubRiskLevel.medium:
        riskDescription = '30-50% probability of encountering stub state';
        break;
      case StubRiskLevel.low:
        riskDescription = '<10% probability of encountering stub state';
        break;
      case StubRiskLevel.unknown:
        riskDescription = 'Unknown - assume medium risk';
        break;
    }
    buffer.writeln('  Risk Description: $riskDescription');
    buffer.writeln('');

    buffer.writeln('Known Device Characteristics:');
    buffer.writeln('  Update Loop Bug: ${profile.hasUpdateLoopBug ? 'Yes ⚠' : 'No ✓'}');
    buffer.writeln('  Native Step Tracking: ${profile.hasNativeStepTracking ? 'Yes ✓' : 'No'}');
    buffer.writeln('  Recommended Retries: ${profile.recommendedRetryCount}');
    buffer.writeln('  Recommended Retry Delay: ${profile.recommendedRetryDelay.inSeconds}s');
    buffer.writeln('');

    if (profile.notes != null && profile.notes!.isNotEmpty) {
      buffer.writeln('OEM-Specific Notes:');
      buffer.writeln(profile.notes);
      buffer.writeln('');
    }

    buffer.writeln('Expected Setup Experience:');
    final estimatedTime = await getEstimatedSetupTime(SdkStatus.unavailableProviderUpdateRequired);
    buffer.writeln('  Estimated Setup Time: ${estimatedTime.inMinutes} minutes');
    buffer.writeln('  Special Handling Required: ${await needsSpecialHandling() ? 'Yes' : 'No'}');
    buffer.writeln('');

    return buffer.toString();
  }

  /// Get warning message if device is high-risk.
  ///
  /// Returns null if device is low/medium risk.
  ///
  /// **Example:**
  /// ```dart
  /// final warning = await advisor.getHighRiskWarning();
  /// if (warning != null) {
  ///   showWarningDialog(warning);
  /// }
  /// ```
  Future<String?> getHighRiskWarning() async {
    final profile = await getDeviceProfile();

    if (!profile.isHighRisk) {
      return null;
    }

    return '⚠ ${profile.manufacturer} devices commonly require Health Connect updates. '
        'Setup may take 2-3 minutes. Please ensure you have a stable internet connection.';
  }

  /// Clear cached device profile (force re-detection).
  void clearCache() {
    _deviceProfile = null;
  }

  /// Export device profile for analytics or debugging.
  ///
  /// Returns JSON map with all device profile data.
  Future<Map<String, dynamic>> exportDeviceProfile() async {
    final profile = await getDeviceProfile();
    return profile.toJson();
  }
}
