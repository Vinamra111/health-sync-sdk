/// Enumeration of supported health data sources
enum HealthSource {
  /// Google Health Connect (Android)
  healthConnect,

  /// Apple HealthKit (iOS)
  appleHealth,

  /// Fitbit Cloud API
  fitbit,

  /// Garmin Connect API
  garmin,

  /// Oura Ring API
  oura,

  /// Whoop API
  whoop,

  /// Strava API
  strava,

  /// MyFitnessPal API
  myFitnessPal,

  /// Generic/Unknown source
  unknown,
}

extension HealthSourceExtension on HealthSource {
  /// Convert to string representation
  String toValue() {
    switch (this) {
      case HealthSource.healthConnect:
        return 'health_connect';
      case HealthSource.appleHealth:
        return 'apple_health';
      case HealthSource.fitbit:
        return 'fitbit';
      case HealthSource.garmin:
        return 'garmin';
      case HealthSource.oura:
        return 'oura';
      case HealthSource.whoop:
        return 'whoop';
      case HealthSource.strava:
        return 'strava';
      case HealthSource.myFitnessPal:
        return 'myfitnesspal';
      case HealthSource.unknown:
        return 'unknown';
    }
  }

  /// Create from string value
  static HealthSource fromValue(String value) {
    switch (value) {
      case 'health_connect':
        return HealthSource.healthConnect;
      case 'apple_health':
        return HealthSource.appleHealth;
      case 'fitbit':
        return HealthSource.fitbit;
      case 'garmin':
        return HealthSource.garmin;
      case 'oura':
        return HealthSource.oura;
      case 'whoop':
        return HealthSource.whoop;
      case 'strava':
        return HealthSource.strava;
      case 'myfitnesspal':
        return HealthSource.myFitnessPal;
      case 'unknown':
        return HealthSource.unknown;
      default:
        return HealthSource.unknown;
    }
  }
}
