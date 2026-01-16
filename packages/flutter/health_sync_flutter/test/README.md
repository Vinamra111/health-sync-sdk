# HealthSync Flutter Tests

Comprehensive unit tests for all enterprise feature improvements made to the HealthSync SDK.

## Test Coverage

### 1. Rate Limiter Tests (`src/utils/rate_limiter_test.dart`)
Tests for circuit breaker, exponential backoff, and statistics tracking improvements.

**Coverage:**
- ✅ Basic retry logic with exponential backoff
- ✅ Circuit breaker opens after consecutive failures
- ✅ Circuit breaker resets after duration
- ✅ Circuit breaker resets on successful operation
- ✅ Statistics tracking (success/failure rates, retry counts)
- ✅ Rate limit hit rate calculation
- ✅ Error analysis and diagnostic reporting
- ✅ Health monitoring warnings

**Key Test Cases:**
```dart
test('circuit breaker opens after consecutive failures')
test('tracks statistics correctly')
test('analyzeErrors returns diagnostic information')
```

### 2. Changes API Tests (`src/utils/changes_api_test.dart`)
Tests for automatic fallback, token validation, and error recovery.

**Coverage:**
- ✅ Initial sync token creation
- ✅ Incremental sync with existing token
- ✅ Automatic fallback on invalid token error
- ✅ Token validation (stale detection, >30 days)
- ✅ Token not found error handling
- ✅ Successful sync without fallback
- ✅ Sync status reporting

**Key Test Cases:**
```dart
test('getChangesWithFallback falls back on invalid token error')
test('validateToken detects stale token (>30 days)')
test('getChangesWithFallback succeeds without fallback when token is valid')
```

### 3. Aggregate Reader Tests (`src/utils/aggregate_reader_test.dart`)
Tests for validation, accuracy checking, and transparency reporting.

**Coverage:**
- ✅ Validation against matching raw data
- ✅ Detection of inaccurate aggregates
- ✅ Sampling of large datasets
- ✅ Empty data handling
- ✅ Confidence calculation based on difference
- ✅ Notes generation for different difference levels
- ✅ Transparency reporting (deduplication, sources)
- ✅ Validation error handling

**Key Test Cases:**
```dart
test('validateAggregate returns accurate validation for matching data')
test('validateAggregate detects inaccurate aggregate')
test('deduplicationRate calculates correctly')
test('getTransparencyReport includes all details')
```

### 4. Device Info Tests (`src/background_sync/device_info_test.dart`)
Tests for manufacturer detection and compatibility assessment.

**Coverage:**
- ✅ Aggressive battery manager detection (Xiaomi, Huawei, OPPO, Vivo, OnePlus, Realme, Asus)
- ✅ Reliable manufacturer detection (Google, Samsung, Motorola)
- ✅ Battery optimization warnings
- ✅ Manufacturer-specific instructions
- ✅ Compatibility level calculation (high/medium/low)
- ✅ Recommended sync frequency
- ✅ Charging and WiFi requirements
- ✅ Case-insensitive detection

**Key Test Cases:**
```dart
test('isAggressiveBatteryManager detects Xiaomi')
test('getBackgroundSyncCompatibility returns high for Google')
test('aggressive battery managers have low compatibility')
```

### 5. Background Sync Stats Tests (`src/background_sync/background_sync_stats_test.dart`)
Tests for execution tracking and health monitoring.

**Coverage:**
- ✅ Success/failure recording
- ✅ Success rate calculation
- ✅ Average delay calculation
- ✅ Health status (>80% success rate)
- ✅ Stuck detection (>24 hours without success)
- ✅ Failure reason tracking
- ✅ Most common failure reason
- ✅ Statistics persistence (save/load)
- ✅ Report generation
- ✅ Edge cases (large delays, zero delays)

**Key Test Cases:**
```dart
test('appearsStuck returns true when no success for >24 hours')
test('isHealthy returns false when success rate <= 80%')
test('tracks failure reasons correctly')
test('save and load persist statistics')
```

### 6. Background Sync Service Tests (`src/background_sync/background_sync_service_test.dart`)
Tests for compatibility checking and callback functionality.

**Coverage:**
- ✅ Compatibility detection for different manufacturers
- ✅ Success/failure callbacks
- ✅ Statistics recording and retrieval
- ✅ Statistics reset
- ✅ Delay tracking
- ✅ Multiple execution tracking
- ✅ Integration with callbacks and stats

**Key Test Cases:**
```dart
test('checkCompatibility returns high for Google devices')
test('success callback is invoked')
test('callbacks work with stats tracking')
```

### 7. Conflict Detector Tests (`src/conflict_detection/conflict_detector_test.dart`)
Tests for confidence scoring, safe recommendations, and warning logic.

**Coverage:**
- ✅ Severity level detection (high/medium/low)
- ✅ Confidence level detection (high/medium/low)
- ✅ shouldWarnUser logic (severity + confidence)
- ✅ Safe recommendations for different scenarios
- ✅ Legitimate multi-device detection
- ✅ Low time overlap handling
- ✅ Low confidence handling
- ✅ Detailed analysis generation
- ✅ Primary/secondary source identification
- ✅ Conflict summary across data types

**Key Test Cases:**
```dart
test('shouldWarnUser returns true for high severity + high confidence')
test('shouldWarnUser returns false for high severity + low confidence')
test('getSafeRecommendation handles legitimate multi-device')
test('highSeverityConflicts filters correctly')
```

## Running Tests

### Run All Tests
```bash
cd packages/flutter/health_sync_flutter
flutter test
```

### Run Specific Test File
```bash
flutter test test/src/utils/rate_limiter_test.dart
```

### Run Tests with Coverage
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Run Tests in Watch Mode
```bash
flutter test --watch
```

## Test Structure

```
test/
├── README.md (this file)
└── src/
    ├── utils/
    │   ├── rate_limiter_test.dart
    │   ├── changes_api_test.dart
    │   └── aggregate_reader_test.dart
    ├── background_sync/
    │   ├── device_info_test.dart
    │   ├── background_sync_stats_test.dart
    │   └── background_sync_service_test.dart
    └── conflict_detection/
        └── conflict_detector_test.dart
```

## Test Statistics

- **Total Test Files**: 7
- **Total Test Groups**: ~35
- **Total Test Cases**: ~150+
- **Estimated Coverage**: >80% for improved features

## Mocking Strategy

### Method Channel Mocking
For tests that interact with platform channels (aggregate_reader, changes_api):
```dart
TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
    .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
  // Mock implementation
});
```

### Shared Preferences Mocking
For tests that use persistent storage (stats, tokens):
```dart
SharedPreferences.setMockInitialValues({});
```

### Custom Mocks
For tests that need custom behavior (sync token manager):
```dart
class MockSyncTokenManager extends SyncTokenManager {
  // Override methods
}
```

## Test Best Practices

1. **Isolation**: Each test is independent and doesn't rely on other tests
2. **Setup/Teardown**: Proper initialization and cleanup in setUp/tearDown
3. **Clear Names**: Test names describe what is being tested
4. **Comprehensive**: Tests cover success cases, failure cases, and edge cases
5. **Realistic**: Tests simulate real-world scenarios

## CI/CD Integration

Add to your CI/CD pipeline:

```yaml
# .github/workflows/test.yml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter test
```

## Troubleshooting

### Tests fail with "No method channel handler"
Make sure you're using `TestWidgetsFlutterBinding.ensureInitialized()` in tests that use method channels.

### Tests fail with SharedPreferences error
Use `SharedPreferences.setMockInitialValues({})` in setUp().

### Tests are slow
Use `flutter test --concurrency=4` to run tests in parallel.

## Contributing

When adding new features, please:
1. Write tests for all new functionality
2. Ensure tests cover success, failure, and edge cases
3. Run all tests before submitting PR
4. Maintain >80% code coverage for new code

## Related Documentation

- [CONFIDENCE_ASSESSMENT.md](../CONFIDENCE_ASSESSMENT.md) - Confidence levels for all features
- [README.md](../README.md) - Main SDK documentation
