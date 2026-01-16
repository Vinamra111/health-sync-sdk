import 'dart:async';
import 'package:flutter/services.dart';
import 'models/onboarding_state.dart';
import 'models/onboarding_result.dart';
import 'models/sdk_status.dart';
import 'models/device_profile.dart';
import 'components/sdk_status_checker.dart';
import 'components/retry_orchestrator.dart';
import 'components/device_advisor.dart';

/// Main orchestrator for Health Connect onboarding flow.
///
/// This service handles the complete onboarding process including:
/// - SDK status checking
/// - Play Store update/install flow
/// - Verification with retry logic (handles "update loop bug")
/// - Permission requests
/// - Device-specific optimizations
///
/// **Usage - Simple:**
/// ```dart
/// final service = HealthConnectOnboardingService();
///
/// final result = await service.checkAndInitialize();
///
/// if (result.requiresUserAction) {
///   // Show UI with action button
///   if (result.requiresSdkUpdate) {
///     await service.openPlayStore();
///   }
/// }
/// ```
///
/// **Usage - Reactive (Streams):**
/// ```dart
/// service.stateStream.listen((state) {
///   print('State: ${state.displayName}');
/// });
///
/// service.resultStream.listen((result) {
///   updateUI(result);
/// });
///
/// await service.checkAndInitialize();
/// ```
class HealthConnectOnboardingService {
  final SdkStatusChecker _statusChecker;
  final RetryOrchestrator _retryOrchestrator;
  final DeviceAdvisor _deviceAdvisor;
  final MethodChannel _channel;

  /// Stream controller for state changes.
  final _stateController = StreamController<OnboardingState>.broadcast();

  /// Stream controller for result updates.
  final _resultController = StreamController<OnboardingResult>.broadcast();

  /// Current onboarding state.
  OnboardingState _currentState = OnboardingState.initial;

  /// Current result.
  OnboardingResult? _currentResult;

  /// Device profile (cached after first load).
  DeviceProfile? _deviceProfile;

  /// Whether onboarding is currently in progress.
  bool _isRunning = false;

  HealthConnectOnboardingService({
    SdkStatusChecker? statusChecker,
    RetryOrchestrator? retryOrchestrator,
    DeviceAdvisor? deviceAdvisor,
    MethodChannel? channel,
  })  : _statusChecker = statusChecker ?? SdkStatusChecker(),
        _retryOrchestrator = retryOrchestrator ?? RetryOrchestrator(),
        _deviceAdvisor = deviceAdvisor ?? DeviceAdvisor(),
        _channel = channel ?? const MethodChannel('health_sync_flutter/health_connect');

  /// Stream of onboarding state changes.
  ///
  /// Emits [OnboardingState] whenever state transitions occur.
  Stream<OnboardingState> get stateStream => _stateController.stream;

  /// Stream of onboarding result updates.
  ///
  /// Emits [OnboardingResult] with comprehensive status information.
  Stream<OnboardingResult> get resultStream => _resultController.stream;

  /// Current onboarding state.
  OnboardingState get currentState => _currentState;

  /// Current result (may be null if not started).
  OnboardingResult? get currentResult => _currentResult;

  /// Whether onboarding is currently running.
  bool get isRunning => _isRunning;

  /// Check Health Connect status and initialize if needed.
  ///
  /// This is the main entry point for the onboarding flow.
  ///
  /// **Parameters:**
  /// - [requiredPermissions]: Optional list of permission IDs needed
  /// - [retryStrategy]: Custom retry strategy (defaults to device-optimized)
  /// - [checkNativeStepTracking]: Whether to check for native step tracking
  /// - [autoOpenPlayStore]: Whether to automatically open Play Store on update/install needed
  ///
  /// **Returns:** [OnboardingResult] with final state
  ///
  /// **Example:**
  /// ```dart
  /// final result = await service.checkAndInitialize(
  ///   requiredPermissions: ['Steps', 'HeartRate'],
  ///   checkNativeStepTracking: true,
  /// );
  ///
  /// if (result.isComplete) {
  ///   // Ready to use Health Connect!
  /// }
  /// ```
  Future<OnboardingResult> checkAndInitialize({
    List<String>? requiredPermissions,
    RetryStrategy? retryStrategy,
    bool checkNativeStepTracking = true,
    bool autoOpenPlayStore = false,
  }) async {
    if (_isRunning) {
      return _currentResult ?? OnboardingResultFactory.initial();
    }

    _isRunning = true;
    _updateState(OnboardingState.initial);

    try {
      // Step 1: Load device profile
      _deviceProfile = await _deviceAdvisor.getDeviceProfile();

      // Step 2: Check SDK status
      _updateState(OnboardingState.checking);

      final sdkStatus = await _statusChecker.checkStatus(
        forceRefresh: true,
        includeVersion: true,
      );

      // Step 3: Handle different SDK statuses
      if (sdkStatus.status.isAvailable) {
        // SDK is ready - proceed to permissions
        return await _handleSdkReady(
          sdkStatus: sdkStatus,
          requiredPermissions: requiredPermissions,
        );
      } else if (sdkStatus.status.requiresUpdate) {
        // SDK requires update
        return await _handleUpdateRequired(
          sdkStatus: sdkStatus,
          retryStrategy: retryStrategy,
          autoOpenPlayStore: autoOpenPlayStore,
        );
      } else if (sdkStatus.status.requiresInstall) {
        // SDK not installed
        return await _handleInstallRequired(
          sdkStatus: sdkStatus,
          autoOpenPlayStore: autoOpenPlayStore,
        );
      } else {
        // Unknown status
        return await _handleUnknownStatus(sdkStatus: sdkStatus);
      }
    } catch (e) {
      return _handleError(e, 'Onboarding failed');
    } finally {
      _isRunning = false;
    }
  }

  /// Handle SDK ready state - check permissions.
  Future<OnboardingResult> _handleSdkReady({
    required SdkStatusInfo sdkStatus,
    List<String>? requiredPermissions,
  }) async {
    _updateState(OnboardingState.sdkReady);

    // If no permissions specified, we're done
    if (requiredPermissions == null || requiredPermissions.isEmpty) {
      final result = OnboardingResultFactory.complete(
        sdkStatus: sdkStatus,
        deviceProfile: _deviceProfile,
      );
      _emitResult(result);
      return result;
    }

    // Check current permissions
    try {
      final grantedPermissions = await _checkPermissions(requiredPermissions);

      final allGranted = requiredPermissions.every(
        (perm) => grantedPermissions.contains(perm),
      );

      if (allGranted) {
        // All permissions granted - complete
        final result = OnboardingResultFactory.complete(
          sdkStatus: sdkStatus,
          deviceProfile: _deviceProfile,
          grantedPermissions: grantedPermissions,
        );
        _emitResult(result);
        return result;
      } else {
        // Permissions needed
        _updateState(OnboardingState.permissionsNeeded);

        final result = OnboardingResult(
          state: OnboardingState.permissionsNeeded,
          sdkStatus: sdkStatus,
          deviceProfile: _deviceProfile,
          userGuidance: 'Grant permissions to access your health data',
          requiresUserAction: true,
          requestedPermissions: requiredPermissions,
          grantedPermissions: grantedPermissions,
        );

        _emitResult(result);
        return result;
      }
    } catch (e) {
      return _handleError(e, 'Failed to check permissions');
    }
  }

  /// Handle update required state.
  Future<OnboardingResult> _handleUpdateRequired({
    required SdkStatusInfo sdkStatus,
    RetryStrategy? retryStrategy,
    bool autoOpenPlayStore = false,
  }) async {
    _updateState(OnboardingState.updateRequired);

    final result = OnboardingResultFactory.updateRequired(
      sdkStatus: sdkStatus,
      deviceProfile: _deviceProfile!,
    );

    _emitResult(result);

    // Auto-open Play Store if requested
    if (autoOpenPlayStore) {
      await openPlayStore();
    }

    return result;
  }

  /// Handle install required state.
  Future<OnboardingResult> _handleInstallRequired({
    required SdkStatusInfo sdkStatus,
    bool autoOpenPlayStore = false,
  }) async {
    _updateState(OnboardingState.sdkUnavailable);

    final result = OnboardingResult(
      state: OnboardingState.sdkUnavailable,
      sdkStatus: sdkStatus,
      deviceProfile: _deviceProfile,
      playStoreUri: sdkStatus.status.playStoreUri,
      userGuidance: 'Health Connect needs to be installed from the Play Store',
      requiresUserAction: true,
      estimatedTime: await _deviceAdvisor.getEstimatedSetupTime(sdkStatus.status),
    );

    _emitResult(result);

    // Auto-open Play Store if requested
    if (autoOpenPlayStore) {
      await openPlayStore();
    }

    return result;
  }

  /// Handle unknown SDK status.
  Future<OnboardingResult> _handleUnknownStatus({
    required SdkStatusInfo sdkStatus,
  }) async {
    _updateState(OnboardingState.failed);

    final troubleshooting = await _deviceAdvisor.getTroubleshootingAdvice(
      sdkStatus: sdkStatus.status,
      errorMessage: sdkStatus.error,
    );

    final result = OnboardingResultFactory.failed(
      errorMessage: sdkStatus.error ?? 'Unable to determine Health Connect status',
      sdkStatus: sdkStatus,
      deviceProfile: _deviceProfile,
      canRetry: true,
    );

    _emitResult(result);
    return result;
  }

  /// Handle errors during onboarding.
  OnboardingResult _handleError(dynamic error, String context) {
    _updateState(OnboardingState.failed);

    final result = OnboardingResultFactory.failed(
      errorMessage: '$context: $error',
      sdkStatus: _currentResult?.sdkStatus,
      deviceProfile: _deviceProfile,
      canRetry: true,
    );

    _emitResult(result);
    return result;
  }

  /// Verify Health Connect after user updates/installs.
  ///
  /// Call this after user returns from Play Store. Uses retry logic
  /// to handle the "update loop bug".
  ///
  /// **Parameters:**
  /// - [customStrategy]: Optional custom retry strategy
  /// - [requiredPermissions]: Permissions to check after verification
  ///
  /// **Example:**
  /// ```dart
  /// // After user taps "Update" and returns from Play Store
  /// final result = await service.verifyAfterUpdate();
  ///
  /// if (result.isSdkAvailable) {
  ///   // Update successful!
  /// }
  /// ```
  Future<OnboardingResult> verifyAfterUpdate({
    RetryStrategy? customStrategy,
    List<String>? requiredPermissions,
  }) async {
    _updateState(OnboardingState.verifying);

    // Get device-optimized retry strategy
    final strategy = customStrategy ?? await _deviceAdvisor.getRetryStrategy();

    // Clear status cache to force fresh check
    _statusChecker.clearCache();

    // Retry until SDK becomes available
    final retryResult = await _retryOrchestrator.execute<SdkStatusInfo>(
      () async {
        final status = await _statusChecker.checkStatus(forceRefresh: true);

        // If SDK is available, success!
        if (status.status.isAvailable) {
          return status;
        }

        // If still requires update/install, keep retrying
        if (status.status.requiresUpdate || status.status.requiresInstall) {
          throw Exception('SDK still requires action: ${status.status.name}');
        }

        // Unknown error
        throw Exception('SDK status unknown: ${status.error}');
      },
      strategy: strategy,
      shouldRetry: RetryPredicates.retryOnUpdateRequired,
      onAttempt: (attempt) {
        // Emit progress updates
        final result = OnboardingResult(
          state: OnboardingState.verifying,
          sdkStatus: _currentResult?.sdkStatus,
          deviceProfile: _deviceProfile,
          userGuidance: 'Verifying Health Connect... '
              '(Attempt ${attempt.attemptNumber}/${attempt.maxAttempts})',
          retryAttempts: attempt.attemptNumber,
          maxRetryAttempts: attempt.maxAttempts,
        );
        _emitResult(result);
      },
    );

    if (retryResult.success && retryResult.value != null) {
      // SDK is now available!
      return await _handleSdkReady(
        sdkStatus: retryResult.value!,
        requiredPermissions: requiredPermissions,
      );
    } else {
      // Verification failed after all retries
      return _handleError(
        retryResult.error ?? 'Verification failed',
        'Health Connect verification failed after ${retryResult.attempts} attempts',
      );
    }
  }

  /// Open Play Store to update/install Health Connect.
  ///
  /// Opens the Health Connect page in Google Play Store app.
  /// Falls back to web URL if Play Store app is not available.
  ///
  /// **Returns:** True if successfully opened, false otherwise
  ///
  /// **Example:**
  /// ```dart
  /// if (result.requiresSdkUpdate) {
  ///   await service.openPlayStore();
  ///   // Wait for user to return, then verify
  ///   await service.verifyAfterUpdate();
  /// }
  /// ```
  Future<bool> openPlayStore() async {
    try {
      _updateState(OnboardingState.updating);

      // Try market:// URI first (opens Play Store app)
      final marketUri = 'market://details?id=com.google.android.apps.healthdata';

      final result = await _channel.invokeMethod<bool>(
        'openUrl',
        {'url': marketUri},
      );

      return result ?? false;
    } catch (e) {
      // Fallback to web URL
      try {
        final webUrl =
            'https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata';

        final result = await _channel.invokeMethod<bool>(
          'openUrl',
          {'url': webUrl},
        );

        return result ?? false;
      } catch (e2) {
        return false;
      }
    }
  }

  /// Request Health Connect permissions.
  ///
  /// Opens Health Connect permission dialog for specified data types.
  ///
  /// **Parameters:**
  /// - [permissions]: List of permission IDs to request
  ///
  /// **Returns:** [OnboardingResult] with granted permissions
  ///
  /// **Example:**
  /// ```dart
  /// final result = await service.requestPermissions(['Steps', 'HeartRate']);
  ///
  /// if (result.allPermissionsGranted) {
  ///   // All permissions granted!
  /// }
  /// ```
  Future<OnboardingResult> requestPermissions(List<String> permissions) async {
    _updateState(OnboardingState.requestingPermissions);

    try {
      // Call platform method to request permissions
      final granted = await _channel.invokeMethod<List>(
        'requestPermissions',
        {'permissions': permissions},
      );

      final grantedPermissions = granted?.cast<String>() ?? [];

      final allGranted = permissions.every(
        (perm) => grantedPermissions.contains(perm),
      );

      if (allGranted) {
        // All permissions granted - complete!
        final result = OnboardingResultFactory.complete(
          sdkStatus: _currentResult!.sdkStatus!,
          deviceProfile: _deviceProfile,
          grantedPermissions: grantedPermissions,
        );

        _emitResult(result);
        return result;
      } else {
        // Some permissions denied
        final result = OnboardingResult(
          state: OnboardingState.permissionsNeeded,
          sdkStatus: _currentResult?.sdkStatus,
          deviceProfile: _deviceProfile,
          userGuidance: 'Some permissions were not granted. '
              'The app may not function correctly.',
          requestedPermissions: permissions,
          grantedPermissions: grantedPermissions,
          requiresUserAction: true,
        );

        _emitResult(result);
        return result;
      }
    } catch (e) {
      return _handleError(e, 'Permission request failed');
    }
  }

  /// Check which permissions are currently granted.
  Future<List<String>> _checkPermissions(List<String> permissions) async {
    try {
      final result = await _channel.invokeMethod<List>(
        'checkPermissions',
        {'permissions': permissions},
      );

      return result?.cast<String>() ?? [];
    } catch (e) {
      return [];
    }
  }

  /// Retry the onboarding process manually.
  ///
  /// Useful when user wants to retry after fixing an issue.
  ///
  /// **Example:**
  /// ```dart
  /// if (result.canRetry) {
  ///   await service.retryManually();
  /// }
  /// ```
  Future<OnboardingResult> retryManually({
    List<String>? requiredPermissions,
  }) async {
    _statusChecker.clearCache();
    _deviceAdvisor.clearCache();

    return await checkAndInitialize(
      requiredPermissions: requiredPermissions,
    );
  }

  /// Cancel ongoing onboarding process.
  ///
  /// Stops retry logic and resets to initial state.
  void cancel() {
    _retryOrchestrator.cancel();
    _isRunning = false;
    _updateState(OnboardingState.initial);
  }

  /// Reset onboarding state.
  ///
  /// Clears all caches and resets to initial state.
  void reset() {
    _statusChecker.clearCache();
    _deviceAdvisor.clearCache();
    _retryOrchestrator.reset();
    _currentState = OnboardingState.initial;
    _currentResult = null;
    _deviceProfile = null;
    _isRunning = false;
  }

  /// Get diagnostic report for troubleshooting.
  ///
  /// Returns comprehensive report with device info, SDK status, and state.
  ///
  /// **Example:**
  /// ```dart
  /// print(await service.getDiagnosticReport());
  /// ```
  Future<String> getDiagnosticReport() async {
    final buffer = StringBuffer();

    buffer.writeln('Health Connect Onboarding Diagnostic Report');
    buffer.writeln('=' * 60);
    buffer.writeln('');

    if (_currentResult != null) {
      buffer.writeln(_currentResult!.getDiagnosticReport());
    } else {
      buffer.writeln('No active onboarding session');
      buffer.writeln('');
    }

    if (_deviceProfile != null) {
      buffer.writeln(await _deviceAdvisor.getCompatibilityReport());
    }

    return buffer.toString();
  }

  /// Update state and emit to stream.
  void _updateState(OnboardingState newState) {
    _currentState = newState;
    _stateController.add(newState);
  }

  /// Emit result to stream.
  void _emitResult(OnboardingResult result) {
    _currentResult = result;
    _resultController.add(result);
  }

  /// Dispose of resources.
  void dispose() {
    _stateController.close();
    _resultController.close();
    _retryOrchestrator.dispose();
  }
}
