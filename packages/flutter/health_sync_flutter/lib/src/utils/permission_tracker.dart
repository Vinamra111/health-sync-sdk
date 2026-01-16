import '../plugins/health_connect/health_connect_types.dart';
import 'logger.dart';

/// Permission failure reason
enum PermissionFailureReason {
  /// User denied the permission
  userDenied,

  /// Permission not available on this device/OS version
  notAvailable,

  /// System error occurred
  systemError,

  /// Health Connect not installed
  healthConnectNotInstalled,

  /// Permission already granted (not a failure, but tracked)
  alreadyGranted,

  /// Timeout waiting for user response
  timeout,

  /// Unknown reason
  unknown,
}

/// Permission request result detail
class PermissionRequestResult {
  final HealthConnectPermission permission;
  final bool granted;
  final PermissionFailureReason? failureReason;
  final String? errorMessage;
  final DateTime timestamp;
  final int attemptNumber;

  const PermissionRequestResult({
    required this.permission,
    required this.granted,
    this.failureReason,
    this.errorMessage,
    required this.timestamp,
    this.attemptNumber = 1,
  });

  Map<String, dynamic> toJson() {
    return {
      'permission': permission.toValue(),
      'granted': granted,
      'failureReason': failureReason?.name,
      'errorMessage': errorMessage,
      'timestamp': timestamp.toIso8601String(),
      'attemptNumber': attemptNumber,
    };
  }
}

/// Permission analytics data
class PermissionAnalytics {
  final Map<HealthConnectPermission, int> _requestCounts = {};
  final Map<HealthConnectPermission, int> _successCounts = {};
  final Map<HealthConnectPermission, int> _failureCounts = {};
  final Map<HealthConnectPermission, List<PermissionFailureReason>> _failureReasons = {};
  final List<PermissionRequestResult> _history = [];

  /// Track a permission request result
  void trackPermissionRequest(PermissionRequestResult result) {
    final perm = result.permission;

    // Update counters
    _requestCounts[perm] = (_requestCounts[perm] ?? 0) + 1;

    if (result.granted) {
      _successCounts[perm] = (_successCounts[perm] ?? 0) + 1;
    } else {
      _failureCounts[perm] = (_failureCounts[perm] ?? 0) + 1;

      if (result.failureReason != null) {
        _failureReasons.putIfAbsent(perm, () => []);
        _failureReasons[perm]!.add(result.failureReason!);
      }
    }

    // Add to history
    _history.add(result);
    if (_history.length > 500) {
      _history.removeAt(0); // Keep last 500 entries
    }

    // Log the failure
    if (!result.granted) {
      logger.warning(
        'Permission request failed',
        category: 'PermissionTracker',
        metadata: {
          'permission': perm.toValue(),
          'reason': result.failureReason?.name ?? 'unknown',
          'errorMessage': result.errorMessage,
          'attemptNumber': result.attemptNumber,
        },
      );
    }
  }

  /// Get success rate for a permission (0.0 to 1.0)
  double getSuccessRate(HealthConnectPermission permission) {
    final requests = _requestCounts[permission] ?? 0;
    if (requests == 0) return 0.0;

    final successes = _successCounts[permission] ?? 0;
    return successes / requests;
  }

  /// Get failure rate for a permission (0.0 to 1.0)
  double getFailureRate(HealthConnectPermission permission) {
    return 1.0 - getSuccessRate(permission);
  }

  /// Get most common failure reason for a permission
  PermissionFailureReason? getMostCommonFailureReason(HealthConnectPermission permission) {
    final reasons = _failureReasons[permission];
    if (reasons == null || reasons.isEmpty) return null;

    final reasonCounts = <PermissionFailureReason, int>{};
    for (final reason in reasons) {
      reasonCounts[reason] = (reasonCounts[reason] ?? 0) + 1;
    }

    return reasonCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  /// Get permissions with highest failure rates
  List<MapEntry<HealthConnectPermission, double>> getProblematicPermissions({int limit = 10}) {
    final entries = _requestCounts.entries
        .where((e) => e.value >= 2) // At least 2 requests
        .map((e) => MapEntry(e.key, getFailureRate(e.key)))
        .where((e) => e.value > 0) // Has failures
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value)); // Sort by failure rate

    return entries.take(limit).toList();
  }

  /// Get permission request history
  List<PermissionRequestResult> getHistory({HealthConnectPermission? permission}) {
    if (permission == null) return List.unmodifiable(_history);

    return _history.where((r) => r.permission == permission).toList();
  }

  /// Export analytics as JSON
  Map<String, dynamic> toJson() {
    return {
      'totalRequests': _requestCounts.values.fold(0, (sum, count) => sum + count),
      'totalSuccesses': _successCounts.values.fold(0, (sum, count) => sum + count),
      'totalFailures': _failureCounts.values.fold(0, (sum, count) => sum + count),
      'permissionStats': _requestCounts.keys.map((perm) {
        return {
          'permission': perm.toValue(),
          'requests': _requestCounts[perm] ?? 0,
          'successes': _successCounts[perm] ?? 0,
          'failures': _failureCounts[perm] ?? 0,
          'successRate': getSuccessRate(perm),
          'failureRate': getFailureRate(perm),
          'mostCommonFailureReason': getMostCommonFailureReason(perm)?.name,
        };
      }).toList(),
      'problematicPermissions': getProblematicPermissions().map((e) {
        return {
          'permission': e.key.toValue(),
          'failureRate': e.value,
        };
      }).toList(),
    };
  }

  /// Generate a diagnostic report
  String generateDiagnosticReport() {
    final buffer = StringBuffer();
    buffer.writeln('=== HealthSync Permission Diagnostic Report ===');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln();

    final totalRequests = _requestCounts.values.fold(0, (sum, count) => sum + count);
    final totalSuccesses = _successCounts.values.fold(0, (sum, count) => sum + count);
    final totalFailures = _failureCounts.values.fold(0, (sum, count) => sum + count);

    buffer.writeln('Total Statistics:');
    buffer.writeln('  Total Requests: $totalRequests');
    buffer.writeln('  Successes: $totalSuccesses');
    buffer.writeln('  Failures: $totalFailures');
    if (totalRequests > 0) {
      buffer.writeln('  Overall Success Rate: ${(totalSuccesses / totalRequests * 100).toStringAsFixed(1)}%');
    }
    buffer.writeln();

    final problematic = getProblematicPermissions();
    if (problematic.isNotEmpty) {
      buffer.writeln('Problematic Permissions (High Failure Rate):');
      for (final entry in problematic) {
        final reason = getMostCommonFailureReason(entry.key);
        buffer.writeln('  ${entry.key.toValue()}:');
        buffer.writeln('    Failure Rate: ${(entry.value * 100).toStringAsFixed(1)}%');
        buffer.writeln('    Requests: ${_requestCounts[entry.key]}');
        buffer.writeln('    Failures: ${_failureCounts[entry.key]}');
        if (reason != null) {
          buffer.writeln('    Most Common Reason: ${reason.name}');
        }
      }
      buffer.writeln();
    }

    buffer.writeln('Recommendations:');
    if (problematic.isEmpty) {
      buffer.writeln('  ✓ All permissions are performing well!');
    } else {
      for (final entry in problematic) {
        final reason = getMostCommonFailureReason(entry.key);
        buffer.writeln('  • ${entry.key.toValue()}:');

        switch (reason) {
          case PermissionFailureReason.userDenied:
            buffer.writeln('    - Improve permission rationale/education');
            buffer.writeln('    - Show benefits of granting this permission');
            break;
          case PermissionFailureReason.notAvailable:
            buffer.writeln('    - Check device compatibility before requesting');
            buffer.writeln('    - Provide fallback functionality');
            break;
          case PermissionFailureReason.healthConnectNotInstalled:
            buffer.writeln('    - Prompt user to install Health Connect');
            buffer.writeln('    - Provide installation link');
            break;
          case PermissionFailureReason.systemError:
            buffer.writeln('    - Investigate system-level issues');
            buffer.writeln('    - Check for OS version compatibility');
            break;
          default:
            buffer.writeln('    - Investigate failure reasons');
        }
      }
    }

    return buffer.toString();
  }

  /// Clear all analytics data
  void clear() {
    _requestCounts.clear();
    _successCounts.clear();
    _failureCounts.clear();
    _failureReasons.clear();
    _history.clear();
  }
}

/// Global permission tracker instance
final permissionTracker = PermissionAnalytics();
