import '../models/data_type.dart';

/// Information about a data source (app) writing health data
class DataSourceInfo {
  /// Package name of the app
  final String packageName;

  /// Human-readable app name
  final String? appName;

  /// Number of records from this source
  final int recordCount;

  /// Data type
  final DataType dataType;

  /// Whether this is a system/trusted app
  final bool isSystemApp;

  /// Device info (if available)
  final String? deviceManufacturer;
  final String? deviceModel;

  /// Percentage of total records
  final double percentage;

  const DataSourceInfo({
    required this.packageName,
    this.appName,
    required this.recordCount,
    required this.dataType,
    required this.isSystemApp,
    this.deviceManufacturer,
    this.deviceModel,
    required this.percentage,
  });

  /// User-friendly display name
  String get displayName => appName ?? packageName;

  @override
  String toString() {
    return 'DataSourceInfo{'
        'app: $displayName, '
        'records: $recordCount (${percentage.toStringAsFixed(1)}%), '
        'system: $isSystemApp'
        '}';
  }
}

/// Conflict between multiple data sources
class DataSourceConflict {
  /// Data type with conflict
  final DataType dataType;

  /// Conflicting sources
  final List<DataSourceInfo> sources;

  /// Time period analyzed
  final DateTime startTime;
  final DateTime endTime;

  /// Total records across all sources
  final int totalRecords;

  /// Severity of conflict (0.0 to 1.0)
  ///
  /// Based on number of sources, distribution, and app types.
  final double severity;

  /// Confidence that this is a real conflict (0.0 to 1.0)
  ///
  /// Confidence levels:
  /// - 0.9-1.0: Very confident this is a real conflict
  /// - 0.7-0.9: Likely a conflict
  /// - 0.5-0.7: Possibly a conflict
  /// - <0.5: Might be legitimate use
  final double confidence;

  /// Type of conflict
  final ConflictType type;

  /// Whether this appears to be legitimate multi-device use
  ///
  /// True if sources are the same app on different devices,
  /// which is a valid use case (e.g., Google Fit on phone + watch).
  final bool isLegitimateMultiDevice;

  /// Time overlap percentage (0.0 to 1.0)
  ///
  /// How much the time ranges of different sources overlap.
  /// Low overlap (<20%) suggests complementary data, not duplicates.
  final double timeOverlap;

  /// Recommendation for resolving
  final String recommendation;

  /// Detailed explanation of the conflict
  ///
  /// Helps users understand why this was flagged.
  final String explanation;

  const DataSourceConflict({
    required this.dataType,
    required this.sources,
    required this.startTime,
    required this.endTime,
    required this.totalRecords,
    required this.severity,
    required this.confidence,
    required this.type,
    required this.recommendation,
    this.isLegitimateMultiDevice = false,
    this.timeOverlap = 1.0,
    this.explanation = '',
  });

  /// Whether this is a high-severity conflict
  bool get isHighSeverity => severity >= 0.7;

  /// Whether this is a medium-severity conflict
  bool get isMediumSeverity => severity >= 0.4 && severity < 0.7;

  /// Whether this is a low-severity conflict
  bool get isLowSeverity => severity < 0.4;

  /// Whether confidence is high (>80%)
  bool get isHighConfidence => confidence >= 0.8;

  /// Whether confidence is medium (50-80%)
  bool get isMediumConfidence => confidence >= 0.5 && confidence < 0.8;

  /// Whether confidence is low (<50%)
  bool get isLowConfidence => confidence < 0.5;

  /// Whether this conflict should trigger a user warning
  ///
  /// Only warn if both severity AND confidence are high enough.
  /// This prevents false positive warnings.
  bool get shouldWarnUser {
    // High severity + high confidence = definitely warn
    if (isHighSeverity && isHighConfidence) return true;

    // High severity but low confidence = don't warn (might be false positive)
    if (isHighSeverity && isLowConfidence) return false;

    // Medium severity + high confidence = warn
    if (isMediumSeverity && isHighConfidence) return true;

    // Everything else = don't warn
    return false;
  }

  /// Get safe, non-destructive recommendation
  ///
  /// Returns a recommendation that won't cause data loss.
  String getSafeRecommendation() {
    if (isLegitimateMultiDevice) {
      return 'You appear to be using ${sources.first.displayName} on multiple devices. '
             'This is normal if you switched devices or use a phone and watch together. '
             'No action needed unless you\'re seeing incorrect totals.';
    }

    if (timeOverlap < 0.2) {
      return 'Multiple apps detected, but they track different time periods. '
             'This may be intentional (e.g., you switched apps). '
             'Review your data timeline to confirm totals are correct.';
    }

    if (isLowConfidence) {
      return 'Multiple data sources detected. This might be normal if you:\n'
             '- Switched health apps recently\n'
             '- Use different apps for different activities\n'
             '- Track data on multiple devices\n\n'
             'Review your data sources and disable any you\'re not using.';
    }

    // High confidence conflict - provide specific guidance
    final appNames = sources.map((s) => s.displayName).join(' and ');
    return 'Multiple apps ($appNames) are tracking ${dataType.toValue()}. '
           'This may cause inflated counts.\n\n'
           'Recommended action:\n'
           '1. Review your data in each app\n'
           '2. Choose which app to keep\n'
           '3. Disable ${dataType.toValue()} tracking in the other app(s)\n\n'
           'If both apps track different activities, this is normal.';
  }

  /// Get detailed analysis for user
  String getDetailedAnalysis() {
    final buffer = StringBuffer();
    buffer.writeln('Conflict Analysis for ${dataType.toValue()}');
    buffer.writeln('');

    buffer.writeln('Severity: ${_getSeverityLabel(severity)} (${(severity * 100).toStringAsFixed(1)}%)');
    buffer.writeln('Confidence: ${_getConfidenceLabel(confidence)} (${(confidence * 100).toStringAsFixed(1)}%)');
    buffer.writeln('Type: ${_getTypeLabel(type)}');
    buffer.writeln('');

    buffer.writeln('Data Sources (${sources.length}):');
    for (final source in sources) {
      buffer.writeln('  • ${source.displayName}: ${source.recordCount} records (${source.percentage.toStringAsFixed(1)}%)');
      if (source.deviceModel != null) {
        buffer.writeln('    Device: ${source.deviceManufacturer} ${source.deviceModel}');
      }
    }
    buffer.writeln('');

    if (isLegitimateMultiDevice) {
      buffer.writeln('✓ Likely legitimate multi-device usage');
    }

    if (timeOverlap < 0.5) {
      buffer.writeln('✓ Sources have low time overlap (${(timeOverlap * 100).toStringAsFixed(1)}%)');
      buffer.writeln('  This suggests complementary data, not duplicates');
    }

    if (explanation.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('Explanation:');
      buffer.writeln(explanation);
    }

    buffer.writeln('');
    buffer.writeln('Recommendation:');
    buffer.writeln(getSafeRecommendation());

    return buffer.toString();
  }

  String _getSeverityLabel(double severity) {
    if (severity >= 0.7) return 'HIGH';
    if (severity >= 0.4) return 'MEDIUM';
    return 'LOW';
  }

  String _getConfidenceLabel(double confidence) {
    if (confidence >= 0.8) return 'HIGH';
    if (confidence >= 0.5) return 'MEDIUM';
    return 'LOW';
  }

  String _getTypeLabel(ConflictType type) {
    switch (type) {
      case ConflictType.multipleWriters:
        return 'Multiple apps writing same data';
      case ConflictType.syncLoop:
        return 'Sync loop detected (apps copying data back and forth)';
      case ConflictType.multipleDevices:
        return 'Same app on multiple devices';
      case ConflictType.manualVsAutomatic:
        return 'Manual entries competing with automatic tracking';
      case ConflictType.unknown:
        return 'Unknown conflict type';
    }
  }

  @override
  String toString() {
    return 'DataSourceConflict{'
        'type: ${dataType.toValue()}, '
        'sources: ${sources.length}, '
        'severity: ${severity.toStringAsFixed(2)}, '
        'confidence: ${confidence.toStringAsFixed(2)}, '
        'conflictType: ${type.name}, '
        'shouldWarn: $shouldWarnUser'
        '}';
  }
}

/// Type of data source conflict
enum ConflictType {
  /// Multiple apps writing the same data type
  multipleWriters,

  /// Same app writing from multiple devices
  multipleDevices,

  /// Manual entry competing with automatic tracking
  manualVsAutomatic,

  /// Potential sync loop detected
  syncLoop,

  /// Unknown/other conflict
  unknown,
}

/// Result of conflict detection analysis
class ConflictDetectionResult {
  /// Data type analyzed
  final DataType dataType;

  /// All detected sources
  final List<DataSourceInfo> sources;

  /// Detected conflicts (if any)
  final List<DataSourceConflict> conflicts;

  /// Whether conflicts were detected
  final bool hasConflicts;

  /// Time period analyzed
  final DateTime startTime;
  final DateTime endTime;

  /// Total records analyzed
  final int totalRecords;

  const ConflictDetectionResult({
    required this.dataType,
    required this.sources,
    required this.conflicts,
    required this.hasConflicts,
    required this.startTime,
    required this.endTime,
    required this.totalRecords,
  });

  /// Primary data source (most records)
  DataSourceInfo? get primarySource {
    if (sources.isEmpty) return null;
    return sources.reduce((a, b) => a.recordCount > b.recordCount ? a : b);
  }

  /// Secondary sources (not primary)
  List<DataSourceInfo> get secondarySources {
    final primary = primarySource;
    if (primary == null) return sources;
    return sources.where((s) => s.packageName != primary.packageName).toList();
  }

  /// High severity conflicts
  List<DataSourceConflict> get highSeverityConflicts {
    return conflicts.where((c) => c.isHighSeverity).toList();
  }

  /// Whether multiple writers detected
  bool get hasMultipleWriters => sources.length > 1;

  @override
  String toString() {
    return 'ConflictDetectionResult{'
        'type: ${dataType.toValue()}, '
        'sources: ${sources.length}, '
        'conflicts: ${conflicts.length}, '
        'hasConflicts: $hasConflicts'
        '}';
  }
}

/// Summary of conflicts across multiple data types
class ConflictSummary {
  /// Results per data type
  final Map<DataType, ConflictDetectionResult> results;

  /// When analysis was performed
  final DateTime analysisTime;

  const ConflictSummary({
    required this.results,
    required this.analysisTime,
  });

  /// Total number of conflicts detected
  int get totalConflicts {
    return results.values.fold(0, (sum, r) => sum + r.conflicts.length);
  }

  /// Data types with conflicts
  List<DataType> get typesWithConflicts {
    return results.entries
        .where((e) => e.value.hasConflicts)
        .map((e) => e.key)
        .toList();
  }

  /// High severity conflicts across all types
  List<DataSourceConflict> get allHighSeverityConflicts {
    return results.values
        .expand((r) => r.highSeverityConflicts)
        .toList();
  }

  /// Whether any conflicts detected
  bool get hasAnyConflicts => totalConflicts > 0;

  /// Whether any high severity conflicts
  bool get hasHighSeverityConflicts => allHighSeverityConflicts.isNotEmpty;

  @override
  String toString() {
    return 'ConflictSummary{'
        'types: ${results.length}, '
        'conflicts: $totalConflicts, '
        'highSeverity: ${allHighSeverityConflicts.length}'
        '}';
  }
}
