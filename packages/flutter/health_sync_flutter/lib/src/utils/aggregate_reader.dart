import 'dart:async';
import 'dart:math';
import 'package:flutter/services.dart';
import '../models/data_type.dart';
import '../models/aggregate_data.dart';
import '../models/health_data.dart';
import 'logger.dart';
import 'rate_limiter.dart';

/// Aggregate Data Reader for Health Connect
///
/// Uses Health Connect's native aggregate API to efficiently compute
/// statistics without reading individual records.
///
/// Benefits:
/// - Automatic deduplication (respects device priority)
/// - Much faster than manual summing
/// - Handles overlapping data sources correctly
/// - System-level accuracy
class AggregateReader {
  final MethodChannel _channel;
  final RateLimiter? _rateLimiter;

  AggregateReader({
    required MethodChannel channel,
    RateLimiter? rateLimiter,
  })  : _channel = channel,
        _rateLimiter = rateLimiter;

  /// Read aggregate data for a query
  ///
  /// Returns aggregated statistics computed by Health Connect.
  /// This is much more efficient than fetching all records and summing manually.
  ///
  /// Example:
  /// ```dart
  /// // Get total steps for last 7 days
  /// final result = await reader.readAggregate(
  ///   AggregateQuery(
  ///     dataType: DataType.steps,
  ///     startTime: DateTime.now().subtract(Duration(days: 7)),
  ///     endTime: DateTime.now(),
  ///   ),
  /// );
  /// print('Total steps: ${result.sumValue}');
  /// ```
  Future<AggregateData> readAggregate(AggregateQuery query) async {
    logger.info(
      'Reading aggregate data for ${query.dataType.toValue()}',
      category: 'AggregateReader',
      metadata: {
        'startTime': query.startTime.toIso8601String(),
        'endTime': query.endTime.toIso8601String(),
        'bucket': query.bucket?.toValue(),
      },
    );

    final operation = () => _readAggregateInternal(query);

    // Use rate limiter if available
    if (_rateLimiter != null) {
      return await _rateLimiter!.execute(
        operation,
        operationName: 'Aggregate ${query.dataType.toValue()}',
      );
    }

    return await operation();
  }

  /// Internal aggregate read implementation
  Future<AggregateData> _readAggregateInternal(AggregateQuery query) async {
    try {
      final recordType = _getRecordType(query.dataType);

      final result = await _channel.invokeMethod(
        'readAggregate',
        {
          'recordType': recordType,
          'startTime': query.startTime.toUtc().toIso8601String(),
          'endTime': query.endTime.toUtc().toIso8601String(),
          'includeBreakdown': query.includeBreakdown,
        },
      );

      final resultMap = Map<String, dynamic>.from(result as Map);

      final aggregateData = AggregateData(
        dataType: query.dataType,
        startTime: query.startTime,
        endTime: query.endTime,
        value: _parseDouble(resultMap['value']),
        minValue: _parseDouble(resultMap['minValue']),
        maxValue: _parseDouble(resultMap['maxValue']),
        avgValue: _parseDouble(resultMap['avgValue']),
        sumValue: _parseDouble(resultMap['sumValue']),
        count: resultMap['count'] as int?,
        raw: resultMap,
      );

      logger.info(
        'Aggregate result: ${aggregateData.sumValue ?? aggregateData.avgValue ?? aggregateData.value}',
        category: 'AggregateReader',
        metadata: {
          'dataType': query.dataType.toValue(),
          'hasData': aggregateData.hasData,
        },
      );

      return aggregateData;
    } catch (e, stackTrace) {
      logger.error(
        'Failed to read aggregate data',
        category: 'AggregateReader',
        error: e,
        stackTrace: stackTrace,
        metadata: {
          'dataType': query.dataType.toValue(),
        },
      );
      rethrow;
    }
  }

  /// Read aggregate data with bucketing (e.g., daily, hourly)
  ///
  /// Returns a list of aggregate data, one per bucket.
  ///
  /// Example:
  /// ```dart
  /// // Get daily step totals for last 7 days
  /// final dailyData = await reader.readAggregateWithBuckets(
  ///   AggregateQuery.daily(
  ///     dataType: DataType.steps,
  ///     startDate: DateTime.now().subtract(Duration(days: 7)),
  ///     endDate: DateTime.now(),
  ///   ),
  /// );
  ///
  /// for (final day in dailyData) {
  ///   print('${day.startTime}: ${day.sumValue} steps');
  /// }
  /// ```
  Future<List<AggregateData>> readAggregateWithBuckets(
    AggregateQuery query,
  ) async {
    if (query.bucket == null || query.bucket == AggregationBucket.none) {
      // No bucketing - return single aggregate
      final result = await readAggregate(query);
      return [result];
    }

    logger.info(
      'Reading bucketed aggregate data for ${query.dataType.toValue()}',
      category: 'AggregateReader',
      metadata: {
        'bucket': query.bucket!.toValue(),
        'startTime': query.startTime.toIso8601String(),
        'endTime': query.endTime.toIso8601String(),
      },
    );

    try {
      final recordType = _getRecordType(query.dataType);

      final result = await (_rateLimiter != null
          ? _rateLimiter!.execute(
              () => _channel.invokeMethod('readAggregateBucketed', {
                    'recordType': recordType,
                    'startTime': query.startTime.toUtc().toIso8601String(),
                    'endTime': query.endTime.toUtc().toIso8601String(),
                    'bucket': query.bucket!.toValue(),
                    'includeBreakdown': query.includeBreakdown,
                  }),
              operationName: 'Aggregate Bucketed ${query.dataType.toValue()}',
            )
          : _channel.invokeMethod('readAggregateBucketed', {
              'recordType': recordType,
              'startTime': query.startTime.toUtc().toIso8601String(),
              'endTime': query.endTime.toUtc().toIso8601String(),
              'bucket': query.bucket!.toValue(),
              'includeBreakdown': query.includeBreakdown,
            }));

      final resultList = result as List<dynamic>;

      final aggregates = resultList.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return AggregateData(
          dataType: query.dataType,
          startTime: DateTime.parse(map['startTime'] as String),
          endTime: DateTime.parse(map['endTime'] as String),
          value: _parseDouble(map['value']),
          minValue: _parseDouble(map['minValue']),
          maxValue: _parseDouble(map['maxValue']),
          avgValue: _parseDouble(map['avgValue']),
          sumValue: _parseDouble(map['sumValue']),
          count: map['count'] as int?,
          raw: map,
        );
      }).toList();

      logger.info(
        'Read ${aggregates.length} bucketed aggregates',
        category: 'AggregateReader',
        metadata: {
          'dataType': query.dataType.toValue(),
          'bucketCount': aggregates.length,
        },
      );

      return aggregates;
    } catch (e, stackTrace) {
      logger.error(
        'Failed to read bucketed aggregate data',
        category: 'AggregateReader',
        error: e,
        stackTrace: stackTrace,
        metadata: {
          'dataType': query.dataType.toValue(),
          'bucket': query.bucket!.toValue(),
        },
      );
      rethrow;
    }
  }

  /// Read aggregate for multiple data types
  ///
  /// Efficiently reads aggregates for multiple types in parallel.
  Future<Map<DataType, AggregateData>> readAggregatesForTypes(
    List<DataType> dataTypes, {
    required DateTime startTime,
    required DateTime endTime,
    bool includeBreakdown = false,
  }) async {
    final results = <DataType, AggregateData>{};

    // Read aggregates sequentially to avoid overwhelming the system
    for (final dataType in dataTypes) {
      try {
        final query = AggregateQuery(
          dataType: dataType,
          startTime: startTime,
          endTime: endTime,
          includeBreakdown: includeBreakdown,
        );

        final result = await readAggregate(query);
        results[dataType] = result;
      } catch (e) {
        logger.error(
          'Failed to read aggregate for ${dataType.toValue()}',
          category: 'AggregateReader',
          error: e,
        );
        // Continue with other types even if one fails
      }
    }

    return results;
  }

  /// Calculate statistics from bucketed aggregates
  ///
  /// Useful for computing summary statistics from daily/hourly data.
  Future<AggregateStats> calculateStats(AggregateQuery query) async {
    final aggregates = await readAggregateWithBuckets(query);

    if (aggregates.isEmpty) {
      throw StateError('No aggregate data available for stats calculation');
    }

    return AggregateStats.fromAggregates(aggregates);
  }

  /// Validate aggregate data against raw data sample
  ///
  /// Fetches a sample of raw records and compares manual calculation
  /// to the aggregate value to verify accuracy.
  ///
  /// This helps identify issues like:
  /// - Incorrect deduplication
  /// - Platform bugs
  /// - Vendor-specific calculation differences
  ///
  /// Example:
  /// ```dart
  /// final aggregate = await reader.readAggregate(query);
  /// final validation = await reader.validateAggregate(
  ///   aggregate,
  ///   fetchRawData: () => plugin.fetchData(DataQuery(...)),
  ///   sampleSize: 100,
  /// );
  ///
  /// if (!validation.isAccurate) {
  ///   print('Warning: Aggregate may be inaccurate');
  ///   print(validation.getReport());
  /// }
  /// ```
  Future<AggregateValidation> validateAggregate(
    AggregateData aggregate, {
    required Future<List<RawHealthData>> Function() fetchRawData,
    int sampleSize = 100,
    double accuracyThreshold = 0.1, // 10% tolerance
  }) async {
    logger.info(
      'Validating aggregate for ${aggregate.dataType.toValue()}',
      category: 'AggregateReader',
      metadata: {
        'sampleSize': sampleSize,
        'threshold': accuracyThreshold,
      },
    );

    try {
      // Fetch raw data
      final rawData = await fetchRawData();

      if (rawData.isEmpty) {
        return AggregateValidation(
          aggregate: aggregate,
          sampleSize: 0,
          isAccurate: false,
          confidence: 0.0,
          notes: ['No raw data available for validation'],
        );
      }

      // Sample data if needed
      final sample = rawData.length <= sampleSize
          ? rawData
          : _sampleData(rawData, sampleSize);

      // Calculate value from sample
      final calculatedValue = _calculateValueFromSample(sample, aggregate.dataType);

      if (calculatedValue == null) {
        return AggregateValidation(
          aggregate: aggregate,
          sampleSize: sample.length,
          isAccurate: false,
          confidence: 0.0,
          notes: ['Could not calculate value from raw data'],
        );
      }

      // Compare with aggregate value
      final aggregateValue = aggregate.value ?? aggregate.sumValue ?? aggregate.avgValue;

      if (aggregateValue == null) {
        return AggregateValidation(
          aggregate: aggregate,
          sampleSize: sample.length,
          isAccurate: false,
          confidence: 0.0,
          calculatedValue: calculatedValue,
          notes: ['Aggregate has no value to compare'],
        );
      }

      // Calculate difference
      final difference = (calculatedValue - aggregateValue).abs();
      final percentageDifference = aggregateValue > 0
          ? (difference / aggregateValue) * 100
          : 0.0;

      // Calculate confidence (inverse of percentage difference)
      final confidence = max(0.0, 1.0 - (percentageDifference / 100));

      // Determine if accurate
      final isAccurate = percentageDifference <= (accuracyThreshold * 100);

      // Generate notes
      final notes = <String>[];
      if (sample.length < rawData.length) {
        notes.add('Validation based on sample of ${sample.length} out of ${rawData.length} records');
      }
      if (percentageDifference > 1 && percentageDifference <= 5) {
        notes.add('Small difference detected (${percentageDifference.toStringAsFixed(2)}%). This may be due to deduplication.');
      } else if (percentageDifference > 5 && percentageDifference <= 10) {
        notes.add('Moderate difference detected. Check for multiple data sources.');
      } else if (percentageDifference > 10) {
        notes.add('Large difference detected! This may indicate a platform issue or vendor-specific calculation.');
      }

      logger.info(
        'Validation complete: ${isAccurate ? 'PASS' : 'FAIL'}',
        category: 'AggregateReader',
        metadata: {
          'confidence': '${(confidence * 100).toStringAsFixed(1)}%',
          'percentageDifference': '${percentageDifference.toStringAsFixed(2)}%',
        },
      );

      return AggregateValidation(
        aggregate: aggregate,
        sampleSize: sample.length,
        isAccurate: isAccurate,
        confidence: confidence,
        calculatedValue: calculatedValue,
        difference: difference,
        percentageDifference: percentageDifference,
        notes: notes,
      );
    } catch (e, stackTrace) {
      logger.error(
        'Validation failed',
        category: 'AggregateReader',
        error: e,
        stackTrace: stackTrace,
      );

      return AggregateValidation(
        aggregate: aggregate,
        sampleSize: 0,
        isAccurate: false,
        confidence: 0.0,
        notes: ['Validation error: ${e.toString()}'],
      );
    }
  }

  /// Sample data randomly
  List<RawHealthData> _sampleData(List<RawHealthData> data, int sampleSize) {
    if (data.length <= sampleSize) return data;

    final random = Random();
    final sampled = <RawHealthData>[];
    final indices = <int>{};

    while (sampled.length < sampleSize) {
      final index = random.nextInt(data.length);
      if (!indices.contains(index)) {
        indices.add(index);
        sampled.add(data[index]);
      }
    }

    return sampled;
  }

  /// Calculate value from raw data sample
  double? _calculateValueFromSample(
    List<RawHealthData> sample,
    DataType dataType,
  ) {
    if (sample.isEmpty) return null;

    // For count-based metrics (steps, etc.), sum the values
    if (_isCountBasedMetric(dataType)) {
      double sum = 0.0;
      for (final record in sample) {
        final value = record.value;
        if (value != null) {
          sum += value;
        }
      }
      return sum;
    }

    // For average-based metrics (heart rate, etc.), calculate average
    if (_isAverageBasedMetric(dataType)) {
      double sum = 0.0;
      int count = 0;
      for (final record in sample) {
        final value = record.value;
        if (value != null) {
          sum += value;
          count++;
        }
      }
      return count > 0 ? sum / count : null;
    }

    // Default: sum
    double sum = 0.0;
    for (final record in sample) {
      final value = record.value;
      if (value != null) {
        sum += value;
      }
    }
    return sum;
  }

  /// Check if data type is count-based (sum)
  bool _isCountBasedMetric(DataType dataType) {
    return dataType == DataType.steps ||
        dataType == DataType.distance ||
        dataType == DataType.calories;
  }

  /// Check if data type is average-based
  bool _isAverageBasedMetric(DataType dataType) {
    return dataType == DataType.heartRate ||
        dataType == DataType.restingHeartRate ||
        dataType == DataType.bloodOxygen ||
        dataType == DataType.bodyTemperature;
  }

  /// Map DataType to Health Connect record type
  String _getRecordType(DataType dataType) {
    switch (dataType) {
      case DataType.steps:
        return 'Steps';
      case DataType.heartRate:
        return 'HeartRate';
      case DataType.restingHeartRate:
        return 'RestingHeartRate';
      case DataType.sleep:
        return 'SleepSession';
      case DataType.activity:
        return 'ExerciseSession';
      case DataType.calories:
        return 'TotalCaloriesBurned';
      case DataType.distance:
        return 'Distance';
      case DataType.bloodOxygen:
        return 'OxygenSaturation';
      case DataType.bloodPressure:
        return 'BloodPressure';
      case DataType.bodyTemperature:
        return 'BodyTemperature';
      case DataType.weight:
        return 'Weight';
      case DataType.height:
        return 'Height';
      case DataType.heartRateVariability:
        return 'HeartRateVariabilityRmssd';
      default:
        throw ArgumentError('Unsupported data type: ${dataType.toValue()}');
    }
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
