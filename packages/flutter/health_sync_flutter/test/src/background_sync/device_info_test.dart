import 'package:flutter_test/flutter_test.dart';
import 'package:health_sync_flutter/src/background_sync/device_info.dart';

void main() {
  group('DeviceInfo', () {
    test('isAggressiveBatteryManager detects Xiaomi', () {
      expect(DeviceInfo.isAggressiveBatteryManager('Xiaomi'), true);
      expect(DeviceInfo.isAggressiveBatteryManager('xiaomi'), true);
      expect(DeviceInfo.isAggressiveBatteryManager('XIAOMI'), true);
    });

    test('isAggressiveBatteryManager detects Huawei', () {
      expect(DeviceInfo.isAggressiveBatteryManager('Huawei'), true);
      expect(DeviceInfo.isAggressiveBatteryManager('huawei'), true);
      expect(DeviceInfo.isAggressiveBatteryManager('HUAWEI'), true);
    });

    test('isAggressiveBatteryManager detects OPPO', () {
      expect(DeviceInfo.isAggressiveBatteryManager('OPPO'), true);
      expect(DeviceInfo.isAggressiveBatteryManager('oppo'), true);
    });

    test('isAggressiveBatteryManager detects Vivo', () {
      expect(DeviceInfo.isAggressiveBatteryManager('Vivo'), true);
      expect(DeviceInfo.isAggressiveBatteryManager('vivo'), true);
    });

    test('isAggressiveBatteryManager detects OnePlus', () {
      expect(DeviceInfo.isAggressiveBatteryManager('OnePlus'), true);
      expect(DeviceInfo.isAggressiveBatteryManager('oneplus'), true);
    });

    test('isAggressiveBatteryManager detects Realme', () {
      expect(DeviceInfo.isAggressiveBatteryManager('Realme'), true);
      expect(DeviceInfo.isAggressiveBatteryManager('realme'), true);
    });

    test('isAggressiveBatteryManager detects Asus', () {
      expect(DeviceInfo.isAggressiveBatteryManager('Asus'), true);
      expect(DeviceInfo.isAggressiveBatteryManager('asus'), true);
    });

    test('isAggressiveBatteryManager returns false for Google', () {
      expect(DeviceInfo.isAggressiveBatteryManager('Google'), false);
      expect(DeviceInfo.isAggressiveBatteryManager('google'), false);
    });

    test('isAggressiveBatteryManager returns false for Samsung', () {
      expect(DeviceInfo.isAggressiveBatteryManager('Samsung'), false);
      expect(DeviceInfo.isAggressiveBatteryManager('samsung'), false);
    });

    test('isAggressiveBatteryManager returns false for Motorola', () {
      expect(DeviceInfo.isAggressiveBatteryManager('Motorola'), false);
      expect(DeviceInfo.isAggressiveBatteryManager('motorola'), false);
    });

    test('getBatteryOptimizationWarning returns warning for Xiaomi', () {
      final warning = DeviceInfo.getBatteryOptimizationWarning('Xiaomi');
      expect(warning, isNotNull);
      expect(warning!.contains('MIUI'), true);
      expect(warning.contains('battery optimization'), true);
    });

    test('getBatteryOptimizationWarning returns warning for Huawei', () {
      final warning = DeviceInfo.getBatteryOptimizationWarning('Huawei');
      expect(warning, isNotNull);
      expect(warning!.contains('EMUI'), true);
    });

    test('getBatteryOptimizationWarning returns warning for OPPO', () {
      final warning = DeviceInfo.getBatteryOptimizationWarning('OPPO');
      expect(warning, isNotNull);
      expect(warning!.contains('ColorOS'), true);
    });

    test('getBatteryOptimizationWarning returns null for Google', () {
      final warning = DeviceInfo.getBatteryOptimizationWarning('Google');
      expect(warning, isNull);
    });

    test('getBatteryOptimizationWarning returns null for Samsung', () {
      final warning = DeviceInfo.getBatteryOptimizationWarning('Samsung');
      expect(warning, isNull);
    });

    test('getManufacturerSpecificInstructions returns instructions for Xiaomi', () {
      final instructions = DeviceInfo.getManufacturerSpecificInstructions('Xiaomi');
      expect(instructions.contains('Settings'), true);
      expect(instructions.contains('Battery & Performance'), true);
      expect(instructions.contains('Autostart'), true);
    });

    test('getManufacturerSpecificInstructions returns instructions for Huawei', () {
      final instructions = DeviceInfo.getManufacturerSpecificInstructions('Huawei');
      expect(instructions.contains('Battery'), true);
      expect(instructions.contains('App launch'), true);
    });

    test('getManufacturerSpecificInstructions returns instructions for OPPO', () {
      final instructions = DeviceInfo.getManufacturerSpecificInstructions('OPPO');
      expect(instructions.contains('Battery'), true);
      expect(instructions.contains('App Optimization'), true);
    });

    test('getManufacturerSpecificInstructions returns generic for unknown manufacturer', () {
      final instructions = DeviceInfo.getManufacturerSpecificInstructions('UnknownBrand');
      expect(instructions.contains('Battery optimization settings'), true);
      expect(instructions.contains('Disable battery optimization'), true);
    });

    test('getBackgroundSyncCompatibility returns high for Google', () {
      final compat = DeviceInfo.getBackgroundSyncCompatibility('Google');
      expect(compat, 'high');
    });

    test('getBackgroundSyncCompatibility returns high for Samsung', () {
      final compat = DeviceInfo.getBackgroundSyncCompatibility('Samsung');
      expect(compat, 'high');
    });

    test('getBackgroundSyncCompatibility returns high for Motorola', () {
      final compat = DeviceInfo.getBackgroundSyncCompatibility('Motorola');
      expect(compat, 'high');
    });

    test('getBackgroundSyncCompatibility returns low for Xiaomi', () {
      final compat = DeviceInfo.getBackgroundSyncCompatibility('Xiaomi');
      expect(compat, 'low');
    });

    test('getBackgroundSyncCompatibility returns low for Huawei', () {
      final compat = DeviceInfo.getBackgroundSyncCompatibility('Huawei');
      expect(compat, 'low');
    });

    test('getBackgroundSyncCompatibility returns low for OPPO', () {
      final compat = DeviceInfo.getBackgroundSyncCompatibility('OPPO');
      expect(compat, 'low');
    });

    test('getBackgroundSyncCompatibility returns medium for unknown manufacturer', () {
      final compat = DeviceInfo.getBackgroundSyncCompatibility('UnknownBrand');
      expect(compat, 'medium');
    });

    test('getRecommendedSyncFrequency returns 15 minutes for high compatibility', () {
      final freq = DeviceInfo.getRecommendedSyncFrequency('Google');
      expect(freq.inMinutes, 15);
    });

    test('getRecommendedSyncFrequency returns 60 minutes for low compatibility', () {
      final freq = DeviceInfo.getRecommendedSyncFrequency('Xiaomi');
      expect(freq.inMinutes, 60);
    });

    test('getRecommendedSyncFrequency returns 30 minutes for medium compatibility', () {
      final freq = DeviceInfo.getRecommendedSyncFrequency('UnknownBrand');
      expect(freq.inMinutes, 30);
    });

    test('shouldRequireCharging returns false for high compatibility', () {
      final shouldRequire = DeviceInfo.shouldRequireCharging('Google');
      expect(shouldRequire, false);
    });

    test('shouldRequireCharging returns true for low compatibility', () {
      final shouldRequire = DeviceInfo.shouldRequireCharging('Xiaomi');
      expect(shouldRequire, true);
    });

    test('shouldRequireCharging returns false for medium compatibility', () {
      final shouldRequire = DeviceInfo.shouldRequireCharging('UnknownBrand');
      expect(shouldRequire, false);
    });

    test('shouldRequireWiFi returns false for high compatibility', () {
      final shouldRequire = DeviceInfo.shouldRequireWiFi('Google');
      expect(shouldRequire, false);
    });

    test('shouldRequireWiFi returns true for low compatibility', () {
      final shouldRequire = DeviceInfo.shouldRequireWiFi('Xiaomi');
      expect(shouldRequire, true);
    });

    test('shouldRequireWiFi returns false for medium compatibility', () {
      final shouldRequire = DeviceInfo.shouldRequireWiFi('UnknownBrand');
      expect(shouldRequire, false);
    });

    test('case insensitive manufacturer detection', () {
      expect(DeviceInfo.isAggressiveBatteryManager('XIAOMI'), true);
      expect(DeviceInfo.isAggressiveBatteryManager('xiaomi'), true);
      expect(DeviceInfo.isAggressiveBatteryManager('XiAoMi'), true);

      expect(DeviceInfo.getBackgroundSyncCompatibility('GOOGLE'), 'high');
      expect(DeviceInfo.getBackgroundSyncCompatibility('google'), 'high');
      expect(DeviceInfo.getBackgroundSyncCompatibility('GoOgLe'), 'high');
    });

    test('manufacturer detection with extra spaces or characters', () {
      expect(DeviceInfo.isAggressiveBatteryManager('Xiaomi '), true);
      expect(DeviceInfo.isAggressiveBatteryManager(' Xiaomi'), true);
    });
  });

  group('DeviceInfo Integration', () {
    test('aggressive battery managers have low compatibility', () {
      final aggressiveManufacturers = ['Xiaomi', 'Huawei', 'OPPO', 'Vivo', 'OnePlus'];

      for (final manufacturer in aggressiveManufacturers) {
        expect(DeviceInfo.isAggressiveBatteryManager(manufacturer), true,
            reason: '$manufacturer should be aggressive');
        expect(DeviceInfo.getBackgroundSyncCompatibility(manufacturer), 'low',
            reason: '$manufacturer should have low compatibility');
        expect(DeviceInfo.shouldRequireCharging(manufacturer), true,
            reason: '$manufacturer should require charging');
        expect(DeviceInfo.shouldRequireWiFi(manufacturer), true,
            reason: '$manufacturer should require WiFi');
        expect(DeviceInfo.getRecommendedSyncFrequency(manufacturer).inMinutes, 60,
            reason: '$manufacturer should have 60min frequency');
      }
    });

    test('reliable manufacturers have high compatibility', () {
      final reliableManufacturers = ['Google', 'Samsung', 'Motorola'];

      for (final manufacturer in reliableManufacturers) {
        expect(DeviceInfo.isAggressiveBatteryManager(manufacturer), false,
            reason: '$manufacturer should not be aggressive');
        expect(DeviceInfo.getBackgroundSyncCompatibility(manufacturer), 'high',
            reason: '$manufacturer should have high compatibility');
        expect(DeviceInfo.shouldRequireCharging(manufacturer), false,
            reason: '$manufacturer should not require charging');
        expect(DeviceInfo.shouldRequireWiFi(manufacturer), false,
            reason: '$manufacturer should not require WiFi');
        expect(DeviceInfo.getRecommendedSyncFrequency(manufacturer).inMinutes, 15,
            reason: '$manufacturer should have 15min frequency');
      }
    });

    test('warning is provided only for aggressive manufacturers', () {
      // Aggressive manufacturers should have warnings
      expect(DeviceInfo.getBatteryOptimizationWarning('Xiaomi'), isNotNull);
      expect(DeviceInfo.getBatteryOptimizationWarning('Huawei'), isNotNull);
      expect(DeviceInfo.getBatteryOptimizationWarning('OPPO'), isNotNull);

      // Reliable manufacturers should not have warnings
      expect(DeviceInfo.getBatteryOptimizationWarning('Google'), isNull);
      expect(DeviceInfo.getBatteryOptimizationWarning('Samsung'), isNull);
    });
  });
}
