import '../models/health_data.dart';

/// Data Aggregation Utility
///
/// Provides functionality to aggregate health data by time periods
class DataAggregator {
  /// Aggregate steps data by day
  ///
  /// Groups raw step data by date and sums the steps for each day
  static List<DailyAggregate> aggregateStepsByDay(List<RawHealthData> data) {
    final Map<String, DailyAggregate> aggregated = {};

    for (final record in data) {
      // Extract date from timestamp
      final DateTime timestamp;
      if (record.timestamp is String) {
        timestamp = DateTime.parse(record.timestamp as String);
      } else {
        timestamp = record.timestamp as DateTime;
      }

      final dateKey = _formatDate(timestamp);

      // Get steps value
      final steps = _extractStepsValue(record);
      if (steps == null) continue;

      if (aggregated.containsKey(dateKey)) {
        // Add to existing day
        aggregated[dateKey]!.totalSteps += steps;
        aggregated[dateKey]!.recordCount++;
      } else {
        // Create new day entry
        aggregated[dateKey] = DailyAggregate(
          date: dateKey,
          totalSteps: steps,
          recordCount: 1,
        );
      }
    }

    // Convert to list and sort by date descending
    final result = aggregated.values.toList();
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  /// Extract steps value from raw health data
  static int? _extractStepsValue(RawHealthData data) {
    final raw = data.raw;

    // Try different possible keys for steps
    if (raw['steps'] != null) {
      if (raw['steps'] is int) {
        return raw['steps'] as int;
      } else if (raw['steps'] is String) {
        return int.tryParse(raw['steps'] as String);
      }
    }

    if (raw['count'] != null) {
      if (raw['count'] is int) {
        return raw['count'] as int;
      } else if (raw['count'] is String) {
        return int.tryParse(raw['count'] as String);
      }
    }

    return null;
  }

  /// Format date to yyyy-MM-dd
  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Parse date string back to DateTime
  static DateTime parseDate(String dateStr) {
    return DateTime.parse('${dateStr}T00:00:00.000Z');
  }
}

/// Daily Aggregate Data Model
class DailyAggregate {
  /// Date in yyyy-MM-dd format
  final String date;

  /// Total steps for this day
  int totalSteps;

  /// Number of records aggregated
  int recordCount;

  DailyAggregate({
    required this.date,
    required this.totalSteps,
    this.recordCount = 1,
  });

  /// Get formatted date for display
  String get formattedDate {
    final dt = DataAggregator.parseDate(date);
    final weekday = _getWeekdayName(dt.weekday);
    return '$weekday, ${dt.day}/${dt.month}/${dt.year}';
  }

  String _getWeekdayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }
}
