import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Background sync execution statistics
///
/// Tracks background sync execution history to monitor reliability
/// and identify issues.
class BackgroundSyncStats {
  static const String _keyPrefix = 'health_sync_bg_stats_';

  /// Last execution time
  DateTime? lastExecution;

  /// Last successful execution time
  DateTime? lastSuccessfulExecution;

  /// Total number of executions
  int totalExecutions;

  /// Number of successful executions
  int successfulExecutions;

  /// Number of failed executions
  int failedExecutions;

  /// Average delay from scheduled time (milliseconds)
  ///
  /// How late background tasks run compared to when they were scheduled.
  /// High delays indicate system is deferring tasks.
  double averageDelay;

  /// Last failure reason
  String? lastFailureReason;

  /// Last failure time
  DateTime? lastFailureTime;

  /// Map of failure reasons to their occurrence count
  Map<String, int> failureReasons;

  BackgroundSyncStats({
    this.lastExecution,
    this.lastSuccessfulExecution,
    this.totalExecutions = 0,
    this.successfulExecutions = 0,
    this.failedExecutions = 0,
    this.averageDelay = 0.0,
    this.lastFailureReason,
    this.lastFailureTime,
    Map<String, int>? failureReasons,
  }) : failureReasons = failureReasons ?? {};

  /// Success rate (0.0 to 1.0)
  double get successRate {
    if (totalExecutions == 0) return 1.0;
    return successfulExecutions / totalExecutions;
  }

  /// Failure rate (0.0 to 1.0)
  double get failureRate => 1.0 - successRate;

  /// Whether sync is healthy (>=80% success rate)
  bool get isHealthy => successRate >= 0.8;

  /// Time since last execution
  Duration? get timeSinceLastExecution {
    if (lastExecution == null) return null;
    return DateTime.now().difference(lastExecution!);
  }

  /// Time since last successful execution
  Duration? get timeSinceLastSuccess {
    if (lastSuccessfulExecution == null) return null;
    return DateTime.now().difference(lastSuccessfulExecution!);
  }

  /// Whether sync appears to be stuck (>24 hours since last success)
  bool get appearsStuck {
    final sinceSuccess = timeSinceLastSuccess;
    return sinceSuccess != null && sinceSuccess > Duration(hours: 24);
  }

  /// Alias for lastFailureTime (for test compatibility)
  DateTime? get lastFailedExecution => lastFailureTime;

  /// Get the most common failure reason
  String? get mostCommonFailureReason {
    if (failureReasons.isEmpty) return null;

    String? mostCommon;
    int maxCount = 0;

    failureReasons.forEach((reason, count) {
      if (count > maxCount) {
        maxCount = count;
        mostCommon = reason;
      }
    });

    return mostCommon;
  }

  /// Record successful execution
  void recordSuccess({
    required DateTime executionTime,
    Duration? delay,
  }) {
    lastExecution = executionTime;
    lastSuccessfulExecution = executionTime;
    totalExecutions++;
    successfulExecutions++;

    if (delay != null) {
      // Update rolling average delay
      final newDelay = delay.inMilliseconds.toDouble();
      averageDelay = ((averageDelay * (totalExecutions - 1)) + newDelay) / totalExecutions;
    }
  }

  /// Record failed execution
  void recordFailure({
    required DateTime executionTime,
    String? reason,
  }) {
    lastExecution = executionTime;
    lastFailureTime = executionTime;
    lastFailureReason = reason;
    totalExecutions++;
    failedExecutions++;

    // Track failure reasons
    if (reason != null) {
      failureReasons[reason] = (failureReasons[reason] ?? 0) + 1;
    }
  }

  /// Reset statistics
  void reset() {
    lastExecution = null;
    lastSuccessfulExecution = null;
    totalExecutions = 0;
    successfulExecutions = 0;
    failedExecutions = 0;
    averageDelay = 0.0;
    lastFailureReason = null;
    lastFailureTime = null;
    failureReasons.clear();
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'lastExecution': lastExecution?.toIso8601String(),
      'lastSuccessfulExecution': lastSuccessfulExecution?.toIso8601String(),
      'totalExecutions': totalExecutions,
      'successfulExecutions': successfulExecutions,
      'failedExecutions': failedExecutions,
      'averageDelay': averageDelay,
      'lastFailureReason': lastFailureReason,
      'lastFailureTime': lastFailureTime?.toIso8601String(),
      'failureReasons': failureReasons,
    };
  }

  /// Create from JSON
  factory BackgroundSyncStats.fromJson(Map<String, dynamic> json) {
    return BackgroundSyncStats(
      lastExecution: json['lastExecution'] != null
          ? DateTime.parse(json['lastExecution'] as String)
          : null,
      lastSuccessfulExecution: json['lastSuccessfulExecution'] != null
          ? DateTime.parse(json['lastSuccessfulExecution'] as String)
          : null,
      totalExecutions: json['totalExecutions'] as int? ?? 0,
      successfulExecutions: json['successfulExecutions'] as int? ?? 0,
      failedExecutions: json['failedExecutions'] as int? ?? 0,
      averageDelay: (json['averageDelay'] as num?)?.toDouble() ?? 0.0,
      lastFailureReason: json['lastFailureReason'] as String?,
      lastFailureTime: json['lastFailureTime'] != null
          ? DateTime.parse(json['lastFailureTime'] as String)
          : null,
      failureReasons: Map<String, int>.from(json['failureReasons'] as Map? ?? {}),
    );
  }

  /// Save to persistent storage
  Future<void> save(String taskTag) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyPrefix + taskTag;
    await prefs.setString(key, jsonEncode(toJson()));
  }

  /// Load from persistent storage
  static Future<BackgroundSyncStats> load(String taskTag) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _keyPrefix + taskTag;
    final jsonString = prefs.getString(key);

    if (jsonString == null) {
      return BackgroundSyncStats();
    }

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return BackgroundSyncStats.fromJson(json);
    } catch (e) {
      return BackgroundSyncStats();
    }
  }

  /// Get diagnostic report
  String getReport() {
    final buffer = StringBuffer();
    buffer.writeln('Background Sync Statistics');
    buffer.writeln('');

    buffer.writeln('Execution History:');
    buffer.writeln('  Total Executions: $totalExecutions');
    buffer.writeln('  Successful: $successfulExecutions');
    buffer.writeln('  Failed: $failedExecutions');
    buffer.writeln('  Success Rate: ${(successRate * 100).toStringAsFixed(1)}%');
    buffer.writeln('');

    if (lastExecution != null) {
      buffer.writeln('Last Execution: $lastExecution');
      buffer.writeln('  Time Since: ${timeSinceLastExecution!.inMinutes} minutes ago');
    } else {
      buffer.writeln('Last Execution: Never');
    }
    buffer.writeln('');

    if (lastSuccessfulExecution != null) {
      buffer.writeln('Last Success: $lastSuccessfulExecution');
      buffer.writeln('  Time Since: ${timeSinceLastSuccess!.inMinutes} minutes ago');
    } else {
      buffer.writeln('Last Success: Never');
    }
    buffer.writeln('');

    if (averageDelay > 0) {
      buffer.writeln('Average Delay: ${(averageDelay / 1000 / 60).toStringAsFixed(1)} minutes');
      if (averageDelay > 3600000) {
        // > 1 hour
        buffer.writeln('  ⚠ High delay indicates system is deferring tasks');
      }
    }
    buffer.writeln('');

    if (lastFailureReason != null) {
      buffer.writeln('Last Failure:');
      buffer.writeln('  Time: $lastFailureTime');
      buffer.writeln('  Reason: $lastFailureReason');
    }
    buffer.writeln('');

    buffer.writeln('Health Status: ${isHealthy ? 'Healthy ✓' : 'Unhealthy ✗'}');
    if (appearsStuck) {
      buffer.writeln('  ⚠ WARNING: Sync appears STUCK (>24 hours since last success)');
    }
    if (!isHealthy && successRate < 0.8) {
      buffer.writeln('  ⚠ WARNING: Low success rate (${(successRate * 100).toStringAsFixed(1)}%)');
    }

    return buffer.toString();
  }

  @override
  String toString() {
    return 'BackgroundSyncStats{'
        'total: $totalExecutions, '
        'successful: $successfulExecutions, '
        'failed: $failedExecutions, '
        'rate: ${(successRate * 100).toStringAsFixed(1)}%, '
        'healthy: $isHealthy'
        '}';
  }
}
