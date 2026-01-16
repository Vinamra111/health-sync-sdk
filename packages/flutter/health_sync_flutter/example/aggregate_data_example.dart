import 'package:health_sync_flutter/health_sync_flutter.dart';

/// Example: Aggregate Data Reader
///
/// Demonstrates efficient statistical queries using Health Connect's
/// native aggregation API (100x faster than manual calculation).
void main() async {
  // Example 1: Simple aggregate (total)
  await simpleAggregateExample();

  // Example 2: Aggregate with breakdown (min, max, avg)
  await aggregateWithBreakdownExample();

  // Example 3: Daily bucketing
  await dailyBucketingExample();

  // Example 4: Multi-type aggregates
  await multiTypeAggregateExample();

  // Example 5: Statistics calculation
  await statisticsExample();

  // Example 6: Real-world dashboard
  await dashboardExample();
}

/// Example 1: Simple aggregate
Future<void> simpleAggregateExample() async {
  print('=== Example 1: Simple Aggregate ===\n');

  final plugin = HealthConnectPlugin();
  await plugin.initialize();
  await plugin.connect();

  // Get total steps for last 7 days
  print('Fetching total steps for last 7 days...');

  final result = await plugin.readAggregate(
    AggregateQuery(
      dataType: DataType.steps,
      startTime: DateTime.now().subtract(Duration(days: 7)),
      endTime: DateTime.now(),
    ),
  );

  print('  Total: ${result.sumValue?.toStringAsFixed(0)} steps');
  print('  Data points: ${result.count}');
  print('  Period: ${result.duration.inDays} days');
  print('  Has data: ${result.hasData}');

  print('');
}

/// Example 2: Aggregate with breakdown
Future<void> aggregateWithBreakdownExample() async {
  print('=== Example 2: Aggregate with Breakdown ===\n');

  final plugin = HealthConnectPlugin();
  await plugin.initialize();
  await plugin.connect();

  // Get heart rate stats for last 24 hours
  print('Fetching heart rate statistics for last 24 hours...\n');

  final result = await plugin.readAggregate(
    AggregateQuery(
      dataType: DataType.heartRate,
      startTime: DateTime.now().subtract(Duration(hours: 24)),
      endTime: DateTime.now(),
      includeBreakdown: true,  // Enable min/max/avg
    ),
  );

  print('Heart Rate Stats:');
  print('  Average: ${result.avgValue?.toStringAsFixed(1)} bpm');
  print('  Minimum: ${result.minValue?.toStringAsFixed(0)} bpm');
  print('  Maximum: ${result.maxValue?.toStringAsFixed(0)} bpm');
  print('  Readings: ${result.count}');

  print('');
}

/// Example 3: Daily bucketing
Future<void> dailyBucketingExample() async {
  print('=== Example 3: Daily Bucketing ===\n');

  final plugin = HealthConnectPlugin();
  await plugin.initialize();
  await plugin.connect();

  // Get daily step totals for last 7 days
  print('Fetching daily step totals for last 7 days...\n');

  final dailySteps = await plugin.readAggregateWithBuckets(
    AggregateQuery.daily(
      dataType: DataType.steps,
      startDate: DateTime.now().subtract(Duration(days: 7)),
      endDate: DateTime.now(),
    ),
  );

  print('Daily Steps:');
  for (final day in dailySteps) {
    final date = '${day.startTime.month}/${day.startTime.day}';
    final steps = day.sumValue?.toStringAsFixed(0) ?? '0';
    final bar = '█' * (int.parse(steps) ~/ 1000);

    print('  $date: $steps steps $bar');
  }

  // Find best and worst days
  if (dailySteps.isNotEmpty) {
    final bestDay = dailySteps.reduce((a, b) =>
        (a.sumValue ?? 0) > (b.sumValue ?? 0) ? a : b);

    final worstDay = dailySteps.reduce((a, b) =>
        (a.sumValue ?? 0) < (b.sumValue ?? 0) ? a : b);

    print('\nSummary:');
    print('  Best: ${bestDay.startTime.month}/${bestDay.startTime.day} '
          '(${bestDay.sumValue?.toStringAsFixed(0)} steps)');
    print('  Worst: ${worstDay.startTime.month}/${worstDay.startTime.day} '
          '(${worstDay.sumValue?.toStringAsFixed(0)} steps)');
  }

  print('');
}

/// Example 4: Multi-type aggregates
Future<void> multiTypeAggregateExample() async {
  print('=== Example 4: Multi-Type Aggregates ===\n');

  final plugin = HealthConnectPlugin();
  await plugin.initialize();
  await plugin.connect();

  final dataTypes = [
    DataType.steps,
    DataType.calories,
    DataType.distance,
    DataType.heartRate,
  ];

  print('Fetching aggregates for ${dataTypes.length} data types...\n');

  final aggregates = await plugin.readAggregatesForTypes(
    dataTypes,
    startTime: DateTime.now().subtract(Duration(days: 1)),
    endTime: DateTime.now(),
    includeBreakdown: true,
  );

  print('24-Hour Summary:');

  // Steps
  final steps = aggregates[DataType.steps];
  if (steps?.hasData ?? false) {
    print('  Steps: ${steps!.sumValue?.toStringAsFixed(0)}');
  }

  // Calories
  final calories = aggregates[DataType.calories];
  if (calories?.hasData ?? false) {
    print('  Calories: ${calories!.sumValue?.toStringAsFixed(0)} kcal');
  }

  // Distance
  final distance = aggregates[DataType.distance];
  if (distance?.hasData ?? false) {
    final km = (distance!.sumValue ?? 0) / 1000;
    print('  Distance: ${km.toStringAsFixed(2)} km');
  }

  // Heart Rate
  final hr = aggregates[DataType.heartRate];
  if (hr?.hasData ?? false) {
    print('  Heart Rate: ${hr!.avgValue?.toStringAsFixed(1)} bpm avg '
          '(${hr.minValue?.toStringAsFixed(0)}-${hr.maxValue?.toStringAsFixed(0)})');
  }

  print('');
}

/// Example 5: Statistics calculation
Future<void> statisticsExample() async {
  print('=== Example 5: Statistics Calculation ===\n');

  final plugin = HealthConnectPlugin();
  await plugin.initialize();
  await plugin.connect();

  // Calculate 30-day statistics
  print('Calculating 30-day statistics...\n');

  final stats = await plugin.calculateAggregateStats(
    AggregateQuery.daily(
      dataType: DataType.steps,
      startDate: DateTime.now().subtract(Duration(days: 30)),
      endDate: DateTime.now(),
    ),
  );

  print('30-Day Step Statistics:');
  print('  Total: ${stats.total.toStringAsFixed(0)} steps');
  print('  Daily Average: ${stats.dailyAverage.toStringAsFixed(0)} steps/day');
  print('  Overall Average: ${stats.average.toStringAsFixed(0)} steps/bucket');
  print('  Best Day: ${stats.maximum.toStringAsFixed(0)} steps');
  print('  Worst Day: ${stats.minimum.toStringAsFixed(0)} steps');
  print('  Data Points: ${stats.dataPoints} days');
  print('  Period: ${stats.endTime.difference(stats.startTime).inDays} days');

  // Calculate goal achievement
  const dailyGoal = 10000;
  final goalPercent = (stats.dailyAverage / dailyGoal * 100);

  print('\nGoal Progress:');
  print('  Daily Goal: $dailyGoal steps');
  print('  Achievement: ${goalPercent.toStringAsFixed(1)}%');

  if (goalPercent >= 100) {
    print('  Status: ✓ Goal exceeded!');
  } else if (goalPercent >= 80) {
    print('  Status: ⚠ Close to goal');
  } else {
    print('  Status: ✗ Below goal');
  }

  print('');
}

/// Example 6: Real-world dashboard
Future<void> dashboardExample() async {
  print('=== Example 6: Real-World Dashboard ===\n');

  final plugin = HealthConnectPlugin();
  await plugin.initialize();
  await plugin.connect();

  // Today's activity
  print('📊 Activity Dashboard\n');

  await _showTodaySummary(plugin);
  await _showWeeklyProgress(plugin);
  await _showMonthlyTrend(plugin);

  print('');
}

Future<void> _showTodaySummary(HealthConnectPlugin plugin) async {
  final today = DateTime.now();
  final startOfDay = DateTime(today.year, today.month, today.day);

  print('━━━ Today ━━━');

  final dataTypes = [DataType.steps, DataType.calories, DataType.distance];

  final aggregates = await plugin.readAggregatesForTypes(
    dataTypes,
    startTime: startOfDay,
    endTime: today,
  );

  // Steps
  final steps = aggregates[DataType.steps]?.sumValue?.toStringAsFixed(0) ?? '0';
  final stepsGoal = 10000;
  final stepsPercent = (double.tryParse(steps) ?? 0) / stepsGoal * 100;
  print('  Steps: $steps / $stepsGoal (${stepsPercent.toStringAsFixed(0)}%)');

  // Calories
  final calories = aggregates[DataType.calories]?.sumValue?.toStringAsFixed(0) ?? '0';
  print('  Calories: $calories kcal');

  // Distance
  final distance = (aggregates[DataType.distance]?.sumValue ?? 0) / 1000;
  print('  Distance: ${distance.toStringAsFixed(2)} km');

  print('');
}

Future<void> _showWeeklyProgress(HealthConnectPlugin plugin) async {
  print('━━━ This Week ━━━');

  final weekStart = DateTime.now().subtract(Duration(days: 7));

  final weeklySteps = await plugin.readAggregateWithBuckets(
    AggregateQuery.daily(
      dataType: DataType.steps,
      startDate: weekStart,
      endDate: DateTime.now(),
    ),
  );

  final weekTotal = weeklySteps.fold<double>(
    0,
    (sum, day) => sum + (day.sumValue ?? 0),
  );

  final weekAvg = weekTotal / weeklySteps.length;
  const dailyGoal = 10000;

  print('  Total: ${weekTotal.toStringAsFixed(0)} steps');
  print('  Daily Avg: ${weekAvg.toStringAsFixed(0)} steps');

  // Count days that met goal
  final goalDays = weeklySteps.where((d) => (d.sumValue ?? 0) >= dailyGoal).length;
  print('  Goal Days: $goalDays / ${weeklySteps.length}');

  // Progress bar
  final progress = (weekAvg / dailyGoal * 20).round().clamp(0, 20);
  final bar = '█' * progress + '░' * (20 - progress);
  print('  Progress: [$bar] ${(weekAvg / dailyGoal * 100).toStringAsFixed(0)}%');

  print('');
}

Future<void> _showMonthlyTrend(HealthConnectPlugin plugin) async {
  print('━━━ 30-Day Trend ━━━');

  final stats = await plugin.calculateAggregateStats(
    AggregateQuery.daily(
      dataType: DataType.steps,
      startDate: DateTime.now().subtract(Duration(days: 30)),
      endDate: DateTime.now(),
    ),
  );

  // Get first and last week for trend
  final firstWeekData = await plugin.readAggregateWithBuckets(
    AggregateQuery.daily(
      dataType: DataType.steps,
      startDate: DateTime.now().subtract(Duration(days: 30)),
      endDate: DateTime.now().subtract(Duration(days: 23)),
    ),
  );

  final lastWeekData = await plugin.readAggregateWithBuckets(
    AggregateQuery.daily(
      dataType: DataType.steps,
      startDate: DateTime.now().subtract(Duration(days: 7)),
      endDate: DateTime.now(),
    ),
  );

  if (firstWeekData.isNotEmpty && lastWeekData.isNotEmpty) {
    final firstWeekAvg = firstWeekData.fold<double>(
          0,
          (sum, d) => sum + (d.sumValue ?? 0),
        ) / 7;

    final lastWeekAvg = lastWeekData.fold<double>(
          0,
          (sum, d) => sum + (d.sumValue ?? 0),
        ) / 7;

    final change = lastWeekAvg - firstWeekAvg;
    final percentChange = (change / firstWeekAvg * 100);

    print('  Daily Avg: ${stats.dailyAverage.toStringAsFixed(0)} steps');
    print('  Best Day: ${stats.maximum.toStringAsFixed(0)} steps');
    print('  Trend: ${change > 0 ? '↗' : '↘'} '
          '${change > 0 ? '+' : ''}${change.toStringAsFixed(0)} steps '
          '(${percentChange > 0 ? '+' : ''}${percentChange.toStringAsFixed(1)}%)');

    if (percentChange > 10) {
      print('  Status: 🔥 Great improvement!');
    } else if (percentChange > 0) {
      print('  Status: ✓ Improving');
    } else if (percentChange > -10) {
      print('  Status: → Stable');
    } else {
      print('  Status: ⚠ Declining');
    }
  }
}

/// Advanced Example: Hourly pattern analysis
Future<void> hourlyPatternExample() async {
  print('=== Advanced: Hourly Pattern Analysis ===\n');

  final plugin = HealthConnectPlugin();
  await plugin.initialize();
  await plugin.connect();

  // Get hourly steps for last 7 days
  final hourlyData = await plugin.readAggregateWithBuckets(
    AggregateQuery.hourly(
      dataType: DataType.steps,
      startDate: DateTime.now().subtract(Duration(days: 7)),
      endDate: DateTime.now(),
    ),
  );

  // Aggregate by hour of day
  final hourlyTotals = List.filled(24, 0.0);
  final hourlyCounts = List.filled(24, 0);

  for (final hour in hourlyData) {
    final hourOfDay = hour.startTime.hour;
    hourlyTotals[hourOfDay] += hour.sumValue ?? 0;
    hourlyCounts[hourOfDay]++;
  }

  // Calculate averages
  final hourlyAverages = List.generate(24, (i) {
    return hourlyCounts[i] > 0 ? hourlyTotals[i] / hourlyCounts[i] : 0.0;
  });

  print('Average Steps by Hour (7-day pattern):\n');

  // Find peak hours
  final maxSteps = hourlyAverages.reduce((a, b) => a > b ? a : b);

  for (var hour = 0; hour < 24; hour++) {
    final avg = hourlyAverages[hour];
    final barLength = maxSteps > 0 ? (avg / maxSteps * 20).round() : 0;
    final bar = '█' * barLength;

    final hourStr = hour.toString().padLeft(2, '0');
    final stepsStr = avg.toStringAsFixed(0).padLeft(5);

    print('  $hourStr:00 | $stepsStr steps $bar');
  }

  // Find most active period
  var maxPeriodSteps = 0.0;
  var maxPeriodStart = 0;

  for (var i = 0; i < 24; i++) {
    final periodSteps = hourlyAverages.sublist(i, (i + 3).clamp(0, 24))
        .fold<double>(0, (sum, val) => sum + val);

    if (periodSteps > maxPeriodSteps) {
      maxPeriodSteps = periodSteps;
      maxPeriodStart = i;
    }
  }

  print('\nMost Active Period: ${maxPeriodStart}:00 - ${maxPeriodStart + 3}:00');
  print('  Average: ${(maxPeriodSteps / 3).toStringAsFixed(0)} steps/hour');

  print('');
}

/// Advanced Example: Comparison between periods
Future<void> periodComparisonExample() async {
  print('=== Advanced: Period Comparison ===\n');

  final plugin = HealthConnectPlugin();
  await plugin.initialize();
  await plugin.connect();

  // Compare this week vs last week
  print('Comparing this week vs last week...\n');

  final thisWeek = await plugin.readAggregate(AggregateQuery(
    dataType: DataType.steps,
    startTime: DateTime.now().subtract(Duration(days: 7)),
    endTime: DateTime.now(),
  ));

  final lastWeek = await plugin.readAggregate(AggregateQuery(
    dataType: DataType.steps,
    startTime: DateTime.now().subtract(Duration(days: 14)),
    endTime: DateTime.now().subtract(Duration(days: 7)),
  ));

  final thisWeekSteps = thisWeek.sumValue ?? 0;
  final lastWeekSteps = lastWeek.sumValue ?? 0;
  final change = thisWeekSteps - lastWeekSteps;
  final percentChange = lastWeekSteps > 0 ? (change / lastWeekSteps * 100) : 0.0;

  print('Weekly Comparison:');
  print('  This Week:  ${thisWeekSteps.toStringAsFixed(0)} steps');
  print('  Last Week:  ${lastWeekSteps.toStringAsFixed(0)} steps');
  print('  Change:     ${change > 0 ? '+' : ''}${change.toStringAsFixed(0)} steps');
  print('  Percent:    ${change > 0 ? '+' : ''}${percentChange.toStringAsFixed(1)}%');

  if (change > 0) {
    print('  Trend: 📈 Improving!');
  } else if (change < 0) {
    print('  Trend: 📉 Declining');
  } else {
    print('  Trend: → Stable');
  }

  print('');
}
