/**
 * Unit Converter
 *
 * Provides utilities for converting between different measurement units
 * commonly used in health data (metric ↔ imperial, etc.).
 *
 * @module normalizer/unit-converter
 */

/**
 * Temperature unit types
 */
export type TemperatureUnit = 'celsius' | 'fahrenheit' | 'kelvin';

/**
 * Distance unit types
 */
export type DistanceUnit = 'meters' | 'kilometers' | 'feet' | 'miles' | 'yards';

/**
 * Weight unit types
 */
export type WeightUnit = 'kilograms' | 'pounds' | 'ounces' | 'grams';

/**
 * Unit Converter
 *
 * Handles conversions between different measurement systems.
 *
 * @class UnitConverter
 */
export class UnitConverter {
  // ============================================================================
  // Weight Conversions
  // ============================================================================

  /**
   * Convert kilograms to pounds
   *
   * @param {number} kg - Weight in kilograms
   * @returns {number} Weight in pounds
   */
  static kgToPounds(kg: number): number {
    return kg * 2.20462262185;
  }

  /**
   * Convert pounds to kilograms
   *
   * @param {number} pounds - Weight in pounds
   * @returns {number} Weight in kilograms
   */
  static poundsToKg(pounds: number): number {
    return pounds / 2.20462262185;
  }

  /**
   * Convert grams to kilograms
   *
   * @param {number} grams - Weight in grams
   * @returns {number} Weight in kilograms
   */
  static gramsToKg(grams: number): number {
    return grams / 1000;
  }

  /**
   * Convert kilograms to grams
   *
   * @param {number} kg - Weight in kilograms
   * @returns {number} Weight in grams
   */
  static kgToGrams(kg: number): number {
    return kg * 1000;
  }

  /**
   * Convert ounces to kilograms
   *
   * @param {number} ounces - Weight in ounces
   * @returns {number} Weight in kilograms
   */
  static ouncesToKg(ounces: number): number {
    return ounces * 0.0283495231;
  }

  /**
   * Convert weight to kilograms from any unit
   *
   * @param {number} value - Weight value
   * @param {WeightUnit} unit - Source unit
   * @returns {number} Weight in kilograms
   */
  static toKilograms(value: number, unit: WeightUnit): number {
    switch (unit) {
      case 'kilograms':
        return value;
      case 'pounds':
        return this.poundsToKg(value);
      case 'grams':
        return this.gramsToKg(value);
      case 'ounces':
        return this.ouncesToKg(value);
      default:
        return value;
    }
  }

  // ============================================================================
  // Distance Conversions
  // ============================================================================

  /**
   * Convert meters to kilometers
   *
   * @param {number} meters - Distance in meters
   * @returns {number} Distance in kilometers
   */
  static metersToKm(meters: number): number {
    return meters / 1000;
  }

  /**
   * Convert kilometers to meters
   *
   * @param {number} km - Distance in kilometers
   * @returns {number} Distance in meters
   */
  static kmToMeters(km: number): number {
    return km * 1000;
  }

  /**
   * Convert meters to miles
   *
   * @param {number} meters - Distance in meters
   * @returns {number} Distance in miles
   */
  static metersToMiles(meters: number): number {
    return meters * 0.000621371192;
  }

  /**
   * Convert miles to meters
   *
   * @param {number} miles - Distance in miles
   * @returns {number} Distance in meters
   */
  static milesToMeters(miles: number): number {
    return miles / 0.000621371192;
  }

  /**
   * Convert meters to feet
   *
   * @param {number} meters - Distance in meters
   * @returns {number} Distance in feet
   */
  static metersToFeet(meters: number): number {
    return meters * 3.2808399;
  }

  /**
   * Convert feet to meters
   *
   * @param {number} feet - Distance in feet
   * @returns {number} Distance in meters
   */
  static feetToMeters(feet: number): number {
    return feet / 3.2808399;
  }

  /**
   * Convert yards to meters
   *
   * @param {number} yards - Distance in yards
   * @returns {number} Distance in meters
   */
  static yardsToMeters(yards: number): number {
    return yards * 0.9144;
  }

  /**
   * Convert distance to meters from any unit
   *
   * @param {number} value - Distance value
   * @param {DistanceUnit} unit - Source unit
   * @returns {number} Distance in meters
   */
  static toMeters(value: number, unit: DistanceUnit): number {
    switch (unit) {
      case 'meters':
        return value;
      case 'kilometers':
        return this.kmToMeters(value);
      case 'miles':
        return this.milesToMeters(value);
      case 'feet':
        return this.feetToMeters(value);
      case 'yards':
        return this.yardsToMeters(value);
      default:
        return value;
    }
  }

  // ============================================================================
  // Temperature Conversions
  // ============================================================================

  /**
   * Convert Celsius to Fahrenheit
   *
   * @param {number} celsius - Temperature in Celsius
   * @returns {number} Temperature in Fahrenheit
   */
  static celsiusToFahrenheit(celsius: number): number {
    return (celsius * 9) / 5 + 32;
  }

  /**
   * Convert Fahrenheit to Celsius
   *
   * @param {number} fahrenheit - Temperature in Fahrenheit
   * @returns {number} Temperature in Celsius
   */
  static fahrenheitToCelsius(fahrenheit: number): number {
    return ((fahrenheit - 32) * 5) / 9;
  }

  /**
   * Convert Celsius to Kelvin
   *
   * @param {number} celsius - Temperature in Celsius
   * @returns {number} Temperature in Kelvin
   */
  static celsiusToKelvin(celsius: number): number {
    return celsius + 273.15;
  }

  /**
   * Convert Kelvin to Celsius
   *
   * @param {number} kelvin - Temperature in Kelvin
   * @returns {number} Temperature in Celsius
   */
  static kelvinToCelsius(kelvin: number): number {
    return kelvin - 273.15;
  }

  /**
   * Convert temperature to Celsius from any unit
   *
   * @param {number} value - Temperature value
   * @param {TemperatureUnit} unit - Source unit
   * @returns {number} Temperature in Celsius
   */
  static toCelsius(value: number, unit: TemperatureUnit): number {
    switch (unit) {
      case 'celsius':
        return value;
      case 'fahrenheit':
        return this.fahrenheitToCelsius(value);
      case 'kelvin':
        return this.kelvinToCelsius(value);
      default:
        return value;
    }
  }

  // ============================================================================
  // Time Conversions
  // ============================================================================

  /**
   * Convert hours to minutes
   *
   * @param {number} hours - Time in hours
   * @returns {number} Time in minutes
   */
  static hoursToMinutes(hours: number): number {
    return hours * 60;
  }

  /**
   * Convert minutes to hours
   *
   * @param {number} minutes - Time in minutes
   * @returns {number} Time in hours
   */
  static minutesToHours(minutes: number): number {
    return minutes / 60;
  }

  /**
   * Convert seconds to minutes
   *
   * @param {number} seconds - Time in seconds
   * @returns {number} Time in minutes
   */
  static secondsToMinutes(seconds: number): number {
    return seconds / 60;
  }

  /**
   * Convert minutes to seconds
   *
   * @param {number} minutes - Time in minutes
   * @returns {number} Time in seconds
   */
  static minutesToSeconds(minutes: number): number {
    return minutes * 60;
  }

  /**
   * Convert milliseconds to minutes
   *
   * @param {number} milliseconds - Time in milliseconds
   * @returns {number} Time in minutes
   */
  static millisecondsToMinutes(milliseconds: number): number {
    return milliseconds / 60000;
  }

  /**
   * Convert minutes to milliseconds
   *
   * @param {number} minutes - Time in minutes
   * @returns {number} Time in milliseconds
   */
  static minutesToMilliseconds(minutes: number): number {
    return minutes * 60000;
  }

  // ============================================================================
  // Pace Conversions (for running/walking)
  // ============================================================================

  /**
   * Convert pace from minutes per kilometer to minutes per mile
   *
   * @param {number} minPerKm - Pace in minutes per kilometer
   * @returns {number} Pace in minutes per mile
   */
  static paceKmToMile(minPerKm: number): number {
    return minPerKm * 1.60934;
  }

  /**
   * Convert pace from minutes per mile to minutes per kilometer
   *
   * @param {number} minPerMile - Pace in minutes per mile
   * @returns {number} Pace in minutes per kilometer
   */
  static paceMileToKm(minPerMile: number): number {
    return minPerMile / 1.60934;
  }

  // ============================================================================
  // Energy Conversions
  // ============================================================================

  /**
   * Convert kilojoules to kilocalories (calories)
   *
   * @param {number} kj - Energy in kilojoules
   * @returns {number} Energy in kilocalories
   */
  static kjToKcal(kj: number): number {
    return kj / 4.184;
  }

  /**
   * Convert kilocalories to kilojoules
   *
   * @param {number} kcal - Energy in kilocalories
   * @returns {number} Energy in kilojoules
   */
  static kcalToKj(kcal: number): number {
    return kcal * 4.184;
  }

  // ============================================================================
  // Utility Functions
  // ============================================================================

  /**
   * Round a number to specified decimal places
   *
   * @param {number} value - Value to round
   * @param {number} [decimals=2] - Number of decimal places
   * @returns {number} Rounded value
   */
  static round(value: number, decimals: number = 2): number {
    const multiplier = Math.pow(10, decimals);
    return Math.round(value * multiplier) / multiplier;
  }

  /**
   * Clamp a value between min and max
   *
   * @param {number} value - Value to clamp
   * @param {number} min - Minimum value
   * @param {number} max - Maximum value
   * @returns {number} Clamped value
   */
  static clamp(value: number, min: number, max: number): number {
    return Math.min(Math.max(value, min), max);
  }
}
