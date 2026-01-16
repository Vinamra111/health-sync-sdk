import 'dart:async';
import 'package:flutter/foundation.dart';
import 'rate_limiter.dart';

/// Batch writer for Health Connect operations
///
/// Implements best practices for writing large datasets:
/// - Max 1000 records per batch (Health Connect limit)
/// - Automatic chunking of large datasets
/// - Rate limiting with exponential backoff
/// - Progress tracking
class BatchWriter {
  /// Maximum records per batch (Health Connect limit)
  static const int maxBatchSize = 1000;

  /// Rate limiter for retry logic
  final RateLimiter rateLimiter;

  /// Whether to enable verbose logging
  final bool verbose;

  BatchWriter({
    RateLimiter? rateLimiter,
    this.verbose = false,
  }) : rateLimiter = rateLimiter ?? RateLimiterConfig.conservative;

  /// Write records in batches with rate limiting
  ///
  /// Automatically splits large datasets into chunks of 1000 records.
  /// Each batch is written with exponential backoff retry logic.
  ///
  /// Returns the total number of successfully written records.
  Future<BatchWriteResult> writeBatch<T>({
    required List<T> records,
    required Future<void> Function(List<T>) writeFunction,
    String? operationName,
    void Function(BatchProgress)? onProgress,
  }) async {
    if (records.isEmpty) {
      return BatchWriteResult(
        totalRecords: 0,
        successfulRecords: 0,
        failedRecords: 0,
        batches: 0,
        duration: Duration.zero,
      );
    }

    final startTime = DateTime.now();
    final totalRecords = records.length;
    final batches = (totalRecords / maxBatchSize).ceil();

    int successfulRecords = 0;
    int failedRecords = 0;
    final List<BatchError> errors = [];

    debugPrint(
      '[BatchWriter] Starting batch write: $totalRecords records in $batches batches',
    );

    for (int i = 0; i < batches; i++) {
      final startIndex = i * maxBatchSize;
      final endIndex = ((i + 1) * maxBatchSize).clamp(0, totalRecords);
      final batch = records.sublist(startIndex, endIndex);

      final batchNum = i + 1;
      final batchSize = batch.length;

      try {
        // Write batch with rate limiting
        await rateLimiter.execute(
          () => writeFunction(batch),
          operationName: '${operationName ?? 'Batch'} $batchNum/$batches ($batchSize records)',
        );

        successfulRecords += batchSize;

        if (verbose) {
          debugPrint(
            '[BatchWriter] ✓ Batch $batchNum/$batches completed: $batchSize records',
          );
        }

        // Report progress
        onProgress?.call(
          BatchProgress(
            currentBatch: batchNum,
            totalBatches: batches,
            recordsProcessed: successfulRecords,
            totalRecords: totalRecords,
            isComplete: batchNum == batches,
          ),
        );
      } catch (e, stackTrace) {
        failedRecords += batchSize;

        debugPrint(
          '[BatchWriter] ✗ Batch $batchNum/$batches failed: $e',
        );

        errors.add(
          BatchError(
            batchNumber: batchNum,
            recordCount: batchSize,
            error: e,
            stackTrace: stackTrace,
          ),
        );

        // Continue with next batch (don't fail entire operation)
      }
    }

    final duration = DateTime.now().difference(startTime);

    debugPrint(
      '[BatchWriter] Completed: $successfulRecords/$totalRecords records written '
      '($failedRecords failed) in ${duration.inMilliseconds}ms',
    );

    return BatchWriteResult(
      totalRecords: totalRecords,
      successfulRecords: successfulRecords,
      failedRecords: failedRecords,
      batches: batches,
      duration: duration,
      errors: errors,
    );
  }

  /// Write records in parallel batches (for multiple data types)
  ///
  /// Useful when writing different data types simultaneously.
  Future<List<BatchWriteResult>> writeParallelBatches<T>({
    required Map<String, List<T>> recordsByType,
    required Future<void> Function(String type, List<T> records) writeFunction,
    void Function(String type, BatchProgress progress)? onProgress,
  }) async {
    final results = <BatchWriteResult>[];

    for (final entry in recordsByType.entries) {
      final type = entry.key;
      final records = entry.value;

      final result = await writeBatch(
        records: records,
        writeFunction: (batch) => writeFunction(type, batch),
        operationName: 'Write $type',
        onProgress: onProgress != null
            ? (progress) => onProgress(type, progress)
            : null,
      );

      results.add(result);
    }

    return results;
  }

  /// Calculate optimal batch size based on record size estimate
  ///
  /// For very large records, use smaller batches to avoid memory issues.
  static int calculateOptimalBatchSize({
    required int recordCount,
    int estimatedBytesPerRecord = 1024, // 1 KB default
    int maxMemoryBytes = 10 * 1024 * 1024, // 10 MB default
  }) {
    // Calculate max records that fit in memory
    final maxRecordsInMemory = maxMemoryBytes ~/ estimatedBytesPerRecord;

    // Use smaller of: Health Connect limit, memory limit, or total records
    return [maxBatchSize, maxRecordsInMemory, recordCount]
        .reduce((a, b) => a < b ? a : b);
  }
}

/// Result of a batch write operation
class BatchWriteResult {
  final int totalRecords;
  final int successfulRecords;
  final int failedRecords;
  final int batches;
  final Duration duration;
  final List<BatchError> errors;

  const BatchWriteResult({
    required this.totalRecords,
    required this.successfulRecords,
    required this.failedRecords,
    required this.batches,
    required this.duration,
    this.errors = const [],
  });

  /// Success rate as percentage
  double get successRate => totalRecords > 0
      ? successfulRecords / totalRecords
      : 0.0;

  /// Whether all records were written successfully
  bool get isFullSuccess => failedRecords == 0;

  /// Whether some records were written
  bool get isPartialSuccess => successfulRecords > 0 && failedRecords > 0;

  /// Whether all records failed
  bool get isFullFailure => successfulRecords == 0 && failedRecords > 0;

  /// Average time per record
  Duration get averageTimePerRecord => totalRecords > 0
      ? Duration(microseconds: duration.inMicroseconds ~/ totalRecords)
      : Duration.zero;

  @override
  String toString() {
    return 'BatchWriteResult{\n'
        '  Total Records: $totalRecords\n'
        '  Successful: $successfulRecords\n'
        '  Failed: $failedRecords\n'
        '  Success Rate: ${(successRate * 100).toStringAsFixed(1)}%\n'
        '  Batches: $batches\n'
        '  Duration: ${duration.inMilliseconds}ms\n'
        '  Avg Time/Record: ${averageTimePerRecord.inMilliseconds}ms\n'
        '  Errors: ${errors.length}\n'
        '}';
  }
}

/// Progress information for batch operations
class BatchProgress {
  final int currentBatch;
  final int totalBatches;
  final int recordsProcessed;
  final int totalRecords;
  final bool isComplete;

  const BatchProgress({
    required this.currentBatch,
    required this.totalBatches,
    required this.recordsProcessed,
    required this.totalRecords,
    required this.isComplete,
  });

  /// Progress as percentage (0.0 to 1.0)
  double get progress => totalRecords > 0
      ? recordsProcessed / totalRecords
      : 0.0;

  /// Progress as percentage (0 to 100)
  int get progressPercent => (progress * 100).round();

  @override
  String toString() {
    return 'BatchProgress(batch $currentBatch/$totalBatches, '
        'records $recordsProcessed/$totalRecords, ${progressPercent}%)';
  }
}

/// Error information for failed batches
class BatchError {
  final int batchNumber;
  final int recordCount;
  final dynamic error;
  final StackTrace? stackTrace;

  const BatchError({
    required this.batchNumber,
    required this.recordCount,
    required this.error,
    this.stackTrace,
  });

  @override
  String toString() {
    return 'BatchError(batch $batchNumber, $recordCount records): $error';
  }
}

/// Batch write statistics aggregator
class BatchWriteStats {
  final List<BatchWriteResult> results;

  const BatchWriteStats(this.results);

  int get totalRecords => results.fold(0, (sum, r) => sum + r.totalRecords);
  int get successfulRecords => results.fold(0, (sum, r) => sum + r.successfulRecords);
  int get failedRecords => results.fold(0, (sum, r) => sum + r.failedRecords);
  int get totalBatches => results.fold(0, (sum, r) => sum + r.batches);

  Duration get totalDuration => results.fold(
    Duration.zero,
    (sum, r) => sum + r.duration,
  );

  double get overallSuccessRate => totalRecords > 0
      ? successfulRecords / totalRecords
      : 0.0;

  @override
  String toString() {
    return 'BatchWriteStats{\n'
        '  Operations: ${results.length}\n'
        '  Total Records: $totalRecords\n'
        '  Successful: $successfulRecords\n'
        '  Failed: $failedRecords\n'
        '  Success Rate: ${(overallSuccessRate * 100).toStringAsFixed(1)}%\n'
        '  Total Batches: $totalBatches\n'
        '  Total Duration: ${totalDuration.inMilliseconds}ms\n'
        '}';
  }
}
