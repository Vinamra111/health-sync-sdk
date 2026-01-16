import 'dart:math';
import '../models/data_type.dart';
import '../models/health_data.dart';
import '../plugins/health_connect/health_connect_plugin.dart';
import '../types/data_query.dart';
import '../utils/logger.dart';
import 'data_source_info.dart';

/// Conflict detector for identifying duplicate data sources
///
/// Detects when multiple apps (Samsung Health, Google Fit, etc.)
/// are writing the same health data, causing inflated counts.
class ConflictDetector {
  /// Analyze data sources for a specific data type
  ///
  /// Identifies which apps are writing data and detects potential conflicts.
  ///
  /// Example:
  /// ```dart
  /// final result = await conflictDetector.detectConflicts(
  ///   plugin: healthConnectPlugin,
  ///   dataType: DataType.steps,
  ///   startTime: DateTime.now().subtract(Duration(days: 7)),
  ///   endTime: DateTime.now(),
  /// );
  ///
  /// if (result.hasConflicts) {
  ///   print('⚠ ${result.conflicts.length} conflicts detected!');
  ///   for (final conflict in result.conflicts) {
  ///     print(conflict.recommendation);
  ///   }
  /// }
  /// ```
  static Future<ConflictDetectionResult> detectConflicts({
    required HealthConnectPlugin plugin,
    required DataType dataType,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    logger.info(
      'Detecting conflicts for ${dataType.toValue()}',
      category: 'ConflictDetection',
      metadata: {
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
      },
    );

    // Fetch data for analysis
    final data = await plugin.fetchData(
      DataQuery(
        dataType: dataType,
        startDate: startTime,
        endDate: endTime,
      ),
    );

    if (data.isEmpty) {
      logger.info(
        'No data found for conflict detection',
        category: 'ConflictDetection',
      );

      return ConflictDetectionResult(
        dataType: dataType,
        sources: [],
        conflicts: [],
        hasConflicts: false,
        startTime: startTime,
        endTime: endTime,
        totalRecords: 0,
      );
    }

    // Group by data source
    final sourceMap = <String, List<RawHealthData>>{};
    for (final record in data) {
      final source = HealthConnectPlugin.getDataSource(record);
      final packageName = source['packageName'] ?? 'unknown';

      sourceMap.putIfAbsent(packageName, () => []).add(record);
    }

    // Build source info
    final sources = <DataSourceInfo>[];
    for (final entry in sourceMap.entries) {
      final packageName = entry.key;
      final records = entry.value;

      // Get metadata from first record
      final firstRecord = records.first;
      final source = HealthConnectPlugin.getDataSource(firstRecord);

      final info = DataSourceInfo(
        packageName: packageName,
        appName: source['appName'],
        recordCount: records.length,
        dataType: dataType,
        isSystemApp: _isSystemApp(packageName),
        deviceManufacturer: source['deviceManufacturer'],
        deviceModel: source['deviceModel'],
        percentage: (records.length / data.length) * 100,
      );

      sources.add(info);
    }

    // Sort by record count (descending)
    sources.sort((a, b) => b.recordCount.compareTo(a.recordCount));

    // Detect conflicts
    final conflicts = _analyzeConflicts(
      sources: sources,
      dataType: dataType,
      startTime: startTime,
      endTime: endTime,
      totalRecords: data.length,
    );

    logger.info(
      'Conflict detection complete',
      category: 'ConflictDetection',
      metadata: {
        'sources': sources.length,
        'conflicts': conflicts.length,
        'totalRecords': data.length,
      },
    );

    return ConflictDetectionResult(
      dataType: dataType,
      sources: sources,
      conflicts: conflicts,
      hasConflicts: conflicts.isNotEmpty,
      startTime: startTime,
      endTime: endTime,
      totalRecords: data.length,
    );
  }

  /// Detect conflicts across multiple data types
  static Future<ConflictSummary> detectConflictsForTypes({
    required HealthConnectPlugin plugin,
    required List<DataType> dataTypes,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    logger.info(
      'Detecting conflicts for ${dataTypes.length} data types',
      category: 'ConflictDetection',
    );

    final results = <DataType, ConflictDetectionResult>{};

    for (final dataType in dataTypes) {
      try {
        final result = await detectConflicts(
          plugin: plugin,
          dataType: dataType,
          startTime: startTime,
          endTime: endTime,
        );

        results[dataType] = result;
      } catch (e) {
        logger.error(
          'Failed to detect conflicts for ${dataType.toValue()}',
          category: 'ConflictDetection',
          error: e,
        );
      }
    }

    return ConflictSummary(
      results: results,
      analysisTime: DateTime.now(),
    );
  }

  /// Analyze sources for conflicts
  static List<DataSourceConflict> _analyzeConflicts({
    required List<DataSourceInfo> sources,
    required DataType dataType,
    required DateTime startTime,
    required DateTime endTime,
    required int totalRecords,
  }) {
    final conflicts = <DataSourceConflict>[];

    // Check for multiple writers
    if (sources.length > 1) {
      final type = _determineConflictType(sources);
      final severity = _calculateSeverity(sources);
      final confidence = _calculateConfidence(sources, type);
      final isLegitimateMultiDevice = _isLegitimateMultiDevice(sources);
      final timeOverlap = _calculateTimeOverlap(sources);
      final recommendation = _getRecommendation(sources, dataType);
      final explanation = _generateExplanation(sources, type, severity, confidence);

      conflicts.add(
        DataSourceConflict(
          dataType: dataType,
          sources: sources,
          startTime: startTime,
          endTime: endTime,
          totalRecords: totalRecords,
          severity: severity,
          confidence: confidence,
          type: type,
          recommendation: recommendation,
          isLegitimateMultiDevice: isLegitimateMultiDevice,
          timeOverlap: timeOverlap,
          explanation: explanation,
        ),
      );
    }

    return conflicts;
  }

  /// Determine type of conflict
  static ConflictType _determineConflictType(List<DataSourceInfo> sources) {
    // Check for sync loop (very similar record counts)
    if (sources.length >= 2) {
      final counts = sources.map((s) => s.recordCount).toList();
      final maxCount = counts.reduce(max);
      final minCount = counts.reduce(min);

      // If all sources have very similar counts, likely sync loop
      if (maxCount > 0 && (minCount / maxCount) > 0.9) {
        return ConflictType.syncLoop;
      }
    }

    // Check for multiple devices
    final devices = sources
        .where((s) => s.deviceModel != null)
        .map((s) => s.deviceModel)
        .toSet();

    if (devices.length > 1) {
      return ConflictType.multipleDevices;
    }

    // Default to multiple writers
    return ConflictType.multipleWriters;
  }

  /// Calculate severity of conflict (0.0 to 1.0)
  static double _calculateSeverity(List<DataSourceInfo> sources) {
    if (sources.length <= 1) return 0.0;

    // Factors:
    // 1. Number of sources (more = higher severity)
    // 2. Distribution of records (more even = higher severity)
    // 3. Presence of non-system apps (higher severity)

    // Factor 1: Number of sources
    final sourceFactor = min((sources.length - 1) / 4.0, 1.0);

    // Factor 2: Distribution evenness (Gini coefficient)
    final counts = sources.map((s) => s.recordCount.toDouble()).toList();
    final distributionFactor = _calculateGiniCoefficient(counts);

    // Factor 3: Non-system apps
    final nonSystemCount = sources.where((s) => !s.isSystemApp).length;
    final nonSystemFactor = min(nonSystemCount / 2.0, 1.0);

    // Weighted average
    final severity = (sourceFactor * 0.4) +
                     (distributionFactor * 0.3) +
                     (nonSystemFactor * 0.3);

    return severity.clamp(0.0, 1.0);
  }

  /// Calculate Gini coefficient (measure of distribution inequality)
  /// Returns 0 (perfectly equal) to 1 (perfectly unequal)
  static double _calculateGiniCoefficient(List<double> values) {
    if (values.isEmpty || values.length == 1) return 0.0;

    final sorted = List<double>.from(values)..sort();
    final n = sorted.length;
    var numerator = 0.0;

    for (var i = 0; i < n; i++) {
      numerator += (i + 1) * sorted[i];
    }

    final sum = sorted.reduce((a, b) => a + b);
    if (sum == 0) return 0.0;

    return (2 * numerator) / (n * sum) - (n + 1) / n;
  }

  /// Get recommendation for resolving conflict
  static String _getRecommendation(
    List<DataSourceInfo> sources,
    DataType dataType,
  ) {
    if (sources.isEmpty) return '';

    final primary = sources.first;
    final secondaryApps = sources.skip(1).map((s) => s.displayName).join(', ');

    if (sources.length == 2) {
      return 'Multiple apps detected: ${primary.displayName} and $secondaryApps. '
             'Disable ${dataType.toValue()} tracking in one app to avoid double-counting.';
    } else {
      return 'Multiple apps detected (${sources.length}): ${primary.displayName}, $secondaryApps. '
             'Keep only one app tracking ${dataType.toValue()} to avoid inflated counts.';
    }
  }

  /// Check if package is a system app
  static bool _isSystemApp(String packageName) {
    final systemApps = [
      'com.google.android.apps.fitness',  // Google Fit
      'com.samsung.health',                // Samsung Health
      'com.android.healthconnect',         // Health Connect
      'com.google.android.gms',            // Google Play Services
    ];

    return systemApps.contains(packageName);
  }

  /// Get user-friendly warning message
  static String getWarningMessage(ConflictDetectionResult result) {
    if (!result.hasConflicts) {
      return 'No conflicts detected. Data looks good!';
    }

    final conflict = result.conflicts.first;
    final sourceNames = conflict.sources.map((s) => s.displayName).join(', ');

    if (conflict.isHighSeverity) {
      return '⚠️ HIGH RISK: Multiple apps ($sourceNames) are writing ${result.dataType.toValue()} data. '
             'This may cause significantly inflated counts and sync loops.';
    } else if (conflict.isMediumSeverity) {
      return '⚠️ WARNING: Multiple apps ($sourceNames) are writing ${result.dataType.toValue()} data. '
             'This may cause double-counting.';
    } else {
      return 'ℹ️ INFO: Multiple apps detected but conflict severity is low.';
    }
  }

  /// Generate detailed report
  static String generateReport(ConflictDetectionResult result) {
    final buffer = StringBuffer();

    buffer.writeln('Conflict Detection Report');
    buffer.writeln('Data Type: ${result.dataType.toValue()}');
    buffer.writeln('Period: ${result.startTime} to ${result.endTime}');
    buffer.writeln('Total Records: ${result.totalRecords}');
    buffer.writeln('');

    buffer.writeln('Data Sources (${result.sources.length}):');
    for (final source in result.sources) {
      buffer.writeln('  • ${source.displayName}');
      buffer.writeln('    Records: ${source.recordCount} (${source.percentage.toStringAsFixed(1)}%)');
      buffer.writeln('    System App: ${source.isSystemApp}');
      if (source.deviceModel != null) {
        buffer.writeln('    Device: ${source.deviceManufacturer} ${source.deviceModel}');
      }
    }
    buffer.writeln('');

    if (result.hasConflicts) {
      buffer.writeln('Conflicts Detected: ${result.conflicts.length}');
      for (final conflict in result.conflicts) {
        buffer.writeln('');
        buffer.writeln('Conflict:');
        buffer.writeln('  Type: ${conflict.type.name}');
        buffer.writeln('  Severity: ${conflict.severity.toStringAsFixed(2)} (${_getSeverityLabel(conflict.severity)})');
        buffer.writeln('  Recommendation: ${conflict.recommendation}');
      }
    } else {
      buffer.writeln('No Conflicts Detected ✓');
    }

    return buffer.toString();
  }

  static String _getSeverityLabel(double severity) {
    if (severity >= 0.7) return 'HIGH';
    if (severity >= 0.4) return 'MEDIUM';
    return 'LOW';
  }

  /// Calculate confidence that this is a real conflict (0.0 to 1.0)
  static double _calculateConfidence(
    List<DataSourceInfo> sources,
    ConflictType type,
  ) {
    if (sources.length <= 1) return 0.0;

    double baseConfidence = 0.5;

    // Higher confidence for sync loops (similar record counts)
    if (type == ConflictType.syncLoop) {
      baseConfidence = 0.9;
    }

    // Higher confidence if both are system apps
    final systemAppCount = sources.where((s) => s.isSystemApp).length;
    if (systemAppCount >= 2) {
      baseConfidence += 0.1;
    }

    // Higher confidence if distribution is even (likely duplicates)
    final maxPercentage = sources.map((s) => s.percentage).reduce(max);
    final minPercentage = sources.map((s) => s.percentage).reduce(min);
    if (maxPercentage < 60 && minPercentage > 40) {
      // Very even distribution = likely duplicates
      baseConfidence += 0.2;
    }

    return baseConfidence.clamp(0.0, 1.0);
  }

  /// Check if sources are legitimate multi-device usage
  static bool _isLegitimateMultiDevice(List<DataSourceInfo> sources) {
    if (sources.length != 2) return false;

    // Check if same app (package name) but different devices
    final packageNames = sources.map((s) => s.packageName).toSet();
    if (packageNames.length == 1) {
      // Same app - check for different devices
      final devices = sources
          .where((s) => s.deviceModel != null)
          .map((s) => s.deviceModel)
          .toSet();
      return devices.length > 1;
    }

    return false;
  }

  /// Calculate time overlap between sources (0.0 to 1.0)
  ///
  /// Currently returns 1.0 (full overlap) as we don't have timestamp data.
  /// This would need actual record timestamps to calculate accurately.
  static double _calculateTimeOverlap(List<DataSourceInfo> sources) {
    // TODO: Calculate actual time overlap when we have timestamp data
    // For now, assume full overlap (worst case)
    return 1.0;
  }

  /// Generate explanation for the conflict
  static String _generateExplanation(
    List<DataSourceInfo> sources,
    ConflictType type,
    double severity,
    double confidence,
  ) {
    final buffer = StringBuffer();

    switch (type) {
      case ConflictType.syncLoop:
        buffer.write('Multiple apps have very similar record counts, '
            'suggesting they may be copying data back and forth.');
        break;
      case ConflictType.multipleDevices:
        buffer.write('The same app is running on multiple devices. '
            'This is normal if you use both a phone and watch.');
        break;
      case ConflictType.multipleWriters:
        buffer.write('Multiple different apps are writing ${sources.first.dataType.toValue()} data.');
        break;
      case ConflictType.manualVsAutomatic:
        buffer.write('Mix of manual entries and automatic tracking detected.');
        break;
      case ConflictType.unknown:
        buffer.write('Multiple data sources detected.');
        break;
    }

    if (confidence < 0.5) {
      buffer.write(' However, confidence is low - this may be normal usage.');
    }

    return buffer.toString();
  }
}
