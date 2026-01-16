/// Represents the current state of the Health Connect onboarding process.
///
/// This enum tracks the user's progress through the Health Connect setup flow,
/// from initial detection through to completion. It handles the "stub" reality
/// where Health Connect may be pre-installed but non-functional, requiring
/// Play Store updates before use.
///
/// State Machine Flow:
/// ```
/// initial -> checking -> [updateRequired|sdkUnavailable|sdkReady]
///   |
///   +-> updateRequired -> updating -> verifying -> sdkReady
///   |
///   +-> sdkUnavailable -> (user installs) -> verifying -> sdkReady
///   |
///   +-> sdkReady -> permissionsNeeded -> requestingPermissions -> complete
///   |
///   +-> failed (terminal state - requires retry)
///   +-> restartRequired (terminal state - requires app restart)
/// ```
enum OnboardingState {
  /// Initial state before any checks have been performed.
  ///
  /// The SDK has not yet queried the Health Connect status.
  initial,

  /// Actively checking Health Connect SDK status.
  ///
  /// Making platform call to determine current SDK availability.
  checking,

  /// Health Connect is installed but requires Play Store update.
  ///
  /// This is the "stub" state - Health Connect exists as a 10KB placeholder
  /// but needs to be hydrated from Play Store (15-30MB download).
  ///
  /// **Common on:**
  /// - Android 14/15 devices (Nothing, OnePlus, Motorola)
  /// - Devices that haven't updated Health Connect in 30+ days
  ///
  /// **User Action Required:** Update via Play Store
  updateRequired,

  /// Health Connect is not installed on this device.
  ///
  /// Rare on Android 14+, but possible on older devices or custom ROMs.
  ///
  /// **User Action Required:** Install from Play Store
  sdkUnavailable,

  /// User is actively updating Health Connect via Play Store.
  ///
  /// This state is set when the user taps "Update" and we deep-link to Play Store.
  /// We're waiting for them to return to the app.
  updating,

  /// User initiated Health Connect installation via Play Store.
  ///
  /// Similar to [updating] but for initial installation rather than update.
  installing,

  /// Verifying Health Connect is now ready after update/install.
  ///
  /// This handles the "update loop bug" where SDK status may still report
  /// `UPDATE_REQUIRED` for ~10 seconds after successful update due to
  /// platform caching issues.
  ///
  /// Retry logic with exponential backoff runs during this state.
  verifying,

  /// Health Connect SDK is ready and functional.
  ///
  /// The SDK has been verified as operational. Next step is permissions.
  sdkReady,

  /// Health Connect needs data access permissions.
  ///
  /// SDK is ready but the app doesn't have required permissions granted.
  /// User needs to grant access to data types (Steps, Heart Rate, etc.)
  permissionsNeeded,

  /// Actively requesting permissions from user.
  ///
  /// Permission dialog is displayed, waiting for user response.
  requestingPermissions,

  /// Onboarding flow completed successfully.
  ///
  /// Health Connect is ready and all required permissions are granted.
  /// The app can now read/write health data.
  complete,

  /// App restart required to complete setup.
  ///
  /// Some devices (rare) require app restart after Health Connect update
  /// for platform channels to properly initialize.
  ///
  /// **Terminal state** - requires user to restart app.
  restartRequired,

  /// Onboarding failed with an unrecoverable error.
  ///
  /// **Terminal state** - requires manual retry or troubleshooting.
  ///
  /// Examples:
  /// - Network timeout during status check
  /// - Play Store not available
  /// - User denied critical permissions multiple times
  /// - Device compatibility issue
  failed,
}

/// Extension methods for [OnboardingState] to provide additional context.
extension OnboardingStateExtension on OnboardingState {
  /// Whether this state requires user action to progress.
  bool get requiresUserAction {
    return this == OnboardingState.updateRequired ||
        this == OnboardingState.sdkUnavailable ||
        this == OnboardingState.permissionsNeeded ||
        this == OnboardingState.restartRequired;
  }

  /// Whether this state is a terminal state (cannot auto-progress).
  bool get isTerminal {
    return this == OnboardingState.complete ||
        this == OnboardingState.failed ||
        this == OnboardingState.restartRequired;
  }

  /// Whether this state indicates active processing (loading state).
  bool get isLoading {
    return this == OnboardingState.checking ||
        this == OnboardingState.updating ||
        this == OnboardingState.installing ||
        this == OnboardingState.verifying ||
        this == OnboardingState.requestingPermissions;
  }

  /// Whether this state indicates success (onboarding complete).
  bool get isSuccess {
    return this == OnboardingState.complete;
  }

  /// Whether this state indicates an error occurred.
  bool get isError {
    return this == OnboardingState.failed;
  }

  /// Whether this state allows retry operation.
  bool get canRetry {
    return this == OnboardingState.failed ||
        this == OnboardingState.updateRequired ||
        this == OnboardingState.sdkUnavailable;
  }

  /// Human-readable display name for this state.
  String get displayName {
    switch (this) {
      case OnboardingState.initial:
        return 'Initializing';
      case OnboardingState.checking:
        return 'Checking Health Connect';
      case OnboardingState.updateRequired:
        return 'Update Required';
      case OnboardingState.sdkUnavailable:
        return 'Health Connect Not Installed';
      case OnboardingState.updating:
        return 'Updating Health Connect';
      case OnboardingState.installing:
        return 'Installing Health Connect';
      case OnboardingState.verifying:
        return 'Verifying Installation';
      case OnboardingState.sdkReady:
        return 'Health Connect Ready';
      case OnboardingState.permissionsNeeded:
        return 'Permissions Required';
      case OnboardingState.requestingPermissions:
        return 'Requesting Permissions';
      case OnboardingState.complete:
        return 'Setup Complete';
      case OnboardingState.restartRequired:
        return 'Restart Required';
      case OnboardingState.failed:
        return 'Setup Failed';
    }
  }

  /// Detailed description of this state for user guidance.
  String get description {
    switch (this) {
      case OnboardingState.initial:
        return 'Preparing to set up Health Connect...';
      case OnboardingState.checking:
        return 'Checking if Health Connect is available on your device...';
      case OnboardingState.updateRequired:
        return 'Health Connect needs to be updated from the Play Store to continue.';
      case OnboardingState.sdkUnavailable:
        return 'Health Connect is not installed. Install it from the Play Store to continue.';
      case OnboardingState.updating:
        return 'Please update Health Connect in the Play Store, then return to this app.';
      case OnboardingState.installing:
        return 'Please install Health Connect from the Play Store, then return to this app.';
      case OnboardingState.verifying:
        return 'Verifying Health Connect is ready. This may take a few seconds...';
      case OnboardingState.sdkReady:
        return 'Health Connect is ready! Next, we need permission to access your health data.';
      case OnboardingState.permissionsNeeded:
        return 'This app needs permission to read and write health data.';
      case OnboardingState.requestingPermissions:
        return 'Please grant the requested permissions in the dialog...';
      case OnboardingState.complete:
        return 'Setup complete! You can now sync your health data.';
      case OnboardingState.restartRequired:
        return 'Please restart the app to complete Health Connect setup.';
      case OnboardingState.failed:
        return 'Setup failed. Please try again or check your device settings.';
    }
  }

  /// Recommended action for the user in this state.
  String? get userAction {
    switch (this) {
      case OnboardingState.updateRequired:
        return 'Tap "Update" to open the Play Store';
      case OnboardingState.sdkUnavailable:
        return 'Tap "Install" to open the Play Store';
      case OnboardingState.permissionsNeeded:
        return 'Tap "Grant Permissions" to continue';
      case OnboardingState.restartRequired:
        return 'Close and reopen the app';
      case OnboardingState.failed:
        return 'Tap "Retry" to try again';
      default:
        return null;
    }
  }
}
