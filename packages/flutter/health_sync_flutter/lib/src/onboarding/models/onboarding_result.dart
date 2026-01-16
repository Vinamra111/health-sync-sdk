import 'onboarding_state.dart';
import 'sdk_status.dart';
import 'device_profile.dart';

/// Result of a Health Connect onboarding operation.
///
/// Contains comprehensive information about the current onboarding state,
/// SDK status, device profile, and any actions needed from the user or developer.
///
/// This is returned from [HealthConnectOnboardingService] operations and
/// emitted via result streams for reactive UI updates.
class OnboardingResult {
  /// Current onboarding state.
  final OnboardingState state;

  /// Current SDK status (if available).
  final SdkStatusInfo? sdkStatus;

  /// Device profile with OEM-specific information.
  final DeviceProfile? deviceProfile;

  /// Play Store URI for updating/installing Health Connect.
  ///
  /// Format: `market://details?id=com.google.android.apps.healthdata`
  ///
  /// Use this with `url_launcher` to deep-link to Play Store.
  final String? playStoreUri;

  /// Error message (if state is failed or error occurred).
  final String? errorMessage;

  /// User-facing guidance message for current state.
  ///
  /// Examples:
  /// - "Please update Health Connect from the Play Store"
  /// - "Grant permissions to continue"
  /// - "Health Connect is ready!"
  final String? userGuidance;

  /// Whether user action is required to progress.
  ///
  /// If true, the UI should present an action button (Update, Install, Grant, etc.)
  final bool requiresUserAction;

  /// Whether the current error/failure can be retried.
  final bool canRetry;

  /// Estimated time to complete setup (if known).
  ///
  /// Used for progress indication and setting user expectations.
  final Duration? estimatedTime;

  /// Number of retry attempts made (for current operation).
  final int retryAttempts;

  /// Maximum retry attempts allowed.
  final int maxRetryAttempts;

  /// Whether this result came from cached data.
  ///
  /// Cached results may be stale, especially during rapid state changes.
  final bool fromCache;

  /// Additional metadata for analytics, debugging, or custom use cases.
  ///
  /// Examples:
  /// - Timing information
  /// - Feature flags
  /// - A/B test variants
  /// - Custom tracking data
  final Map<String, dynamic> metadata;

  /// Timestamp when this result was created.
  final DateTime timestamp;

  /// Requested permissions (if in permission-related state).
  final List<String>? requestedPermissions;

  /// Granted permissions (if in permission-related state).
  final List<String>? grantedPermissions;

  OnboardingResult({
    required this.state,
    this.sdkStatus,
    this.deviceProfile,
    this.playStoreUri,
    this.errorMessage,
    this.userGuidance,
    this.requiresUserAction = false,
    this.canRetry = false,
    this.estimatedTime,
    this.retryAttempts = 0,
    this.maxRetryAttempts = 5,
    this.fromCache = false,
    this.metadata = const {},
    DateTime? timestamp,
    this.requestedPermissions,
    this.grantedPermissions,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Whether onboarding completed successfully.
  bool get isComplete => state == OnboardingState.complete;

  /// Whether onboarding failed.
  bool get isFailed => state == OnboardingState.failed;

  /// Whether onboarding is in progress (loading state).
  bool get isLoading => state.isLoading;

  /// Whether onboarding is in a terminal state (cannot auto-progress).
  bool get isTerminal => state.isTerminal;

  /// Whether SDK is available.
  bool get isSdkAvailable => sdkStatus?.status.isAvailable ?? false;

  /// Whether SDK requires update.
  bool get requiresSdkUpdate => sdkStatus?.status.requiresUpdate ?? false;

  /// Whether SDK requires install.
  bool get requiresSdkInstall => sdkStatus?.status.requiresInstall ?? false;

  /// Whether permissions are needed.
  bool get requiresPermissions => state == OnboardingState.permissionsNeeded;

  /// Whether all requested permissions were granted.
  bool get allPermissionsGranted {
    if (requestedPermissions == null || grantedPermissions == null) {
      return false;
    }
    return requestedPermissions!
        .every((perm) => grantedPermissions!.contains(perm));
  }

  /// Percentage of permissions granted (0.0 to 1.0).
  double get permissionGrantRate {
    if (requestedPermissions == null ||
        requestedPermissions!.isEmpty ||
        grantedPermissions == null) {
      return 0.0;
    }
    final granted = requestedPermissions!
        .where((perm) => grantedPermissions!.contains(perm))
        .length;
    return granted / requestedPermissions!.length;
  }

  /// Whether retry is available and recommended.
  bool get shouldRetry {
    return canRetry && retryAttempts < maxRetryAttempts;
  }

  /// Progress percentage (0.0 to 1.0).
  ///
  /// Rough estimation based on state. Useful for progress bars.
  double get progress {
    switch (state) {
      case OnboardingState.initial:
        return 0.0;
      case OnboardingState.checking:
        return 0.1;
      case OnboardingState.updateRequired:
      case OnboardingState.sdkUnavailable:
        return 0.2;
      case OnboardingState.updating:
      case OnboardingState.installing:
        return 0.4;
      case OnboardingState.verifying:
        return 0.6;
      case OnboardingState.sdkReady:
        return 0.7;
      case OnboardingState.permissionsNeeded:
        return 0.8;
      case OnboardingState.requestingPermissions:
        return 0.9;
      case OnboardingState.complete:
        return 1.0;
      case OnboardingState.failed:
      case OnboardingState.restartRequired:
        return 0.0; // Terminal states
    }
  }

  /// Get user-facing status message.
  String getStatusMessage() {
    if (userGuidance != null) {
      return userGuidance!;
    }
    return state.description;
  }

  /// Get recommended user action (button label).
  String? getActionLabel() {
    if (requiresSdkUpdate) {
      return 'Update Health Connect';
    }
    if (requiresSdkInstall) {
      return 'Install Health Connect';
    }
    if (requiresPermissions) {
      return 'Grant Permissions';
    }
    if (canRetry) {
      return 'Retry';
    }
    if (state == OnboardingState.restartRequired) {
      return 'Restart App';
    }
    return null;
  }

  /// Get diagnostic report for troubleshooting.
  String getDiagnosticReport() {
    final buffer = StringBuffer();
    buffer.writeln('Health Connect Onboarding Diagnostic Report');
    buffer.writeln('=' * 50);
    buffer.writeln('');

    buffer.writeln('Current State: ${state.displayName}');
    buffer.writeln('Timestamp: $timestamp');
    buffer.writeln('Progress: ${(progress * 100).toStringAsFixed(0)}%');
    buffer.writeln('');

    if (sdkStatus != null) {
      buffer.writeln('SDK Status:');
      buffer.writeln('  Status: ${sdkStatus!.status.displayName}');
      buffer.writeln('  Version: ${sdkStatus!.sdkVersion ?? 'unknown'}');
      buffer.writeln('  From Cache: ${sdkStatus!.fromCache}');
      if (sdkStatus!.checkDurationMs != null) {
        buffer.writeln('  Check Duration: ${sdkStatus!.checkDurationMs}ms');
      }
      buffer.writeln('');
    }

    if (deviceProfile != null) {
      buffer.writeln('Device Profile:');
      buffer.writeln('  Manufacturer: ${deviceProfile!.manufacturer}');
      if (deviceProfile!.model != null) {
        buffer.writeln('  Model: ${deviceProfile!.model}');
      }
      buffer.writeln('  Android: ${deviceProfile!.androidVersion} '
          '(SDK ${deviceProfile!.androidSdkVersion})');
      buffer.writeln('  Stub Risk: ${deviceProfile!.stubRiskLevel.name}');
      buffer.writeln('  Update Loop Bug: ${deviceProfile!.hasUpdateLoopBug}');
      buffer.writeln('  Native Steps: ${deviceProfile!.hasNativeStepTracking}');
      buffer.writeln('');
    }

    if (requestedPermissions != null) {
      buffer.writeln('Permissions:');
      buffer.writeln('  Requested: ${requestedPermissions!.length}');
      buffer.writeln('  Granted: ${grantedPermissions?.length ?? 0}');
      buffer.writeln('  Grant Rate: ${(permissionGrantRate * 100).toStringAsFixed(0)}%');
      buffer.writeln('');
    }

    buffer.writeln('Retry Information:');
    buffer.writeln('  Attempts: $retryAttempts / $maxRetryAttempts');
    buffer.writeln('  Can Retry: $canRetry');
    buffer.writeln('  Should Retry: $shouldRetry');
    buffer.writeln('');

    if (estimatedTime != null) {
      buffer.writeln('Estimated Time: ${estimatedTime!.inSeconds} seconds');
      buffer.writeln('');
    }

    if (errorMessage != null) {
      buffer.writeln('Error:');
      buffer.writeln('  Message: $errorMessage');
      buffer.writeln('');
    }

    if (metadata.isNotEmpty) {
      buffer.writeln('Metadata:');
      metadata.forEach((key, value) {
        buffer.writeln('  $key: $value');
      });
      buffer.writeln('');
    }

    buffer.writeln('User Action Required: $requiresUserAction');
    if (requiresUserAction) {
      final actionLabel = getActionLabel();
      if (actionLabel != null) {
        buffer.writeln('Recommended Action: $actionLabel');
      }
    }

    return buffer.toString();
  }

  /// Copy with updated fields.
  OnboardingResult copyWith({
    OnboardingState? state,
    SdkStatusInfo? sdkStatus,
    DeviceProfile? deviceProfile,
    String? playStoreUri,
    String? errorMessage,
    String? userGuidance,
    bool? requiresUserAction,
    bool? canRetry,
    Duration? estimatedTime,
    int? retryAttempts,
    int? maxRetryAttempts,
    bool? fromCache,
    Map<String, dynamic>? metadata,
    DateTime? timestamp,
    List<String>? requestedPermissions,
    List<String>? grantedPermissions,
  }) {
    return OnboardingResult(
      state: state ?? this.state,
      sdkStatus: sdkStatus ?? this.sdkStatus,
      deviceProfile: deviceProfile ?? this.deviceProfile,
      playStoreUri: playStoreUri ?? this.playStoreUri,
      errorMessage: errorMessage ?? this.errorMessage,
      userGuidance: userGuidance ?? this.userGuidance,
      requiresUserAction: requiresUserAction ?? this.requiresUserAction,
      canRetry: canRetry ?? this.canRetry,
      estimatedTime: estimatedTime ?? this.estimatedTime,
      retryAttempts: retryAttempts ?? this.retryAttempts,
      maxRetryAttempts: maxRetryAttempts ?? this.maxRetryAttempts,
      fromCache: fromCache ?? this.fromCache,
      metadata: metadata ?? this.metadata,
      timestamp: timestamp ?? this.timestamp,
      requestedPermissions: requestedPermissions ?? this.requestedPermissions,
      grantedPermissions: grantedPermissions ?? this.grantedPermissions,
    );
  }

  /// Convert to JSON for storage/analytics.
  Map<String, dynamic> toJson() {
    return {
      'state': state.name,
      'sdkStatus': sdkStatus?.toJson(),
      'deviceProfile': deviceProfile?.toJson(),
      'playStoreUri': playStoreUri,
      'errorMessage': errorMessage,
      'userGuidance': userGuidance,
      'requiresUserAction': requiresUserAction,
      'canRetry': canRetry,
      'estimatedTimeMs': estimatedTime?.inMilliseconds,
      'retryAttempts': retryAttempts,
      'maxRetryAttempts': maxRetryAttempts,
      'fromCache': fromCache,
      'metadata': metadata,
      'timestamp': timestamp.toIso8601String(),
      'requestedPermissions': requestedPermissions,
      'grantedPermissions': grantedPermissions,
    };
  }

  /// Create from JSON.
  factory OnboardingResult.fromJson(Map<String, dynamic> json) {
    return OnboardingResult(
      state: OnboardingState.values.firstWhere(
        (s) => s.name == json['state'],
        orElse: () => OnboardingState.initial,
      ),
      sdkStatus: json['sdkStatus'] != null
          ? SdkStatusInfo.fromJson(json['sdkStatus'] as Map<String, dynamic>)
          : null,
      deviceProfile: json['deviceProfile'] != null
          ? DeviceProfile.fromJson(
              json['deviceProfile'] as Map<String, dynamic>)
          : null,
      playStoreUri: json['playStoreUri'] as String?,
      errorMessage: json['errorMessage'] as String?,
      userGuidance: json['userGuidance'] as String?,
      requiresUserAction: json['requiresUserAction'] as bool? ?? false,
      canRetry: json['canRetry'] as bool? ?? false,
      estimatedTime: json['estimatedTimeMs'] != null
          ? Duration(milliseconds: json['estimatedTimeMs'] as int)
          : null,
      retryAttempts: json['retryAttempts'] as int? ?? 0,
      maxRetryAttempts: json['maxRetryAttempts'] as int? ?? 5,
      fromCache: json['fromCache'] as bool? ?? false,
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : null,
      requestedPermissions: (json['requestedPermissions'] as List?)
          ?.map((e) => e as String)
          .toList(),
      grantedPermissions: (json['grantedPermissions'] as List?)
          ?.map((e) => e as String)
          .toList(),
    );
  }

  @override
  String toString() {
    return 'OnboardingResult{'
        'state: ${state.name}, '
        'sdkAvailable: $isSdkAvailable, '
        'progress: ${(progress * 100).toStringAsFixed(0)}%, '
        'requiresUserAction: $requiresUserAction, '
        'canRetry: $canRetry'
        '}';
  }
}

/// Factory methods for creating common OnboardingResult instances.
extension OnboardingResultFactory on OnboardingResult {
  /// Create initial result.
  static OnboardingResult initial() {
    return OnboardingResult(
      state: OnboardingState.initial,
      userGuidance: 'Preparing to set up Health Connect...',
    );
  }

  /// Create checking result.
  static OnboardingResult checking({DeviceProfile? deviceProfile}) {
    return OnboardingResult(
      state: OnboardingState.checking,
      deviceProfile: deviceProfile,
      userGuidance: 'Checking Health Connect status...',
    );
  }

  /// Create update required result.
  static OnboardingResult updateRequired({
    required SdkStatusInfo sdkStatus,
    required DeviceProfile deviceProfile,
  }) {
    return OnboardingResult(
      state: OnboardingState.updateRequired,
      sdkStatus: sdkStatus,
      deviceProfile: deviceProfile,
      playStoreUri: sdkStatus.status.playStoreUri,
      userGuidance: deviceProfile.getUpdateInstructions(),
      requiresUserAction: true,
      estimatedTime: Duration(minutes: 2),
    );
  }

  /// Create complete result.
  static OnboardingResult complete({
    required SdkStatusInfo sdkStatus,
    DeviceProfile? deviceProfile,
    List<String>? grantedPermissions,
  }) {
    return OnboardingResult(
      state: OnboardingState.complete,
      sdkStatus: sdkStatus,
      deviceProfile: deviceProfile,
      grantedPermissions: grantedPermissions,
      userGuidance: 'Health Connect is ready! You can now sync your health data.',
    );
  }

  /// Create failed result.
  static OnboardingResult failed({
    required String errorMessage,
    SdkStatusInfo? sdkStatus,
    DeviceProfile? deviceProfile,
    bool canRetry = true,
    int retryAttempts = 0,
  }) {
    return OnboardingResult(
      state: OnboardingState.failed,
      sdkStatus: sdkStatus,
      deviceProfile: deviceProfile,
      errorMessage: errorMessage,
      userGuidance: 'Setup failed: $errorMessage',
      canRetry: canRetry,
      retryAttempts: retryAttempts,
    );
  }
}
