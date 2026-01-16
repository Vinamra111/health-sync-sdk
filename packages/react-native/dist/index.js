"use strict";
/**
 * @healthsync/react-native
 *
 * React Native Health Connect integration for HealthSync SDK.
 * Provides access to Android Health Connect data through a unified API.
 *
 * @example
 * ```typescript
 * import { HealthConnectPlugin } from '@healthsync/react-native';
 * import { HealthSyncSDK } from '@healthsync/core';
 *
 * // Initialize SDK with Health Connect plugin
 * const sdk = new HealthSyncSDK();
 * const healthConnect = new HealthConnectPlugin();
 *
 * await sdk.registerPlugin(healthConnect);
 * await healthConnect.connect();
 *
 * // Fetch data
 * const data = await healthConnect.fetchData({
 *   dataType: DataType.STEPS,
 *   startDate: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString(),
 *   endDate: new Date().toISOString(),
 * });
 * ```
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.HealthConnectBridge = exports.ErrorAction = exports.ConnectionStatus = exports.HealthSource = exports.DataType = exports.DEFAULT_HEALTH_CONNECT_CONFIG = exports.HEALTH_CONNECT_TYPE_MAP = exports.HealthConnectExerciseType = exports.HealthConnectSleepStage = exports.HealthConnectAvailability = exports.HealthConnectRecordType = exports.HealthConnectPermission = exports.HealthConnectPlugin = void 0;
const health_connect_plugin_1 = require("@healthsync/core/dist/plugins/health-connect/health-connect-plugin");
const HealthConnectBridge_1 = require("./HealthConnectBridge");
/**
 * Health Connect Plugin for React Native
 *
 * This extends the core HealthConnectPlugin and automatically sets up
 * the React Native platform bridge.
 */
class HealthConnectPlugin extends health_connect_plugin_1.HealthConnectPlugin {
    constructor(config = {}) {
        super(config);
        // Automatically set up the React Native bridge
        const bridge = new HealthConnectBridge_1.HealthConnectBridge();
        this.setPlatformBridge(bridge);
    }
}
exports.HealthConnectPlugin = HealthConnectPlugin;
var types_1 = require("@healthsync/core/dist/plugins/health-connect/types");
Object.defineProperty(exports, "HealthConnectPermission", { enumerable: true, get: function () { return types_1.HealthConnectPermission; } });
Object.defineProperty(exports, "HealthConnectRecordType", { enumerable: true, get: function () { return types_1.HealthConnectRecordType; } });
Object.defineProperty(exports, "HealthConnectAvailability", { enumerable: true, get: function () { return types_1.HealthConnectAvailability; } });
Object.defineProperty(exports, "HealthConnectSleepStage", { enumerable: true, get: function () { return types_1.HealthConnectSleepStage; } });
Object.defineProperty(exports, "HealthConnectExerciseType", { enumerable: true, get: function () { return types_1.HealthConnectExerciseType; } });
Object.defineProperty(exports, "HEALTH_CONNECT_TYPE_MAP", { enumerable: true, get: function () { return types_1.HEALTH_CONNECT_TYPE_MAP; } });
Object.defineProperty(exports, "DEFAULT_HEALTH_CONNECT_CONFIG", { enumerable: true, get: function () { return types_1.DEFAULT_HEALTH_CONNECT_CONFIG; } });
// Re-export core SDK types
var unified_data_1 = require("@healthsync/core/dist/models/unified-data");
Object.defineProperty(exports, "DataType", { enumerable: true, get: function () { return unified_data_1.DataType; } });
Object.defineProperty(exports, "HealthSource", { enumerable: true, get: function () { return unified_data_1.HealthSource; } });
var plugin_interface_1 = require("@healthsync/core/dist/plugins/plugin-interface");
Object.defineProperty(exports, "ConnectionStatus", { enumerable: true, get: function () { return plugin_interface_1.ConnectionStatus; } });
Object.defineProperty(exports, "ErrorAction", { enumerable: true, get: function () { return plugin_interface_1.ErrorAction; } });
// Export the bridge for advanced usage
var HealthConnectBridge_2 = require("./HealthConnectBridge");
Object.defineProperty(exports, "HealthConnectBridge", { enumerable: true, get: function () { return HealthConnectBridge_2.HealthConnectBridge; } });
