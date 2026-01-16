"use strict";
/**
 * React Native Health Connect Bridge
 *
 * TypeScript bindings for the native Health Connect module.
 * Implements the HealthConnectBridge interface from @healthsync/core.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.HealthConnectBridge = void 0;
const react_native_1 = require("react-native");
const types_1 = require("@healthsync/core/dist/plugins/health-connect/types");
const LINKING_ERROR = `The package '@healthsync/react-native' doesn't seem to be linked. Make sure: \n\n` +
    react_native_1.Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
    '- You rebuilt the app after installing the package\n' +
    '- You are not using Expo Go\n';
const HealthConnectModule = react_native_1.NativeModules.HealthConnectModule
    ? react_native_1.NativeModules.HealthConnectModule
    : new Proxy({}, {
        get() {
            throw new Error(LINKING_ERROR);
        },
    });
/**
 * React Native implementation of Health Connect Bridge
 *
 * This class bridges TypeScript code to the native Android Health Connect module.
 */
class HealthConnectBridge {
    /**
     * Check Health Connect availability
     */
    async checkAvailability() {
        if (react_native_1.Platform.OS !== 'android') {
            return types_1.HealthConnectAvailability.NOT_SUPPORTED;
        }
        try {
            const result = await HealthConnectModule.checkAvailability();
            switch (result) {
                case 'installed':
                    return types_1.HealthConnectAvailability.INSTALLED;
                case 'not_installed':
                    return types_1.HealthConnectAvailability.NOT_INSTALLED;
                default:
                    return types_1.HealthConnectAvailability.NOT_SUPPORTED;
            }
        }
        catch (error) {
            console.error('[HealthConnect] Failed to check availability:', error);
            return types_1.HealthConnectAvailability.NOT_SUPPORTED;
        }
    }
    /**
     * Check permissions
     */
    async checkPermissions(permissions) {
        if (react_native_1.Platform.OS !== 'android') {
            return permissions.map(p => ({
                permission: p,
                granted: false,
                checkedAt: new Date().toISOString(),
            }));
        }
        try {
            const result = await HealthConnectModule.checkPermissions(permissions);
            return result.map(item => ({
                permission: item.permission,
                granted: item.granted,
                checkedAt: item.checkedAt,
            }));
        }
        catch (error) {
            console.error('[HealthConnect] Failed to check permissions:', error);
            throw error;
        }
    }
    /**
     * Request permissions
     *
     * IMPORTANT: MainActivity must extend ReactFragmentActivity for this to work.
     */
    async requestPermissions(permissions) {
        if (react_native_1.Platform.OS !== 'android') {
            console.warn('[HealthConnect] Permissions only available on Android');
            return [];
        }
        try {
            const granted = await HealthConnectModule.requestPermissions(permissions);
            return granted;
        }
        catch (error) {
            console.error('[HealthConnect] Failed to request permissions:', error);
            throw error;
        }
    }
    /**
     * Read records from Health Connect
     *
     * CRITICAL: Dates are converted to UTC ISO 8601 format with 'Z' suffix
     * This matches the fix we implemented in Flutter (v2.1)
     */
    async readRecords(request) {
        if (react_native_1.Platform.OS !== 'android') {
            console.warn('[HealthConnect] Read records only available on Android');
            return [];
        }
        try {
            // CRITICAL: Convert to UTC and use toISOString() to ensure 'Z' suffix
            // JavaScript Date.toISOString() always returns UTC with 'Z' suffix
            // Example: "2025-12-31T15:53:13.406Z" (WITH timezone)
            // This matches our Flutter v2.1 fix: .toUtc().toIso8601String()
            const requestData = {
                recordType: request.recordType,
                startTime: request.startTime.toISOString(), // Always includes 'Z' for UTC
                endTime: request.endTime.toISOString(), // Always includes 'Z' for UTC
                ...(request.limit !== undefined && { limit: request.limit }),
                ...(request.offset !== undefined && { offset: request.offset }),
            };
            const records = await HealthConnectModule.readRecords(requestData);
            return records;
        }
        catch (error) {
            console.error('[HealthConnect] Failed to read records:', error);
            throw error;
        }
    }
}
exports.HealthConnectBridge = HealthConnectBridge;
