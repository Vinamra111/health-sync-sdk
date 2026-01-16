import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../../models/connection_status.dart';
import '../../models/data_type.dart';
import '../../models/health_data.dart';
import '../../models/health_source.dart';
import '../../types/data_query.dart';
import '../../types/errors.dart';
import '../../utils/logger.dart';
import 'fitbit_types.dart';

/// Fitbit Plugin for Flutter
///
/// Provides access to Fitbit health data through OAuth 2.0 + PKCE authentication
/// and the Fitbit Web API.
class FitbitPlugin {
  /// Plugin ID
  static const String id = 'fitbit';

  /// Plugin name
  static const String name = 'Fitbit';

  /// Plugin version
  static const String version = '1.0.0';

  /// Supported data types
  static const List<DataType> supportedDataTypes = [
    DataType.steps,
    DataType.heartRate,
    DataType.restingHeartRate,
    DataType.sleep,
    DataType.activity,
    DataType.calories,
    DataType.distance,
    DataType.bloodOxygen,
    DataType.weight,
    DataType.heartRateVariability,
    DataType.vo2Max,
    DataType.respiratoryRate,
    DataType.bodyTemperature,
  ];

  /// Whether plugin requires authentication
  static const bool requiresAuthentication = true;

  /// Whether plugin is cloud-based
  static const bool isCloudBased = true;

  /// Current connection status
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;

  /// Get current connection status
  ConnectionStatus get connectionStatus => _connectionStatus;

  /// Plugin configuration
  final FitbitConfig config;

  /// Secure storage for tokens
  final _storage = const FlutterSecureStorage();

  /// PKCE code verifier (temporary)
  String? _codeVerifier;

  /// OAuth state for CSRF protection (temporary)
  String? _oauthState;

  /// Create Fitbit plugin instance
  FitbitPlugin({
    FitbitConfig? config,
  }) : config = config ?? const FitbitConfig();

  // ============================================================================
  // Lifecycle Methods
  // ============================================================================

  /// Initialize the plugin
  Future<void> initialize() async {
    logger.info('Initializing Fitbit plugin', category: 'Fitbit');

    try {
      // Check if already authenticated
      final isAuth = await isAuthenticated();

      if (isAuth) {
        _connectionStatus = ConnectionStatus.connected;
        logger.info('Fitbit plugin initialized - Already authenticated',
            category: 'Fitbit');
      } else {
        _connectionStatus = ConnectionStatus.disconnected;
        logger.info('Fitbit plugin initialized - Not authenticated',
            category: 'Fitbit');
      }
    } catch (e, stackTrace) {
      logger.error(
        'Failed to initialize Fitbit plugin',
        category: 'Fitbit',
        error: e,
        stackTrace: stackTrace,
      );
      throw HealthSyncConnectionError('Failed to initialize: $e');
    }
  }

  /// Connect to Fitbit (starts OAuth flow)
  ///
  /// Returns authorization URL that should be opened in browser
  Future<FitbitConnectionResult> connect() async {
    logger.info('Starting Fitbit connection', category: 'Fitbit');

    try {
      // Validate configuration
      if (config.clientId == 'YOUR_FITBIT_CLIENT_ID' ||
          config.clientId.isEmpty ||
          config.clientId.length < 6) {
        throw HealthSyncConnectionError(
          'Invalid Client ID. Please configure your Fitbit credentials in Settings.'
        );
      }

      if (config.clientSecret == 'YOUR_FITBIT_CLIENT_SECRET' ||
          config.clientSecret.isEmpty ||
          config.clientSecret.length < 16) {
        throw HealthSyncConnectionError(
          'Invalid Client Secret. Please configure your Fitbit credentials in Settings.'
        );
      }

      if (config.redirectUri.isEmpty ||
          !config.redirectUri.contains('://')) {
        throw HealthSyncConnectionError(
          'Invalid Redirect URI. Please configure your Fitbit credentials in Settings.'
        );
      }

      // Check if already connected
      if (await isAuthenticated()) {
        _connectionStatus = ConnectionStatus.connected;
        return FitbitConnectionResult(
          status: ConnectionStatus.connected,
          message: 'Already connected to Fitbit',
        );
      }

      // Generate PKCE parameters
      _codeVerifier = _generateCodeVerifier();
      final codeChallenge = _generateCodeChallenge(_codeVerifier!);

      // Generate state for CSRF protection
      _oauthState = _generateCodeVerifier(); // Reuse same random generation logic

      // Build authorization URL
      final authUrl = _buildAuthorizationUrl(codeChallenge, _oauthState!);

      _connectionStatus = ConnectionStatus.connecting;

      logger.info('OAuth authorization URL generated', category: 'Fitbit');

      return FitbitConnectionResult(
        status: ConnectionStatus.connecting,
        message: 'Please authorize in browser',
        authorizationUrl: authUrl,
        codeVerifier: _codeVerifier,
        state: _oauthState,
      );
    } catch (e, stackTrace) {
      logger.error(
        'Failed to connect to Fitbit',
        category: 'Fitbit',
        error: e,
        stackTrace: stackTrace,
      );
      throw HealthSyncConnectionError('Connection failed: $e');
    }
  }

  /// Launch OAuth authorization URL in browser
  Future<void> launchOAuth() async {
    final result = await connect();

    if (result.authorizationUrl == null) {
      throw HealthSyncConnectionError('No authorization URL generated');
    }

    try {
      final uri = Uri.parse(result.authorizationUrl!);

      logger.info('Launching OAuth URL: ${uri.toString()}', category: 'Fitbit');

      // Try to launch directly - canLaunchUrl() is unreliable on Android
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (launched) {
        logger.info('Successfully launched OAuth URL in browser', category: 'Fitbit');
      } else {
        throw HealthSyncConnectionError(
          'Failed to launch browser. Please ensure you have a web browser installed.'
        );
      }
    } catch (e) {
      logger.error('Failed to launch OAuth URL', category: 'Fitbit', error: e);

      if (e is HealthSyncConnectionError) {
        rethrow;
      }

      throw HealthSyncConnectionError(
        'Could not open browser: ${e.toString()}. Please check your device settings.'
      );
    }
  }

  /// Validate OAuth state for CSRF protection
  bool validateState(String receivedState) {
    if (_oauthState == null) {
      logger.warning('No OAuth state found for validation', category: 'Fitbit');
      return false;
    }

    final isValid = _oauthState == receivedState;

    if (!isValid) {
      logger.error('OAuth state validation failed - Possible CSRF attack',
          category: 'Fitbit');
    }

    return isValid;
  }

  /// Complete OAuth flow with authorization code
  Future<FitbitConnectionResult> completeAuthorization(
    String code, {
    String? state,
  }) async {
    logger.info('Completing Fitbit authorization', category: 'Fitbit');

    // Validate state if provided (CSRF protection)
    if (state != null && !validateState(state)) {
      throw HealthSyncAuthenticationError(
          'Invalid OAuth state - Possible CSRF attack');
    }

    if (_codeVerifier == null) {
      throw HealthSyncAuthenticationError(
          'Code verifier not found. Start OAuth flow first.');
    }

    try {
      // Exchange code for tokens
      final response = await http.post(
        Uri.parse(config.tokenUrl),
        headers: {
          'Authorization':
              'Basic ${base64Encode(utf8.encode('${config.clientId}:${config.clientSecret}'))}',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'client_id': config.clientId,
          'grant_type': 'authorization_code',
          'code': code,
          'code_verifier': _codeVerifier!,
          'redirect_uri': config.redirectUri,
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw HealthSyncConnectionError('Request timed out. Please check your internet connection.');
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Validate response data
        if (data['access_token'] == null || data['refresh_token'] == null) {
          throw HealthSyncAuthenticationError('Invalid token response from Fitbit');
        }

        // Save tokens
        await _saveTokens(
          accessToken: data['access_token'],
          refreshToken: data['refresh_token'],
          expiresIn: data['expires_in'],
          userId: data['user_id'],
        );

        _codeVerifier = null; // Clear verifier
        _oauthState = null; // Clear state
        _connectionStatus = ConnectionStatus.connected;

        logger.info('Fitbit authorization completed successfully',
            category: 'Fitbit');

        return FitbitConnectionResult(
          status: ConnectionStatus.connected,
          message: 'Connected to Fitbit successfully',
        );
      } else {
        // Parse error response
        String errorMessage = 'Authorization failed';
        try {
          final errorData = json.decode(response.body);
          if (errorData['errors'] != null && errorData['errors'].isNotEmpty) {
            errorMessage = errorData['errors'][0]['message'] ?? errorMessage;
          } else if (errorData['error_description'] != null) {
            errorMessage = errorData['error_description'];
          }
        } catch (_) {
          // Use default error message
        }

        logger.error('Token exchange failed: ${response.statusCode} - $errorMessage',
            category: 'Fitbit');

        throw HealthSyncAuthenticationError(errorMessage);
      }
    } on HealthSyncAuthenticationError {
      rethrow;
    } on HealthSyncConnectionError {
      rethrow;
    } catch (e, stackTrace) {
      logger.error(
        'Failed to complete Fitbit authorization',
        category: 'Fitbit',
        error: e,
        stackTrace: stackTrace,
      );

      // Provide more specific error messages
      String userMessage = 'Authorization failed';
      if (e.toString().contains('SocketException') ||
          e.toString().contains('NetworkException')) {
        userMessage = 'Network error. Please check your internet connection.';
      } else if (e.toString().contains('FormatException')) {
        userMessage = 'Invalid response from Fitbit. Please try again.';
      } else if (e.toString().contains('TimeoutException')) {
        userMessage = 'Request timed out. Please check your internet connection.';
      }

      throw HealthSyncAuthenticationError(userMessage);
    }
  }

  /// Disconnect from Fitbit (revokes tokens)
  Future<void> disconnect() async {
    logger.info('Disconnecting from Fitbit', category: 'Fitbit');

    try {
      final accessToken =
          await _storage.read(key: FitbitConfig.keyAccessToken);

      if (accessToken != null) {
        // Revoke token
        await http.post(
          Uri.parse(config.revokeUrl),
          headers: {
            'Authorization':
                'Basic ${base64Encode(utf8.encode('${config.clientId}:${config.clientSecret}'))}',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {
            'token': accessToken,
          },
        );
      }
    } catch (e) {
      logger.warning('Error revoking Fitbit token',
          category: 'Fitbit');
    } finally {
      // Clear all stored data
      await Future.wait([
        _storage.delete(key: FitbitConfig.keyAccessToken),
        _storage.delete(key: FitbitConfig.keyRefreshToken),
        _storage.delete(key: FitbitConfig.keyExpiresAt),
        _storage.delete(key: FitbitConfig.keyUserId),
      ]);

      _connectionStatus = ConnectionStatus.disconnected;

      logger.info('Disconnected from Fitbit', category: 'Fitbit');
    }
  }

  // ============================================================================
  // Data Fetching
  // ============================================================================

  /// Fetch health data
  Future<List<RawHealthData>> fetchData(DataQuery query) async {
    logger.info('Fetching Fitbit data',
        category: 'Fitbit', metadata: {'dataType': query.dataType.toString()});

    if (!await isAuthenticated()) {
      throw HealthSyncAuthenticationError('Not authenticated with Fitbit');
    }

    try {
      switch (query.dataType) {
        case DataType.steps:
          return await _fetchSteps(query);
        case DataType.heartRate:
        case DataType.restingHeartRate:
          return await _fetchHeartRate(query);
        case DataType.sleep:
          return await _fetchSleep(query);
        case DataType.weight:
          return await _fetchWeight(query);
        case DataType.activity:
          return await _fetchActivity(query);
        default:
          throw HealthSyncValidationError(
              'Data type ${query.dataType} not supported by Fitbit plugin');
      }
    } catch (e, stackTrace) {
      logger.error(
        'Failed to fetch Fitbit data',
        category: 'Fitbit',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // ============================================================================
  // Private: OAuth & Token Management
  // ============================================================================

  String _generateCodeVerifier() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64UrlEncode(values).replaceAll('=', '');
  }

  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }

  String _buildAuthorizationUrl(String codeChallenge, String state) {
    final params = {
      'client_id': config.clientId,
      'response_type': 'code',
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
      'redirect_uri': config.redirectUri,
      'scope': config.scopes.join(' '),
      'state': state, // CSRF protection
      'expires_in': '31536000', // 1 year
    };

    return Uri.parse(config.authorizationUrl)
        .replace(queryParameters: params)
        .toString();
  }

  Future<void> _saveTokens({
    required String accessToken,
    required String refreshToken,
    required int expiresIn,
    required String userId,
  }) async {
    final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

    await Future.wait([
      _storage.write(key: FitbitConfig.keyAccessToken, value: accessToken),
      _storage.write(key: FitbitConfig.keyRefreshToken, value: refreshToken),
      _storage.write(
          key: FitbitConfig.keyExpiresAt, value: expiresAt.toIso8601String()),
      _storage.write(key: FitbitConfig.keyUserId, value: userId),
    ]);
  }

  Future<bool> refreshAccessToken() async {
    try {
      final refreshToken =
          await _storage.read(key: FitbitConfig.keyRefreshToken);
      if (refreshToken == null) return false;

      final response = await http.post(
        Uri.parse(config.tokenUrl),
        headers: {
          'Authorization':
              'Basic ${base64Encode(utf8.encode('${config.clientId}:${config.clientSecret}'))}',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _saveTokens(
          accessToken: data['access_token'],
          refreshToken: data['refresh_token'],
          expiresIn: data['expires_in'],
          userId: data['user_id'],
        );
        return true;
      }
      return false;
    } catch (e) {
      logger.error('Failed to refresh access token', category: 'Fitbit', error: e);
      return false;
    }
  }

  Future<String?> getAccessToken() async {
    final accessToken = await _storage.read(key: FitbitConfig.keyAccessToken);
    if (accessToken == null) return null;

    // Check expiration
    final expiresAtStr = await _storage.read(key: FitbitConfig.keyExpiresAt);
    if (expiresAtStr != null) {
      final expiresAt = DateTime.parse(expiresAtStr);
      final now = DateTime.now();

      // Refresh if expiring in less than 5 minutes
      if (expiresAt.isBefore(now.add(const Duration(minutes: 5)))) {
        final refreshed = await refreshAccessToken();
        if (!refreshed) return null;
        return await _storage.read(key: FitbitConfig.keyAccessToken);
      }
    }

    return accessToken;
  }

  Future<bool> isAuthenticated() async {
    final token = await getAccessToken();
    return token != null;
  }

  // ============================================================================
  // Private: API Requests
  // ============================================================================

  Future<Map<String, dynamic>> _apiRequest(String endpoint) async {
    final accessToken = await getAccessToken();
    if (accessToken == null) {
      throw HealthSyncAuthenticationError('Not authenticated');
    }

    final url = '${config.apiBaseUrl}$endpoint';
    logger.info('Fitbit API Request: $url', category: 'Fitbit');

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
          'Accept-Language': 'en_US',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw HealthSyncConnectionError(
            'Request timed out. Please check your internet connection.'
          );
        },
      );

      logger.info('Fitbit API Response: ${response.statusCode}', category: 'Fitbit');

      if (response.statusCode == 200) {
        try {
          return json.decode(response.body) as Map<String, dynamic>;
        } catch (e) {
          logger.error('Failed to parse Fitbit API response',
            category: 'Fitbit',
            error: e,
            metadata: {'body': response.body}
          );
          throw HealthSyncApiError('Invalid response format from Fitbit');
        }
      } else if (response.statusCode == 401) {
        logger.warning('Fitbit token expired, attempting refresh', category: 'Fitbit');
        // Try refreshing
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          logger.info('Token refreshed successfully, retrying request', category: 'Fitbit');
          return await _apiRequest(endpoint);
        }
        throw HealthSyncAuthenticationError('Authentication expired. Please reconnect to Fitbit.');
      } else if (response.statusCode == 429) {
        logger.error('Fitbit rate limit exceeded', category: 'Fitbit');
        throw HealthSyncRateLimitError('Rate limit exceeded. Please wait before trying again.');
      } else {
        // Log detailed error information
        logger.error(
          'Fitbit API error: ${response.statusCode}',
          category: 'Fitbit',
          metadata: {
            'endpoint': endpoint,
            'statusCode': response.statusCode,
            'body': response.body,
          }
        );

        // Parse error message from response
        String errorMessage = 'API error (${response.statusCode})';
        try {
          final errorData = json.decode(response.body);
          if (errorData['errors'] != null && errorData['errors'].isNotEmpty) {
            errorMessage = errorData['errors'][0]['message'] ?? errorMessage;
          }
        } catch (_) {
          // Use default error message if parsing fails
        }

        throw HealthSyncApiError(errorMessage);
      }
    } on HealthSyncAuthenticationError {
      rethrow;
    } on HealthSyncConnectionError {
      rethrow;
    } on HealthSyncRateLimitError {
      rethrow;
    } on HealthSyncApiError {
      rethrow;
    } catch (e, stackTrace) {
      logger.error(
        'Unexpected error in Fitbit API request',
        category: 'Fitbit',
        error: e,
        stackTrace: stackTrace,
      );

      // Provide more specific error messages
      if (e.toString().contains('SocketException') ||
          e.toString().contains('NetworkException')) {
        throw HealthSyncConnectionError('Network error. Please check your internet connection.');
      } else if (e.toString().contains('TimeoutException')) {
        throw HealthSyncConnectionError('Request timed out. Please try again.');
      } else {
        throw HealthSyncApiError('Failed to fetch data: ${e.toString()}');
      }
    }
  }

  /// API request for v1.2 endpoints (like sleep)
  /// Sleep API uses version 1.2 instead of 1.0
  Future<Map<String, dynamic>> _apiRequestV1_2(String endpoint) async {
    final accessToken = await getAccessToken();
    if (accessToken == null) {
      throw HealthSyncAuthenticationError('Not authenticated');
    }

    // Use v1.2 base URL instead of v1
    final url = 'https://api.fitbit.com/1.2$endpoint';
    logger.info('Fitbit API Request (v1.2): $url', category: 'Fitbit');

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
          'Accept-Language': 'en_US',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw HealthSyncConnectionError(
            'Request timed out. Please check your internet connection.'
          );
        },
      );

      logger.info('Fitbit API Response: ${response.statusCode}', category: 'Fitbit');

      if (response.statusCode == 200) {
        try {
          return json.decode(response.body) as Map<String, dynamic>;
        } catch (e) {
          logger.error('Failed to parse Fitbit API response',
            category: 'Fitbit',
            error: e,
            metadata: {'body': response.body}
          );
          throw HealthSyncApiError('Invalid response format from Fitbit');
        }
      } else if (response.statusCode == 401) {
        logger.warning('Fitbit token expired, attempting refresh', category: 'Fitbit');
        // Try refreshing
        final refreshed = await refreshAccessToken();
        if (refreshed) {
          logger.info('Token refreshed successfully, retrying request', category: 'Fitbit');
          return await _apiRequestV1_2(endpoint);  // Recursive call with v1.2
        }
        throw HealthSyncAuthenticationError('Authentication expired. Please reconnect to Fitbit.');
      } else if (response.statusCode == 429) {
        logger.error('Fitbit rate limit exceeded', category: 'Fitbit');
        throw HealthSyncRateLimitError('Rate limit exceeded. Please wait before trying again.');
      } else {
        // Log detailed error information
        logger.error(
          'Fitbit API error: ${response.statusCode}',
          category: 'Fitbit',
          metadata: {
            'endpoint': endpoint,
            'statusCode': response.statusCode,
            'body': response.body,
          }
        );

        // Parse error message from response
        String errorMessage = 'API error (${response.statusCode})';
        try {
          final errorData = json.decode(response.body);
          if (errorData['errors'] != null && errorData['errors'].isNotEmpty) {
            errorMessage = errorData['errors'][0]['message'] ?? errorMessage;
          }
        } catch (_) {
          // Use default error message if parsing fails
        }

        throw HealthSyncApiError(errorMessage);
      }
    } on HealthSyncAuthenticationError {
      rethrow;
    } on HealthSyncConnectionError {
      rethrow;
    } on HealthSyncRateLimitError {
      rethrow;
    } on HealthSyncApiError {
      rethrow;
    } catch (e, stackTrace) {
      logger.error(
        'Unexpected error in Fitbit API request',
        category: 'Fitbit',
        error: e,
        stackTrace: stackTrace,
      );

      // Provide more specific error messages
      if (e.toString().contains('SocketException') ||
          e.toString().contains('NetworkException')) {
        throw HealthSyncConnectionError('Network error. Please check your internet connection.');
      } else if (e.toString().contains('TimeoutException')) {
        throw HealthSyncConnectionError('Request timed out. Please try again.');
      } else {
        throw HealthSyncApiError('Failed to fetch data: ${e.toString()}');
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<String> _getUserId() async {
    return await _storage.read(key: FitbitConfig.keyUserId) ?? '-';
  }

  /// Safely truncate a string to a maximum length
  /// Prevents RangeError when string is shorter than maxLength
  String _safeTruncate(String text, int maxLength) {
    if (text.length <= maxLength) {
      return text;
    }
    return text.substring(0, maxLength);
  }

  // ============================================================================
  // Private: Data Type Handlers
  // ============================================================================

  Future<List<RawHealthData>> _fetchSteps(DataQuery query) async {
    final userId = await _getUserId();
    final startDate = _formatDate(query.startDate);

    // Fitbit API doesn't support future dates - cap endDate at today
    final now = DateTime.now();
    final adjustedEndDate = query.endDate.isAfter(now) ? now : query.endDate;
    final endDate = _formatDate(adjustedEndDate);

    logger.info(
      'Fetching Fitbit steps data: $startDate to $endDate',
      category: 'Fitbit',
      metadata: {'userId': userId, 'startDate': startDate, 'endDate': endDate},
    );

    final data = await _apiRequest(
      '/user/$userId/activities/steps/date/$startDate/$endDate.json',
    );

    final steps = data['activities-steps'] as List<dynamic>? ?? [];

    logger.info(
      'Found ${steps.length} steps records',
      category: 'Fitbit',
      metadata: {'count': steps.length},
    );

    final parsed = <RawHealthData>[];
    int parseErrors = 0;

    for (var i = 0; i < steps.length; i++) {
      try {
        final item = steps[i] as Map<String, dynamic>;

        final record = RawHealthData(
          sourceDataType: 'fitbit-steps',
          source: HealthSource.fitbit,
          timestamp: DateTime.parse('${item['dateTime']}T00:00:00.000Z'),
          endTimestamp: DateTime.parse('${item['dateTime']}T23:59:59.999Z'),
          raw: {
            'steps': int.tryParse(item['value'].toString()) ?? 0,
            'date': item['dateTime'],
          },
        );

        parsed.add(record);
      } catch (e, stackTrace) {
        parseErrors++;
        logger.error(
          'Failed to parse steps record $i',
          category: 'Fitbit',
          error: e,
          stackTrace: stackTrace,
          metadata: {'record': steps[i].toString()},
        );
      }
    }

    logger.info(
      'Steps parsing complete: ${parsed.length} records, $parseErrors errors',
      category: 'Fitbit',
      metadata: {'totalParsed': parsed.length, 'parseErrors': parseErrors},
    );

    return parsed;
  }

  Future<List<RawHealthData>> _fetchHeartRate(DataQuery query) async {
    final userId = await _getUserId();
    final date = _formatDate(query.startDate);

    logger.info(
      'Fetching Fitbit heart rate data: $date',
      category: 'Fitbit',
      metadata: {'userId': userId, 'date': date},
    );

    final data = await _apiRequest(
      '/user/$userId/activities/heart/date/$date/1d.json',
    );

    final heartRateData = data['activities-heart'] as List<dynamic>? ?? [];

    logger.info(
      'Found ${heartRateData.length} heart rate records',
      category: 'Fitbit',
      metadata: {'count': heartRateData.length},
    );

    final parsed = <RawHealthData>[];
    int parseErrors = 0;

    for (var i = 0; i < heartRateData.length; i++) {
      try {
        final item = heartRateData[i] as Map<String, dynamic>;
        final timestamp = DateTime.parse('${item['dateTime']}T00:00:00.000Z');

        final record = RawHealthData(
          sourceDataType: 'fitbit-heart-rate',
          source: HealthSource.fitbit,
          timestamp: timestamp,
          raw: {
            'restingHeartRate': item['value']?['restingHeartRate'],
            'heartRateZones': item['value']?['heartRateZones'],
            'date': item['dateTime'],
          },
        );

        parsed.add(record);
      } catch (e, stackTrace) {
        parseErrors++;
        logger.error(
          'Failed to parse heart rate record $i',
          category: 'Fitbit',
          error: e,
          stackTrace: stackTrace,
          metadata: {'record': heartRateData[i].toString()},
        );
      }
    }

    logger.info(
      'Heart rate parsing complete: ${parsed.length} records, $parseErrors errors',
      category: 'Fitbit',
      metadata: {'totalParsed': parsed.length, 'parseErrors': parseErrors},
    );

    return parsed;
  }

  Future<List<RawHealthData>> _fetchSleep(DataQuery query) async {
    final userId = await _getUserId();
    final startDate = _formatDate(query.startDate);

    // Fitbit API doesn't support future dates - cap endDate at today
    final now = DateTime.now();
    final adjustedEndDate = query.endDate.isAfter(now) ? now : query.endDate;
    final endDate = _formatDate(adjustedEndDate);

    logger.info(
      'Fetching Fitbit sleep data: $startDate to $endDate',
      category: 'Fitbit',
      metadata: {'userId': userId, 'startDate': startDate, 'endDate': endDate},
    );

    // Sleep API uses v1.2, not v1 like other endpoints
    // Official endpoint: https://api.fitbit.com/1.2/user/-/sleep/date/{date}/{date}.json
    final data = await _apiRequestV1_2(
      '/user/-/sleep/date/$startDate/$endDate.json',
    );

    logger.info(
      'Fitbit API returned sleep data',
      category: 'Fitbit',
      metadata: {'rawResponse': _safeTruncate(data.toString(), 500)},
    );

    final sleep = data['sleep'] as List<dynamic>? ?? [];

    logger.info(
      'Found ${sleep.length} sleep records',
      category: 'Fitbit',
      metadata: {'count': sleep.length},
    );

    final parsed = <RawHealthData>[];
    int manualCount = 0;
    int autoCount = 0;
    int parseErrors = 0;

    for (var i = 0; i < sleep.length; i++) {
      try {
        final item = sleep[i] as Map<String, dynamic>;
        final logType = item['logType'] as String? ?? 'unknown';
        final type = item['type'] as String? ?? 'unknown';

        if (logType == 'manual') {
          manualCount++;
        } else if (logType == 'auto_detected') {
          autoCount++;
        }

        logger.info(
          'Sleep record $i: type=$type, logType=$logType, logId=${item['logId']}',
          category: 'Fitbit',
        );

        final record = RawHealthData(
          sourceDataType: 'fitbit-sleep',
          source: HealthSource.fitbit,
          timestamp: DateTime.parse(item['startTime']),
          endTimestamp: DateTime.parse(item['endTime']),
          raw: {
            'duration': item['duration'],
            'efficiency': item['efficiency'],
            'minutesAsleep': item['minutesAsleep'],
            'minutesAwake': item['minutesAwake'],
            'stages': item['levels']?['summary'],
            'logType': logType, // Track if manual or auto
            'type': type, // Track if classic or stages
            'isMainSleep': item['isMainSleep'] ?? false,
            'dateOfSleep': item['dateOfSleep'],
          },
          sourceId: item['logId'].toString(),
        );

        parsed.add(record);
      } catch (e, stackTrace) {
        parseErrors++;
        logger.error(
          'Failed to parse sleep record $i',
          category: 'Fitbit',
          error: e,
          stackTrace: stackTrace,
          metadata: {'record': sleep[i].toString()},
        );
      }
    }

    logger.info(
      'Sleep parsing complete: $manualCount manual, $autoCount auto, $parseErrors errors',
      category: 'Fitbit',
      metadata: {
        'manualCount': manualCount,
        'autoCount': autoCount,
        'parseErrors': parseErrors,
        'totalParsed': parsed.length,
      },
    );

    return parsed;
  }

  Future<List<RawHealthData>> _fetchWeight(DataQuery query) async {
    final userId = await _getUserId();
    final startDate = _formatDate(query.startDate);

    // Fitbit API doesn't support future dates - cap endDate at today
    final now = DateTime.now();
    final adjustedEndDate = query.endDate.isAfter(now) ? now : query.endDate;
    final endDate = _formatDate(adjustedEndDate);

    logger.info(
      'Fetching Fitbit weight data: $startDate to $endDate',
      category: 'Fitbit',
      metadata: {'userId': userId, 'startDate': startDate, 'endDate': endDate},
    );

    final data = await _apiRequest(
      '/user/$userId/body/log/weight/date/$startDate/$endDate.json',
    );

    final weight = data['weight'] as List<dynamic>? ?? [];

    logger.info(
      'Found ${weight.length} weight records',
      category: 'Fitbit',
      metadata: {'count': weight.length},
    );

    final parsed = <RawHealthData>[];
    int parseErrors = 0;

    for (var i = 0; i < weight.length; i++) {
      try {
        final item = weight[i] as Map<String, dynamic>;
        final timestamp =
            DateTime.parse('${item['date']}T${item['time']}'.replaceAll(' ', 'T'));

        logger.info(
          'Weight record $i: date=${item['date']}, logId=${item['logId']}',
          category: 'Fitbit',
        );

        final record = RawHealthData(
          sourceDataType: 'fitbit-weight',
          source: HealthSource.fitbit,
          timestamp: timestamp,
          raw: {
            'weight': item['weight'],
            'bmi': item['bmi'],
            'fat': item['fat'],
            'source': item['source'] ?? 'unknown', // Track if manual or from scale
          },
          sourceId: item['logId'].toString(),
        );

        parsed.add(record);
      } catch (e, stackTrace) {
        parseErrors++;
        logger.error(
          'Failed to parse weight record $i',
          category: 'Fitbit',
          error: e,
          stackTrace: stackTrace,
          metadata: {'record': weight[i].toString()},
        );
      }
    }

    logger.info(
      'Weight parsing complete: ${parsed.length} records, $parseErrors errors',
      category: 'Fitbit',
      metadata: {'totalParsed': parsed.length, 'parseErrors': parseErrors},
    );

    return parsed;
  }

  Future<List<RawHealthData>> _fetchActivity(DataQuery query) async {
    final userId = await _getUserId();
    final date = _formatDate(query.startDate);

    logger.info(
      'Fetching Fitbit activity data: $date',
      category: 'Fitbit',
      metadata: {'userId': userId, 'date': date},
    );

    try {
      final data = await _apiRequest(
        '/user/$userId/activities/date/$date.json',
      );

      final summary = data['summary'] as Map<String, dynamic>?;

      if (summary == null) {
        logger.warning(
          'No activity summary found in response',
          category: 'Fitbit',
        );
        return [];
      }

      final timestamp = DateTime.parse('${date}T00:00:00.000Z');

      final record = RawHealthData(
        sourceDataType: 'fitbit-activity',
        source: HealthSource.fitbit,
        timestamp: timestamp,
        endTimestamp: DateTime.parse('${date}T23:59:59.999Z'),
        raw: {
          'steps': summary['steps'],
          'calories': summary['caloriesOut'],
          'distance': summary['distances']?[0]?['distance'],
          'activeMinutes':
              (summary['fairlyActiveMinutes'] ?? 0) + (summary['veryActiveMinutes'] ?? 0),
          'floors': summary['floors'],
        },
      );

      logger.info(
        'Activity parsing complete: 1 record',
        category: 'Fitbit',
      );

      return [record];
    } catch (e, stackTrace) {
      logger.error(
        'Failed to parse activity data',
        category: 'Fitbit',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }
}
