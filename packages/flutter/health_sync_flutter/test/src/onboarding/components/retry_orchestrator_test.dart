import 'package:flutter_test/flutter_test.dart';
import 'package:health_sync_flutter/src/onboarding/components/retry_orchestrator.dart';

void main() {
  group('RetryStrategy', () {
    group('linear', () {
      test('creates linear strategy with correct parameters', () {
        const strategy = RetryStrategy.linear(
          maxAttempts: 5,
          delay: Duration(seconds: 2),
        );

        expect(strategy.type, RetryStrategyType.linear);
        expect(strategy.maxAttempts, 5);
        expect(strategy.initialDelay, Duration(seconds: 2));
      });

      test('calculates fixed delay for all attempts', () {
        const strategy = RetryStrategy.linear(
          maxAttempts: 5,
          delay: Duration(seconds: 1),
        );

        expect(strategy.calculateDelay(1), Duration(seconds: 1));
        expect(strategy.calculateDelay(2), Duration(seconds: 1));
        expect(strategy.calculateDelay(3), Duration(seconds: 1));
        expect(strategy.calculateDelay(5), Duration(seconds: 1));
      });
    });

    group('exponential', () {
      test('creates exponential strategy with correct parameters', () {
        const strategy = RetryStrategy.exponential(
          maxAttempts: 5,
          initialDelay: Duration(seconds: 1),
          maxDelay: Duration(seconds: 16),
        );

        expect(strategy.type, RetryStrategyType.exponential);
        expect(strategy.maxAttempts, 5);
        expect(strategy.initialDelay, Duration(seconds: 1));
        expect(strategy.maxDelay, Duration(seconds: 16));
      });

      test('calculates exponential backoff delays', () {
        const strategy = RetryStrategy.exponential(
          maxAttempts: 5,
          initialDelay: Duration(seconds: 1),
          maxDelay: Duration(seconds: 32),
          addJitter: false, // Disable jitter for predictable tests
        );

        // Exponential: 1s, 2s, 4s, 8s, 16s
        expect(strategy.calculateDelay(1), Duration(seconds: 1));
        expect(strategy.calculateDelay(2), Duration(seconds: 2));
        expect(strategy.calculateDelay(3), Duration(seconds: 4));
        expect(strategy.calculateDelay(4), Duration(seconds: 8));
        expect(strategy.calculateDelay(5), Duration(seconds: 16));
      });

      test('caps delay at maxDelay', () {
        const strategy = RetryStrategy.exponential(
          maxAttempts: 10,
          initialDelay: Duration(seconds: 1),
          maxDelay: Duration(seconds: 10),
          addJitter: false,
        );

        // Should cap at 10 seconds
        expect(strategy.calculateDelay(1), Duration(seconds: 1));
        expect(strategy.calculateDelay(2), Duration(seconds: 2));
        expect(strategy.calculateDelay(3), Duration(seconds: 4));
        expect(strategy.calculateDelay(4), Duration(seconds: 8));
        expect(strategy.calculateDelay(5), Duration(seconds: 10)); // Capped
        expect(strategy.calculateDelay(6), Duration(seconds: 10)); // Capped
      });

      test('adds jitter when enabled', () {
        const strategy = RetryStrategy.exponential(
          maxAttempts: 5,
          initialDelay: Duration(seconds: 2),
          addJitter: true,
          jitterFactor: 0.2,
        );

        // With 20% jitter on 2s delay, should be between 1.6s and 2.4s
        final delay = strategy.calculateDelay(1);
        expect(delay.inMilliseconds, greaterThanOrEqualTo(1600));
        expect(delay.inMilliseconds, lessThanOrEqualTo(2400));
      });
    });

    group('custom', () {
      test('uses custom delay calculator', () {
        final strategy = RetryStrategy.custom(
          maxAttempts: 5,
          delayCalculator: (attempt) => Duration(seconds: attempt * 3),
        );

        expect(strategy.calculateDelay(1), Duration(seconds: 3));
        expect(strategy.calculateDelay(2), Duration(seconds: 6));
        expect(strategy.calculateDelay(3), Duration(seconds: 9));
      });
    });

    test('calculates total retry time', () {
      const strategy = RetryStrategy.linear(
        maxAttempts: 5,
        delay: Duration(seconds: 2),
      );

      // 5 attempts × 2 seconds = 10 seconds
      expect(strategy.totalRetryTime, Duration(seconds: 10));
    });
  });

  group('RetryAttempt', () {
    test('identifies first attempt', () {
      final attempt = RetryAttempt(
        attemptNumber: 1,
        maxAttempts: 5,
        delay: Duration(seconds: 1),
      );

      expect(attempt.isFirstAttempt, true);
      expect(attempt.isLastAttempt, false);
    });

    test('identifies last attempt', () {
      final attempt = RetryAttempt(
        attemptNumber: 5,
        maxAttempts: 5,
        delay: Duration(seconds: 1),
      );

      expect(attempt.isFirstAttempt, false);
      expect(attempt.isLastAttempt, true);
    });

    test('calculates progress correctly', () {
      final attempt = RetryAttempt(
        attemptNumber: 3,
        maxAttempts: 5,
        delay: Duration(seconds: 1),
      );

      expect(attempt.progress, 0.6); // 3/5 = 0.6
    });

    test('stores error from previous attempt', () {
      final error = Exception('Test error');
      final attempt = RetryAttempt(
        attemptNumber: 2,
        maxAttempts: 5,
        delay: Duration(seconds: 1),
        error: error,
      );

      expect(attempt.error, error);
    });
  });

  group('RetryResult', () {
    test('creates successful result', () {
      final result = RetryResult.success(42, 3, Duration(seconds: 5));

      expect(result.success, true);
      expect(result.value, 42);
      expect(result.attempts, 3);
      expect(result.totalDuration, Duration(seconds: 5));
      expect(result.error, isNull);
    });

    test('creates failed result', () {
      final error = Exception('Failed');
      final errors = [Exception('Error 1'), Exception('Error 2')];
      final result = RetryResult.failure(
        error,
        3,
        Duration(seconds: 5),
        errors,
      );

      expect(result.success, false);
      expect(result.error, error);
      expect(result.attempts, 3);
      expect(result.totalDuration, Duration(seconds: 5));
      expect(result.errors, errors);
      expect(result.value, isNull);
    });
  });

  group('RetryOrchestrator', () {
    late RetryOrchestrator orchestrator;

    setUp(() {
      orchestrator = RetryOrchestrator();
    });

    tearDown(() {
      orchestrator.dispose();
    });

    test('succeeds on first attempt', () async {
      var callCount = 0;

      final result = await orchestrator.execute(
        () async {
          callCount++;
          return 'success';
        },
        strategy: RetryStrategy.linear(maxAttempts: 5),
      );

      expect(result.success, true);
      expect(result.value, 'success');
      expect(result.attempts, 1);
      expect(callCount, 1);
    });

    test('retries on failure and eventually succeeds', () async {
      var callCount = 0;

      final result = await orchestrator.execute(
        () async {
          callCount++;
          if (callCount < 3) {
            throw Exception('Not ready yet');
          }
          return 'success';
        },
        strategy: RetryStrategy.linear(maxAttempts: 5, delay: Duration(milliseconds: 10)),
      );

      expect(result.success, true);
      expect(result.value, 'success');
      expect(result.attempts, 3);
      expect(callCount, 3);
    });

    test('fails after max attempts', () async {
      var callCount = 0;

      final result = await orchestrator.execute(
        () async {
          callCount++;
          throw Exception('Always fails');
        },
        strategy: RetryStrategy.linear(maxAttempts: 3, delay: Duration(milliseconds: 10)),
      );

      expect(result.success, false);
      expect(result.attempts, 3);
      expect(callCount, 3);
      expect(result.error, isA<Exception>());
      expect(result.errors.length, 3);
    });

    test('respects shouldRetry predicate', () async {
      var callCount = 0;

      final result = await orchestrator.execute(
        () async {
          callCount++;
          if (callCount == 1) {
            throw Exception('Transient error');
          } else {
            throw Exception('Fatal error');
          }
        },
        strategy: RetryStrategy.linear(maxAttempts: 5, delay: Duration(milliseconds: 10)),
        shouldRetry: (error) => error.toString().contains('Transient'),
      );

      expect(result.success, false);
      expect(result.attempts, 2); // First attempt + one retry, then fatal error stops it
      expect(callCount, 2);
    });

    test('emits attempt events to stream', () async {
      final attempts = <RetryAttempt>[];

      orchestrator.attemptStream.listen(attempts.add);

      var callCount = 0;
      await orchestrator.execute(
        () async {
          callCount++;
          if (callCount < 3) {
            throw Exception('Not ready');
          }
          return 'success';
        },
        strategy: RetryStrategy.linear(maxAttempts: 5, delay: Duration(milliseconds: 10)),
      );

      await Future.delayed(Duration(milliseconds: 50)); // Let stream events process

      expect(attempts.length, 3);
      expect(attempts[0].attemptNumber, 1);
      expect(attempts[1].attemptNumber, 2);
      expect(attempts[2].attemptNumber, 3);
    });

    test('calls onAttempt callback', () async {
      final attemptNumbers = <int>[];

      await orchestrator.execute(
        () async {
          // Callback is called before operation executes, so when attemptNumbers has [1, 2],
          // the operation will see length 2 and succeed
          if (attemptNumbers.length < 2) {
            throw Exception('Not ready');
          }
          return 'success';
        },
        strategy: RetryStrategy.linear(maxAttempts: 5, delay: Duration(milliseconds: 10)),
        onAttempt: (attempt) {
          attemptNumbers.add(attempt.attemptNumber);
        },
      );

      expect(attemptNumbers, [1, 2]); // Only 2 attempts needed since callback is called first
    });

    test('can be cancelled during retry', () async {
      final result = orchestrator.execute(
        () async {
          await Future.delayed(Duration(milliseconds: 50));
          throw Exception('Always fails');
        },
        strategy: RetryStrategy.linear(maxAttempts: 10, delay: Duration(milliseconds: 50)),
      );

      // Cancel after a short delay
      Future.delayed(Duration(milliseconds: 100), () {
        orchestrator.cancel();
      });

      final finalResult = await result;

      expect(finalResult.success, false);
      expect(finalResult.attempts, lessThan(10)); // Should be cancelled before all attempts
    });

    test('retryUntil succeeds when condition becomes true', () async {
      var callCount = 0;

      final success = await orchestrator.retryUntil(
        () async {
          callCount++;
          return callCount >= 3; // Becomes true on 3rd attempt
        },
        strategy: RetryStrategy.linear(maxAttempts: 5, delay: Duration(milliseconds: 10)),
      );

      expect(success, true);
      expect(callCount, 3);
    });

    test('retryUntil fails when max attempts exceeded', () async {
      final success = await orchestrator.retryUntil(
        () async => false, // Always false
        strategy: RetryStrategy.linear(maxAttempts: 3, delay: Duration(milliseconds: 10)),
      );

      expect(success, false);
    });

    test('retryStream emits attempts until condition met', () async {
      var callCount = 0;
      final attempts = <RetryAttempt>[];

      await for (final attempt in orchestrator.retryStream(
        () async {
          callCount++;
          return callCount >= 3;
        },
        strategy: RetryStrategy.linear(maxAttempts: 5, delay: Duration(milliseconds: 10)),
      )) {
        attempts.add(attempt);
      }

      expect(attempts.length, 3);
      expect(callCount, 3);
    });
  });

  group('RetryPredicates', () {
    test('alwaysRetry returns true for any error', () {
      expect(RetryPredicates.alwaysRetry(Exception('test')), true);
      expect(RetryPredicates.alwaysRetry('string error'), true);
    });

    test('neverRetry returns false for any error', () {
      expect(RetryPredicates.neverRetry(Exception('test')), false);
      expect(RetryPredicates.neverRetry('string error'), false);
    });

    test('retryOnType filters by error type', () {
      expect(
        RetryPredicates.retryOnType<FormatException>(FormatException('test')),
        true,
      );
      expect(
        RetryPredicates.retryOnType<FormatException>(Exception('test')),
        false,
      );
    });

    test('retryOnMessageContains filters by error message', () {
      final predicate = RetryPredicates.retryOnMessageContains('timeout');

      expect(predicate(Exception('Connection timeout')), true);
      expect(predicate(Exception('Request TIMEOUT')), true);
      expect(predicate(Exception('Connection refused')), false);
    });

    test('retryOnUpdateRequired detects Health Connect update errors', () {
      expect(
        RetryPredicates.retryOnUpdateRequired(
          Exception('SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED'),
        ),
        true,
      );
      expect(
        RetryPredicates.retryOnUpdateRequired(
          Exception('Health Connect update required'),
        ),
        true,
      );
      expect(
        RetryPredicates.retryOnUpdateRequired(
          Exception('Different error'),
        ),
        false,
      );
    });

    test('retryOnNetworkError detects network errors', () {
      expect(
        RetryPredicates.retryOnNetworkError(Exception('Network timeout')),
        true,
      );
      expect(
        RetryPredicates.retryOnNetworkError(Exception('Connection failed')),
        true,
      );
      expect(
        RetryPredicates.retryOnNetworkError(Exception('Different error')),
        false,
      );
    });

    test('any combines predicates with OR logic', () {
      final predicate = RetryPredicates.any([
        (e) => e.toString().contains('timeout'),
        (e) => e.toString().contains('network'),
      ]);

      expect(predicate(Exception('timeout')), true);
      expect(predicate(Exception('network')), true);
      expect(predicate(Exception('other')), false);
    });

    test('all combines predicates with AND logic', () {
      final predicate = RetryPredicates.all([
        (e) => e.toString().contains('error'),
        (e) => e.toString().contains('timeout'),
      ]);

      expect(predicate(Exception('error timeout')), true);
      expect(predicate(Exception('error')), false);
      expect(predicate(Exception('timeout')), false);
    });
  });
}
