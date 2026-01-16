/// Represents the Health Connect SDK availability status.
///
/// This mirrors the status codes returned by the native Health Connect SDK's
/// `getSdkStatus()` API. These statuses are critical for handling the
/// "stub" reality where Health Connect may be pre-installed but non-functional.
///
/// **Important:** Always use `getSdkStatus()` as the source of truth, not
/// `Build.VERSION.SDK_INT`. A device running Android 14 may have Health Connect
/// in a stub state requiring Play Store update.
enum SdkStatus {
  /// Health Connect SDK is fully available and ready to use.
  ///
  /// All Health Connect APIs can be called safely.
  /// This is the desired state for normal app operation.
  ///
  /// **Native Code:** `HealthConnectClient.SDK_AVAILABLE` (1)
  available,

  /// Health Connect is installed but requires a Play Store update.
  ///
  /// This is the "stub" state - Health Connect exists as a lightweight placeholder
  /// (~10KB) but needs to be "hydrated" via Play Store update (~15-30MB).
  ///
  /// **Common Scenarios:**
  /// - Fresh Android 14/15 devices (Nothing, OnePlus, Motorola)
  /// - Devices that haven't updated Health Connect in 30+ days
  /// - After factory reset on Android 14+ devices
  ///
  /// **Native Code:** `HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED` (3)
  ///
  /// **Action:** Direct user to Play Store to update
  unavailableProviderUpdateRequired,

  /// Health Connect is not installed on this device.
  ///
  /// Rare on Android 14+ but possible on:
  /// - Older Android versions (pre-14)
  /// - Custom ROMs without GMS
  /// - Devices in certain regions
  ///
  /// **Native Code:** `HealthConnectClient.SDK_UNAVAILABLE` (2)
  ///
  /// **Action:** Direct user to Play Store to install
  unavailable,

  /// SDK status check failed or returned unknown code.
  ///
  /// This can occur due to:
  /// - Platform channel errors
  /// - Unexpected SDK status codes
  /// - Device compatibility issues
  ///
  /// **Action:** Show error message and allow retry
  unknown,
}

/// Extension methods for [SdkStatus] to provide additional context.
extension SdkStatusExtension on SdkStatus {
  /// Whether the SDK is ready for use.
  bool get isAvailable => this == SdkStatus.available;

  /// Whether the SDK requires a Play Store update.
  bool get requiresUpdate => this == SdkStatus.unavailableProviderUpdateRequired;

  /// Whether the SDK is not installed at all.
  bool get requiresInstall => this == SdkStatus.unavailable;

  /// Whether the SDK status is unknown or error.
  bool get isUnknown => this == SdkStatus.unknown;

  /// Whether user action is required (update or install).
  bool get requiresUserAction => requiresUpdate || requiresInstall;

  /// Play Store deep link for updating/installing Health Connect.
  String get playStoreUri => 'market://details?id=com.google.android.apps.healthdata';

  /// Play Store web URL (fallback for devices without Play Store app).
  String get playStoreWebUrl =>
      'https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata';

  /// Human-readable display name for this status.
  String get displayName {
    switch (this) {
      case SdkStatus.available:
        return 'Available';
      case SdkStatus.unavailableProviderUpdateRequired:
        return 'Update Required';
      case SdkStatus.unavailable:
        return 'Not Installed';
      case SdkStatus.unknown:
        return 'Unknown';
    }
  }

  /// Detailed description of this status for user guidance.
  String get description {
    switch (this) {
      case SdkStatus.available:
        return 'Health Connect is ready to use on this device.';
      case SdkStatus.unavailableProviderUpdateRequired:
        return 'Health Connect is installed but needs to be updated from the Play Store. '
            'This is common on Android 14/15 devices where Health Connect comes pre-installed '
            'as a lightweight stub requiring a one-time update.';
      case SdkStatus.unavailable:
        return 'Health Connect is not installed on this device. '
            'You can install it for free from the Play Store.';
      case SdkStatus.unknown:
        return 'Unable to determine Health Connect status. This may indicate a device '
            'compatibility issue or temporary error.';
    }
  }

  /// Recommended action for the user based on this status.
  String? get recommendedAction {
    switch (this) {
      case SdkStatus.available:
        return null; // No action needed
      case SdkStatus.unavailableProviderUpdateRequired:
        return 'Update Health Connect from the Play Store';
      case SdkStatus.unavailable:
        return 'Install Health Connect from the Play Store';
      case SdkStatus.unknown:
        return 'Check device compatibility or try again';
    }
  }

  /// Whether this status should trigger automatic retry logic.
  ///
  /// After a user updates/installs Health Connect, the status may still report
  /// as unavailable for ~10 seconds due to platform caching ("update loop bug").
  /// We should automatically retry status checks in these cases.
  bool get shouldAutoRetry {
    return requiresUpdate || requiresInstall || isUnknown;
  }

  /// Estimated time to resolve this status (for progress indication).
  Duration? get estimatedResolutionTime {
    switch (this) {
      case SdkStatus.available:
        return null;
      case SdkStatus.unavailableProviderUpdateRequired:
        return Duration(minutes: 2); // Play Store update typically 1-3 minutes
      case SdkStatus.unavailable:
        return Duration(minutes: 3); // Play Store install typically 2-4 minutes
      case SdkStatus.unknown:
        return Duration(seconds: 10); // Retry should resolve quickly
    }
  }

  /// Convert to native SDK status code for platform channel communication.
  int toNativeCode() {
    switch (this) {
      case SdkStatus.available:
        return 1;
      case SdkStatus.unavailable:
        return 2;
      case SdkStatus.unavailableProviderUpdateRequired:
        return 3;
      case SdkStatus.unknown:
        return -1;
    }
  }

  /// Create [SdkStatus] from native SDK status code.
  static SdkStatus fromNativeCode(int code) {
    switch (code) {
      case 1:
        return SdkStatus.available;
      case 2:
        return SdkStatus.unavailable;
      case 3:
        return SdkStatus.unavailableProviderUpdateRequired;
      default:
        return SdkStatus.unknown;
    }
  }
}

/// Wrapper class for SDK status with additional metadata.
///
/// Provides context beyond just the status enum, including timing information
/// and device-specific details that can help with troubleshooting and analytics.
class SdkStatusInfo {
  /// The SDK status.
  final SdkStatus status;

  /// When this status was checked.
  final DateTime timestamp;

  /// SDK version string (if available).
  ///
  /// Example: "1.1.0-prerelease_2024_04_30"
  ///
  /// Null if SDK is not available or version couldn't be determined.
  final String? sdkVersion;

  /// Package version code (if available).
  ///
  /// This is the versionCode from Health Connect's APK manifest.
  /// Useful for tracking which specific build is installed.
  final int? packageVersionCode;

  /// Whether the status was retrieved from cache.
  ///
  /// If true, the status may be stale (especially relevant for the
  /// "update loop bug" where cached status is incorrect for ~10 seconds).
  final bool fromCache;

  /// Time taken to check the status (in milliseconds).
  ///
  /// Useful for performance monitoring and detecting slow platform calls.
  final int? checkDurationMs;

  /// Any error that occurred during status check.
  final String? error;

  /// Device manufacturer (for OEM-specific behavior tracking).
  final String? manufacturer;

  const SdkStatusInfo({
    required this.status,
    required this.timestamp,
    this.sdkVersion,
    this.packageVersionCode,
    this.fromCache = false,
    this.checkDurationMs,
    this.error,
    this.manufacturer,
  });

  /// Whether this status info is stale (>5 seconds old).
  ///
  /// Stale status should be re-checked, especially during onboarding flow
  /// where status can change rapidly.
  bool get isStale {
    return DateTime.now().difference(timestamp) > Duration(seconds: 5);
  }

  /// Whether this represents a successful status check.
  bool get isSuccess => error == null;

  /// Copy with updated fields.
  SdkStatusInfo copyWith({
    SdkStatus? status,
    DateTime? timestamp,
    String? sdkVersion,
    int? packageVersionCode,
    bool? fromCache,
    int? checkDurationMs,
    String? error,
    String? manufacturer,
  }) {
    return SdkStatusInfo(
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      sdkVersion: sdkVersion ?? this.sdkVersion,
      packageVersionCode: packageVersionCode ?? this.packageVersionCode,
      fromCache: fromCache ?? this.fromCache,
      checkDurationMs: checkDurationMs ?? this.checkDurationMs,
      error: error ?? this.error,
      manufacturer: manufacturer ?? this.manufacturer,
    );
  }

  /// Convert to JSON for storage/analytics.
  Map<String, dynamic> toJson() {
    return {
      'status': status.name,
      'timestamp': timestamp.toIso8601String(),
      'sdkVersion': sdkVersion,
      'packageVersionCode': packageVersionCode,
      'fromCache': fromCache,
      'checkDurationMs': checkDurationMs,
      'error': error,
      'manufacturer': manufacturer,
    };
  }

  /// Create from JSON.
  factory SdkStatusInfo.fromJson(Map<String, dynamic> json) {
    return SdkStatusInfo(
      status: SdkStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => SdkStatus.unknown,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      sdkVersion: json['sdkVersion'] as String?,
      packageVersionCode: json['packageVersionCode'] as int?,
      fromCache: json['fromCache'] as bool? ?? false,
      checkDurationMs: json['checkDurationMs'] as int?,
      error: json['error'] as String?,
      manufacturer: json['manufacturer'] as String?,
    );
  }

  @override
  String toString() {
    return 'SdkStatusInfo{'
        'status: ${status.name}, '
        'timestamp: $timestamp, '
        'version: $sdkVersion, '
        'fromCache: $fromCache, '
        'error: $error'
        '}';
  }
}
