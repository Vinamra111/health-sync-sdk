import '../../models/connection_status.dart';

/// Fitbit Plugin Configuration
class FitbitConfig {
  /// Fitbit OAuth Client ID
  final String clientId;

  /// Fitbit OAuth Client Secret
  final String clientSecret;

  /// OAuth Redirect URI
  final String redirectUri;

  /// OAuth Scopes
  final List<String> scopes;

  /// Authorization URL
  final String authorizationUrl;

  /// Token URL
  final String tokenUrl;

  /// Revoke URL
  final String revokeUrl;

  /// API Base URL
  final String apiBaseUrl;

  /// Secure storage keys
  static const String keyAccessToken = 'fitbit_access_token';
  static const String keyRefreshToken = 'fitbit_refresh_token';
  static const String keyExpiresAt = 'fitbit_expires_at';
  static const String keyUserId = 'fitbit_user_id';

  const FitbitConfig({
    this.clientId = 'YOUR_FITBIT_CLIENT_ID',
    this.clientSecret = 'YOUR_FITBIT_CLIENT_SECRET',
    this.redirectUri = 'healthsync://fitbit/callback',
    this.scopes = const [
      'activity',
      'heartrate',
      'sleep',
      'weight',
      'nutrition',
      'oxygen_saturation',
      'respiratory_rate',
      'temperature',
    ],
    this.authorizationUrl = 'https://www.fitbit.com/oauth2/authorize',
    this.tokenUrl = 'https://api.fitbit.com/oauth2/token',
    this.revokeUrl = 'https://api.fitbit.com/oauth2/revoke',
    this.apiBaseUrl = 'https://api.fitbit.com/1',
  });
}

/// Fitbit Connection Result
class FitbitConnectionResult {
  /// Connection status
  final ConnectionStatus status;

  /// Message
  final String message;

  /// Authorization URL (when status is pending)
  final String? authorizationUrl;

  /// Code verifier for PKCE (when status is pending)
  final String? codeVerifier;

  /// OAuth state for CSRF protection (when status is pending)
  final String? state;

  const FitbitConnectionResult({
    required this.status,
    required this.message,
    this.authorizationUrl,
    this.codeVerifier,
    this.state,
  });
}
