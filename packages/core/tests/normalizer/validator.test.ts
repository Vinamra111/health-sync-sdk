/**
 * Data Validator Tests
 *
 * Tests for health data validation
 */

import { DataValidator } from '../../src/normalizer/validator';

describe('DataValidator', () => {
  describe('validateSteps', () => {
    it('should accept valid step counts', () => {
      const result = DataValidator.validateSteps(5000);
      expect(result.valid).toBe(true);
      expect(result.errors).toHaveLength(0);
    });

    it('should reject negative step counts', () => {
      const result = DataValidator.validateSteps(-100);
      expect(result.valid).toBe(false);
      expect(result.errors).toContain('Step count cannot be negative');
    });

    it('should warn for unusually high step counts', () => {
      const result = DataValidator.validateSteps(150000);
      expect(result.valid).toBe(true);
      expect(result.warnings).toContain('Step count unusually high (>100,000 steps)');
    });
  });

  describe('validateHeartRate', () => {
    it('should accept valid heart rates', () => {
      expect(DataValidator.validateHeartRate(60).valid).toBe(true);
      expect(DataValidator.validateHeartRate(180).valid).toBe(true);
    });

    it('should reject negative heart rates', () => {
      const result = DataValidator.validateHeartRate(-10);
      expect(result.valid).toBe(false);
    });

    it('should warn for unusually low heart rates', () => {
      const result = DataValidator.validateHeartRate(25);
      expect(result.warnings).toContain('Heart rate unusually low (<30 bpm)');
    });

    it('should reject extremely high heart rates', () => {
      const result = DataValidator.validateHeartRate(260);
      expect(result.valid).toBe(false);
      expect(result.errors).toContain('Heart rate exceeds maximum plausible value (>250 bpm)');
    });
  });

  describe('validateBloodPressure', () => {
    it('should accept valid blood pressure', () => {
      const result = DataValidator.validateBloodPressure(120, 80);
      expect(result.valid).toBe(true);
    });

    it('should reject systolic less than diastolic', () => {
      const result = DataValidator.validateBloodPressure(80, 120);
      expect(result.valid).toBe(false);
      expect(result.errors).toContain('Systolic pressure must be greater than diastolic pressure');
    });

    it('should warn for out of normal range', () => {
      // 210/140 is outside normal range (>200 systolic, >130 diastolic)
      const result = DataValidator.validateBloodPressure(210, 140);
      expect(result.valid).toBe(true);
      expect(result.warnings.length).toBeGreaterThan(0);
    });
  });

  describe('validateBloodOxygen', () => {
    it('should accept valid SpO2 values', () => {
      expect(DataValidator.validateBloodOxygen(98).valid).toBe(true);
    });

    it('should reject values outside 0-100 range', () => {
      expect(DataValidator.validateBloodOxygen(101).valid).toBe(false);
      expect(DataValidator.validateBloodOxygen(-1).valid).toBe(false);
    });

    it('should warn for low oxygen levels', () => {
      const result = DataValidator.validateBloodOxygen(85);
      expect(result.warnings).toContain('Blood oxygen below normal range (<90%)');
    });
  });

  describe('validateWeight', () => {
    it('should accept valid weights', () => {
      expect(DataValidator.validateWeight(70).valid).toBe(true);
    });

    it('should reject zero or negative weights', () => {
      expect(DataValidator.validateWeight(0).valid).toBe(false);
      expect(DataValidator.validateWeight(-5).valid).toBe(false);
    });

    it('should warn for unusual weights', () => {
      expect(DataValidator.validateWeight(15).warnings.length).toBeGreaterThan(0);
      expect(DataValidator.validateWeight(350).warnings.length).toBeGreaterThan(0);
    });
  });

  describe('validateTimestamp', () => {
    it('should accept valid ISO timestamps', () => {
      const result = DataValidator.validateTimestamp('2024-01-01T12:00:00Z');
      expect(result.valid).toBe(true);
    });

    it('should reject invalid timestamp formats', () => {
      const result = DataValidator.validateTimestamp('invalid-date');
      expect(result.valid).toBe(false);
    });

    it('should warn for future timestamps', () => {
      const futureDate = new Date(Date.now() + 86400000).toISOString();
      const result = DataValidator.validateTimestamp(futureDate);
      expect(result.warnings).toContain('Timestamp is in the future');
    });
  });

  describe('validateDateRange', () => {
    it('should accept valid date ranges', () => {
      const result = DataValidator.validateDateRange('2024-01-01', '2024-01-31');
      expect(result.valid).toBe(true);
    });

    it('should reject when end date is before start date', () => {
      const result = DataValidator.validateDateRange('2024-01-31', '2024-01-01');
      expect(result.valid).toBe(false);
      expect(result.errors).toContain('End date must be after start date');
    });
  });

  describe('assertValid', () => {
    it('should not throw for valid result', () => {
      const result = { valid: true, errors: [], warnings: [] };
      expect(() => {
        DataValidator.assertValid(result, 'testField');
      }).not.toThrow();
    });

    it('should throw ValidationError for invalid result', () => {
      const result = {
        valid: false,
        errors: ['Test error'],
        warnings: [],
      };

      expect(() => {
        DataValidator.assertValid(result, 'testField');
      }).toThrow('Validation failed for testField');
    });
  });
});
