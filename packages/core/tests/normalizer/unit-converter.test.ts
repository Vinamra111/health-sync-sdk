/**
 * Unit Converter Tests
 *
 * Tests for health data unit conversions
 */

import { UnitConverter } from '../../src/normalizer/unit-converter';

describe('UnitConverter', () => {
  describe('Distance Conversions', () => {
    it('should convert meters to kilometers', () => {
      expect(UnitConverter.metersToKm(1000)).toBe(1);
      expect(UnitConverter.metersToKm(5000)).toBe(5);
      expect(UnitConverter.metersToKm(0)).toBe(0);
    });

    it('should convert kilometers to meters', () => {
      expect(UnitConverter.kmToMeters(1)).toBe(1000);
      expect(UnitConverter.kmToMeters(5)).toBe(5000);
      expect(UnitConverter.kmToMeters(0)).toBe(0);
    });

    it('should convert meters to miles', () => {
      expect(UnitConverter.metersToMiles(1609.34)).toBeCloseTo(1, 2);
      expect(UnitConverter.metersToMiles(8046.72)).toBeCloseTo(5, 2);
    });

    it('should convert miles to meters', () => {
      expect(UnitConverter.milesToMeters(1)).toBeCloseTo(1609.34, 0);
      expect(UnitConverter.milesToMeters(5)).toBeCloseTo(8046.72, 0);
    });

    it('should convert meters to feet', () => {
      expect(UnitConverter.metersToFeet(1)).toBeCloseTo(3.28084, 2);
      expect(UnitConverter.metersToFeet(10)).toBeCloseTo(32.8084, 2);
    });

    it('should convert feet to meters', () => {
      expect(UnitConverter.feetToMeters(1)).toBeCloseTo(0.3048, 3);
      expect(UnitConverter.feetToMeters(10)).toBeCloseTo(3.048, 2);
    });

    it('should handle roundtrip conversions for distance', () => {
      const original = 1000;

      // Meters -> Km -> Meters
      expect(UnitConverter.kmToMeters(UnitConverter.metersToKm(original))).toBe(original);

      // Meters -> Miles -> Meters
      const miles = UnitConverter.metersToMiles(original);
      expect(UnitConverter.milesToMeters(miles)).toBeCloseTo(original, 0);

      // Meters -> Feet -> Meters
      const feet = UnitConverter.metersToFeet(original);
      expect(UnitConverter.feetToMeters(feet)).toBeCloseTo(original, 0);
    });
  });

  describe('Weight Conversions', () => {
    it('should convert kilograms to pounds', () => {
      expect(UnitConverter.kgToPounds(1)).toBeCloseTo(2.20462, 2);
      expect(UnitConverter.kgToPounds(70)).toBeCloseTo(154.324, 2);
      expect(UnitConverter.kgToPounds(0)).toBe(0);
    });

    it('should convert pounds to kilograms', () => {
      expect(UnitConverter.poundsToKg(1)).toBeCloseTo(0.453592, 3);
      expect(UnitConverter.poundsToKg(154.324)).toBeCloseTo(70, 1);
      expect(UnitConverter.poundsToKg(0)).toBe(0);
    });

    it('should handle roundtrip conversions for weight', () => {
      const original = 70;

      // Kg -> Pounds -> Kg
      const pounds = UnitConverter.kgToPounds(original);
      expect(UnitConverter.poundsToKg(pounds)).toBeCloseTo(original, 2);
    });
  });

  describe('Temperature Conversions', () => {
    it('should convert Celsius to Fahrenheit', () => {
      expect(UnitConverter.celsiusToFahrenheit(0)).toBe(32);
      expect(UnitConverter.celsiusToFahrenheit(100)).toBe(212);
      expect(UnitConverter.celsiusToFahrenheit(37)).toBeCloseTo(98.6, 1);
      expect(UnitConverter.celsiusToFahrenheit(-40)).toBe(-40);
    });

    it('should convert Fahrenheit to Celsius', () => {
      expect(UnitConverter.fahrenheitToCelsius(32)).toBe(0);
      expect(UnitConverter.fahrenheitToCelsius(212)).toBe(100);
      expect(UnitConverter.fahrenheitToCelsius(98.6)).toBeCloseTo(37, 1);
      expect(UnitConverter.fahrenheitToCelsius(-40)).toBe(-40);
    });

    it('should handle roundtrip conversions for temperature', () => {
      const original = 37;

      // Celsius -> Fahrenheit -> Celsius
      const fahrenheit = UnitConverter.celsiusToFahrenheit(original);
      expect(UnitConverter.fahrenheitToCelsius(fahrenheit)).toBeCloseTo(original, 2);
    });
  });


  describe('Edge Cases', () => {
    it('should handle negative values appropriately', () => {
      // Temperature can be negative
      expect(UnitConverter.celsiusToFahrenheit(-10)).toBeCloseTo(14, 1);
      expect(UnitConverter.fahrenheitToCelsius(14)).toBeCloseTo(-10, 1);
    });

    it('should handle very small values', () => {
      expect(UnitConverter.metersToKm(1)).toBe(0.001);
      expect(UnitConverter.kgToPounds(0.1)).toBeCloseTo(0.220462, 3);
    });

    it('should handle very large values', () => {
      expect(UnitConverter.metersToKm(1000000)).toBe(1000);
      expect(UnitConverter.kgToPounds(1000)).toBeCloseTo(2204.62, 1);
    });

    it('should maintain precision for common health values', () => {
      // Body weight
      const weight = 70.5; // kg
      const weightLbs = UnitConverter.kgToPounds(weight);
      expect(weightLbs).toBeCloseTo(155.426, 2);

      // Running distance
      const distance = 5000; // meters
      const distanceMiles = UnitConverter.metersToMiles(distance);
      expect(distanceMiles).toBeCloseTo(3.107, 2);

      // Body temperature
      const temp = 37.5; // Celsius
      const tempF = UnitConverter.celsiusToFahrenheit(temp);
      expect(tempF).toBeCloseTo(99.5, 1);
    });
  });
});
