import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_sync_flutter/src/models/data_type.dart';
import 'package:health_sync_flutter/src/models/health_data.dart';
import 'package:health_sync_flutter/src/utils/changes_api.dart';
import 'package:health_sync_flutter/src/utils/sync_token_manager.dart';

class MockSyncTokenManager extends SyncTokenManager {
  final Map<String, String> _tokens = {};
  final Map<String, DateTime> _tokenTimes = {};

  @override
  Future<String?> getToken(DataType dataType) async {
    return _tokens[dataType.toValue()];
  }

  @override
  Future<void> saveToken(DataType dataType, String token) async {
    _tokens[dataType.toValue()] = token;
    _tokenTimes[dataType.toValue()] = DateTime.now();
  }

  @override
  Future<void> clearToken(DataType dataType) async {
    _tokens.remove(dataType.toValue());
    _tokenTimes.remove(dataType.toValue());
  }

  @override
  Future<void> initialize() async {
    // Mock implementation - no-op
  }

  @override
  Future<DateTime?> getTokenCreationTime(DataType dataType) async {
    return _tokenTimes[dataType.toValue()];
  }

  void setTokenTime(DataType dataType, DateTime time) {
    _tokenTimes[dataType.toValue()] = time;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChangesApi', () {
    late MethodChannel channel;
    late MockSyncTokenManager tokenManager;
    late ChangesApi changesApi;

    setUp(() {
      channel = const MethodChannel('health_sync_flutter/health_connect');
      tokenManager = MockSyncTokenManager();
      changesApi = ChangesApi(
        channel: channel,
        tokenManager: tokenManager,
      );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('getChanges returns initial sync when no token exists', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'getChangesToken') {
          return 'initial_token_123';
        }
        return null;
      });

      final result = await changesApi.getChanges(DataType.steps);

      expect(result.isSuccess, true);
      expect(result.isInitialSync, true);
      expect(result.changes.length, 0);  // Initial sync returns no data
      expect(result.usedFallback, false);
    });

    test('getChanges returns incremental changes with existing token', () async {
      await tokenManager.saveToken(DataType.steps, 'existing_token');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'getChanges') {
          expect(methodCall.arguments['token'], 'existing_token');
          final now = DateTime.now();
          return {
            'changes': [
              {
                'sourceDataType': 'Steps',
                'source': 'health_connect',
                'timestamp': now.toIso8601String(),
                'raw': {'value': 500, 'unit': 'count'},
              }
            ],
            'hasMore': false,
            'nextToken': 'new_token_456',
          };
        }
        return null;
      });

      final result = await changesApi.getChanges(DataType.steps);

      expect(result.isSuccess, true);
      expect(result.isInitialSync, false);
      expect(result.changes.length, 1);
      expect(result.usedFallback, false);
    });

    test('getChangesWithFallback falls back on invalid token error', () async {
      await tokenManager.saveToken(DataType.steps, 'corrupted_token');

      var methodCallCount = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        methodCallCount++;
        if (methodCall.method == 'getChanges') {
          // First call fails with invalid token
          throw PlatformException(
            code: 'INVALID_TOKEN',
            message: 'Token is invalid or expired',
          );
        }
        return null;
      });

      final result = await changesApi.getChangesWithFallback(
        DataType.steps,
        fullSyncCallback: () async {
          return [
            RawHealthData.simple(
              value: 1000.0,
              unit: 'count',
              timestamp: DateTime.now(),
              source: {},
            ),
          ];
        },
      );

      expect(result.isSuccess, true);
      expect(result.usedFallback, true);
      expect(result.changes.length, 1);
      expect(result.changes.first.value, 1000);
    });

    test('getChangesWithFallback falls back on token not found error', () async {
      // Save a token first so getChanges actually gets called
      await tokenManager.saveToken(DataType.steps, 'some_token');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'getChanges') {
          throw PlatformException(
            code: 'ERROR',
            message: 'Token not found in database',
          );
        }
        return null;
      });

      final result = await changesApi.getChangesWithFallback(
        DataType.steps,
        fullSyncCallback: () async {
          return [
            RawHealthData.simple(
              value: 2000.0,
              unit: 'count',
              timestamp: DateTime.now(),
              source: {},
            ),
          ];
        },
      );

      expect(result.usedFallback, true);
      expect(result.changes.length, 1);
    });

    test('getChangesWithFallback succeeds without fallback when token is valid', () async {
      await tokenManager.saveToken(DataType.steps, 'valid_token');

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        if (methodCall.method == 'getChanges') {
          final now = DateTime.now();
          return {
            'changes': [
              {
                'sourceDataType': 'Steps',
                'source': 'health_connect',
                'timestamp': now.toIso8601String(),
                'raw': {'value': 500, 'unit': 'count'},
              }
            ],
            'hasMore': false,
            'nextToken': 'new_valid_token',
          };
        }
        return null;
      });

      var fallbackCalled = false;
      final result = await changesApi.getChangesWithFallback(
        DataType.steps,
        fullSyncCallback: () async {
          fallbackCalled = true;
          return [];
        },
      );

      expect(result.isSuccess, true);
      expect(result.usedFallback, false);
      expect(fallbackCalled, false);
      expect(result.changes.length, 1);
    });

    test('validateToken detects stale token (>30 days)', () async {
      final oldTime = DateTime.now().subtract(Duration(days: 35));
      await tokenManager.saveToken(DataType.steps, 'old_token');
      tokenManager.setTokenTime(DataType.steps, oldTime);

      final validation = await changesApi.validateToken(DataType.steps);

      expect(validation.isValid, false);
      expect(validation.isStale, true);
      expect(validation.reason, contains('stale'));
    });

    test('validateToken accepts recent token (<30 days)', () async {
      final recentTime = DateTime.now().subtract(Duration(days: 5));
      await tokenManager.saveToken(DataType.steps, 'recent_token');
      tokenManager.setTokenTime(DataType.steps, recentTime);

      final validation = await changesApi.validateToken(DataType.steps);

      expect(validation.isValid, true);
      expect(validation.isStale, false);
    });

    test('validateToken handles missing token', () async {
      final validation = await changesApi.validateToken(DataType.steps);

      expect(validation.isValid, false);
      expect(validation.reason, contains('No token'));
    });

    test('validateToken handles missing creation time', () async {
      await tokenManager.saveToken(DataType.steps, 'token_no_time');
      // Don't set creation time

      final validation = await changesApi.validateToken(DataType.steps);

      expect(validation.isValid, true); // Assumes valid if no time available
    });

    test('resetSync clears token and resets state', () async {
      await tokenManager.saveToken(DataType.steps, 'some_token');

      await changesApi.resetSync(DataType.steps);

      final token = await tokenManager.getToken(DataType.steps);
      expect(token, isNull);
    });

    test('getSyncStatus returns correct status', () async {
      await tokenManager.saveToken(DataType.heartRate, 'hr_token');
      tokenManager.setTokenTime(DataType.heartRate, DateTime.now().subtract(Duration(days: 5)));

      final status = await changesApi.getSyncStatus(DataType.heartRate);

      expect(status.hasToken, true);
      expect(status.dataType, DataType.heartRate);
      expect(status.tokenAge, isNotNull);
      expect(status.tokenAge!.inDays, 5);
    });

    test('getSyncStatus handles no token', () async {
      final status = await changesApi.getSyncStatus(DataType.steps);

      expect(status.hasToken, false);
      expect(status.tokenAge, isNull);
    });
  });

  group('ChangesResult', () {
    test('isSuccess is true when no error', () {
      final result = ChangesResult(
        changes: [],
        hasMore: false,
        nextToken: null,
        isInitialSync: false,
      );

      expect(result.isSuccess, true);
    });

    test('isSuccess is false when error exists', () {
      final result = ChangesResult(
        changes: [],
        hasMore: false,
        nextToken: null,
        isInitialSync: false,
        error: 'Something went wrong',
      );

      expect(result.isSuccess, false);
    });

    test('hasChanges is true when changes exist', () {
      final result = ChangesResult(
        changes: [
          RawHealthData.simple(
            value: 100,
            unit: 'count',
            timestamp: DateTime.now(),
            source: {},
          ),
        ],
        hasMore: false,
        nextToken: null,
        isInitialSync: false,
      );

      expect(result.hasChanges, true);
    });

    test('usedFallback flag is preserved', () {
      final result = ChangesResult(
        changes: [],
        hasMore: false,
        nextToken: null,
        isInitialSync: false,
        usedFallback: true,
      );

      expect(result.usedFallback, true);
    });
  });

  group('TokenValidation', () {
    test('valid token has correct properties', () {
      final validation = TokenValidation(
        isValid: true,
        isStale: false,
        tokenAge: Duration(days: 5),
      );

      expect(validation.isValid, true);
      expect(validation.isStale, false);
      expect(validation.shouldRefresh, false);
    });

    test('stale token should refresh', () {
      final validation = TokenValidation(
        isValid: false,
        isStale: true,
        tokenAge: Duration(days: 35),
        reason: 'Token is stale',
      );

      expect(validation.isValid, false);
      expect(validation.isStale, true);
      expect(validation.shouldRefresh, true);
    });
  });
}
