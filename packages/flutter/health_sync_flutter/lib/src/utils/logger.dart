import 'package:flutter/foundation.dart';

/// Log level for SDK logging
enum LogLevel {
  debug,
  info,
  warning,
  error,
  critical,
}

/// Log entry for SDK events
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? category;
  final Map<String, dynamic>? metadata;
  final Object? error;
  final StackTrace? stackTrace;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.category,
    this.metadata,
    this.error,
    this.stackTrace,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'message': message,
      if (category != null) 'category': category,
      if (metadata != null) 'metadata': metadata,
      if (error != null) 'error': error.toString(),
      if (stackTrace != null) 'stackTrace': stackTrace.toString(),
    };
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('[${timestamp.toIso8601String()}] ');
    buffer.write('[${level.name.toUpperCase()}] ');
    if (category != null) buffer.write('[$category] ');
    buffer.write(message);
    if (metadata != null && metadata!.isNotEmpty) {
      buffer.write(' | Metadata: $metadata');
    }
    if (error != null) {
      buffer.write('\n  Error: $error');
    }
    if (stackTrace != null) {
      buffer.write('\n  Stack: $stackTrace');
    }
    return buffer.toString();
  }
}

/// Callback for custom log handling
typedef LogCallback = void Function(LogEntry entry);

/// Callback for analytics/telemetry
typedef AnalyticsCallback = void Function(String event, Map<String, dynamic> properties);

/// HealthSync SDK Logger with analytics integration
class HealthSyncLogger {
  static final HealthSyncLogger _instance = HealthSyncLogger._internal();
  factory HealthSyncLogger() => _instance;
  HealthSyncLogger._internal();

  LogLevel _minLevel = kDebugMode ? LogLevel.debug : LogLevel.info;
  final List<LogEntry> _logs = [];
  final List<LogCallback> _callbacks = [];
  AnalyticsCallback? _analyticsCallback;

  /// Maximum number of logs to keep in memory
  int maxLogsInMemory = 1000;

  /// Enable/disable console logging
  bool enableConsoleLogging = true;

  /// Set minimum log level
  void setMinLevel(LogLevel level) {
    _minLevel = level;
  }

  /// Add custom log callback (for sending to backend, Sentry, etc.)
  void addLogCallback(LogCallback callback) {
    _callbacks.add(callback);
  }

  /// Set analytics callback (for Mixpanel, Amplitude, Firebase, etc.)
  void setAnalyticsCallback(AnalyticsCallback callback) {
    _analyticsCallback = callback;
  }

  /// Get all logs
  List<LogEntry> get logs => List.unmodifiable(_logs);

  /// Clear all logs
  void clearLogs() {
    _logs.clear();
  }

  /// Export logs as JSON
  List<Map<String, dynamic>> exportLogsAsJson() {
    return _logs.map((log) => log.toJson()).toList();
  }

  /// Log a message
  void log(
    LogLevel level,
    String message, {
    String? category,
    Map<String, dynamic>? metadata,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < _minLevel.index) return;

    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      category: category,
      metadata: metadata,
      error: error,
      stackTrace: stackTrace,
    );

    // Add to logs
    _logs.add(entry);
    if (_logs.length > maxLogsInMemory) {
      _logs.removeAt(0); // Remove oldest
    }

    // Console logging
    if (enableConsoleLogging) {
      _printToConsole(entry);
    }

    // Custom callbacks
    for (final callback in _callbacks) {
      try {
        callback(entry);
      } catch (e) {
        debugPrint('Error in log callback: $e');
      }
    }

    // Analytics (only for important events)
    if (level.index >= LogLevel.warning.index && _analyticsCallback != null) {
      try {
        _analyticsCallback!(
          'sdk_${level.name}',
          {
            'message': message,
            if (category != null) 'category': category,
            if (metadata != null) ...metadata,
          },
        );
      } catch (e) {
        debugPrint('Error in analytics callback: $e');
      }
    }
  }

  void _printToConsole(LogEntry entry) {
    switch (entry.level) {
      case LogLevel.debug:
        debugPrint('🔍 ${entry.toString()}');
        break;
      case LogLevel.info:
        debugPrint('ℹ️  ${entry.toString()}');
        break;
      case LogLevel.warning:
        debugPrint('⚠️  ${entry.toString()}');
        break;
      case LogLevel.error:
        debugPrint('❌ ${entry.toString()}');
        break;
      case LogLevel.critical:
        debugPrint('🚨 ${entry.toString()}');
        break;
    }
  }

  // Convenience methods
  void debug(String message, {String? category, Map<String, dynamic>? metadata}) {
    log(LogLevel.debug, message, category: category, metadata: metadata);
  }

  void info(String message, {String? category, Map<String, dynamic>? metadata}) {
    log(LogLevel.info, message, category: category, metadata: metadata);
  }

  void warning(String message, {String? category, Map<String, dynamic>? metadata}) {
    log(LogLevel.warning, message, category: category, metadata: metadata);
  }

  void error(
    String message, {
    String? category,
    Map<String, dynamic>? metadata,
    Object? error,
    StackTrace? stackTrace,
  }) {
    log(
      LogLevel.error,
      message,
      category: category,
      metadata: metadata,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void critical(
    String message, {
    String? category,
    Map<String, dynamic>? metadata,
    Object? error,
    StackTrace? stackTrace,
  }) {
    log(
      LogLevel.critical,
      message,
      category: category,
      metadata: metadata,
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// Global logger instance
final logger = HealthSyncLogger();
