import 'package:flutter/services.dart';
import '../models/sdk_status.dart';
import '../models/device_profile.dart';

/// Component responsible for checking Health Connect SDK status.
///
/// This is the core component that communicates with the native Android layer
/// to determine if Health Connect is available, requires update, or is not installed.
///
/// **Key Responsibilities:**
/// - Query native `getSdkStatus()` API
/// - Handle platform channel errors
/// - Provide caching to avoid excessive platform calls
/// - Return structured [SdkStatusInfo] with metadata
///
/// **Performance:**
/// - Target: <500ms for initial check
/// - Target: <100ms for cached check
/// - Caches results for 5 seconds to reduce platform overhead
class SdkStatusChecker {
  final MethodChannel _channel;

  /// Cache for SDK status to avoid excessive platform calls.
  SdkStatusInfo? _cachedStatus;

  /// Cache duration (5 seconds).
  static const _cacheDuration = Duration(seconds: 5);

  SdkStatusChecker({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('health_sync_flutter/health_connect');

  /// Check Health Connect SDK status.
  ///
  /// Returns [SdkStatusInfo] containing the current status and metadata.
  ///
  /// **Parameters:**
  /// - [forceRefresh]: If true, bypasses cache and queries platform directly
  /// - [includeVersion]: If true, fetches SDK version (adds ~50ms overhead)
  ///
  /// **Example:**
  /// ```dart
  /// final checker = SdkStatusChecker();
  /// final status = await checker.checkStatus();
  ///
  /// if (status.status.requiresUpdate) {
  ///   // Direct user to Play Store
  /// }
  /// ```
  Future<SdkStatusInfo> checkStatus({
    bool forceRefresh = false,
    bool includeVersion = false,
  }) async {
    // Return cached status if valid
    if (!forceRefresh && _cachedStatus != null && !_cachedStatus!.isStale) {
      return _cachedStatus!;
    }

    final startTime = DateTime.now();

    try {
      // Call native getSdkStatus() API
      final result = await _channel.invokeMethod<Map>('getSdkStatus', {
        'includeVersion': includeVersion,
      });

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      if (result == null) {
        return _createErrorStatus(
          'getSdkStatus returned null',
          duration.inMilliseconds,
        );
      }

      // Parse status code
      final statusCode = result['statusCode'] as int? ?? -1;
      final status = SdkStatusExtension.fromNativeCode(statusCode);

      // Get device manufacturer for OEM-specific tracking
      final deviceProfile = await DeviceProfile.fromCurrentDevice();

      // Create status info
      final statusInfo = SdkStatusInfo(
        status: status,
        timestamp: endTime,
        sdkVersion: result['version'] as String?,
        packageVersionCode: result['versionCode'] as int?,
        fromCache: false,
        checkDurationMs: duration.inMilliseconds,
        manufacturer: deviceProfile.manufacturer,
      );

      // Cache the result
      _cachedStatus = statusInfo;

      return statusInfo;
    } on PlatformException catch (e) {
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      return _createErrorStatus(
        'Platform error: ${e.code} - ${e.message}',
        duration.inMilliseconds,
      );
    } catch (e) {
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      return _createErrorStatus(
        'Unexpected error: $e',
        duration.inMilliseconds,
      );
    }
  }

  /// Check if Health Connect is available (shorthand).
  ///
  /// Returns true if SDK status is [SdkStatus.available].
  ///
  /// **Example:**
  /// ```dart
  /// if (await checker.isAvailable()) {
  ///   // Proceed with Health Connect operations
  /// }
  /// ```
  Future<bool> isAvailable({bool forceRefresh = false}) async {
    final status = await checkStatus(forceRefresh: forceRefresh);
    return status.status.isAvailable;
  }

  /// Check if Health Connect requires update.
  ///
  /// Returns true if SDK status is [SdkStatus.unavailableProviderUpdateRequired].
  Future<bool> requiresUpdate({bool forceRefresh = false}) async {
    final status = await checkStatus(forceRefresh: forceRefresh);
    return status.status.requiresUpdate;
  }

  /// Check if Health Connect is not installed.
  ///
  /// Returns true if SDK status is [SdkStatus.unavailable].
  Future<bool> requiresInstall({bool forceRefresh = false}) async {
    final status = await checkStatus(forceRefresh: forceRefresh);
    return status.status.requiresInstall;
  }

  /// Get SDK version string.
  ///
  /// Returns null if SDK is not available or version cannot be determined.
  ///
  /// **Note:** This makes a platform call if not cached, so prefer
  /// calling [checkStatus] with `includeVersion: true` if you need both
  /// status and version.
  Future<String?> getSdkVersion() async {
    final status = await checkStatus(includeVersion: true);
    return status.sdkVersion;
  }

  /// Clear cached status.
  ///
  /// Forces next [checkStatus] call to query platform layer.
  /// Use this after user performs an action that may change status
  /// (like updating Health Connect).
  void clearCache() {
    _cachedStatus = null;
  }

  /// Get cached status (if available and not stale).
  ///
  /// Returns null if no valid cache exists.
  SdkStatusInfo? getCachedStatus() {
    if (_cachedStatus != null && !_cachedStatus!.isStale) {
      return _cachedStatus!.copyWith(fromCache: true);
    }
    return null;
  }

  /// Check status with retry logic.
  ///
  /// Retries the status check up to [maxAttempts] times with [delay] between attempts.
  /// Useful for handling transient errors or the "update loop bug".
  ///
  /// **Parameters:**
  /// - [maxAttempts]: Maximum number of retry attempts (default: 5)
  /// - [delay]: Delay between attempts (default: 1 second)
  /// - [targetStatus]: Optional target status to wait for (e.g., [SdkStatus.available])
  /// - [onRetry]: Optional callback invoked on each retry attempt
  ///
  /// **Example:**
  /// ```dart
  /// // Wait for SDK to become available after update
  /// final status = await checker.checkStatusWithRetry(
  ///   maxAttempts: 8,
  ///   delay: Duration(seconds: 2),
  ///   targetStatus: SdkStatus.available,
  ///   onRetry: (attempt, status) {
  ///     print('Retry $attempt: ${status.status.name}');
  ///   },
  /// );
  /// ```
  Future<SdkStatusInfo> checkStatusWithRetry({
    int maxAttempts = 5,
    Duration delay = const Duration(seconds: 1),
    SdkStatus? targetStatus,
    void Function(int attempt, SdkStatusInfo status)? onRetry,
  }) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      // Clear cache to force fresh check
      clearCache();

      final status = await checkStatus(forceRefresh: true);

      // If we got target status, return immediately
      if (targetStatus != null && status.status == targetStatus) {
        return status;
      }

      // If no target specified and status is not unknown, return
      if (targetStatus == null && !status.status.isUnknown) {
        return status;
      }

      // If this is the last attempt, return whatever we got
      if (attempt == maxAttempts) {
        return status;
      }

      // Notify callback
      if (onRetry != null) {
        onRetry(attempt, status);
      }

      // Wait before next attempt
      await Future.delayed(delay);
    }

    // Should never reach here, but return error status as fallback
    return _createErrorStatus(
      'Max retry attempts ($maxAttempts) exceeded',
      0,
    );
  }

  /// Stream SDK status changes with polling.
  ///
  /// Emits [SdkStatusInfo] at regular intervals.
  /// Useful for reactive UI that needs to track status changes.
  ///
  /// **Parameters:**
  /// - [interval]: Polling interval (default: 2 seconds)
  /// - [stopWhen]: Optional predicate to stop polling when condition met
  ///
  /// **Example:**
  /// ```dart
  /// // Monitor status until it becomes available
  /// await for (final status in checker.statusStream(
  ///   interval: Duration(seconds: 2),
  ///   stopWhen: (status) => status.status.isAvailable,
  /// )) {
  ///   print('Status: ${status.status.name}');
  /// }
  /// ```
  Stream<SdkStatusInfo> statusStream({
    Duration interval = const Duration(seconds: 2),
    bool Function(SdkStatusInfo)? stopWhen,
  }) async* {
    while (true) {
      clearCache();
      final status = await checkStatus(forceRefresh: true);
      yield status;

      // Stop if condition met
      if (stopWhen != null && stopWhen(status)) {
        break;
      }

      await Future.delayed(interval);
    }
  }

  /// Create error status info.
  SdkStatusInfo _createErrorStatus(String error, int durationMs) {
    return SdkStatusInfo(
      status: SdkStatus.unknown,
      timestamp: DateTime.now(),
      fromCache: false,
      checkDurationMs: durationMs,
      error: error,
    );
  }

  /// Create a mock status for testing.
  ///
  /// This is useful for testing UI components without actual Health Connect.
  ///
  /// **Example:**
  /// ```dart
  /// final mockChecker = SdkStatusChecker();
  /// final mockStatus = SdkStatusChecker.createMockStatus(
  ///   status: SdkStatus.available,
  ///   sdkVersion: '1.1.0-prerelease_2024_04_30',
  /// );
  /// ```
  static SdkStatusInfo createMockStatus({
    required SdkStatus status,
    String? sdkVersion,
    int? packageVersionCode,
    String? manufacturer,
  }) {
    return SdkStatusInfo(
      status: status,
      timestamp: DateTime.now(),
      sdkVersion: sdkVersion,
      packageVersionCode: packageVersionCode,
      fromCache: false,
      checkDurationMs: 100,
      manufacturer: manufacturer,
    );
  }
}
