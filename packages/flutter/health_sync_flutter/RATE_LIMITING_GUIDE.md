# Rate Limiting and Batch Operations Guide

This guide explains how to use the HealthSync SDK's built-in rate limiting and batch writing features to handle large datasets and Health Connect API limits.

## Overview

Health Connect enforces strict limits on API operations:
- **Maximum 1000 records per batch write**
- **Rate limiting** on high-frequency API calls
- **RateLimitExceededException** thrown when limits are exceeded

The HealthSync SDK automatically handles these limits with:
- **Exponential backoff retry logic** (1s → 2s → 4s → 8s → 16s)
- **Automatic batching** of large datasets into 1000-record chunks
- **Progress tracking** for long-running operations
- **Error recovery** with detailed failure reporting

## Features

### 1. Automatic Rate Limiting

All Health Connect API calls are automatically wrapped with rate limiting:

```dart
// Read operations automatically retry on rate limits
final data = await healthConnectPlugin.fetchData(
  DataQuery(
    dataType: DataType.steps,
    startDate: DateTime.now().subtract(Duration(days: 7)),
    endDate: DateTime.now(),
  ),
);
// If rate limited, automatically retries with exponential backoff
```

### 2. Batch Writing

Writing large datasets is automatically chunked into 1000-record batches:

```dart
// Prepare 5000 step records
final records = List.generate(5000, (i) => {
  'count': 100 + i,
  'startTime': DateTime.now().subtract(Duration(hours: i)).toUtc().toIso8601String(),
  'endTime': DateTime.now().subtract(Duration(hours: i - 1)).toUtc().toIso8601String(),
});

// Automatically split into 5 batches of 1000 records each
final result = await healthConnectPlugin.insertRecords(
  dataType: DataType.steps,
  records: records,
  onProgress: (progress) {
    print('Progress: ${progress.progressPercent}% (${progress.recordsProcessed}/${progress.totalRecords})');
  },
);

print('Success: ${result.successfulRecords}/${result.totalRecords} records written');
print('Duration: ${result.duration.inSeconds}s');
print('Success Rate: ${(result.successRate * 100).toStringAsFixed(1)}%');
```

### 3. Custom Rate Limiter Configuration

You can customize the rate limiter behavior:

```dart
import 'package:health_sync_flutter/health_sync_flutter.dart';

// Conservative (default): 5 retries, 1s → 16s backoff
final plugin1 = HealthConnectPlugin(
  rateLimiter: RateLimiterConfig.conservative,
);

// Aggressive: 10 retries, 0.5s → 32s backoff
final plugin2 = HealthConnectPlugin(
  rateLimiter: RateLimiterConfig.aggressive,
);

// Fast: 3 retries, 1s → 4s backoff
final plugin3 = HealthConnectPlugin(
  rateLimiter: RateLimiterConfig.fast,
);

// Custom configuration
final plugin4 = HealthConnectPlugin(
  rateLimiter: RateLimiter(
    maxRetries: 7,
    initialDelayMs: 2000,  // Start with 2s delay
    maxDelayMs: 30000,     // Cap at 30s
    enableBackoff: true,
  ),
);
```

## Rate Limiter Presets

| Preset | Max Retries | Initial Delay | Max Delay | Best For |
|--------|-------------|---------------|-----------|----------|
| **Conservative** (default) | 5 | 1s | 16s | Most apps, balanced retry |
| **Aggressive** | 10 | 0.5s | 32s | Critical operations, must succeed |
| **Fast** | 3 | 1s | 4s | Quick operations, fail fast |
| **No Backoff** | 5 | 1s | 1s | Testing, constant retry |

## Exponential Backoff Schedule

The default conservative configuration retries with these delays:

| Attempt | Delay | Total Time |
|---------|-------|------------|
| 1st retry | 1s | 1s |
| 2nd retry | 2s | 3s |
| 3rd retry | 4s | 7s |
| 4th retry | 8s | 15s |
| 5th retry | 16s | 31s |

## Batch Write Result

`insertRecords()` returns a detailed `BatchWriteResult`:

```dart
final result = await plugin.insertRecords(...);

// Check overall success
if (result.isFullSuccess) {
  print('All ${result.totalRecords} records written successfully!');
} else if (result.isPartialSuccess) {
  print('Partial success: ${result.successfulRecords}/${result.totalRecords}');
  print('Errors: ${result.errors.length}');

  // Inspect errors
  for (final error in result.errors) {
    print('Batch ${error.batchNumber} failed: ${error.error}');
  }
} else if (result.isFullFailure) {
  print('All batches failed');
}

// Performance metrics
print('Average time per record: ${result.averageTimePerRecord.inMilliseconds}ms');
print('Success rate: ${(result.successRate * 100).toStringAsFixed(1)}%');
```

## Progress Tracking

Monitor long-running batch operations:

```dart
await healthConnectPlugin.insertRecords(
  dataType: DataType.steps,
  records: largeDataset,
  onProgress: (progress) {
    // Update UI progress bar
    setState(() {
      _progress = progress.progress;  // 0.0 to 1.0
      _progressText = 'Batch ${progress.currentBatch}/${progress.totalBatches} '
                      '(${progress.progressPercent}%)';
    });

    if (progress.isComplete) {
      print('All batches completed!');
    }
  },
);
```

## Error Handling

The SDK handles rate limits automatically, but you should still catch other errors:

```dart
try {
  final result = await healthConnectPlugin.insertRecords(
    dataType: DataType.steps,
    records: records,
  );

  if (!result.isFullSuccess) {
    // Some records failed - inspect result.errors
    for (final error in result.errors) {
      print('Error in batch ${error.batchNumber}: ${error.error}');
    }
  }
} on HealthSyncAuthenticationError catch (e) {
  print('Missing permissions: $e');
  // Request permissions
} on HealthSyncConnectionError catch (e) {
  print('Not connected: $e');
  // Connect to Health Connect
} on HealthSyncDataFetchError catch (e) {
  print('Data error: $e');
  // Handle data type not supported, etc.
} catch (e) {
  print('Unexpected error: $e');
}
```

## Rate Limit Detection

The SDK automatically detects rate limit errors by checking for:
- `"rate limit"` in error message
- `"too many requests"` in error message
- HTTP status code `429`
- `"quota exceeded"` in error message
- `"throttle"` in error message

When detected, it automatically retries with exponential backoff.

## Advanced: Direct BatchWriter Usage

For custom batch operations, use `BatchWriter` directly:

```dart
import 'package:health_sync_flutter/health_sync_flutter.dart';

final batchWriter = BatchWriter(
  rateLimiter: RateLimiterConfig.aggressive,
  verbose: true,  // Enable detailed logging
);

final result = await batchWriter.writeBatch<MyRecord>(
  records: myLargeDataset,
  writeFunction: (batch) async {
    // Your custom write logic
    await myCustomApi.writeBatch(batch);
  },
  operationName: 'Custom Operation',
  onProgress: (progress) {
    print('Progress: ${progress.progressPercent}%');
  },
);
```

## Advanced: Parallel Batch Writes

Write multiple data types in parallel:

```dart
final recordsByType = {
  'steps': stepsRecords,
  'heartRate': heartRateRecords,
  'sleep': sleepRecords,
};

final results = await batchWriter.writeParallelBatches(
  recordsByType: recordsByType,
  writeFunction: (type, records) async {
    // Write each type
    await myApi.write(type, records);
  },
  onProgress: (type, progress) {
    print('$type: ${progress.progressPercent}%');
  },
);

// Aggregate statistics
final stats = BatchWriteStats(results);
print('Total: ${stats.totalRecords} records');
print('Success rate: ${(stats.overallSuccessRate * 100).toStringAsFixed(1)}%');
```

## Best Practices

### 1. Use Default Configuration for Most Cases
```dart
// Simple - uses conservative defaults
final plugin = HealthConnectPlugin();
```

### 2. Handle Partial Failures
```dart
final result = await plugin.insertRecords(...);
if (!result.isFullSuccess) {
  // Retry failed batches or log for later
  final failedBatches = result.errors;
  await retryFailedBatches(failedBatches);
}
```

### 3. Show Progress for Large Operations
```dart
// For datasets > 1000 records, always show progress
if (records.length > 1000) {
  showProgressDialog();
  await plugin.insertRecords(
    records: records,
    onProgress: (progress) => updateProgressDialog(progress),
  );
  hideProgressDialog();
}
```

### 4. Test Rate Limiting in Development
```dart
// Simulate rate limit errors to test retry logic
final testPlugin = HealthConnectPlugin(
  rateLimiter: RateLimiter(
    maxRetries: 2,
    initialDelayMs: 100,  // Fast retries for testing
    maxDelayMs: 500,
  ),
);
```

### 5. Calculate Optimal Batch Size for Large Records
```dart
// For very large records (e.g., sleep sessions with detailed metadata)
final optimalSize = BatchWriter.calculateOptimalBatchSize(
  recordCount: myRecords.length,
  estimatedBytesPerRecord: 10 * 1024,  // 10 KB per record
  maxMemoryBytes: 50 * 1024 * 1024,    // 50 MB max memory
);
print('Optimal batch size: $optimalSize');
```

## Logging

Enable verbose logging to debug batch operations:

```dart
final batchWriter = BatchWriter(
  rateLimiter: RateLimiterConfig.conservative,
  verbose: true,  // Enables detailed batch logging
);
```

Logs will show:
- Batch progress (`✓ Batch 3/5 completed: 1000 records`)
- Rate limit retries (`Rate limit hit (attempt 2/5). Retrying in 2000ms...`)
- Failure details (`✗ Batch 2/5 failed: RateLimitExceededException`)

## Performance Tips

1. **Batch Size**: Default 1000 is optimal for most cases
2. **Progress Callbacks**: Use sparingly for very large datasets (every batch, not every record)
3. **Parallel Writes**: Use for independent data types to reduce total time
4. **Memory**: For huge datasets (100k+ records), consider processing in chunks
5. **Retry Strategy**: Use aggressive config only when necessary (more retries = longer total time)

## Common Issues

### Issue: "Rate limit exceeded" even with retry logic
**Solution**: Increase `maxRetries` or `maxDelayMs` in custom configuration

### Issue: Batch writes taking too long
**Solution**: Use `Fast` preset or reduce batch size for smaller, quicker batches

### Issue: Out of memory with large datasets
**Solution**: Process in smaller chunks or use `calculateOptimalBatchSize()`

### Issue: Need to resume failed batches
**Solution**: Store `result.errors` and retry specific failed batches later

## Testing

Test rate limiting behavior:

```dart
test('Rate limiting retries on failure', () async {
  var attempts = 0;

  final rateLimiter = RateLimiter(maxRetries: 3);

  try {
    await rateLimiter.execute(() async {
      attempts++;
      if (attempts < 3) {
        throw Exception('rate limit exceeded');
      }
      return 'success';
    });
  } catch (e) {
    fail('Should have succeeded after retries');
  }

  expect(attempts, 3);
});
```

## Additional Resources

- [Health Connect API Limits](https://developer.android.com/health-and-fitness/guides/health-connect/develop/rate-limits)
- [Exponential Backoff Best Practices](https://cloud.google.com/iot/docs/how-tos/exponential-backoff)
- [HealthSync SDK Documentation](../README.md)

## Support

For issues or questions:
- Check logs with `verbose: true`
- Review `BatchWriteResult.errors` for failure details
- Report issues with rate limiter configuration and error messages
