/// Enumeration of supported health data types
enum DataType {
  /// Step count data
  steps,

  /// Heart rate measurements (BPM)
  heartRate,

  /// Resting heart rate
  restingHeartRate,

  /// Sleep session data
  sleep,

  /// Physical activity/workout sessions
  activity,

  /// Calories burned
  calories,

  /// Distance traveled
  distance,

  /// Active minutes/energy
  activeMinutes,

  /// Blood oxygen saturation (SpO2)
  bloodOxygen,

  /// Blood pressure measurements
  bloodPressure,

  /// Blood glucose levels
  bloodGlucose,

  /// Body temperature
  bodyTemperature,

  /// Body weight measurements
  weight,

  /// Height measurements
  height,

  /// Body Mass Index
  bmi,

  /// Body fat percentage
  bodyFat,

  /// Hydration/water intake
  hydration,

  /// Nutrition/food intake
  nutrition,

  /// Respiratory rate
  respiratoryRate,

  /// Heart rate variability
  heartRateVariability,

  /// VO2 Max (cardio fitness)
  vo2Max,
}

extension DataTypeExtension on DataType {
  /// Convert to string representation
  String toValue() {
    switch (this) {
      case DataType.steps:
        return 'steps';
      case DataType.heartRate:
        return 'heart_rate';
      case DataType.restingHeartRate:
        return 'resting_heart_rate';
      case DataType.sleep:
        return 'sleep';
      case DataType.activity:
        return 'activity';
      case DataType.calories:
        return 'calories';
      case DataType.distance:
        return 'distance';
      case DataType.activeMinutes:
        return 'active_minutes';
      case DataType.bloodOxygen:
        return 'blood_oxygen';
      case DataType.bloodPressure:
        return 'blood_pressure';
      case DataType.bloodGlucose:
        return 'blood_glucose';
      case DataType.bodyTemperature:
        return 'body_temperature';
      case DataType.weight:
        return 'weight';
      case DataType.height:
        return 'height';
      case DataType.bmi:
        return 'bmi';
      case DataType.bodyFat:
        return 'body_fat';
      case DataType.hydration:
        return 'hydration';
      case DataType.nutrition:
        return 'nutrition';
      case DataType.respiratoryRate:
        return 'respiratory_rate';
      case DataType.heartRateVariability:
        return 'heart_rate_variability';
      case DataType.vo2Max:
        return 'vo2_max';
    }
  }

  /// Create from string value
  static DataType fromValue(String value) {
    switch (value) {
      case 'steps':
        return DataType.steps;
      case 'heart_rate':
        return DataType.heartRate;
      case 'resting_heart_rate':
        return DataType.restingHeartRate;
      case 'sleep':
        return DataType.sleep;
      case 'activity':
        return DataType.activity;
      case 'calories':
        return DataType.calories;
      case 'distance':
        return DataType.distance;
      case 'active_minutes':
        return DataType.activeMinutes;
      case 'blood_oxygen':
        return DataType.bloodOxygen;
      case 'blood_pressure':
        return DataType.bloodPressure;
      case 'blood_glucose':
        return DataType.bloodGlucose;
      case 'body_temperature':
        return DataType.bodyTemperature;
      case 'weight':
        return DataType.weight;
      case 'height':
        return DataType.height;
      case 'bmi':
        return DataType.bmi;
      case 'body_fat':
        return DataType.bodyFat;
      case 'hydration':
        return DataType.hydration;
      case 'nutrition':
        return DataType.nutrition;
      case 'respiratory_rate':
        return DataType.respiratoryRate;
      case 'heart_rate_variability':
        return DataType.heartRateVariability;
      case 'vo2_max':
        return DataType.vo2Max;
      default:
        throw ArgumentError('Unknown DataType: $value');
    }
  }
}
