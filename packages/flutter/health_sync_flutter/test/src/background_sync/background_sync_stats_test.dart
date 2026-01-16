import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:health_sync_flutter/src/background_sync/background_sync_stats.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackgroundSyncStats', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('initial stats are zero', () {
      final stats = BackgroundSyncStats();

      expect(stats.totalExecutions, 0);
      expect(stats.successfulExecutions, 0);
      expect(stats.failedExecutions, 0);
      expect(stats.successRate, 1.0); // 100% when no executions
      expect(stats.isHealthy, true);
      expect(stats.appearsStuck, false);
    });

    test('recordSuccess updates statistics', () {
      final stats = BackgroundSyncStats();
      final executionTime = DateTime.now();

      stats.recordSuccess(
        executionTime: executionTime,
        delay: Duration(minutes: 5),
      );

      expect(stats.totalExecutions, 1);
      expect(stats.successfulExecutions, 1);
      expect(stats.failedExecutions, 0);
      expect(stats.successRate, 1.0);
      expect(stats.lastSuccessfulExecution, executionTime);
      expect(stats.averageDelay, 5 * 60 * 1000); // 5 minutes in milliseconds
    });

    test('recordFailure updates statistics', () {
      final stats = BackgroundSyncStats();
      final executionTime = DateTime.now();

      stats.recordFailure(
        executionTime: executionTime,
        reason: 'Network error',
      );

      expect(stats.totalExecutions, 1);
      expect(stats.successfulExecutions, 0);
      expect(stats.failedExecutions, 1);
      expect(stats.successRate, 0.0);
      expect(stats.lastFailedExecution, executionTime);
      expect(stats.failureReasons.length, 1);
      expect(stats.failureReasons['Network error'], 1);
    });

    test('calculates success rate correctly', () {
      final stats = BackgroundSyncStats();

      // 7 successes, 3 failures = 70% success rate
      for (var i = 0; i < 7; i++) {
        stats.recordSuccess(
          executionTime: DateTime.now(),
        );
      }

      for (var i = 0; i < 3; i++) {
        stats.recordFailure(
          executionTime: DateTime.now(),
          reason: 'Error $i',
        );
      }

      expect(stats.totalExecutions, 10);
      expect(stats.successfulExecutions, 7);
      expect(stats.failedExecutions, 3);
      expect(stats.successRate, 0.7);
    });

    test('calculates average delay correctly', () {
      final stats = BackgroundSyncStats();

      stats.recordSuccess(
        executionTime: DateTime.now(),
        delay: Duration(minutes: 5),
      );

      stats.recordSuccess(
        executionTime: DateTime.now(),
        delay: Duration(minutes: 10),
      );

      stats.recordSuccess(
        executionTime: DateTime.now(),
        delay: Duration(minutes: 15),
      );

      // Average: (5 + 10 + 15) / 3 = 10 minutes = 600000 milliseconds
      expect(stats.averageDelay, closeTo(600000, 100));
    });

    test('isHealthy returns true when success rate > 80%', () {
      final stats = BackgroundSyncStats();

      // 9 successes, 1 failure = 90% success rate
      for (var i = 0; i < 9; i++) {
        stats.recordSuccess(executionTime: DateTime.now());
      }
      stats.recordFailure(executionTime: DateTime.now(), reason: 'Error');

      expect(stats.isHealthy, true);
    });

    test('isHealthy returns false when success rate <= 80%', () {
      final stats = BackgroundSyncStats();

      // 7 successes, 3 failures = 70% success rate
      for (var i = 0; i < 7; i++) {
        stats.recordSuccess(executionTime: DateTime.now());
      }
      for (var i = 0; i < 3; i++) {
        stats.recordFailure(executionTime: DateTime.now(), reason: 'Error');
      }

      expect(stats.isHealthy, false);
    });

    test('appearsStuck returns true when no success for >24 hours', () {
      final stats = BackgroundSyncStats();
      final oldTime = DateTime.now().subtract(Duration(hours: 25));

      stats.recordSuccess(executionTime: oldTime);

      expect(stats.appearsStuck, true);
      expect(stats.timeSinceLastSuccess!.inHours, greaterThan(24));
    });

    test('appearsStuck returns false when recent success', () {
      final stats = BackgroundSyncStats();
      final recentTime = DateTime.now().subtract(Duration(hours: 1));

      stats.recordSuccess(executionTime: recentTime);

      expect(stats.appearsStuck, false);
    });

    test('appearsStuck returns false when no executions yet', () {
      final stats = BackgroundSyncStats();

      expect(stats.appearsStuck, false);
    });

    test('tracks failure reasons correctly', () {
      final stats = BackgroundSyncStats();

      stats.recordFailure(executionTime: DateTime.now(), reason: 'Network error');
      stats.recordFailure(executionTime: DateTime.now(), reason: 'Network error');
      stats.recordFailure(executionTime: DateTime.now(), reason: 'Timeout');
      stats.recordFailure(executionTime: DateTime.now(), reason: 'Permission denied');

      expect(stats.failureReasons['Network error'], 2);
      expect(stats.failureReasons['Timeout'], 1);
      expect(stats.failureReasons['Permission denied'], 1);
      expect(stats.mostCommonFailureReason, 'Network error');
    });

    test('mostCommonFailureReason returns null when no failures', () {
      final stats = BackgroundSyncStats();

      expect(stats.mostCommonFailureReason, isNull);
    });

    test('save and load persist statistics', () async {
      final stats = BackgroundSyncStats();

      stats.recordSuccess(
        executionTime: DateTime(2024, 1, 1, 12, 0),
        delay: Duration(minutes: 5),
      );
      stats.recordFailure(
        executionTime: DateTime(2024, 1, 1, 13, 0),
        reason: 'Test error',
      );

      await stats.save('test_task');

      final loadedStats = await BackgroundSyncStats.load('test_task');

      expect(loadedStats.totalExecutions, 2);
      expect(loadedStats.successfulExecutions, 1);
      expect(loadedStats.failedExecutions, 1);
      expect(loadedStats.successRate, 0.5);
      expect(loadedStats.failureReasons['Test error'], 1);
    });

    test('load returns empty stats when no data exists', () async {
      final stats = await BackgroundSyncStats.load('nonexistent_task');

      expect(stats.totalExecutions, 0);
      expect(stats.successfulExecutions, 0);
      expect(stats.failedExecutions, 0);
    });

    test('getReport generates formatted report', () {
      final stats = BackgroundSyncStats();

      stats.recordSuccess(
        executionTime: DateTime.now(),
        delay: Duration(minutes: 5),
      );
      stats.recordFailure(
        executionTime: DateTime.now(),
        reason: 'Network error',
      );

      final report = stats.getReport();

      expect(report.contains('Background Sync Statistics'), true);
      expect(report.contains('Total Executions: 2'), true);
      expect(report.contains('Successful: 1'), true);
      expect(report.contains('Failed: 1'), true);
      expect(report.contains('Success Rate: 50.0%'), true);
      expect(report.contains('Average Delay'), true);
      expect(report.contains('Network error'), true);
    });

    test('getReport shows stuck warning', () {
      final stats = BackgroundSyncStats();
      final oldTime = DateTime.now().subtract(Duration(hours: 25));

      stats.recordSuccess(executionTime: oldTime);

      final report = stats.getReport();

      expect(report.contains('WARNING: Sync appears STUCK'), true);
      expect(report.contains('>24 hours'), true);
    });

    test('getReport shows unhealthy warning', () {
      final stats = BackgroundSyncStats();

      // 6 successes, 4 failures = 60% success rate (unhealthy)
      for (var i = 0; i < 6; i++) {
        stats.recordSuccess(executionTime: DateTime.now());
      }
      for (var i = 0; i < 4; i++) {
        stats.recordFailure(executionTime: DateTime.now(), reason: 'Error');
      }

      final report = stats.getReport();

      expect(report.contains('WARNING: Low success rate'), true);
    });

    test('toString provides summary', () {
      final stats = BackgroundSyncStats();

      for (var i = 0; i < 8; i++) {
        stats.recordSuccess(
          executionTime: DateTime.now(),
          delay: Duration(minutes: 5),
        );
      }
      for (var i = 0; i < 2; i++) {
        stats.recordFailure(executionTime: DateTime.now(), reason: 'Error');
      }

      final str = stats.toString();

      expect(str.contains('total: 10'), true);
      expect(str.contains('successful: 8'), true);
      expect(str.contains('failed: 2'), true);
      expect(str.contains('80.0%'), true);
      expect(str.contains('healthy: true'), true);
    });

    test('timeSinceLastSuccess calculates duration correctly', () {
      final stats = BackgroundSyncStats();
      final pastTime = DateTime.now().subtract(Duration(hours: 2, minutes: 30));

      stats.recordSuccess(executionTime: pastTime);

      final duration = stats.timeSinceLastSuccess;
      expect(duration, isNotNull);
      expect(duration!.inHours, 2);
      expect(duration.inMinutes, greaterThanOrEqualTo(150)); // At least 2.5 hours
    });

    test('ignores delay when not provided', () {
      final stats = BackgroundSyncStats();

      stats.recordSuccess(executionTime: DateTime.now());
      stats.recordSuccess(executionTime: DateTime.now());

      // Average delay should be 0 when no delays recorded
      expect(stats.averageDelay, 0);
    });

    test('handles multiple different failure reasons', () {
      final stats = BackgroundSyncStats();

      final reasons = [
        'Network timeout',
        'Permission denied',
        'Rate limit exceeded',
        'Network timeout', // Duplicate
        'Permission denied', // Duplicate
        'Network timeout', // Most common
      ];

      for (final reason in reasons) {
        stats.recordFailure(executionTime: DateTime.now(), reason: reason);
      }

      expect(stats.failureReasons.length, 3);
      expect(stats.failureReasons['Network timeout'], 3);
      expect(stats.failureReasons['Permission denied'], 2);
      expect(stats.failureReasons['Rate limit exceeded'], 1);
      expect(stats.mostCommonFailureReason, 'Network timeout');
    });
  });

  group('BackgroundSyncStats Edge Cases', () {
    test('handles very large delays', () {
      final stats = BackgroundSyncStats();

      stats.recordSuccess(
        executionTime: DateTime.now(),
        delay: Duration(hours: 24),
      );

      expect(stats.averageDelay, 24 * 60 * 60 * 1000); // 24 hours in ms
    });

    test('handles zero delay', () {
      final stats = BackgroundSyncStats();

      stats.recordSuccess(
        executionTime: DateTime.now(),
        delay: Duration.zero,
      );

      expect(stats.averageDelay, 0);
    });

    test('success rate is 100% when only successes', () {
      final stats = BackgroundSyncStats();

      for (var i = 0; i < 10; i++) {
        stats.recordSuccess(executionTime: DateTime.now());
      }

      expect(stats.successRate, 1.0);
      expect(stats.isHealthy, true);
    });

    test('success rate is 0% when only failures', () {
      final stats = BackgroundSyncStats();

      for (var i = 0; i < 10; i++) {
        stats.recordFailure(executionTime: DateTime.now(), reason: 'Error');
      }

      expect(stats.successRate, 0.0);
      expect(stats.isHealthy, false);
    });
  });
}
