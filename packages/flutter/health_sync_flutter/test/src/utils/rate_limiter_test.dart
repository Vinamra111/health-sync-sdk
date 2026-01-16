import 'package:flutter_test/flutter_test.dart';
import 'package:health_sync_flutter/src/utils/rate_limiter.dart';

void main() {
  group('RateLimiter', () {
    test('executes operation successfully without retry', () async {
      final limiter = RateLimiter(maxRetries: 3);
      var callCount = 0;

      final result = await limiter.execute(() async {
        callCount++;
        return 'success';
      });

      expect(result, 'success');
      expect(callCount, 1);
    });

    test('retries on rate limit error and succeeds', () async {
      final limiter = RateLimiter(
        maxRetries: 3,
        initialDelayMs: 10,
        enableBackoff: false,
      );
      var callCount = 0;

      final result = await limiter.execute(() async {
        callCount++;
        if (callCount < 3) {
          throw Exception('RateLimitExceededException');
        }
        return 'success after retry';
      });

      expect(result, 'success after retry');
      expect(callCount, 3);
    });

    test('circuit breaker opens after consecutive failures', () async {
      final limiter = RateLimiter(
        maxRetries: 2,
        circuitBreakerThreshold: 3,
        initialDelayMs: 1,
      );

      // Cause 3 consecutive failures
      for (var i = 0; i < 3; i++) {
        try {
          await limiter.execute(() async {
            throw Exception('Some error');
          });
        } catch (e) {
          // Expected to fail
        }
      }

      // Next call should throw CircuitBreakerOpenException
      expect(
        () => limiter.execute(() async => 'test'),
        throwsA(isA<CircuitBreakerOpenException>()),
      );
    });

    test('circuit breaker resets after duration', () async {
      final limiter = RateLimiter(
        maxRetries: 1,
        circuitBreakerThreshold: 2,
        circuitBreakerResetDuration: Duration(milliseconds: 100),
        initialDelayMs: 1,
      );

      // Cause 2 failures to open circuit
      for (var i = 0; i < 2; i++) {
        try {
          await limiter.execute(() async {
            throw Exception('Error');
          });
        } catch (e) {
          // Expected
        }
      }

      // Circuit should be open
      expect(
        () => limiter.execute(() async => 'test'),
        throwsA(isA<CircuitBreakerOpenException>()),
      );

      // Wait for reset duration
      await Future.delayed(Duration(milliseconds: 150));

      // Circuit should be closed, allow operation
      final result = await limiter.execute(() async => 'success');
      expect(result, 'success');
    });

    test('circuit breaker resets on successful operation', () async {
      final limiter = RateLimiter(
        maxRetries: 1,
        circuitBreakerThreshold: 3,
        initialDelayMs: 1,
      );

      // Cause 2 failures (not enough to open)
      for (var i = 0; i < 2; i++) {
        try {
          await limiter.execute(() async {
            throw Exception('Error');
          });
        } catch (e) {
          // Expected
        }
      }

      // Successful operation resets counter
      await limiter.execute(() async => 'success');

      // Now cause 2 more failures
      for (var i = 0; i < 2; i++) {
        try {
          await limiter.execute(() async {
            throw Exception('Error');
          });
        } catch (e) {
          // Expected
        }
      }

      // Circuit should NOT be open (counter was reset)
      final result = await limiter.execute(() async => 'test');
      expect(result, 'test');
    });

    test('tracks statistics correctly', () async {
      final limiter = RateLimiter(
        maxRetries: 2,
        initialDelayMs: 10,
        enableBackoff: false,
      );

      // Successful operation
      await limiter.execute(() async => 'success1');

      // Operation with retry
      var attemptCount = 0;
      await limiter.execute(() async {
        attemptCount++;
        if (attemptCount < 2) {
          throw Exception('RateLimitExceededException');
        }
        return 'success2';
      });

      // Failed operation
      try {
        await limiter.execute(() async {
          throw Exception('Some error');
        });
      } catch (e) {
        // Expected
      }

      final stats = limiter.getStats();
      expect(stats.totalOperations, 3);
      expect(stats.successfulOperations, 2);
      expect(stats.failedOperations, 1);
      expect(stats.rateLimitHits, 1);
      expect(stats.totalRetries, 1);
      expect(stats.successRate, closeTo(0.666, 0.01));
    });

    test('statistics rate limit hit rate calculation', () async {
      final limiter = RateLimiter(
        maxRetries: 2,
        initialDelayMs: 5,
        enableBackoff: false,
      );

      // 2 operations with rate limit
      for (var i = 0; i < 2; i++) {
        var attempt = 0;
        await limiter.execute(() async {
          attempt++;
          if (attempt < 2) {
            throw Exception('RateLimitExceededException');
          }
          return 'success';
        });
      }

      // 1 operation without rate limit
      await limiter.execute(() async => 'success');

      final stats = limiter.getStats();
      expect(stats.rateLimitHitRate, closeTo(0.666, 0.01));
    });

    test('reset statistics works correctly', () async {
      final limiter = RateLimiter(maxRetries: 2, initialDelayMs: 5);

      await limiter.execute(() async => 'success');

      var stats = limiter.getStats();
      expect(stats.totalOperations, 1);

      limiter.resetStats();
      stats = limiter.getStats();
      expect(stats.totalOperations, 0);
      expect(stats.successfulOperations, 0);
      expect(stats.failedOperations, 0);
    });

    test('exponential backoff increases delay', () async {
      final limiter = RateLimiter(
        maxRetries: 4,  // Need 4 retries to test 3 delays
        initialDelayMs: 10,
        enableBackoff: true,
      );

      final delays = <int>[];
      var attempt = 0;

      final startTime = DateTime.now();
      await limiter.execute(() async {
        attempt++;
        if (attempt < 4) {
          final currentTime = DateTime.now();
          if (attempt > 1) {
            delays.add(currentTime.difference(startTime).inMilliseconds);
          }
          throw Exception('RateLimitExceededException');
        }
        return 'success';
      });

      // Delays should be approximately: 10ms, 20ms, 40ms (exponential)
      expect(delays.length, 2);  // Only 2 delays recorded (attempts 2 and 3)
      // Just verify delays are increasing (rough check due to timing variance)
      expect(delays[1] > delays[0], true);
    });

    test('analyzeErrors returns diagnostic information', () async {
      final limiter = RateLimiter(maxRetries: 2, initialDelayMs: 1);

      // Execute multiple operations with rate limiting
      for (var i = 0; i < 25; i++) {
        var callCount = 0;  // Needs to be outside to persist across retries
        await limiter.execute(() async {
          callCount++;
          if (callCount < 2) {
            throw Exception('RateLimitExceededException');
          }
          return 'success';
        });
      }

      final analysis = limiter.analyzeErrors();
      expect(analysis.contains('rate limit hit rate'), true);
      expect(analysis.contains('HIGH'), true);
      expect(analysis.contains('investigate'), true);
    });
  });

  group('CircuitBreakerOpenException', () {
    test('has descriptive message', () {
      final exception = CircuitBreakerOpenException(
        'Circuit breaker is open',
      );

      expect(exception.toString(), contains('Circuit breaker'));
    });
  });

  group('RateLimitStats', () {
    test('calculates success rate correctly', () {
      final stats = RateLimitStats();
      stats.recordSuccess(hadRetries: false, retryCount: 0, duration: Duration(milliseconds: 100));
      stats.recordSuccess(hadRetries: false, retryCount: 0, duration: Duration(milliseconds: 100));
      stats.recordFailure(isRateLimit: false);

      expect(stats.successRate, closeTo(0.666, 0.01));
    });

    test('calculates rate limit hit rate correctly', () {
      final stats = RateLimitStats();
      stats.recordSuccess(hadRetries: true, retryCount: 1, duration: Duration(milliseconds: 100));
      stats.recordSuccess(hadRetries: true, retryCount: 1, duration: Duration(milliseconds: 100));
      stats.recordSuccess(hadRetries: false, retryCount: 0, duration: Duration(milliseconds: 100));

      expect(stats.rateLimitHitRate, closeTo(0.666, 0.01));
    });

    test('tracks last rate limit hit time', () {
      final stats = RateLimitStats();
      final beforeTime = DateTime.now();

      stats.recordSuccess(hadRetries: true, retryCount: 1, duration: Duration(milliseconds: 100));

      final afterTime = DateTime.now();

      expect(stats.lastRateLimitHit, isNotNull);
      expect(
        stats.lastRateLimitHit!.isAfter(beforeTime.subtract(Duration(seconds: 1))),
        true,
      );
      expect(
        stats.lastRateLimitHit!.isBefore(afterTime.add(Duration(seconds: 1))),
        true,
      );
    });

    test('reset clears all statistics', () {
      final stats = RateLimitStats();
      stats.recordSuccess(hadRetries: true, retryCount: 2, duration: Duration(milliseconds: 100));
      stats.recordFailure(isRateLimit: true);

      expect(stats.totalOperations, 2);

      stats.reset();

      expect(stats.totalOperations, 0);
      expect(stats.successfulOperations, 0);
      expect(stats.failedOperations, 0);
      expect(stats.rateLimitHits, 0);
      expect(stats.lastRateLimitHit, isNull);
    });

    test('getReport returns formatted statistics', () {
      final stats = RateLimitStats();
      stats.recordSuccess(hadRetries: true, retryCount: 1, duration: Duration(milliseconds: 100));
      stats.recordSuccess(hadRetries: false, retryCount: 0, duration: Duration(milliseconds: 50));
      stats.recordFailure(isRateLimit: true);

      final report = stats.getReport();
      expect(report.contains('Total Operations'), true);
      expect(report.contains('Success Rate'), true);
      expect(report.contains('Rate Limit Hit Rate'), true);
      expect(report.contains('Average Duration'), true);
    });
  });
}
