import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_sync_flutter/src/models/aggregate_data.dart';
import 'package:health_sync_flutter/src/models/data_type.dart';
import 'package:health_sync_flutter/src/models/health_data.dart';
import 'package:health_sync_flutter/src/utils/aggregate_reader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AggregateReader', () {
    late MethodChannel channel;
    late AggregateReader reader;

    setUp(() {
      channel = const MethodChannel('health_sync_flutter/health_connect');
      reader = AggregateReader(channel: channel);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('validateAggregate returns accurate validation for matching data', () async {
      final aggregate = AggregateData(
        dataType: DataType.steps,
        startTime: DateTime(2024, 1, 1),
        endTime: DateTime(2024, 1, 2),
        sumValue: 10000,
        includedRecords: 100,
        excludedRecords: 10,
      );

      // Mock raw data that sums to 10000
      final rawData = List.generate(100, (index) {
        return RawHealthData.simple(
          value: 100,
          unit: 'count',
          timestamp: DateTime(2024, 1, 1).add(Duration(minutes: index)),
          source: {},
        );
      });

      final validation = await reader.validateAggregate(
        aggregate,
        fetchRawData: () async => rawData,
        sampleSize: 100,
        accuracyThreshold: 0.1,
      );

      expect(validation.isAccurate, true);
      expect(validation.confidence, greaterThan(0.9));
      expect(validation.calculatedValue, 10000);
      expect(validation.percentageDifference, lessThan(1));
    });

    test('validateAggregate detects inaccurate aggregate', () async {
      final aggregate = AggregateData(
        dataType: DataType.steps,
        startTime: DateTime(2024, 1, 1),
        endTime: DateTime(2024, 1, 2),
        sumValue: 10000, // Aggregate says 10000
      );

      // But raw data actually sums to 15000
      final rawData = List.generate(100, (index) {
        return RawHealthData.simple(
          value: 150, // 150 * 100 = 15000
          unit: 'count',
          timestamp: DateTime(2024, 1, 1).add(Duration(minutes: index)),
          source: {},
        );
      });

      final validation = await reader.validateAggregate(
        aggregate,
        fetchRawData: () async => rawData,
        sampleSize: 100,
        accuracyThreshold: 0.1, // 10% threshold
      );

      expect(validation.isAccurate, false);
      expect(validation.confidence, lessThan(0.7));
      expect(validation.calculatedValue, 15000);
      expect(validation.percentageDifference, closeTo(50, 1)); // 50% difference
    });

    test('validateAggregate samples large datasets', () async {
      final aggregate = AggregateData(
        dataType: DataType.steps,
        startTime: DateTime(2024, 1, 1),
        endTime: DateTime(2024, 1, 2),
        sumValue: 100000,
      );

      // Create 1000 records
      final rawData = List.generate(1000, (index) {
        return RawHealthData.simple(
          value: 100,
          unit: 'count',
          timestamp: DateTime(2024, 1, 1).add(Duration(minutes: index)),
          source: {},
        );
      });

      final validation = await reader.validateAggregate(
        aggregate,
        fetchRawData: () async => rawData,
        sampleSize: 100, // Only sample 100 of 1000
      );

      expect(validation.sampleSize, 100);
      expect(validation.notes.any((n) => n.contains('sample')), true);
    });

    test('validateAggregate handles empty raw data', () async {
      final aggregate = AggregateData(
        dataType: DataType.steps,
        startTime: DateTime(2024, 1, 1),
        endTime: DateTime(2024, 1, 2),
        sumValue: 10000,
      );

      final validation = await reader.validateAggregate(
        aggregate,
        fetchRawData: () async => [],
        sampleSize: 100,
      );

      expect(validation.isAccurate, false);
      expect(validation.confidence, 0.0);
      expect(validation.sampleSize, 0);
      expect(validation.notes.any((n) => n.contains('No raw data')), true);
    });

    test('validateAggregate handles aggregate with no value', () async {
      final aggregate = AggregateData(
        dataType: DataType.steps,
        startTime: DateTime(2024, 1, 1),
        endTime: DateTime(2024, 1, 2),
        // No sumValue, value, or avgValue
      );

      final rawData = [
        RawHealthData.simple(
          value: 100,
          unit: 'count',
          timestamp: DateTime(2024, 1, 1),
          source: {},
        ),
      ];

      final validation = await reader.validateAggregate(
        aggregate,
        fetchRawData: () async => rawData,
      );

      expect(validation.isAccurate, false);
      expect(validation.confidence, 0.0);
      expect(validation.notes.any((n) => n.contains('no value')), true);
    });

    test('validateAggregate calculates confidence based on difference', () async {
      // Test various difference levels
      final testCases = [
        (aggregateValue: 10000, rawValue: 10000, expectedConfidence: 1.0), // Perfect match
        (aggregateValue: 10000, rawValue: 10100, expectedConfidence: 0.99), // 1% diff
        (aggregateValue: 10000, rawValue: 10500, expectedConfidence: 0.95), // 5% diff
        (aggregateValue: 10000, rawValue: 11000, expectedConfidence: 0.90), // 10% diff
        (aggregateValue: 10000, rawValue: 12000, expectedConfidence: 0.80), // 20% diff
      ];

      for (final testCase in testCases) {
        final aggregate = AggregateData(
          dataType: DataType.steps,
          startTime: DateTime(2024, 1, 1),
          endTime: DateTime(2024, 1, 2),
          sumValue: testCase.aggregateValue.toDouble(),
        );

        final rawData = [
          RawHealthData.simple(
            value: testCase.rawValue.toDouble(),
            unit: 'count',
            timestamp: DateTime(2024, 1, 1),
            source: {},
          ),
        ];

        final validation = await reader.validateAggregate(
          aggregate,
          fetchRawData: () async => rawData,
        );

        expect(validation.confidence, closeTo(testCase.expectedConfidence, 0.01));
      }
    });

    test('validateAggregate adds notes for different difference levels', () async {
      // Small difference (2%)
      var aggregate = AggregateData(
        dataType: DataType.steps,
        startTime: DateTime(2024, 1, 1),
        endTime: DateTime(2024, 1, 2),
        sumValue: 10000,
      );

      var validation = await reader.validateAggregate(
        aggregate,
        fetchRawData: () async => [
          RawHealthData.simple(value: 10200, unit: 'count', timestamp: DateTime.now(), source: {}),
        ],
      );

      expect(validation.notes.any((n) => n.contains('Small difference')), true);

      // Moderate difference (7%)
      validation = await reader.validateAggregate(
        aggregate,
        fetchRawData: () async => [
          RawHealthData.simple(value: 10700, unit: 'count', timestamp: DateTime.now(), source: {}),
        ],
      );

      expect(validation.notes.any((n) => n.contains('Moderate difference')), true);

      // Large difference (15%)
      validation = await reader.validateAggregate(
        aggregate,
        fetchRawData: () async => [
          RawHealthData.simple(value: 11500, unit: 'count', timestamp: DateTime.now(), source: {}),
        ],
      );

      expect(validation.notes.any((n) => n.contains('Large difference')), true);
    });

    test('validateAggregate handles validation errors gracefully', () async {
      final aggregate = AggregateData(
        dataType: DataType.steps,
        startTime: DateTime(2024, 1, 1),
        endTime: DateTime(2024, 1, 2),
        sumValue: 10000,
      );

      final validation = await reader.validateAggregate(
        aggregate,
        fetchRawData: () async {
          throw Exception('Network error');
        },
      );

      expect(validation.isAccurate, false);
      expect(validation.confidence, 0.0);
      expect(validation.notes.any((n) => n.contains('Validation error')), true);
    });
  });

  group('AggregateData Transparency', () {
    test('deduplicationRate calculates correctly', () {
      final aggregate = AggregateData(
        dataType: DataType.steps,
        startTime: DateTime(2024, 1, 1),
        endTime: DateTime(2024, 1, 2),
        sumValue: 10000,
        includedRecords: 90,
        excludedRecords: 10,
      );

      expect(aggregate.deduplicationRate, closeTo(0.1, 0.01));
      expect(aggregate.totalRecordsProcessed, 100);
    });

    test('hasSignificantDeduplication detects high dedup rates', () {
      var aggregate = AggregateData(
        dataType: DataType.steps,
        startTime: DateTime(2024, 1, 1),
        endTime: DateTime(2024, 1, 2),
        sumValue: 10000,
        includedRecords: 85,
        excludedRecords: 15, // 15% dedup
      );

      expect(aggregate.hasSignificantDeduplication, true);

      aggregate = AggregateData(
        dataType: DataType.steps,
        startTime: DateTime(2024, 1, 1),
        endTime: DateTime(2024, 1, 2),
        sumValue: 10000,
        includedRecords: 95,
        excludedRecords: 5, // 5% dedup
      );

      expect(aggregate.hasSignificantDeduplication, false);
    });

    test('getTransparencyReport includes all details', () {
      final aggregate = AggregateData(
        dataType: DataType.steps,
        startTime: DateTime(2024, 1, 1),
        endTime: DateTime(2024, 1, 2),
        sumValue: 10000,
        includedRecords: 90,
        excludedRecords: 10,
        sourcesIncluded: ['com.google.fit', 'com.samsung.health'],
        deduplicationMethod: 'priority-based',
      );

      final report = aggregate.getTransparencyReport();

      expect(report.contains('Records Included: 90'), true);
      expect(report.contains('Records Excluded (Duplicates): 10'), true);
      expect(report.contains('Deduplication Rate: 10.0%'), true);
      expect(report.contains('Data Sources'), true);
      expect(report.contains('com.google.fit'), true);
      expect(report.contains('priority-based'), true);
    });

    test('getTransparencyReport handles missing data', () {
      final aggregate = AggregateData(
        dataType: DataType.steps,
        startTime: DateTime(2024, 1, 1),
        endTime: DateTime(2024, 1, 2),
        sumValue: 10000,
      );

      final report = aggregate.getTransparencyReport();

      // Report should have header but no records/dedup info
      expect(report.contains('Aggregate Transparency Report'), true);
      expect(report.contains('Records Included'), false);
      expect(report.contains('Records Excluded'), false);
    });
  });

  group('AggregateValidation', () {
    test('getReport generates comprehensive report', () {
      final aggregate = AggregateData(
        dataType: DataType.steps,
        startTime: DateTime(2024, 1, 1),
        endTime: DateTime(2024, 1, 2),
        sumValue: 10000,
      );

      final validation = AggregateValidation(
        aggregate: aggregate,
        sampleSize: 100,
        isAccurate: true,
        confidence: 0.95,
        calculatedValue: 10000,
        difference: 0,
        percentageDifference: 0,
        notes: ['Perfect match'],
      );

      final report = validation.getReport();

      expect(report.contains('Validation Report'), true);
      expect(report.contains('Data Type: steps'), true);
      expect(report.contains('Aggregate Value: 10000'), true);
      expect(report.contains('Calculated Value'), true);
      expect(report.contains('Confidence: 95.0%'), true);
      expect(report.contains('Accurate: Yes'), true);
    });

    test('getReport shows inaccurate result', () {
      final aggregate = AggregateData(
        dataType: DataType.steps,
        startTime: DateTime(2024, 1, 1),
        endTime: DateTime(2024, 1, 2),
        sumValue: 10000,
      );

      final validation = AggregateValidation(
        aggregate: aggregate,
        sampleSize: 100,
        isAccurate: false,
        confidence: 0.60,
        calculatedValue: 15000,
        difference: 5000,
        percentageDifference: 50,
        notes: ['Large difference detected'],
      );

      final report = validation.getReport();

      expect(report.contains('Accurate: No'), true);
      expect(report.contains('Confidence: 60.0%'), true);
      expect(report.contains('50.00%'), true);
    });

    test('toString provides summary', () {
      final aggregate = AggregateData(
        dataType: DataType.steps,
        startTime: DateTime(2024, 1, 1),
        endTime: DateTime(2024, 1, 2),
        sumValue: 10000,
      );

      final validation = AggregateValidation(
        aggregate: aggregate,
        sampleSize: 50,
        isAccurate: true,
        confidence: 0.90,
      );

      final str = validation.toString();
      expect(str.contains('accurate: true'), true);
      expect(str.contains('90.0%'), true);
      expect(str.contains('sampleSize: 50'), true);
    });
  });
}
