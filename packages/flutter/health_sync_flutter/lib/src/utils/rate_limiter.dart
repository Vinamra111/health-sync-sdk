import 'dart:async';
import 'package:flutter/foundation.dart';
import '../utils/logger.dart';

/// Rate limiter with exponential backoff for Health Connect operations
///
/// Implements retry logic to handle RateLimitExceededException from Health Connect.
/// Uses exponential backoff: 1s -> 2s -> 4s -> 8s -> 16s
///
/// IMPORTANT: Rate limiting should be a safety net, not a solution.
/// If you're hitting rate limits frequently (>10%), investigate root cause:
/// - Are you calling APIs in loops?
/// - Can you batch operations?
/// - Is there a logic error causing excessive calls?
///
/// Use `getStats()` to monitor rate limit frequency and identify issues.
class RateLimiter {
  /// Maximum number of retry attempts
  final int maxRetries;

  /// Initial delay in milliseconds (default: 1000ms = 1s)
  final int initialDelayMs;

  /// Maximum delay in milliseconds (default: 16000ms = 16s)
  final int maxDelayMs;

  /// Whether backoff is enabled (default: true)
  final bool enableBackoff;

  /// Circuit breaker: Stop retrying if this many consecutive failures occur
  final int circuitBreakerThreshold;

  /// Circuit breaker: Reset after this duration without failures
  final Duration circuitBreakerResetDuration;

  /// Statistics tracking
  final RateLimitStats _stats = RateLimitStats();

  /// Circuit breaker state
  int _consecutiveFailures = 0;
  DateTime? _lastFailureTime;
  bool _circuitOpen = false;

  RateLimiter({
    this.maxRetries = 5,
    this.initialDelayMs = 1000,
    this.maxDelayMs = 16000,
    this.enableBackoff = true,
    this.circuitBreakerThreshold = 10,
    this.circuitBreakerResetDuration = const Duration(minutes: 5),
  });

  /// Execute an operation with exponential backoff retry logic
  ///
  /// Automatically retries if rate limit is exceeded.
  /// Throws the original exception if max retries are reached.
  ///
  /// Throws [CircuitBreakerOpenException] if circuit breaker is open
  /// (too many consecutive failures).
  Future<T> execute<T>(
    Future<T> Function() operation, {
    String? operationName,
  }) async {
    // Check circuit breaker
    _checkCircuitBreaker();

    if (_circuitOpen) {
      logger.error(
        'Circuit breaker OPEN - refusing operation',
        category: 'RateLimiter',
        metadata: {
          'operation': operationName ?? 'Unknown',
          'consecutiveFailures': _consecutiveFailures,
          'advice': 'Too many failures detected. Check for architectural issues in your code. '
                    'Circuit will reset after $circuitBreakerResetDuration without failures.',
        },
      );
      throw CircuitBreakerOpenException(
        'Rate limiter circuit breaker is open after $_consecutiveFailures consecutive failures. '
        'This indicates a systemic issue that needs investigation.',
      );
    }

    int attempt = 0;
    int delayMs = initialDelayMs;
    final startTime = DateTime.now();

    while (true) {
      try {
        // Attempt the operation
        final result = await operation();

        // Success - record stats and reset circuit breaker
        final duration = DateTime.now().difference(startTime);
        _stats.recordSuccess(
          hadRetries: attempt > 0,
          retryCount: attempt,
          duration: duration,
        );
        _consecutiveFailures = 0;
        _circuitOpen = false;

        // Warn if we hit rate limits frequently
        if (_stats.rateLimitHitRate > 0.1 && _stats.totalOperations > 20) {
          logger.warning(
            'Rate limit hit rate is HIGH (${(_stats.rateLimitHitRate * 100).toStringAsFixed(1)}%)',
            category: 'RateLimiter',
            metadata: {
              'stats': _stats.toString(),
              'advice': 'This is a symptom of architectural issues. Investigate:\n'
                       '- Are you calling APIs in loops?\n'
                       '- Can you batch operations?\n'
                       '- Is there a logic error causing excessive calls?',
            },
          );
        }

        return result;
      } catch (e, stackTrace) {
        attempt++;

        // Check if this is a rate limit error
        final isRateLimitError = _isRateLimitError(e);
        final errorDetails = _analyzeError(e);

        // If not a rate limit error or max retries reached, record failure and throw
        if (!isRateLimitError || attempt >= maxRetries) {
          _stats.recordFailure(isRateLimit: isRateLimitError);
          _consecutiveFailures++;
          _lastFailureTime = DateTime.now();

          logger.error(
            '${operationName ?? 'Operation'} failed after $attempt attempts',
            category: 'RateLimiter',
            metadata: {
              'attempts': attempt,
              'maxRetries': maxRetries,
              'isRateLimitError': isRateLimitError,
              'errorType': errorDetails['type'],
              'errorPattern': errorDetails['pattern'],
              'consecutiveFailures': _consecutiveFailures,
            },
          );
          rethrow;
        }

        // Log retry attempt with diagnostic info
        logger.warning(
          '${operationName ?? 'Operation'} hit rate limit (attempt $attempt/$maxRetries)',
          category: 'RateLimiter',
          metadata: {
            'retryDelay': '${delayMs}ms',
            'errorDetails': errorDetails,
            'nextAttempt': attempt + 1,
          },
        );

        // Wait before retry
        await Future.delayed(Duration(milliseconds: delayMs));

        // Calculate next delay with exponential backoff
        if (enableBackoff) {
          delayMs = (delayMs * 2).clamp(initialDelayMs, maxDelayMs);
        }
      }
    }
  }

  /// Execute multiple operations in parallel with rate limiting
  ///
  /// Useful for batch operations that need individual rate limiting.
  Future<List<T>> executeParallel<T>(
    List<Future<T> Function()> operations, {
    String? operationName,
  }) async {
    final results = <T>[];

    for (int i = 0; i < operations.length; i++) {
      final result = await execute(
        operations[i],
        operationName: '${operationName ?? 'Operation'} ${i + 1}/${operations.length}',
      );
      results.add(result);
    }

    return results;
  }

  /// Check circuit breaker and reset if needed
  void _checkCircuitBreaker() {
    if (_consecutiveFailures >= circuitBreakerThreshold) {
      _circuitOpen = true;
    }

    // Reset circuit breaker if enough time has passed
    if (_lastFailureTime != null &&
        DateTime.now().difference(_lastFailureTime!) > circuitBreakerResetDuration) {
      _consecutiveFailures = 0;
      _circuitOpen = false;
      _lastFailureTime = null;
      logger.info(
        'Circuit breaker RESET - resuming operations',
        category: 'RateLimiter',
      );
    }
  }

  /// Check if an error is a rate limit error
  bool _isRateLimitError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Common rate limit error patterns
    return errorString.contains('rate limit') ||
        errorString.contains('ratelimit') ||  // Support RateLimitExceededException
        errorString.contains('too many requests') ||
        errorString.contains('429') ||
        errorString.contains('quota exceeded') ||
        errorString.contains('throttle');
  }

  /// Analyze error to provide diagnostic information
  Map<String, String> _analyzeError(dynamic error) {
    final errorString = error.toString();
    final errorLower = errorString.toLowerCase();

    String type = 'Unknown';
    String pattern = 'None';
    String advice = '';

    if (errorLower.contains('429')) {
      type = 'HTTP 429 - Too Many Requests';
      pattern = 'HTTP status code';
      advice = 'Standard rate limit response. Retry with backoff should work.';
    } else if (errorLower.contains('rate limit')) {
      type = 'Rate Limit Exception';
      pattern = 'Error message contains "rate limit"';
      advice = 'Explicit rate limiting by Health Connect. Consider reducing request frequency.';
    } else if (errorLower.contains('quota exceeded')) {
      type = 'Quota Exceeded';
      pattern = 'Error message contains "quota exceeded"';
      advice = 'Daily/hourly quota reached. May need to wait longer or reduce total requests.';
    } else if (errorLower.contains('throttle')) {
      type = 'Throttling';
      pattern = 'Error message contains "throttle"';
      advice = 'Request throttled by system. This is normal under heavy load.';
    }

    return {
      'type': type,
      'pattern': pattern,
      'advice': advice,
      'rawError': errorString.length > 200 ? errorString.substring(0, 200) + '...' : errorString,
    };
  }

  /// Get delay for specific attempt number
  int getDelayForAttempt(int attempt) {
    if (!enableBackoff) return initialDelayMs;

    int delay = initialDelayMs;
    for (int i = 1; i < attempt; i++) {
      delay = (delay * 2).clamp(initialDelayMs, maxDelayMs);
    }
    return delay;
  }

  /// Get current statistics
  ///
  /// Use this to monitor rate limiting behavior and identify issues.
  /// If rateLimitHitRate > 0.1 (10%), investigate your code for problems.
  RateLimitStats getStats() => _stats;

  /// Reset statistics
  void resetStats() {
    _stats.reset();
  }

  /// Check if circuit breaker is currently open
  bool get isCircuitOpen => _circuitOpen;

  /// Get number of consecutive failures
  int get consecutiveFailures => _consecutiveFailures;

  /// Analyze rate limiting errors and provide diagnostic information
  ///
  /// Returns a string with analysis and recommendations if rate limiting
  /// is happening frequently.
  String analyzeErrors() {
    final stats = getStats();
    final buffer = StringBuffer();

    buffer.writeln('Rate Limiter Error Analysis');
    buffer.writeln('=========================');
    buffer.writeln('Total Operations: ${stats.totalOperations}');
    buffer.writeln('Rate Limit Hits: ${stats.rateLimitHits}');
    buffer.writeln('Rate Limit Hit Rate: ${(stats.rateLimitHitRate * 100).toStringAsFixed(1)}%');
    buffer.writeln('');

    if (stats.rateLimitHitRate > 0.1 && stats.totalOperations > 20) {
      buffer.writeln('⚠️ WARNING: rate limit hit rate is HIGH (>10%)');
      buffer.writeln('');
      buffer.writeln('This indicates a potential problem in your code:');
      buffer.writeln('- Are you calling APIs in tight loops?');
      buffer.writeln('- Can operations be batched?');
      buffer.writeln('- Is there a logic error causing excessive calls?');
      buffer.writeln('');
      buffer.writeln('RECOMMENDATION: investigate and fix the root cause.');
      buffer.writeln('Rate limiting should be rare, not routine.');
    } else if (stats.rateLimitHitRate > 0.05 && stats.totalOperations > 20) {
      buffer.writeln('⚠️ NOTICE: rate limit hit rate is moderate (>5%)');
      buffer.writeln('Consider reviewing your API usage patterns.');
    } else {
      buffer.writeln('✓ Rate limiting is within normal levels.');
    }

    return buffer.toString();
  }

  @override
  String toString() {
    return 'RateLimiter(maxRetries: $maxRetries, initialDelay: ${initialDelayMs}ms, '
        'maxDelay: ${maxDelayMs}ms, backoff: $enableBackoff, circuitBreaker: $circuitBreakerThreshold)';
  }
}

/// Preset rate limiter configurations
class RateLimiterConfig {
  /// Conservative rate limiter (5 retries, up to 16s delay)
  static RateLimiter get conservative => RateLimiter(
    maxRetries: 5,
    initialDelayMs: 1000,
    maxDelayMs: 16000,
    enableBackoff: true,
  );

  /// Aggressive rate limiter (10 retries, up to 32s delay)
  static RateLimiter get aggressive => RateLimiter(
    maxRetries: 10,
    initialDelayMs: 500,
    maxDelayMs: 32000,
    enableBackoff: true,
  );

  /// Fast rate limiter (3 retries, up to 4s delay)
  static RateLimiter get fast => RateLimiter(
    maxRetries: 3,
    initialDelayMs: 1000,
    maxDelayMs: 4000,
    enableBackoff: true,
  );

  /// No backoff (5 retries with constant 1s delay)
  static RateLimiter get noBackoff => RateLimiter(
    maxRetries: 5,
    initialDelayMs: 1000,
    maxDelayMs: 1000,
    enableBackoff: false,
  );
}

/// Rate limit statistics
class RateLimitStats {
  int totalOperations = 0;
  int successfulOperations = 0;
  int failedOperations = 0;
  int rateLimitFailures = 0;
  int totalRetries = 0;
  int rateLimitHits = 0;
  DateTime? lastRateLimitHit;
  Duration totalDuration = Duration.zero;

  void recordSuccess({
    bool hadRetries = false,
    int retryCount = 0,
    required Duration duration,
  }) {
    totalOperations++;
    successfulOperations++;
    totalDuration += duration;
    if (hadRetries) {
      totalRetries += retryCount;
      rateLimitHits++;
      lastRateLimitHit = DateTime.now();
    }
  }

  void recordFailure({bool isRateLimit = false}) {
    totalOperations++;
    failedOperations++;
    if (isRateLimit) {
      rateLimitFailures++;
    }
  }

  void reset() {
    totalOperations = 0;
    successfulOperations = 0;
    failedOperations = 0;
    rateLimitFailures = 0;
    totalRetries = 0;
    rateLimitHits = 0;
    lastRateLimitHit = null;
    totalDuration = Duration.zero;
  }

  double get successRate => totalOperations > 0
      ? successfulOperations / totalOperations
      : 0.0;

  double get rateLimitHitRate => totalOperations > 0
      ? rateLimitHits / totalOperations
      : 0.0;

  double get averageRetriesPerOperation => totalOperations > 0
      ? totalRetries / totalOperations
      : 0.0;

  double get averageDurationMs => totalOperations > 0
      ? totalDuration.inMilliseconds / totalOperations
      : 0.0;

  /// Health check - returns true if everything looks good
  bool get isHealthy {
    if (totalOperations < 10) return true; // Not enough data
    return successRate > 0.95 && rateLimitHitRate < 0.1;
  }

  /// Generate a formatted report
  String getReport() {
    final buffer = StringBuffer();
    buffer.writeln('Rate Limiter Statistics Report');
    buffer.writeln('============================');
    buffer.writeln('Total Operations: $totalOperations');
    buffer.writeln('Successful: $successfulOperations');
    buffer.writeln('Failed: $failedOperations');
    buffer.writeln('Success Rate: ${(successRate * 100).toStringAsFixed(1)}%');
    buffer.writeln('');
    buffer.writeln('Rate Limiting:');
    buffer.writeln('  Hits: $rateLimitHits');
    buffer.writeln('  Rate Limit Hit Rate: ${(rateLimitHitRate * 100).toStringAsFixed(1)}%');
    buffer.writeln('  Failures: $rateLimitFailures');
    buffer.writeln('  Total Retries: $totalRetries');
    buffer.writeln('  Avg Retries/Op: ${averageRetriesPerOperation.toStringAsFixed(2)}');
    buffer.writeln('');
    buffer.writeln('Performance:');
    buffer.writeln('  Average Duration: ${averageDurationMs.toStringAsFixed(1)}ms');
    if (lastRateLimitHit != null) {
      buffer.writeln('  Last Hit: $lastRateLimitHit');
    }
    buffer.writeln('');
    buffer.writeln('Health: ${isHealthy ? '✓ Healthy' : '✗ Unhealthy'}');
    return buffer.toString();
  }

  @override
  String toString() {
    return 'RateLimitStats{\n'
        '  Total Operations: $totalOperations\n'
        '  Successful: $successfulOperations\n'
        '  Failed: $failedOperations (rate limit: $rateLimitFailures)\n'
        '  Success Rate: ${(successRate * 100).toStringAsFixed(1)}%\n'
        '  Rate Limit Hits: $rateLimitHits\n'
        '  Hit Rate: ${(rateLimitHitRate * 100).toStringAsFixed(1)}%\n'
        '  Avg Retries: ${averageRetriesPerOperation.toStringAsFixed(2)}\n'
        '  Avg Duration: ${averageDurationMs.toStringAsFixed(1)}ms\n'
        '  Last Hit: ${lastRateLimitHit ?? 'Never'}\n'
        '  Healthy: ${isHealthy ? '✓' : '✗'}\n'
        '}';
  }
}

/// Exception thrown when circuit breaker is open
class CircuitBreakerOpenException implements Exception {
  final String message;

  CircuitBreakerOpenException(this.message);

  @override
  String toString() => 'CircuitBreakerOpenException: $message';
}
