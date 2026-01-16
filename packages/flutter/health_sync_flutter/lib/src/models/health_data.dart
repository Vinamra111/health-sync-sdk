import 'health_source.dart';

/// Raw health data from a source platform
class RawHealthData {
  /// Original data type identifier from the source
  final String sourceDataType;

  /// Source platform identifier
  final HealthSource source;

  /// ISO timestamp of the measurement
  final DateTime timestamp;

  /// End timestamp for range-based data
  final DateTime? endTimestamp;

  /// Raw data payload in platform-specific format
  final Map<String, dynamic> raw;

  /// Original record ID from the source platform
  final String? sourceId;

  const RawHealthData({
    required this.sourceDataType,
    required this.source,
    required this.timestamp,
    this.endTimestamp,
    required this.raw,
    this.sourceId,
  });

  /// Simple test constructor
  factory RawHealthData.simple({
    required double value,
    required String unit,
    required DateTime timestamp,
    Map<String, dynamic> source = const {},
  }) {
    return RawHealthData(
      sourceDataType: unit,
      source: HealthSource.healthConnect,
      timestamp: timestamp,
      raw: {
        'value': value,
        'unit': unit,
        ...source,
      },
    );
  }

  /// Get numeric value from raw data
  double? get value {
    if (raw.containsKey('value')) {
      final val = raw['value'];
      if (val is num) return val.toDouble();
    }
    return null;
  }

  /// Get unit from raw data
  String? get unit {
    if (raw.containsKey('unit')) {
      return raw['unit'] as String?;
    }
    return null;
  }

  /// Create from JSON
  factory RawHealthData.fromJson(Map<String, dynamic> json) {
    return RawHealthData(
      sourceDataType: json['sourceDataType'] as String,
      source: HealthSourceExtension.fromValue(json['source'] as String),
      timestamp: DateTime.parse(json['timestamp'] as String),
      endTimestamp: json['endTimestamp'] != null
          ? DateTime.parse(json['endTimestamp'] as String)
          : null,
      raw: Map<String, dynamic>.from(json['raw'] as Map),
      sourceId: json['sourceId'] as String?,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'sourceDataType': sourceDataType,
      'source': source.toValue(),
      'timestamp': timestamp.toIso8601String(),
      if (endTimestamp != null) 'endTimestamp': endTimestamp!.toIso8601String(),
      'raw': raw,
      if (sourceId != null) 'sourceId': sourceId,
    };
  }

  @override
  String toString() {
    return 'RawHealthData(sourceDataType: $sourceDataType, source: $source, '
        'timestamp: $timestamp, raw: $raw)';
  }
}
