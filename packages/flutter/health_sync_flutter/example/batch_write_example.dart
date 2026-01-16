import 'package:health_sync_flutter/health_sync_flutter.dart';

/// Example: Writing Large Datasets with Automatic Batching and Rate Limiting
///
/// This example demonstrates how to write 5000 step records to Health Connect.
/// The SDK automatically:
/// - Splits into 5 batches of 1000 records each (Health Connect limit)
/// - Retries on rate limit errors with exponential backoff
/// - Tracks progress and reports detailed results
void main() async {
  // Initialize Health Connect plugin
  final plugin = HealthConnectPlugin(
    // Optional: Use aggressive retry strategy for critical operations
    rateLimiter: RateLimiterConfig.aggressive,
  );

  await plugin.initialize();
  await plugin.connect();

  // Example 1: Simple batch write
  await simpleExample(plugin);

  // Example 2: Batch write with progress tracking
  await progressExample(plugin);

  // Example 3: Custom rate limiter configuration
  await customConfigExample();

  // Example 4: Handling partial failures
  await errorHandlingExample(plugin);
}

/// Example 1: Simple batch write
Future<void> simpleExample(HealthConnectPlugin plugin) async {
  print('=== Example 1: Simple Batch Write ===\n');

  // Generate 5000 step records
  final records = List.generate(5000, (i) {
    final time = DateTime.now().subtract(Duration(hours: i));
    return {
      'count': 100 + (i % 500), // 100-600 steps
      'startTime': time.toUtc().toIso8601String(),
      'endTime': time.add(Duration(minutes: 30)).toUtc().toIso8601String(),
    };
  });

  print('Writing ${records.length} step records...');

  // Automatically split into 1000-record batches with rate limiting
  final result = await plugin.insertRecords(
    dataType: DataType.steps,
    records: records,
  );

  // Print results
  print('✓ Success: ${result.successfulRecords}/${result.totalRecords} records');
  print('  Batches: ${result.batches}');
  print('  Duration: ${result.duration.inSeconds}s');
  print('  Success Rate: ${(result.successRate * 100).toStringAsFixed(1)}%');
  print('  Avg Time/Record: ${result.averageTimePerRecord.inMilliseconds}ms\n');
}

/// Example 2: Batch write with progress tracking
Future<void> progressExample(HealthConnectPlugin plugin) async {
  print('=== Example 2: Progress Tracking ===\n');

  final records = List.generate(3000, (i) {
    final time = DateTime.now().subtract(Duration(hours: i));
    return {
      'count': 200 + (i % 300),
      'startTime': time.toUtc().toIso8601String(),
      'endTime': time.add(Duration(minutes: 45)).toUtc().toIso8601String(),
    };
  });

  print('Writing ${records.length} records with progress tracking...\n');

  final result = await plugin.insertRecords(
    dataType: DataType.steps,
    records: records,
    onProgress: (progress) {
      // Update progress bar in UI
      final percent = progress.progressPercent;
      final bar = '█' * (percent ~/ 5) + '░' * (20 - (percent ~/ 5));
      print('[$bar] $percent% - Batch ${progress.currentBatch}/${progress.totalBatches}');
    },
  );

  print('\n✓ Completed: ${result.successfulRecords}/${result.totalRecords} records\n');
}

/// Example 3: Custom rate limiter configuration
Future<void> customConfigExample() async {
  print('=== Example 3: Custom Configuration ===\n');

  // Create plugin with custom rate limiter
  final plugin = HealthConnectPlugin(
    rateLimiter: RateLimiter(
      maxRetries: 10,        // More retries for critical operations
      initialDelayMs: 500,   // Start with 0.5s delay
      maxDelayMs: 30000,     // Cap at 30s
      enableBackoff: true,   // Enable exponential backoff
    ),
  );

  await plugin.initialize();
  await plugin.connect();

  final records = List.generate(2000, (i) {
    final time = DateTime.now().subtract(Duration(hours: i));
    return {
      'beatsPerMinute': 60 + (i % 40), // 60-100 bpm
      'time': time.toUtc().toIso8601String(),
    };
  });

  print('Writing ${records.length} heart rate records with custom retry strategy...');

  final result = await plugin.insertRecords(
    dataType: DataType.heartRate,
    records: records,
  );

  print('✓ Result: ${result.successfulRecords}/${result.totalRecords} records');
  print('  Configuration: 10 retries, 0.5s → 30s backoff\n');
}

/// Example 4: Handling partial failures
Future<void> errorHandlingExample(HealthConnectPlugin plugin) async {
  print('=== Example 4: Error Handling ===\n');

  final records = List.generate(4000, (i) {
    final time = DateTime.now().subtract(Duration(hours: i));
    return {
      'count': 150 + (i % 400),
      'startTime': time.toUtc().toIso8601String(),
      'endTime': time.add(Duration(hours: 1)).toUtc().toIso8601String(),
    };
  });

  print('Writing ${records.length} records with error handling...');

  try {
    final result = await plugin.insertRecords(
      dataType: DataType.steps,
      records: records,
    );

    // Check for full success
    if (result.isFullSuccess) {
      print('✓ All records written successfully!');
    }
    // Check for partial success
    else if (result.isPartialSuccess) {
      print('⚠ Partial success: ${result.successfulRecords}/${result.totalRecords}');
      print('  Failed batches: ${result.errors.length}');

      // Inspect individual errors
      for (final error in result.errors) {
        print('  - Batch ${error.batchNumber} (${error.recordCount} records): ${error.error}');
      }

      // Option 1: Retry failed batches
      print('\n  Retrying failed batches...');
      await retryFailedBatches(plugin, result.errors, records);

      // Option 2: Log for later processing
      // await logFailedBatches(result.errors);
    }
    // Check for full failure
    else if (result.isFullFailure) {
      print('✗ All batches failed!');
      print('  Errors: ${result.errors.length}');
    }
  } on HealthSyncAuthenticationError catch (e) {
    print('✗ Missing permissions: $e');
    // Request permissions and retry
    await plugin.requestPermissions([
      HealthConnectPermission.readSteps,
    ]);
  } on HealthSyncConnectionError catch (e) {
    print('✗ Not connected: $e');
    // Reconnect and retry
    await plugin.connect();
  } catch (e) {
    print('✗ Unexpected error: $e');
  }

  print('');
}

/// Retry failed batches
Future<void> retryFailedBatches(
  HealthConnectPlugin plugin,
  List<BatchError> errors,
  List<Map<String, dynamic>> allRecords,
) async {
  for (final error in errors) {
    // Calculate which records were in this batch
    final batchIndex = error.batchNumber - 1;
    final startIndex = batchIndex * 1000;
    final endIndex = (startIndex + error.recordCount).clamp(0, allRecords.length);
    final failedRecords = allRecords.sublist(startIndex, endIndex);

    print('  Retrying batch ${error.batchNumber} (${failedRecords.length} records)...');

    try {
      final retryResult = await plugin.insertRecords(
        dataType: DataType.steps,
        records: failedRecords,
      );

      if (retryResult.isFullSuccess) {
        print('  ✓ Retry successful!');
      } else {
        print('  ✗ Retry failed: ${retryResult.failedRecords} records still failed');
      }
    } catch (e) {
      print('  ✗ Retry error: $e');
    }
  }
}

/// Advanced Example: Direct BatchWriter usage
Future<void> advancedBatchWriterExample() async {
  print('=== Advanced: Direct BatchWriter Usage ===\n');

  final batchWriter = BatchWriter(
    rateLimiter: RateLimiterConfig.aggressive,
    verbose: true, // Enable detailed logging
  );

  // Custom data structure
  final myRecords = List.generate(5000, (i) => MyCustomRecord(
    id: i,
    value: i * 2,
    timestamp: DateTime.now().subtract(Duration(hours: i)),
  ));

  print('Writing ${myRecords.length} custom records...\n');

  final result = await batchWriter.writeBatch<MyCustomRecord>(
    records: myRecords,
    writeFunction: (batch) async {
      // Your custom write logic
      print('Writing batch of ${batch.length} records...');
      await Future.delayed(Duration(milliseconds: 100)); // Simulate API call
    },
    operationName: 'Custom Operation',
    onProgress: (progress) {
      print('Progress: ${progress.progressPercent}% (${progress.recordsProcessed}/${progress.totalRecords})');
    },
  );

  print('\n✓ Completed: ${result.successfulRecords}/${result.totalRecords} records');
  print('  Duration: ${result.duration.inSeconds}s');
  print('  Avg Time/Record: ${result.averageTimePerRecord.inMilliseconds}ms\n');
}

/// Custom record class for advanced example
class MyCustomRecord {
  final int id;
  final int value;
  final DateTime timestamp;

  MyCustomRecord({
    required this.id,
    required this.value,
    required this.timestamp,
  });
}

/// Advanced Example: Parallel batch writes
Future<void> parallelBatchExample() async {
  print('=== Advanced: Parallel Batch Writes ===\n');

  final batchWriter = BatchWriter(
    rateLimiter: RateLimiterConfig.conservative,
  );

  // Multiple data types to write in parallel
  final recordsByType = {
    'steps': List.generate(2000, (i) => {'count': 100 + i}),
    'heartRate': List.generate(1500, (i) => {'bpm': 70 + i}),
    'sleep': List.generate(500, (i) => {'duration': 7 + (i % 3)}),
  };

  print('Writing multiple data types in parallel...\n');

  final results = await batchWriter.writeParallelBatches(
    recordsByType: recordsByType,
    writeFunction: (type, records) async {
      print('Writing $type batch of ${records.length} records...');
      await Future.delayed(Duration(milliseconds: 50)); // Simulate API call
    },
    onProgress: (type, progress) {
      print('$type: ${progress.progressPercent}% (batch ${progress.currentBatch}/${progress.totalBatches})');
    },
  );

  // Aggregate statistics
  final stats = BatchWriteStats(results);
  print('\n✓ All operations completed!');
  print('  Total Records: ${stats.totalRecords}');
  print('  Successful: ${stats.successfulRecords}');
  print('  Failed: ${stats.failedRecords}');
  print('  Success Rate: ${(stats.overallSuccessRate * 100).toStringAsFixed(1)}%');
  print('  Total Duration: ${stats.totalDuration.inSeconds}s');
  print('  Total Batches: ${stats.totalBatches}\n');
}
