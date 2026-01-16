/// Connection status enumeration
enum ConnectionStatus {
  /// Plugin is connected and ready
  connected,

  /// Plugin is disconnected
  disconnected,

  /// Plugin is connecting
  connecting,

  /// Plugin is disconnecting
  disconnecting,

  /// Connection is in error state
  error,

  /// Connection requires re-authentication
  requiresAuth,
}

extension ConnectionStatusExtension on ConnectionStatus {
  /// Convert to string representation
  String toValue() {
    switch (this) {
      case ConnectionStatus.connected:
        return 'connected';
      case ConnectionStatus.disconnected:
        return 'disconnected';
      case ConnectionStatus.connecting:
        return 'connecting';
      case ConnectionStatus.disconnecting:
        return 'disconnecting';
      case ConnectionStatus.error:
        return 'error';
      case ConnectionStatus.requiresAuth:
        return 'requires_auth';
    }
  }

  /// Create from string value
  static ConnectionStatus fromValue(String value) {
    switch (value) {
      case 'connected':
        return ConnectionStatus.connected;
      case 'disconnected':
        return ConnectionStatus.disconnected;
      case 'connecting':
        return ConnectionStatus.connecting;
      case 'disconnecting':
        return ConnectionStatus.disconnecting;
      case 'error':
        return ConnectionStatus.error;
      case 'requires_auth':
        return ConnectionStatus.requiresAuth;
      default:
        return ConnectionStatus.disconnected;
    }
  }
}
