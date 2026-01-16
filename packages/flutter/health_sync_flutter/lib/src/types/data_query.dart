import '../models/data_type.dart';

/// Query parameters for fetching health data
class DataQuery {
  /// Type of data to fetch
  final DataType dataType;

  /// Start of date range
  final DateTime startDate;

  /// End of date range
  final DateTime endDate;

  /// Maximum number of records to return
  final int? limit;

  /// Offset for pagination
  final int? offset;

  const DataQuery({
    required this.dataType,
    required this.startDate,
    required this.endDate,
    this.limit,
    this.offset,
  });

  Map<String, dynamic> toJson() {
    return {
      'dataType': dataType.toValue(),
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      if (limit != null) 'limit': limit,
      if (offset != null) 'offset': offset,
    };
  }
}
