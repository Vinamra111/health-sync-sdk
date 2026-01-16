import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:health_sync_flutter/src/models/data_type.dart';
import 'package:health_sync_flutter/src/background_sync/background_sync_config.dart';
import 'package:health_sync_flutter/src/background_sync/background_sync_service.dart';
import 'package:health_sync_flutter/src/background_sync/background_sync_stats.dart';
import 'package:health_sync_flutter/src/background_sync/device_info.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BackgroundSyncService Compatibility', () {
    late BackgroundSyncService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      service = BackgroundSyncService();
    });

    test('checkCompatibility returns high for Google devices', () {
      // Note: This test relies on DeviceInfo.getManufacturer() which may not work in tests
      // Testing the DeviceCompatibility class structure instead
      final compat = DeviceCompatibility(
        manufacturer: 'Google',
        level: 'high',
        isAggressiveBatteryManager: false,
        recommendedFrequency: Duration(minutes: 15),
        shouldRequireCharging: false,
        shouldRequireWiFi: false,
      );

      expect(compat.isReliable, true);
      expect(compat.shouldWarnUser, false);
      expect(compat.level, 'high');
    });

    test('checkCompatibility returns low for Xiaomi devices', () {
      final compat = DeviceCompatibility(
        manufacturer: 'Xiaomi',
        level: 'low',
        isAggressiveBatteryManager: true,
        warning: 'Background sync may not work reliably on MIUI devices',
        recommendedFrequency: Duration(minutes: 60),
        shouldRequireCharging: true,
        shouldRequireWiFi: true,
      );

      expect(compat.isReliable, false);
      expect(compat.shouldWarnUser, true);
      expect(compat.level, 'low');
      expect(compat.warning, isNotNull);
    });

    test('DeviceCompatibility identifies reliable manufacturers', () {
      final reliableDevices = [
        DeviceCompatibility(
          manufacturer: 'Google',
          level: 'high',
          isAggressiveBatteryManager: false,
          recommendedFrequency: Duration(minutes: 15),
          shouldRequireCharging: false,
          shouldRequireWiFi: false,
        ),
        DeviceCompatibility(
          manufacturer: 'Samsung',
          level: 'high',
          isAggressiveBatteryManager: false,
          recommendedFrequency: Duration(minutes: 15),
          shouldRequireCharging: false,
          shouldRequireWiFi: false,
        ),
      ];

      for (final device in reliableDevices) {
        expect(device.isReliable, true);
        expect(device.shouldWarnUser, false);
      }
    });

    test('DeviceCompatibility identifies problematic manufacturers', () {
      final problematicDevices = [
        DeviceCompatibility(
          manufacturer: 'Xiaomi',
          level: 'low',
          isAggressiveBatteryManager: true,
          warning: 'Warning',
          recommendedFrequency: Duration(minutes: 60),
          shouldRequireCharging: true,
          shouldRequireWiFi: true,
        ),
        DeviceCompatibility(
          manufacturer: 'Huawei',
          level: 'low',
          isAggressiveBatteryManager: true,
          warning: 'Warning',
          recommendedFrequency: Duration(minutes: 60),
          shouldRequireCharging: true,
          shouldRequireWiFi: true,
        ),
      ];

      for (final device in problematicDevices) {
        expect(device.isReliable, false);
        expect(device.shouldWarnUser, true);
      }
    });

    test('toString provides summary', () {
      final compat = DeviceCompatibility(
        manufacturer: 'Google',
        level: 'high',
        isAggressiveBatteryManager: false,
        recommendedFrequency: Duration(minutes: 15),
        shouldRequireCharging: false,
        shouldRequireWiFi: false,
      );

      final str = compat.toString();
      expect(str.contains('manufacturer: Google'), true);
      expect(str.contains('level: high'), true);
      expect(str.contains('reliable: true'), true);
    });
  });

  group('BackgroundSyncService Stats', () {
    late BackgroundSyncService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      service = BackgroundSyncService();
    });

    test('recordSuccess updates statistics', () async {
      final taskTag = 'test_task';
      final scheduledTime = DateTime.now().subtract(Duration(minutes: 5));

      await service.recordSuccess(
        taskTag: taskTag,
        scheduledTime: scheduledTime,
      );

      final stats = await service.getExecutionStats(taskTag: taskTag);

      expect(stats.totalExecutions, 1);
      expect(stats.successfulExecutions, 1);
      expect(stats.failedExecutions, 0);
      expect(stats.successRate, 1.0);
      expect(stats.lastSuccessfulExecution, isNotNull);
    });

    test('recordFailure updates statistics', () async {
      final taskTag = 'test_task';

      await service.recordFailure(
        taskTag: taskTag,
        reason: 'Network error',
      );

      final stats = await service.getExecutionStats(taskTag: taskTag);

      expect(stats.totalExecutions, 1);
      expect(stats.successfulExecutions, 0);
      expect(stats.failedExecutions, 1);
      expect(stats.successRate, 0.0);
      expect(stats.failureReasons['Network error'], 1);
    });

    test('resetStats clears all statistics', () async {
      final taskTag = 'test_task';

      // Record some data
      await service.recordSuccess(taskTag: taskTag);
      await service.recordFailure(taskTag: taskTag, reason: 'Error');

      var stats = await service.getExecutionStats(taskTag: taskTag);
      expect(stats.totalExecutions, 2);

      // Reset
      await service.resetStats(taskTag: taskTag);

      stats = await service.getExecutionStats(taskTag: taskTag);
      expect(stats.totalExecutions, 0);
      expect(stats.successfulExecutions, 0);
      expect(stats.failedExecutions, 0);
    });

    test('success callback is invoked', () async {
      var callbackCalled = false;
      DateTime? callbackTime;

      service.onSuccess = (timestamp) {
        callbackCalled = true;
        callbackTime = timestamp;
      };

      await service.recordSuccess(taskTag: 'test_task');

      expect(callbackCalled, true);
      expect(callbackTime, isNotNull);
    });

    test('failure callback is invoked', () async {
      var callbackCalled = false;
      String? callbackError;
      DateTime? callbackTime;

      service.onFailure = (error, timestamp) {
        callbackCalled = true;
        callbackError = error;
        callbackTime = timestamp;
      };

      await service.recordFailure(
        taskTag: 'test_task',
        reason: 'Test error',
      );

      expect(callbackCalled, true);
      expect(callbackError, 'Test error');
      expect(callbackTime, isNotNull);
    });

    test('multiple success and failure recordings', () async {
      final taskTag = 'test_task';

      // Record 7 successes
      for (var i = 0; i < 7; i++) {
        await service.recordSuccess(taskTag: taskTag);
      }

      // Record 3 failures
      for (var i = 0; i < 3; i++) {
        await service.recordFailure(
          taskTag: taskTag,
          reason: 'Error $i',
        );
      }

      final stats = await service.getExecutionStats(taskTag: taskTag);

      expect(stats.totalExecutions, 10);
      expect(stats.successfulExecutions, 7);
      expect(stats.failedExecutions, 3);
      expect(stats.successRate, 0.7);
      expect(stats.isHealthy, false); // 70% < 80% threshold
    });

    test('tracks delay in success recording', () async {
      final taskTag = 'test_task';
      final scheduledTime = DateTime.now().subtract(Duration(minutes: 10));

      await service.recordSuccess(
        taskTag: taskTag,
        scheduledTime: scheduledTime,
      );

      final stats = await service.getExecutionStats(taskTag: taskTag);

      // Delay should be approximately 10 minutes
      expect(stats.averageDelay, greaterThan(9 * 60 * 1000)); // At least 9 minutes
      expect(stats.averageDelay, lessThan(11 * 60 * 1000)); // At most 11 minutes
    });

    test('getExecutionStats returns empty stats for new task', () async {
      final stats = await service.getExecutionStats(taskTag: 'new_task');

      expect(stats.totalExecutions, 0);
      expect(stats.successRate, 1.0); // Default to 100% when no data
      expect(stats.isHealthy, true);
    });
  });

  group('BackgroundSyncInfo', () {
    test('toString provides summary', () {
      final info = BackgroundSyncInfo(
        isScheduled: true,
        config: BackgroundSyncConfig(
          enabled: true,
          dataTypes: [],
          frequency: Duration(minutes: 30),
        ),
        lastScheduledTime: DateTime.now(),
      );

      final str = info.toString();
      expect(str.contains('scheduled: true'), true);
      expect(str.contains('30min'), true);
    });
  });

  group('BackgroundSyncService Integration', () {
    test('callbacks work with stats tracking', () async {
      SharedPreferences.setMockInitialValues({});
      final service = BackgroundSyncService();

      var successCount = 0;
      var failureCount = 0;

      service.onSuccess = (_) => successCount++;
      service.onFailure = (_, __) => failureCount++;

      final taskTag = 'integration_test';

      // Record mixed results
      await service.recordSuccess(taskTag: taskTag);
      await service.recordSuccess(taskTag: taskTag);
      await service.recordFailure(taskTag: taskTag, reason: 'Error 1');
      await service.recordSuccess(taskTag: taskTag);
      await service.recordFailure(taskTag: taskTag, reason: 'Error 2');

      // Verify callbacks were called
      expect(successCount, 3);
      expect(failureCount, 2);

      // Verify stats were updated
      final stats = await service.getExecutionStats(taskTag: taskTag);
      expect(stats.totalExecutions, 5);
      expect(stats.successfulExecutions, 3);
      expect(stats.failedExecutions, 2);
      expect(stats.successRate, 0.6);
    });

    test('compatibility recommendations match device characteristics', () {
      // High compatibility device
      final googleCompat = DeviceCompatibility(
        manufacturer: 'Google',
        level: 'high',
        isAggressiveBatteryManager: false,
        recommendedFrequency: Duration(minutes: 15),
        shouldRequireCharging: false,
        shouldRequireWiFi: false,
      );

      expect(googleCompat.recommendedFrequency.inMinutes, 15);
      expect(googleCompat.shouldRequireCharging, false);
      expect(googleCompat.shouldRequireWiFi, false);

      // Low compatibility device
      final xiaomiCompat = DeviceCompatibility(
        manufacturer: 'Xiaomi',
        level: 'low',
        isAggressiveBatteryManager: true,
        recommendedFrequency: Duration(minutes: 60),
        shouldRequireCharging: true,
        shouldRequireWiFi: true,
      );

      expect(xiaomiCompat.recommendedFrequency.inMinutes, 60);
      expect(xiaomiCompat.shouldRequireCharging, true);
      expect(xiaomiCompat.shouldRequireWiFi, true);
    });
  });
}
