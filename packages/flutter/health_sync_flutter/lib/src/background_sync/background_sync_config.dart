import '../models/data_type.dart';

/// Configuration for background sync
class BackgroundSyncConfig {
  /// Data types to sync in background
  final List<DataType> dataTypes;

  /// Sync frequency (minimum 15 minutes per Android restrictions)
  final Duration frequency;

  /// Whether to use incremental sync (Changes API) or full sync
  final bool useIncrementalSync;

  /// Whether to require charging
  final bool requiresCharging;

  /// Whether to require WiFi
  final bool requiresWiFi;

  /// Whether to require device idle
  final bool requiresDeviceIdle;

  /// Whether to require battery not low
  final bool requiresBatteryNotLow;

  /// Whether to require storage not low
  final bool requiresStorageNotLow;

  /// Callback to process synced data (called in background)
  final Future<void> Function(DataType, List<dynamic>)? onDataSynced;

  /// Callback when sync completes (called in background)
  final Future<void> Function(BackgroundSyncResult)? onSyncComplete;

  /// Callback when sync fails (called in background)
  final Future<void> Function(String error)? onSyncFailed;

  /// Whether background sync is enabled
  final bool enabled;

  /// Unique tag for this sync task
  final String taskTag;

  const BackgroundSyncConfig({
    required this.dataTypes,
    this.frequency = const Duration(minutes: 15),
    this.useIncrementalSync = true,
    this.requiresCharging = false,
    this.requiresWiFi = false,
    this.requiresDeviceIdle = false,
    this.requiresBatteryNotLow = true,
    this.requiresStorageNotLow = true,
    this.onDataSynced,
    this.onSyncComplete,
    this.onSyncFailed,
    this.enabled = true,
    this.taskTag = 'healthSyncBackgroundTask',
  });

  /// Create conservative config (minimal battery usage)
  factory BackgroundSyncConfig.conservative({
    required List<DataType> dataTypes,
    Duration frequency = const Duration(hours: 1),
    Future<void> Function(DataType, List<dynamic>)? onDataSynced,
  }) {
    return BackgroundSyncConfig(
      dataTypes: dataTypes,
      frequency: frequency,
      useIncrementalSync: true,
      requiresCharging: true,
      requiresWiFi: true,
      requiresDeviceIdle: false,
      requiresBatteryNotLow: true,
      requiresStorageNotLow: true,
      onDataSynced: onDataSynced,
    );
  }

  /// Create balanced config (reasonable battery/frequency tradeoff)
  factory BackgroundSyncConfig.balanced({
    required List<DataType> dataTypes,
    Duration frequency = const Duration(minutes: 30),
    Future<void> Function(DataType, List<dynamic>)? onDataSynced,
  }) {
    return BackgroundSyncConfig(
      dataTypes: dataTypes,
      frequency: frequency,
      useIncrementalSync: true,
      requiresCharging: false,
      requiresWiFi: false,
      requiresDeviceIdle: false,
      requiresBatteryNotLow: true,
      requiresStorageNotLow: true,
      onDataSynced: onDataSynced,
    );
  }

  /// Create aggressive config (frequent sync, higher battery usage)
  factory BackgroundSyncConfig.aggressive({
    required List<DataType> dataTypes,
    Duration frequency = const Duration(minutes: 15),
    Future<void> Function(DataType, List<dynamic>)? onDataSynced,
  }) {
    return BackgroundSyncConfig(
      dataTypes: dataTypes,
      frequency: frequency,
      useIncrementalSync: true,
      requiresCharging: false,
      requiresWiFi: false,
      requiresDeviceIdle: false,
      requiresBatteryNotLow: false,
      requiresStorageNotLow: false,
      onDataSynced: onDataSynced,
    );
  }

  /// Copy with modifications
  BackgroundSyncConfig copyWith({
    List<DataType>? dataTypes,
    Duration? frequency,
    bool? useIncrementalSync,
    bool? requiresCharging,
    bool? requiresWiFi,
    bool? requiresDeviceIdle,
    bool? requiresBatteryNotLow,
    bool? requiresStorageNotLow,
    Future<void> Function(DataType, List<dynamic>)? onDataSynced,
    Future<void> Function(BackgroundSyncResult)? onSyncComplete,
    Future<void> Function(String)? onSyncFailed,
    bool? enabled,
    String? taskTag,
  }) {
    return BackgroundSyncConfig(
      dataTypes: dataTypes ?? this.dataTypes,
      frequency: frequency ?? this.frequency,
      useIncrementalSync: useIncrementalSync ?? this.useIncrementalSync,
      requiresCharging: requiresCharging ?? this.requiresCharging,
      requiresWiFi: requiresWiFi ?? this.requiresWiFi,
      requiresDeviceIdle: requiresDeviceIdle ?? this.requiresDeviceIdle,
      requiresBatteryNotLow: requiresBatteryNotLow ?? this.requiresBatteryNotLow,
      requiresStorageNotLow: requiresStorageNotLow ?? this.requiresStorageNotLow,
      onDataSynced: onDataSynced ?? this.onDataSynced,
      onSyncComplete: onSyncComplete ?? this.onSyncComplete,
      onSyncFailed: onSyncFailed ?? this.onSyncFailed,
      enabled: enabled ?? this.enabled,
      taskTag: taskTag ?? this.taskTag,
    );
  }

  @override
  String toString() {
    return 'BackgroundSyncConfig{'
        'dataTypes: ${dataTypes.map((t) => t.toValue()).toList()}, '
        'frequency: ${frequency.inMinutes}min, '
        'incremental: $useIncrementalSync, '
        'charging: $requiresCharging, '
        'wifi: $requiresWiFi, '
        'enabled: $enabled'
        '}';
  }
}

/// Result of a background sync operation
class BackgroundSyncResult {
  /// When the sync started
  final DateTime startTime;

  /// When the sync completed
  final DateTime endTime;

  /// Data types that were synced
  final List<DataType> dataTypes;

  /// Total records synced per data type
  final Map<DataType, int> recordCounts;

  /// Whether sync was successful
  final bool success;

  /// Error message if failed
  final String? errorMessage;

  /// Whether incremental sync was used
  final bool wasIncremental;

  const BackgroundSyncResult({
    required this.startTime,
    required this.endTime,
    required this.dataTypes,
    required this.recordCounts,
    required this.success,
    this.errorMessage,
    required this.wasIncremental,
  });

  /// Duration of the sync
  Duration get duration => endTime.difference(startTime);

  /// Total records synced across all types
  int get totalRecords => recordCounts.values.fold(0, (sum, count) => sum + count);

  @override
  String toString() {
    return 'BackgroundSyncResult{'
        'duration: ${duration.inSeconds}s, '
        'types: ${dataTypes.length}, '
        'records: $totalRecords, '
        'success: $success, '
        'incremental: $wasIncremental'
        '}';
  }
}
