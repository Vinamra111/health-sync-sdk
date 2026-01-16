# Health Connect Native Bridge Implementation Guide

This guide explains how to implement the native platform bridge for the Health Connect plugin, enabling your application to access Android Health Connect data.

## Table of Contents

- [Overview](#overview)
- [Bridge Interface](#bridge-interface)
- [Android Implementation](#android-implementation)
- [React Native Integration](#react-native-integration)
- [TypeScript Integration](#typescript-integration)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)

## Overview

The Health Connect plugin uses a **platform bridge pattern** to separate cross-platform TypeScript code from platform-specific native code. This allows the plugin to work across different frameworks (React Native, Capacitor, etc.) while maintaining a consistent API.

### Architecture

```
┌─────────────────────────────────────┐
│   TypeScript Application Code      │
└─────────────────┬───────────────────┘
                  │
┌─────────────────▼───────────────────┐
│   HealthConnectPlugin (TypeScript)  │
│   - Connection management           │
│   - Data query logic                │
│   - Permission flow                 │
└─────────────────┬───────────────────┘
                  │ HealthConnectBridge
┌─────────────────▼───────────────────┐
│   Native Bridge Implementation      │
│   - Android Health Connect API      │
│   - Native permission dialogs       │
│   - Data reading/writing            │
└─────────────────────────────────────┘
```

## Bridge Interface

The `HealthConnectBridge` interface defines four methods that must be implemented:

```typescript
interface HealthConnectBridge {
  /**
   * Check if Health Connect is available on this device
   */
  checkAvailability(): Promise<HealthConnectAvailability>;

  /**
   * Check status of requested permissions
   */
  checkPermissions(
    permissions: HealthConnectPermission[]
  ): Promise<PermissionStatus[]>;

  /**
   * Request permissions from the user
   * Returns array of granted permissions
   */
  requestPermissions(
    permissions: HealthConnectPermission[]
  ): Promise<HealthConnectPermission[]>;

  /**
   * Read health records from Health Connect
   */
  readRecords(
    request: ReadRecordsRequest
  ): Promise<HealthConnectRecord[]>;
}
```

### Method Details

#### `checkAvailability()`

**Purpose:** Determine if Health Connect is installed and usable on the device.

**Returns:**
- `'installed'` - Health Connect is available
- `'not_installed'` - Health Connect app needs to be installed
- `'not_supported'` - Device doesn't support Health Connect (Android < 14 without backport)

**Implementation Notes:**
- Check Android SDK version (Health Connect available on Android 14+)
- Check if Health Connect backport app is installed (for Android 13)
- Return appropriate status

---

#### `checkPermissions(permissions)`

**Purpose:** Check which permissions are currently granted.

**Parameters:**
- `permissions`: Array of permission strings to check (e.g., `['android.permission.health.READ_STEPS']`)

**Returns:** Array of `PermissionStatus` objects:
```typescript
{
  permission: string;
  granted: boolean;
  checkedAt: string; // ISO 8601 timestamp
}
```

**Implementation Notes:**
- Use Health Connect's permission checking API
- Return current status for each requested permission
- Include timestamp when check was performed

---

#### `requestPermissions(permissions)`

**Purpose:** Show native permission dialog and request permissions from user.

**Parameters:**
- `permissions`: Array of permission strings to request

**Returns:** Array of permission strings that were **granted**

**Implementation Notes:**
- Launch Health Connect permission activity
- Wait for user response
- Only return permissions that were actually granted
- May return empty array if user denies all permissions

---

#### `readRecords(request)`

**Purpose:** Read health data records from Health Connect.

**Parameters:**
```typescript
{
  recordType: string;     // e.g., "Steps", "HeartRate"
  startTime: Date;        // Start of time range
  endTime: Date;          // End of time range
  limit?: number;         // Max records to return
  offset?: number;        // Pagination offset
}
```

**Returns:** Array of `HealthConnectRecord` objects with record data

**Implementation Notes:**
- Query Health Connect using the ReadRecordsRequest API
- Convert native record objects to JavaScript objects
- Handle pagination with limit/offset
- Map record fields to expected structure
- Return empty array if no records found

## Android Implementation

### Prerequisites

1. **Minimum SDK Version:** Android 14 (API level 34) or Android 13 with Health Connect backport
2. **Dependencies:** Add to your `build.gradle`:

```gradle
dependencies {
    // Health Connect SDK
    implementation "androidx.health.connect:connect-client:1.1.0-alpha07"

    // Kotlin coroutines (if not already included)
    implementation "org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3"
}
```

3. **Permissions:** Add to `AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Health Connect permissions -->
    <uses-permission android:name="android.permission.health.READ_STEPS"/>
    <uses-permission android:name="android.permission.health.READ_HEART_RATE"/>
    <uses-permission android:name="android.permission.health.READ_SLEEP"/>
    <uses-permission android:name="android.permission.health.READ_DISTANCE"/>
    <uses-permission android:name="android.permission.health.READ_EXERCISE"/>
    <uses-permission android:name="android.permission.health.READ_TOTAL_CALORIES_BURNED"/>
    <uses-permission android:name="android.permission.health.READ_ACTIVE_CALORIES_BURNED"/>
    <uses-permission android:name="android.permission.health.READ_OXYGEN_SATURATION"/>
    <uses-permission android:name="android.permission.health.READ_BLOOD_PRESSURE"/>
    <uses-permission android:name="android.permission.health.READ_BODY_TEMPERATURE"/>
    <uses-permission android:name="android.permission.health.READ_WEIGHT"/>
    <uses-permission android:name="android.permission.health.READ_HEIGHT"/>
    <uses-permission android:name="android.permission.health.READ_HEART_RATE_VARIABILITY"/>

    <application>
        <!-- Health Connect intent filter -->
        <activity-alias
            android:name="ViewHealthDataActivity"
            android:exported="true"
            android:targetActivity=".MainActivity"
            android:permission="android.permission.START_VIEW_PERMISSION_USAGE">
            <intent-filter>
                <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />
            </intent-filter>
        </activity-alias>
    </application>
</manifest>
```

### Kotlin Implementation

Create a file `HealthConnectBridgeImpl.kt`:

```kotlin
package com.yourapp.healthsync

import android.content.Context
import android.os.Build
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.*
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant

class HealthConnectBridgeImpl(private val context: Context) {

    private var healthConnectClient: HealthConnectClient? = null

    init {
        // Initialize Health Connect client if available
        if (HealthConnectClient.getSdkStatus(context) == HealthConnectClient.SDK_AVAILABLE) {
            healthConnectClient = HealthConnectClient.getOrCreate(context)
        }
    }

    /**
     * Check Health Connect availability
     */
    suspend fun checkAvailability(): String = withContext(Dispatchers.IO) {
        when (HealthConnectClient.getSdkStatus(context)) {
            HealthConnectClient.SDK_AVAILABLE -> "installed"
            HealthConnectClient.SDK_UNAVAILABLE -> "not_installed"
            HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> "not_installed"
            else -> "not_supported"
        }
    }

    /**
     * Check permission status
     */
    suspend fun checkPermissions(permissions: List<String>): JSONArray = withContext(Dispatchers.IO) {
        val client = healthConnectClient ?: return@withContext JSONArray()

        val healthPermissions = permissions.map { HealthPermission.createReadPermission(it) }.toSet()
        val grantedPermissions = client.permissionController.getGrantedPermissions()

        val result = JSONArray()
        permissions.forEach { permission ->
            val healthPerm = HealthPermission.createReadPermission(permission)
            result.put(JSONObject().apply {
                put("permission", permission)
                put("granted", grantedPermissions.contains(healthPerm))
                put("checkedAt", Instant.now().toString())
            })
        }

        result
    }

    /**
     * Request permissions from user
     * Note: This requires launching an Activity - see integration example
     */
    suspend fun getPermissionsToRequest(permissions: List<String>): Set<String> = withContext(Dispatchers.IO) {
        val client = healthConnectClient ?: return@withContext emptySet()

        val healthPermissions = permissions.map { HealthPermission.createReadPermission(it) }.toSet()
        val grantedPermissions = client.permissionController.getGrantedPermissions()

        healthPermissions
            .filter { !grantedPermissions.contains(it) }
            .map { it.permissionType }
            .toSet()
    }

    /**
     * Read health records
     */
    suspend fun readRecords(request: JSONObject): JSONArray = withContext(Dispatchers.IO) {
        val client = healthConnectClient ?: return@withContext JSONArray()

        val recordType = request.getString("recordType")
        val startTime = Instant.parse(request.getString("startTime"))
        val endTime = Instant.parse(request.getString("endTime"))
        val limit = if (request.has("limit")) request.getInt("limit") else 1000

        val timeRangeFilter = TimeRangeFilter.between(startTime, endTime)

        val records = when (recordType) {
            "Steps" -> readStepsRecords(client, timeRangeFilter, limit)
            "HeartRate" -> readHeartRateRecords(client, timeRangeFilter, limit)
            "SleepSession" -> readSleepRecords(client, timeRangeFilter, limit)
            "Distance" -> readDistanceRecords(client, timeRangeFilter, limit)
            "ExerciseSession" -> readExerciseRecords(client, timeRangeFilter, limit)
            "TotalCaloriesBurned" -> readCaloriesRecords(client, timeRangeFilter, limit)
            "OxygenSaturation" -> readOxygenSaturationRecords(client, timeRangeFilter, limit)
            "BloodPressure" -> readBloodPressureRecords(client, timeRangeFilter, limit)
            "BodyTemperature" -> readBodyTemperatureRecords(client, timeRangeFilter, limit)
            "Weight" -> readWeightRecords(client, timeRangeFilter, limit)
            "Height" -> readHeightRecords(client, timeRangeFilter, limit)
            "HeartRateVariabilityRmssd" -> readHRVRecords(client, timeRangeFilter, limit)
            else -> JSONArray()
        }

        records
    }

    // Record-specific reading methods

    private suspend fun readStepsRecords(
        client: HealthConnectClient,
        timeRange: TimeRangeFilter,
        limit: Int
    ): JSONArray {
        val request = ReadRecordsRequest(
            recordType = StepsRecord::class,
            timeRangeFilter = timeRange,
            pageSize = limit
        )

        val response = client.readRecords(request)
        val result = JSONArray()

        response.records.forEach { record ->
            result.put(JSONObject().apply {
                put("id", record.metadata.id)
                put("startTime", record.startTime.toString())
                put("endTime", record.endTime.toString())
                put("count", record.count)
            })
        }

        return result
    }

    private suspend fun readHeartRateRecords(
        client: HealthConnectClient,
        timeRange: TimeRangeFilter,
        limit: Int
    ): JSONArray {
        val request = ReadRecordsRequest(
            recordType = HeartRateRecord::class,
            timeRangeFilter = timeRange,
            pageSize = limit
        )

        val response = client.readRecords(request)
        val result = JSONArray()

        response.records.forEach { record ->
            record.samples.forEach { sample ->
                result.put(JSONObject().apply {
                    put("id", record.metadata.id)
                    put("time", sample.time.toString())
                    put("bpm", sample.beatsPerMinute)
                })
            }
        }

        return result
    }

    private suspend fun readSleepRecords(
        client: HealthConnectClient,
        timeRange: TimeRangeFilter,
        limit: Int
    ): JSONArray {
        val request = ReadRecordsRequest(
            recordType = SleepSessionRecord::class,
            timeRangeFilter = timeRange,
            pageSize = limit
        )

        val response = client.readRecords(request)
        val result = JSONArray()

        response.records.forEach { record ->
            result.put(JSONObject().apply {
                put("id", record.metadata.id)
                put("startTime", record.startTime.toString())
                put("endTime", record.endTime.toString())
                put("title", record.title ?: "")
                put("notes", record.notes ?: "")

                // Add sleep stages
                val stages = JSONArray()
                record.stages.forEach { stage ->
                    stages.put(JSONObject().apply {
                        put("stage", stage.stage)
                        put("startTime", stage.startTime.toString())
                        put("endTime", stage.endTime.toString())
                    })
                }
                put("stages", stages)
            })
        }

        return result
    }

    private suspend fun readDistanceRecords(
        client: HealthConnectClient,
        timeRange: TimeRangeFilter,
        limit: Int
    ): JSONArray {
        val request = ReadRecordsRequest(
            recordType = DistanceRecord::class,
            timeRangeFilter = timeRange,
            pageSize = limit
        )

        val response = client.readRecords(request)
        val result = JSONArray()

        response.records.forEach { record ->
            result.put(JSONObject().apply {
                put("id", record.metadata.id)
                put("startTime", record.startTime.toString())
                put("endTime", record.endTime.toString())
                put("distance", record.distance.inMeters)
            })
        }

        return result
    }

    private suspend fun readExerciseRecords(
        client: HealthConnectClient,
        timeRange: TimeRangeFilter,
        limit: Int
    ): JSONArray {
        val request = ReadRecordsRequest(
            recordType = ExerciseSessionRecord::class,
            timeRangeFilter = timeRange,
            pageSize = limit
        )

        val response = client.readRecords(request)
        val result = JSONArray()

        response.records.forEach { record ->
            result.put(JSONObject().apply {
                put("id", record.metadata.id)
                put("startTime", record.startTime.toString())
                put("endTime", record.endTime.toString())
                put("exerciseType", record.exerciseType)
                put("title", record.title ?: "")
            })
        }

        return result
    }

    private suspend fun readCaloriesRecords(
        client: HealthConnectClient,
        timeRange: TimeRangeFilter,
        limit: Int
    ): JSONArray {
        val request = ReadRecordsRequest(
            recordType = TotalCaloriesBurnedRecord::class,
            timeRangeFilter = timeRange,
            pageSize = limit
        )

        val response = client.readRecords(request)
        val result = JSONArray()

        response.records.forEach { record ->
            result.put(JSONObject().apply {
                put("id", record.metadata.id)
                put("startTime", record.startTime.toString())
                put("endTime", record.endTime.toString())
                put("energy", record.energy.inKilocalories)
            })
        }

        return result
    }

    private suspend fun readOxygenSaturationRecords(
        client: HealthConnectClient,
        timeRange: TimeRangeFilter,
        limit: Int
    ): JSONArray {
        val request = ReadRecordsRequest(
            recordType = OxygenSaturationRecord::class,
            timeRangeFilter = timeRange,
            pageSize = limit
        )

        val response = client.readRecords(request)
        val result = JSONArray()

        response.records.forEach { record ->
            result.put(JSONObject().apply {
                put("id", record.metadata.id)
                put("time", record.time.toString())
                put("percentage", record.percentage.value)
            })
        }

        return result
    }

    private suspend fun readBloodPressureRecords(
        client: HealthConnectClient,
        timeRange: TimeRangeFilter,
        limit: Int
    ): JSONArray {
        val request = ReadRecordsRequest(
            recordType = BloodPressureRecord::class,
            timeRangeFilter = timeRange,
            pageSize = limit
        )

        val response = client.readRecords(request)
        val result = JSONArray()

        response.records.forEach { record ->
            result.put(JSONObject().apply {
                put("id", record.metadata.id)
                put("time", record.time.toString())
                put("systolic", record.systolic.inMillimetersOfMercury)
                put("diastolic", record.diastolic.inMillimetersOfMercury)
            })
        }

        return result
    }

    private suspend fun readBodyTemperatureRecords(
        client: HealthConnectClient,
        timeRange: TimeRangeFilter,
        limit: Int
    ): JSONArray {
        val request = ReadRecordsRequest(
            recordType = BodyTemperatureRecord::class,
            timeRangeFilter = timeRange,
            pageSize = limit
        )

        val response = client.readRecords(request)
        val result = JSONArray()

        response.records.forEach { record ->
            result.put(JSONObject().apply {
                put("id", record.metadata.id)
                put("time", record.time.toString())
                put("temperature", record.temperature.inCelsius)
            })
        }

        return result
    }

    private suspend fun readWeightRecords(
        client: HealthConnectClient,
        timeRange: TimeRangeFilter,
        limit: Int
    ): JSONArray {
        val request = ReadRecordsRequest(
            recordType = WeightRecord::class,
            timeRangeFilter = timeRange,
            pageSize = limit
        )

        val response = client.readRecords(request)
        val result = JSONArray()

        response.records.forEach { record ->
            result.put(JSONObject().apply {
                put("id", record.metadata.id)
                put("time", record.time.toString())
                put("weight", record.weight.inKilograms)
            })
        }

        return result
    }

    private suspend fun readHeightRecords(
        client: HealthConnectClient,
        timeRange: TimeRangeFilter,
        limit: Int
    ): JSONArray {
        val request = ReadRecordsRequest(
            recordType = HeightRecord::class,
            timeRangeFilter = timeRange,
            pageSize = limit
        )

        val response = client.readRecords(request)
        val result = JSONArray()

        response.records.forEach { record ->
            result.put(JSONObject().apply {
                put("id", record.metadata.id)
                put("time", record.time.toString())
                put("height", record.height.inMeters)
            })
        }

        return result
    }

    private suspend fun readHRVRecords(
        client: HealthConnectClient,
        timeRange: TimeRangeFilter,
        limit: Int
    ): JSONArray {
        val request = ReadRecordsRequest(
            recordType = HeartRateVariabilityRmssdRecord::class,
            timeRangeFilter = timeRange,
            pageSize = limit
        )

        val response = client.readRecords(request)
        val result = JSONArray()

        response.records.forEach { record ->
            result.put(JSONObject().apply {
                put("id", record.metadata.id)
                put("time", record.time.toString())
                put("heartRateVariability", record.heartRateVariabilityMillis)
            })
        }

        return result
    }
}
```

## React Native Integration

### Creating the Native Module

Create `HealthConnectModule.kt`:

```kotlin
package com.yourapp.healthsync

import android.app.Activity
import androidx.health.connect.client.permission.HealthPermission
import com.facebook.react.bridge.*
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject

class HealthConnectModule(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    private val bridge = HealthConnectBridgeImpl(reactContext)
    private val scope = CoroutineScope(Dispatchers.Main)

    override fun getName() = "HealthConnectModule"

    @ReactMethod
    fun checkAvailability(promise: Promise) {
        scope.launch {
            try {
                val result = bridge.checkAvailability()
                promise.resolve(result)
            } catch (e: Exception) {
                promise.reject("ERROR", e.message, e)
            }
        }
    }

    @ReactMethod
    fun checkPermissions(permissions: ReadableArray, promise: Promise) {
        scope.launch {
            try {
                val permissionList = permissions.toArrayList().map { it.toString() }
                val result = bridge.checkPermissions(permissionList)
                promise.resolve(convertJsonToMap(result))
            } catch (e: Exception) {
                promise.reject("ERROR", e.message, e)
            }
        }
    }

    @ReactMethod
    fun requestPermissions(permissions: ReadableArray, promise: Promise) {
        scope.launch {
            try {
                val permissionList = permissions.toArrayList().map { it.toString() }
                val permissionsToRequest = bridge.getPermissionsToRequest(permissionList)

                if (permissionsToRequest.isEmpty()) {
                    // All permissions already granted
                    promise.resolve(convertToWritableArray(permissionList))
                    return@launch
                }

                // Launch permission request activity
                val activity = currentActivity
                if (activity == null) {
                    promise.reject("ERROR", "No activity available")
                    return@launch
                }

                val healthPermissions = permissionsToRequest.map {
                    HealthPermission.createReadPermission(it)
                }.toSet()

                // Store promise for callback
                requestPromise = promise

                // Launch permission request
                val intent = HealthPermissionContract().createIntent(
                    activity,
                    healthPermissions
                )
                activity.startActivityForResult(intent, PERMISSION_REQUEST_CODE)

            } catch (e: Exception) {
                promise.reject("ERROR", e.message, e)
            }
        }
    }

    @ReactMethod
    fun readRecords(request: ReadableMap, promise: Promise) {
        scope.launch {
            try {
                val requestJson = convertMapToJson(request)
                val result = bridge.readRecords(requestJson)
                promise.resolve(convertJsonToArray(result))
            } catch (e: Exception) {
                promise.reject("ERROR", e.message, e)
            }
        }
    }

    // Helper methods

    private fun convertJsonToMap(jsonArray: JSONArray): WritableArray {
        val array = Arguments.createArray()
        for (i in 0 until jsonArray.length()) {
            val obj = jsonArray.getJSONObject(i)
            val map = Arguments.createMap()
            obj.keys().forEach { key ->
                when (val value = obj.get(key)) {
                    is String -> map.putString(key, value)
                    is Boolean -> map.putBoolean(key, value)
                    is Int -> map.putInt(key, value)
                    is Double -> map.putDouble(key, value)
                }
            }
            array.pushMap(map)
        }
        return array
    }

    private fun convertJsonToArray(jsonArray: JSONArray): WritableArray {
        val array = Arguments.createArray()
        for (i in 0 until jsonArray.length()) {
            val obj = jsonArray.getJSONObject(i)
            val map = Arguments.createMap()
            obj.keys().forEach { key ->
                when (val value = obj.get(key)) {
                    is String -> map.putString(key, value)
                    is Boolean -> map.putBoolean(key, value)
                    is Int -> map.putInt(key, value)
                    is Double -> map.putDouble(key, value)
                    is JSONArray -> map.putArray(key, convertJsonToArray(value))
                }
            }
            array.pushMap(map)
        }
        return array
    }

    private fun convertMapToJson(map: ReadableMap): JSONObject {
        val json = JSONObject()
        val iterator = map.keySetIterator()
        while (iterator.hasNextKey()) {
            val key = iterator.nextKey()
            when (val value = map.getDynamic(key)) {
                is String -> json.put(key, value)
                is Boolean -> json.put(key, value)
                is Int -> json.put(key, value)
                is Double -> json.put(key, value)
            }
        }
        return json
    }

    private fun convertToWritableArray(list: List<String>): WritableArray {
        val array = Arguments.createArray()
        list.forEach { array.pushString(it) }
        return array
    }

    companion object {
        private const val PERMISSION_REQUEST_CODE = 10001
        private var requestPromise: Promise? = null
    }
}
```

Register the module in `MainApplication.kt`:

```kotlin
override fun getPackages(): List<ReactPackage> {
    return PackageList(this).packages.apply {
        add(object : ReactPackage {
            override fun createNativeModules(reactContext: ReactApplicationContext): List<NativeModule> {
                return listOf(HealthConnectModule(reactContext))
            }

            override fun createViewManagers(reactContext: ReactApplicationContext): List<ViewManager<*, *>> {
                return emptyList()
            }
        })
    }
}
```

## TypeScript Integration

### Creating the Bridge Connection

Create `healthConnectBridge.ts`:

```typescript
import { NativeModules } from 'react-native';
import {
  HealthConnectBridge,
  HealthConnectAvailability,
  HealthConnectPermission,
  HealthConnectRecord,
  PermissionStatus,
} from '@healthsync/core';

const { HealthConnectModule } = NativeModules;

/**
 * React Native implementation of HealthConnectBridge
 */
export class ReactNativeHealthConnectBridge implements HealthConnectBridge {
  async checkAvailability(): Promise<HealthConnectAvailability> {
    const result = await HealthConnectModule.checkAvailability();
    return result as HealthConnectAvailability;
  }

  async checkPermissions(
    permissions: HealthConnectPermission[]
  ): Promise<PermissionStatus[]> {
    const result = await HealthConnectModule.checkPermissions(permissions);
    return result.map((item: any) => ({
      permission: item.permission,
      granted: item.granted,
      checkedAt: item.checkedAt,
    }));
  }

  async requestPermissions(
    permissions: HealthConnectPermission[]
  ): Promise<HealthConnectPermission[]> {
    const granted = await HealthConnectModule.requestPermissions(permissions);
    return granted;
  }

  async readRecords(request: {
    recordType: string;
    startTime: Date;
    endTime: Date;
    limit?: number;
    offset?: number;
  }): Promise<HealthConnectRecord[]> {
    const result = await HealthConnectModule.readRecords({
      recordType: request.recordType,
      startTime: request.startTime.toISOString(),
      endTime: request.endTime.toISOString(),
      limit: request.limit,
      offset: request.offset,
    });

    return result;
  }
}
```

### Using the Bridge with the Plugin

```typescript
import { HealthConnectPlugin } from '@healthsync/core';
import { ReactNativeHealthConnectBridge } from './healthConnectBridge';

// Create plugin instance
const healthConnectPlugin = new HealthConnectPlugin({
  autoRequestPermissions: true,
  batchSize: 1000,
});

// Create and set the native bridge
const bridge = new ReactNativeHealthConnectBridge();
healthConnectPlugin.setPlatformBridge(bridge);

// Initialize the plugin
await healthConnectPlugin.initialize({
  custom: {
    logger: console, // Optional: pass a logger
  },
});

// Connect to Health Connect
const result = await healthConnectPlugin.connect();

if (result.success) {
  console.log('Connected to Health Connect!');

  // Fetch data
  const stepsData = await healthConnectPlugin.fetchData({
    dataType: DataType.STEPS,
    startDate: new Date('2024-01-01').toISOString(),
    endDate: new Date().toISOString(),
  });

  console.log(`Fetched ${stepsData.length} step records`);
}
```

## Testing

### Unit Testing the Bridge

Create test mocks for the native module:

```typescript
// __mocks__/HealthConnectModule.ts
export const HealthConnectModule = {
  checkAvailability: jest.fn().mockResolvedValue('installed'),

  checkPermissions: jest.fn().mockResolvedValue([
    {
      permission: 'android.permission.health.READ_STEPS',
      granted: true,
      checkedAt: new Date().toISOString(),
    },
  ]),

  requestPermissions: jest.fn().mockResolvedValue([
    'android.permission.health.READ_STEPS',
  ]),

  readRecords: jest.fn().mockResolvedValue([
    {
      id: 'record-1',
      startTime: '2024-01-15T10:00:00Z',
      endTime: '2024-01-15T10:05:00Z',
      count: 500,
    },
  ]),
};
```

### Integration Testing

Test the bridge with actual Health Connect data:

```typescript
describe('Health Connect Bridge Integration', () => {
  let plugin: HealthConnectPlugin;
  let bridge: ReactNativeHealthConnectBridge;

  beforeEach(() => {
    plugin = new HealthConnectPlugin();
    bridge = new ReactNativeHealthConnectBridge();
    plugin.setPlatformBridge(bridge);
  });

  it('should check availability', async () => {
    const availability = await bridge.checkAvailability();
    expect(['installed', 'not_installed', 'not_supported']).toContain(availability);
  });

  it('should fetch steps data', async () => {
    await plugin.initialize({});
    await plugin.connect();

    const data = await plugin.fetchData({
      dataType: DataType.STEPS,
      startDate: new Date('2024-01-01').toISOString(),
      endDate: new Date().toISOString(),
    });

    expect(Array.isArray(data)).toBe(true);
  });
});
```

## Troubleshooting

### Common Issues

#### 1. "Health Connect not available"

**Problem:** Plugin can't detect Health Connect on the device.

**Solutions:**
- Ensure device is running Android 14+ OR has Health Connect backport installed
- Check `AndroidManifest.xml` has correct permissions declared
- Verify Health Connect app is installed and up-to-date

#### 2. Permissions not being requested

**Problem:** Permission dialog doesn't appear.

**Solutions:**
- Ensure Activity context is available when calling `requestPermissions()`
- Check that permissions are declared in `AndroidManifest.xml`
- Verify permission strings match exactly (including `android.permission.health.` prefix)
- Check that Health Connect app has necessary permissions itself

#### 3. No data returned from queries

**Problem:** `readRecords()` returns empty array.

**Solutions:**
- Verify permissions are actually granted (use `checkPermissions()`)
- Check date range is valid and contains data
- Ensure Health Connect has data for the requested type
- Verify record type string matches exactly

#### 4. Native module not found

**Problem:** `NativeModules.HealthConnectModule` is undefined.

**Solutions:**
- Rebuild the native app completely
- Check module is registered in `MainApplication.kt`
- Verify package name matches in all files
- Clear metro cache: `npx react-native start --reset-cache`

#### 5. Kotlin compilation errors

**Problem:** Build fails with Kotlin errors.

**Solutions:**
- Ensure Kotlin version is 1.8.0 or higher
- Add kotlinx-coroutines dependency
- Sync Gradle files
- Check for conflicting dependency versions

### Debug Logging

Add logging to the bridge implementation:

```kotlin
private fun log(message: String) {
    if (BuildConfig.DEBUG) {
        android.util.Log.d("HealthConnectBridge", message)
    }
}

// Use throughout implementation
suspend fun checkAvailability(): String {
    log("Checking Health Connect availability...")
    val result = when (HealthConnectClient.getSdkStatus(context)) {
        HealthConnectClient.SDK_AVAILABLE -> {
            log("Health Connect is installed")
            "installed"
        }
        else -> {
            log("Health Connect not available")
            "not_installed"
        }
    }
    return result
}
```

## Additional Resources

- [Android Health Connect Documentation](https://developer.android.com/health-and-fitness/guides/health-connect)
- [Health Connect API Reference](https://developer.android.com/reference/kotlin/androidx/health/connect/client/package-summary)
- [Health Connect Permissions Guide](https://developer.android.com/health-and-fitness/guides/health-connect/plan/data-types)
- [Sample App on GitHub](https://github.com/android/health-samples)

## Next Steps

1. Implement the bridge for your platform
2. Test with mock data first
3. Test with real Health Connect data
4. Handle all edge cases and errors
5. Add proper logging for debugging
6. Write comprehensive tests
7. Deploy and monitor for issues

Need help? Check the troubleshooting section or file an issue on GitHub.
