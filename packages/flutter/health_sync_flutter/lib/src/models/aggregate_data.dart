import 'data_type.dart';

/// Aggregated health data result
///
/// Represents aggregated statistics for a specific metric over a time period.
/// Health Connect automatically handles deduplication and device priority.
class AggregateData {
  /// Data type being aggregated
  final DataType dataType;

  /// Start of aggregation period
  final DateTime startTime;

  /// End of aggregation period
  final DateTime endTime;

  /// Aggregated value (e.g., total steps, average heart rate)
  final double? value;

  /// Minimum value in period (if applicable)
  final double? minValue;

  /// Maximum value in period (if applicable)
  final double? maxValue;

  /// Average value in period (if applicable)
  final double? avgValue;

  /// Sum/total value in period (if applicable)
  final double? sumValue;

  /// Count of data points aggregated
  final int? count;

  /// Number of records included in aggregation
  ///
  /// Helps understand how much data was used for calculation.
  final int? includedRecords;

  /// Number of records excluded (duplicates)
  ///
  /// Shows how many duplicates Health Connect detected and removed.
  final int? excludedRecords;

  /// Data sources that contributed to this aggregate
  ///
  /// List of app package names that provided data.
  /// Example: ['com.google.android.apps.fitness', 'com.samsung.health']
  final List<String>? sourcesIncluded;

  /// Deduplication method used
  ///
  /// Describes how Health Connect handled duplicates.
  /// Values: 'automatic', 'priority-based', 'timestamp-based', 'unknown'
  final String? deduplicationMethod;

  /// Raw aggregate data from platform
  final Map<String, dynamic> raw;

  const AggregateData({
    required this.dataType,
    required this.startTime,
    required this.endTime,
    this.value,
    this.minValue,
    this.maxValue,
    this.avgValue,
    this.sumValue,
    this.count,
    this.includedRecords,
    this.excludedRecords,
    this.sourcesIncluded,
    this.deduplicationMethod,
    this.raw = const {},
  });

  /// Create from JSON
  factory AggregateData.fromJson(Map<String, dynamic> json) {
    return AggregateData(
      dataType: DataTypeExtension.fromValue(json['dataType'] as String),
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      value: _parseDouble(json['value']),
      minValue: _parseDouble(json['minValue']),
      maxValue: _parseDouble(json['maxValue']),
      avgValue: _parseDouble(json['avgValue']),
      sumValue: _parseDouble(json['sumValue']),
      count: json['count'] as int?,
      includedRecords: json['includedRecords'] as int?,
      excludedRecords: json['excludedRecords'] as int?,
      sourcesIncluded: (json['sourcesIncluded'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      deduplicationMethod: json['deduplicationMethod'] as String?,
      raw: Map<String, dynamic>.from(json['raw'] as Map? ?? {}),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'dataType': dataType.toValue(),
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      if (value != null) 'value': value,
      if (minValue != null) 'minValue': minValue,
      if (maxValue != null) 'maxValue': maxValue,
      if (avgValue != null) 'avgValue': avgValue,
      if (sumValue != null) 'sumValue': sumValue,
      if (count != null) 'count': count,
      if (includedRecords != null) 'includedRecords': includedRecords,
      if (excludedRecords != null) 'excludedRecords': excludedRecords,
      if (sourcesIncluded != null) 'sourcesIncluded': sourcesIncluded,
      if (deduplicationMethod != null) 'deduplicationMethod': deduplicationMethod,
      'raw': raw,
    };
  }

  /// Duration of aggregation period
  Duration get duration => endTime.difference(startTime);

  /// Whether aggregation has data
  bool get hasData => value != null || sumValue != null || avgValue != null;

  /// Total records processed (included + excluded)
  int? get totalRecordsProcessed {
    if (includedRecords == null) return null;
    return includedRecords! + (excludedRecords ?? 0);
  }

  /// Deduplication rate (percentage of records that were duplicates)
  double? get deduplicationRate {
    final total = totalRecordsProcessed;
    if (total == null || total == 0) return null;
    return (excludedRecords ?? 0) / total;
  }

  /// Whether significant deduplication occurred (>10% duplicates)
  bool get hasSignificantDeduplication {
    final rate = deduplicationRate;
    return rate != null && rate > 0.1;
  }

  /// Get transparency report
  String getTransparencyReport() {
    final buffer = StringBuffer();
    buffer.writeln('Aggregate Transparency Report');
    buffer.writeln('Data Type: ${dataType.toValue()}');
    buffer.writeln('Period: ${startTime.toIso8601String()} to ${endTime.toIso8601String()}');
    buffer.writeln('');

    if (includedRecords != null) {
      buffer.writeln('Records Included: $includedRecords');
    }
    if (excludedRecords != null) {
      buffer.writeln('Records Excluded (Duplicates): $excludedRecords');
    }
    if (deduplicationRate != null) {
      buffer.writeln('Deduplication Rate: ${(deduplicationRate! * 100).toStringAsFixed(1)}%');
    }
    if (sourcesIncluded != null && sourcesIncluded!.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('Data Sources:');
      for (final source in sourcesIncluded!) {
        buffer.writeln('  - $source');
      }
    }
    if (deduplicationMethod != null) {
      buffer.writeln('');
      buffer.writeln('Deduplication Method: $deduplicationMethod');
    }

    return buffer.toString();
  }

  @override
  String toString() {
    return 'AggregateData{'
        'type: ${dataType.toValue()}, '
        'period: ${startTime.toIso8601String()} - ${endTime.toIso8601String()}, '
        'value: $value, '
        'sum: $sumValue, '
        'avg: $avgValue, '
        'min: $minValue, '
        'max: $maxValue, '
        'count: $count'
        '}';
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

/// Aggregate query configuration
class AggregateQuery {
  /// Data type to aggregate
  final DataType dataType;

  /// Start of time range
  final DateTime startTime;

  /// End of time range
  final DateTime endTime;

  /// Aggregation bucket size (optional, defaults to entire period)
  final AggregationBucket? bucket;

  /// Include detailed breakdowns (min, max, avg)
  final bool includeBreakdown;

  const AggregateQuery({
    required this.dataType,
    required this.startTime,
    required this.endTime,
    this.bucket,
    this.includeBreakdown = false,
  });

  /// Create query for daily aggregation
  factory AggregateQuery.daily({
    required DataType dataType,
    required DateTime startDate,
    required DateTime endDate,
    bool includeBreakdown = false,
  }) {
    return AggregateQuery(
      dataType: dataType,
      startTime: startDate,
      endTime: endDate,
      bucket: AggregationBucket.daily,
      includeBreakdown: includeBreakdown,
    );
  }

  /// Create query for hourly aggregation
  factory AggregateQuery.hourly({
    required DataType dataType,
    required DateTime startDate,
    required DateTime endDate,
    bool includeBreakdown = false,
  }) {
    return AggregateQuery(
      dataType: dataType,
      startTime: startDate,
      endTime: endDate,
      bucket: AggregationBucket.hourly,
      includeBreakdown: includeBreakdown,
    );
  }

  /// Create query for weekly aggregation
  factory AggregateQuery.weekly({
    required DataType dataType,
    required DateTime startDate,
    required DateTime endDate,
    bool includeBreakdown = false,
  }) {
    return AggregateQuery(
      dataType: dataType,
      startTime: startDate,
      endTime: endDate,
      bucket: AggregationBucket.weekly,
      includeBreakdown: includeBreakdown,
    );
  }

  /// Convert to platform method arguments
  Map<String, dynamic> toMethodArgs() {
    return {
      'dataType': dataType.toValue(),
      'startTime': startTime.toUtc().toIso8601String(),
      'endTime': endTime.toUtc().toIso8601String(),
      if (bucket != null) 'bucket': bucket!.toValue(),
      'includeBreakdown': includeBreakdown,
    };
  }
}

/// Time bucket for aggregation
enum AggregationBucket {
  /// Aggregate by hour
  hourly,

  /// Aggregate by day
  daily,

  /// Aggregate by week
  weekly,

  /// Aggregate by month
  monthly,

  /// No bucketing (entire period)
  none,
}

/// Extension for AggregationBucket
extension AggregationBucketExtension on AggregationBucket {
  String toValue() {
    switch (this) {
      case AggregationBucket.hourly:
        return 'HOURLY';
      case AggregationBucket.daily:
        return 'DAILY';
      case AggregationBucket.weekly:
        return 'WEEKLY';
      case AggregationBucket.monthly:
        return 'MONTHLY';
      case AggregationBucket.none:
        return 'NONE';
    }
  }

  static AggregationBucket fromValue(String value) {
    switch (value.toUpperCase()) {
      case 'HOURLY':
        return AggregationBucket.hourly;
      case 'DAILY':
        return AggregationBucket.daily;
      case 'WEEKLY':
        return AggregationBucket.weekly;
      case 'MONTHLY':
        return AggregationBucket.monthly;
      case 'NONE':
        return AggregationBucket.none;
      default:
        throw ArgumentError('Invalid aggregation bucket: $value');
    }
  }

  /// Get duration for this bucket
  Duration get duration {
    switch (this) {
      case AggregationBucket.hourly:
        return Duration(hours: 1);
      case AggregationBucket.daily:
        return Duration(days: 1);
      case AggregationBucket.weekly:
        return Duration(days: 7);
      case AggregationBucket.monthly:
        return Duration(days: 30);
      case AggregationBucket.none:
        return Duration.zero;
    }
  }
}

/// Aggregate statistics summary
class AggregateStats {
  /// Data type
  final DataType dataType;

  /// Time period
  final DateTime startTime;
  final DateTime endTime;

  /// Total/sum value
  final double total;

  /// Average value
  final double average;

  /// Minimum value
  final double minimum;

  /// Maximum value
  final double maximum;

  /// Number of data points
  final int dataPoints;

  /// Daily average
  final double dailyAverage;

  const AggregateStats({
    required this.dataType,
    required this.startTime,
    required this.endTime,
    required this.total,
    required this.average,
    required this.minimum,
    required this.maximum,
    required this.dataPoints,
    required this.dailyAverage,
  });

  /// Create from list of aggregate data
  factory AggregateStats.fromAggregates(
    List<AggregateData> aggregates,
  ) {
    if (aggregates.isEmpty) {
      throw ArgumentError('Cannot create stats from empty aggregates');
    }

    final dataType = aggregates.first.dataType;
    final startTime = aggregates.map((a) => a.startTime).reduce(
          (a, b) => a.isBefore(b) ? a : b,
        );
    final endTime = aggregates.map((a) => a.endTime).reduce(
          (a, b) => a.isAfter(b) ? a : b,
        );

    // Calculate statistics
    final values = aggregates
        .where((a) => a.value != null || a.sumValue != null)
        .map((a) => a.value ?? a.sumValue!)
        .toList();

    if (values.isEmpty) {
      throw ArgumentError('No valid values in aggregates');
    }

    final total = values.fold<double>(0, (sum, val) => sum + val);
    final average = total / values.length;
    final minimum = values.reduce((a, b) => a < b ? a : b);
    final maximum = values.reduce((a, b) => a > b ? a : b);

    final durationDays = endTime.difference(startTime).inDays;
    final dailyAverage = durationDays > 0 ? total / durationDays : total;

    return AggregateStats(
      dataType: dataType,
      startTime: startTime,
      endTime: endTime,
      total: total,
      average: average,
      minimum: minimum,
      maximum: maximum,
      dataPoints: values.length,
      dailyAverage: dailyAverage,
    );
  }

  @override
  String toString() {
    return 'AggregateStats{'
        'type: ${dataType.toValue()}, '
        'period: ${endTime.difference(startTime).inDays} days, '
        'total: $total, '
        'avg: $average, '
        'daily: $dailyAverage, '
        'range: $minimum-$maximum'
        '}';
  }
}

/// Aggregate validation result
///
/// Validates aggregate data against raw data sample to check accuracy.
class AggregateValidation {
  /// Aggregate being validated
  final AggregateData aggregate;

  /// Number of raw records sampled for validation
  final int sampleSize;

  /// Whether validation passed
  final bool isAccurate;

  /// Confidence level (0.0 to 1.0)
  ///
  /// 1.0 = Perfect match
  /// 0.9-0.99 = Very close (within 1%)
  /// 0.8-0.89 = Close (within 5%)
  /// 0.7-0.79 = Acceptable (within 10%)
  /// <0.7 = Inaccurate
  final double confidence;

  /// Calculated value from raw data sample
  final double? calculatedValue;

  /// Difference between aggregate and calculated
  final double? difference;

  /// Percentage difference
  final double? percentageDifference;

  /// Validation notes/warnings
  final List<String> notes;

  const AggregateValidation({
    required this.aggregate,
    required this.sampleSize,
    required this.isAccurate,
    required this.confidence,
    this.calculatedValue,
    this.difference,
    this.percentageDifference,
    this.notes = const [],
  });

  /// Get validation report
  String getReport() {
    final buffer = StringBuffer();
    buffer.writeln('Aggregate Validation Report');
    buffer.writeln('Data Type: ${aggregate.dataType.toValue()}');
    buffer.writeln('Period: ${aggregate.startTime.toIso8601String()} to ${aggregate.endTime.toIso8601String()}');
    buffer.writeln('');

    buffer.writeln('Aggregate Value: ${aggregate.value ?? aggregate.sumValue}');
    if (calculatedValue != null) {
      buffer.writeln('Calculated Value (from sample): $calculatedValue');
    }
    if (difference != null) {
      buffer.writeln('Difference: $difference');
    }
    if (percentageDifference != null) {
      buffer.writeln('Percentage Difference: ${percentageDifference!.toStringAsFixed(2)}%');
    }

    buffer.writeln('');
    buffer.writeln('Sample Size: $sampleSize records');
    buffer.writeln('Confidence: ${(confidence * 100).toStringAsFixed(1)}%');
    buffer.writeln('Accurate: ${isAccurate ? 'Yes ✓' : 'No ✗'}');

    if (notes.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('Notes:');
      for (final note in notes) {
        buffer.writeln('  - $note');
      }
    }

    return buffer.toString();
  }

  @override
  String toString() {
    return 'AggregateValidation{'
        'accurate: $isAccurate, '
        'confidence: ${(confidence * 100).toStringAsFixed(1)}%, '
        'sampleSize: $sampleSize'
        '}';
  }
}
