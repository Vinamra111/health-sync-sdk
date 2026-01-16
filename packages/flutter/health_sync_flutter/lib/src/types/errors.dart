/// Base class for all HealthSync errors
class HealthSyncError implements Exception {
  final String message;
  final Object? cause;

  HealthSyncError(this.message, [this.cause]);

  @override
  String toString() => 'HealthSyncError: $message${cause != null ? ' (caused by: $cause)' : ''}';
}

/// Connection error
class HealthSyncConnectionError extends HealthSyncError {
  HealthSyncConnectionError(super.message, [super.cause]);

  @override
  String toString() => 'HealthSyncConnectionError: $message';
}

/// Authentication error
class HealthSyncAuthenticationError extends HealthSyncError {
  HealthSyncAuthenticationError(super.message, [super.cause]);

  @override
  String toString() => 'HealthSyncAuthenticationError: $message';
}

/// Data fetch error
class HealthSyncDataFetchError extends HealthSyncError {
  HealthSyncDataFetchError(super.message, [super.cause]);

  @override
  String toString() => 'HealthSyncDataFetchError: $message';
}

/// Configuration error
class HealthSyncConfigurationError extends HealthSyncError {
  HealthSyncConfigurationError(super.message, [super.cause]);

  @override
  String toString() => 'HealthSyncConfigurationError: $message';
}

/// Rate limit error (API throttling)
class HealthSyncRateLimitError extends HealthSyncError {
  HealthSyncRateLimitError(super.message, [super.cause]);

  @override
  String toString() => 'HealthSyncRateLimitError: $message';
}

/// API error (HTTP errors, server errors)
class HealthSyncApiError extends HealthSyncError {
  HealthSyncApiError(super.message, [super.cause]);

  @override
  String toString() => 'HealthSyncApiError: $message';
}

/// Validation error (invalid parameters, data)
class HealthSyncValidationError extends HealthSyncError {
  HealthSyncValidationError(super.message, [super.cause]);

  @override
  String toString() => 'HealthSyncValidationError: $message';
}
