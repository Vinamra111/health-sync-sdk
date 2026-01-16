import 'dart:async';
import 'dart:math' as math;

/// Retry strategy type.
enum RetryStrategyType {
  /// Fixed delay between retries.
  ///
  /// Example: 1s, 1s, 1s, 1s, 1s
  linear,

  /// Exponentially increasing delay between retries.
  ///
  /// Example: 1s, 2s, 4s, 8s, 16s
  exponential,

  /// Custom delay calculator.
  custom,
}

/// Configuration for retry behavior.
class RetryStrategy {
  /// Type of retry strategy.
  final RetryStrategyType type;

  /// Maximum number of retry attempts.
  final int maxAttempts;

  /// Initial delay before first retry.
  final Duration initialDelay;

  /// Maximum delay between retries (for exponential backoff).
  final Duration maxDelay;

  /// Multiplier for exponential backoff (default: 2.0).
  final double backoffMultiplier;

  /// Optional custom delay calculator.
  ///
  /// Takes attempt number (1-based) and returns delay duration.
  final Duration Function(int attempt)? customDelayCalculator;

  /// Whether to add jitter to delays (randomization to avoid thundering herd).
  final bool addJitter;

  /// Jitter factor (0.0 to 1.0). 0.2 means ±20% randomization.
  final double jitterFactor;

  const RetryStrategy({
    required this.type,
    required this.maxAttempts,
    required this.initialDelay,
    this.maxDelay = const Duration(seconds: 30),
    this.backoffMultiplier = 2.0,
    this.customDelayCalculator,
    this.addJitter = false,
    this.jitterFactor = 0.2,
  });

  /// Linear retry strategy with fixed delays.
  ///
  /// Example: 5 attempts with 1 second delay.
  /// Delays: 1s, 1s, 1s, 1s, 1s
  const RetryStrategy.linear({
    int maxAttempts = 5,
    Duration delay = const Duration(seconds: 1),
  }) : this(
          type: RetryStrategyType.linear,
          maxAttempts: maxAttempts,
          initialDelay: delay,
        );

  /// Exponential backoff retry strategy.
  ///
  /// Example: 5 attempts starting with 1 second, max 16 seconds.
  /// Delays: 1s, 2s, 4s, 8s, 16s
  const RetryStrategy.exponential({
    int maxAttempts = 5,
    Duration initialDelay = const Duration(seconds: 1),
    Duration maxDelay = const Duration(seconds: 16),
    double backoffMultiplier = 2.0,
    bool addJitter = true,
    double jitterFactor = 0.2,
  }) : this(
          type: RetryStrategyType.exponential,
          maxAttempts: maxAttempts,
          initialDelay: initialDelay,
          maxDelay: maxDelay,
          backoffMultiplier: backoffMultiplier,
          addJitter: addJitter,
          jitterFactor: jitterFactor,
        );

  /// Custom retry strategy with user-defined delay calculator.
  const RetryStrategy.custom({
    required int maxAttempts,
    required Duration Function(int attempt) delayCalculator,
  }) : this(
          type: RetryStrategyType.custom,
          maxAttempts: maxAttempts,
          initialDelay: Duration.zero,
          customDelayCalculator: delayCalculator,
        );

  /// Calculate delay for a given attempt.
  Duration calculateDelay(int attempt) {
    if (type == RetryStrategyType.custom && customDelayCalculator != null) {
      return customDelayCalculator!(attempt);
    }

    Duration delay;

    if (type == RetryStrategyType.linear) {
      delay = initialDelay;
    } else {
      // Exponential backoff
      final multiplier = math.pow(backoffMultiplier, attempt - 1).toDouble();
      final delayMs = (initialDelay.inMilliseconds * multiplier).round();
      delay = Duration(milliseconds: delayMs);

      // Cap at max delay
      if (delay > maxDelay) {
        delay = maxDelay;
      }
    }

    // Add jitter if enabled
    if (addJitter) {
      final jitterMs = (delay.inMilliseconds * jitterFactor).round();
      final randomJitter =
          math.Random().nextInt(jitterMs * 2 + 1) - jitterMs;
      delay = Duration(
        milliseconds: math.max(0, delay.inMilliseconds + randomJitter),
      );
    }

    return delay;
  }

  /// Get total time for all retries (worst case, without jitter).
  Duration get totalRetryTime {
    var total = Duration.zero;
    for (int i = 1; i <= maxAttempts; i++) {
      total += calculateDelay(i);
    }
    return total;
  }
}

/// Information about a retry attempt.
class RetryAttempt {
  /// Attempt number (1-based).
  final int attemptNumber;

  /// Total attempts allowed.
  final int maxAttempts;

  /// Delay before this attempt.
  final Duration delay;

  /// Whether this is the first attempt.
  final bool isFirstAttempt;

  /// Whether this is the last attempt.
  final bool isLastAttempt;

  /// Error from previous attempt (null on first attempt).
  final dynamic error;

  /// Timestamp of this attempt.
  final DateTime timestamp;

  RetryAttempt({
    required this.attemptNumber,
    required this.maxAttempts,
    required this.delay,
    this.error,
    DateTime? timestamp,
  })  : isFirstAttempt = attemptNumber == 1,
        isLastAttempt = attemptNumber == maxAttempts,
        timestamp = timestamp ?? DateTime.now();

  /// Progress (0.0 to 1.0).
  double get progress => attemptNumber / maxAttempts;

  @override
  String toString() {
    return 'RetryAttempt{attempt: $attemptNumber/$maxAttempts, delay: ${delay.inSeconds}s}';
  }
}

/// Result of a retry operation.
class RetryResult<T> {
  /// Whether the operation succeeded.
  final bool success;

  /// Result value (if successful).
  final T? value;

  /// Error (if failed).
  final dynamic error;

  /// Number of attempts made.
  final int attempts;

  /// Total time taken.
  final Duration totalDuration;

  /// List of all errors encountered.
  final List<dynamic> errors;

  const RetryResult({
    required this.success,
    this.value,
    this.error,
    required this.attempts,
    required this.totalDuration,
    this.errors = const [],
  });

  /// Create successful result.
  factory RetryResult.success(T value, int attempts, Duration duration) {
    return RetryResult(
      success: true,
      value: value,
      attempts: attempts,
      totalDuration: duration,
    );
  }

  /// Create failed result.
  factory RetryResult.failure(
    dynamic error,
    int attempts,
    Duration duration,
    List<dynamic> errors,
  ) {
    return RetryResult(
      success: false,
      error: error,
      attempts: attempts,
      totalDuration: duration,
      errors: errors,
    );
  }
}

/// Orchestrates retry logic for operations.
///
/// Handles transient failures with configurable retry strategies including
/// linear and exponential backoff. Critical for handling the Health Connect
/// "update loop bug" where SDK status may be incorrect for 10+ seconds after update.
///
/// **Example: Linear Retry**
/// ```dart
/// final orchestrator = RetryOrchestrator();
/// final result = await orchestrator.execute(
///   () => checkHealthConnectStatus(),
///   strategy: RetryStrategy.linear(maxAttempts: 5, delay: Duration(seconds: 1)),
/// );
/// ```
///
/// **Example: Exponential Backoff**
/// ```dart
/// final result = await orchestrator.execute(
///   () => checkHealthConnectStatus(),
///   strategy: RetryStrategy.exponential(
///     maxAttempts: 5,
///     initialDelay: Duration(seconds: 1),
///     maxDelay: Duration(seconds: 16),
///   ),
/// );
/// ```
class RetryOrchestrator {
  /// Stream controller for retry attempt events.
  final _attemptController = StreamController<RetryAttempt>.broadcast();

  /// Whether this orchestrator has been cancelled.
  bool _cancelled = false;

  /// Stream of retry attempts.
  ///
  /// Emits [RetryAttempt] for each retry attempt. Useful for UI progress updates.
  Stream<RetryAttempt> get attemptStream => _attemptController.stream;

  /// Execute an operation with retry logic.
  ///
  /// **Parameters:**
  /// - [operation]: The operation to execute (must return Future<T>)
  /// - [strategy]: Retry strategy configuration
  /// - [shouldRetry]: Optional predicate to determine if error is retryable
  /// - [onAttempt]: Optional callback invoked on each attempt
  ///
  /// **Returns:** [RetryResult] with success status, value, or error
  ///
  /// **Example:**
  /// ```dart
  /// final result = await orchestrator.execute(
  ///   () async {
  ///     final status = await checkStatus();
  ///     if (status.requiresUpdate) {
  ///       throw Exception('Still requires update');
  ///     }
  ///     return status;
  ///   },
  ///   strategy: RetryStrategy.exponential(maxAttempts: 5),
  ///   shouldRetry: (error) => error.toString().contains('requires update'),
  /// );
  /// ```
  Future<RetryResult<T>> execute<T>(
    Future<T> Function() operation, {
    RetryStrategy strategy = const RetryStrategy.linear(),
    bool Function(dynamic error)? shouldRetry,
    void Function(RetryAttempt attempt)? onAttempt,
  }) async {
    final startTime = DateTime.now();
    final errors = <dynamic>[];

    for (int attempt = 1; attempt <= strategy.maxAttempts; attempt++) {
      if (_cancelled) {
        return RetryResult.failure(
          Exception('Retry cancelled'),
          attempt - 1,
          DateTime.now().difference(startTime),
          errors,
        );
      }

      final delay = attempt == 1
          ? Duration.zero
          : strategy.calculateDelay(attempt - 1);

      final attemptInfo = RetryAttempt(
        attemptNumber: attempt,
        maxAttempts: strategy.maxAttempts,
        delay: delay,
        error: errors.isNotEmpty ? errors.last : null,
      );

      // Emit attempt event
      _attemptController.add(attemptInfo);

      // Notify callback
      if (onAttempt != null) {
        onAttempt(attemptInfo);
      }

      // Wait before retry (except first attempt)
      if (attempt > 1) {
        await Future.delayed(delay);
      }

      try {
        final result = await operation();
        final duration = DateTime.now().difference(startTime);
        return RetryResult.success(result, attempt, duration);
      } catch (e) {
        errors.add(e);

        // Check if we should retry this error
        if (shouldRetry != null && !shouldRetry(e)) {
          final duration = DateTime.now().difference(startTime);
          return RetryResult.failure(e, attempt, duration, errors);
        }

        // If this was the last attempt, return failure
        if (attempt == strategy.maxAttempts) {
          final duration = DateTime.now().difference(startTime);
          return RetryResult.failure(e, attempt, duration, errors);
        }

        // Otherwise, continue to next attempt
      }
    }

    // Should never reach here, but return failure as fallback
    final duration = DateTime.now().difference(startTime);
    return RetryResult.failure(
      Exception('Max attempts exceeded'),
      strategy.maxAttempts,
      duration,
      errors,
    );
  }

  /// Execute a condition check with retry until it becomes true.
  ///
  /// Keeps retrying until the condition returns true or max attempts reached.
  ///
  /// **Parameters:**
  /// - [condition]: Function that returns true when desired state is reached
  /// - [strategy]: Retry strategy configuration
  /// - [onAttempt]: Optional callback invoked on each attempt
  ///
  /// **Returns:** True if condition met, false if max attempts exceeded
  ///
  /// **Example:**
  /// ```dart
  /// // Wait until Health Connect becomes available
  /// final success = await orchestrator.retryUntil(
  ///   () async {
  ///     final status = await checkStatus();
  ///     return status.isAvailable;
  ///   },
  ///   strategy: RetryStrategy.exponential(maxAttempts: 8),
  /// );
  /// ```
  Future<bool> retryUntil(
    Future<bool> Function() condition, {
    RetryStrategy strategy = const RetryStrategy.linear(),
    void Function(RetryAttempt attempt)? onAttempt,
  }) async {
    final result = await execute<bool>(
      () async {
        final conditionMet = await condition();
        if (!conditionMet) {
          throw Exception('Condition not met yet');
        }
        return conditionMet;
      },
      strategy: strategy,
      shouldRetry: (error) => true, // Always retry on error
      onAttempt: onAttempt,
    );

    return result.success && result.value == true;
  }

  /// Stream version of retry logic.
  ///
  /// Emits results for each retry attempt, allowing reactive UI updates.
  ///
  /// **Example:**
  /// ```dart
  /// await for (final attempt in orchestrator.retryStream(
  ///   () => checkStatus(),
  ///   strategy: RetryStrategy.exponential(),
  /// )) {
  ///   print('Attempt ${attempt.attemptNumber}: ${attempt.delay}');
  /// }
  /// ```
  Stream<RetryAttempt> retryStream(
    Future<bool> Function() condition, {
    RetryStrategy strategy = const RetryStrategy.linear(),
  }) async* {
    for (int attempt = 1; attempt <= strategy.maxAttempts; attempt++) {
      if (_cancelled) {
        break;
      }

      final delay = attempt == 1
          ? Duration.zero
          : strategy.calculateDelay(attempt - 1);

      final attemptInfo = RetryAttempt(
        attemptNumber: attempt,
        maxAttempts: strategy.maxAttempts,
        delay: delay,
      );

      yield attemptInfo;

      // Wait before check (except first attempt)
      if (attempt > 1) {
        await Future.delayed(delay);
      }

      try {
        final result = await condition();
        if (result) {
          break; // Condition met, stop retrying
        }
      } catch (e) {
        // Continue to next attempt on error
        if (attempt == strategy.maxAttempts) {
          break;
        }
      }
    }
  }

  /// Cancel ongoing retry operations.
  ///
  /// Sets cancellation flag that will be checked on next retry attempt.
  void cancel() {
    _cancelled = true;
  }

  /// Reset cancellation flag.
  void reset() {
    _cancelled = false;
  }

  /// Whether this orchestrator is cancelled.
  bool get isCancelled => _cancelled;

  /// Dispose of resources.
  void dispose() {
    _attemptController.close();
  }
}

/// Predefined retry predicates for common scenarios.
class RetryPredicates {
  /// Retry on all errors.
  static bool alwaysRetry(dynamic error) => true;

  /// Never retry (fail immediately).
  static bool neverRetry(dynamic error) => false;

  /// Retry only on specific error types.
  static bool retryOnType<T>(dynamic error) => error is T;

  /// Retry only if error message contains specific text.
  static bool Function(dynamic) retryOnMessageContains(String text) {
    return (error) => error.toString().toLowerCase().contains(text.toLowerCase());
  }

  /// Retry on Health Connect "update required" errors.
  static bool retryOnUpdateRequired(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('update required') ||
        errorStr.contains('unavailable_provider_update_required') ||
        errorStr.contains('sdk_unavailable');
  }

  /// Retry on transient network errors.
  static bool retryOnNetworkError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    return errorStr.contains('network') ||
        errorStr.contains('connection') ||
        errorStr.contains('timeout') ||
        errorStr.contains('socket');
  }

  /// Combine multiple predicates with OR logic.
  static bool Function(dynamic) any(List<bool Function(dynamic)> predicates) {
    return (error) => predicates.any((predicate) => predicate(error));
  }

  /// Combine multiple predicates with AND logic.
  static bool Function(dynamic) all(List<bool Function(dynamic)> predicates) {
    return (error) => predicates.every((predicate) => predicate(error));
  }
}
