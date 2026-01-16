package com.healthsync.reactnative

import android.app.Activity
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.*
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import com.facebook.react.bridge.*
import com.facebook.react.module.annotations.ReactModule
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.time.Instant
import kotlin.reflect.KClass

/**
 * React Native Health Connect Module
 *
 * Provides Android Health Connect integration for React Native applications.
 * Reuses the same logic as Flutter implementation but adapted for React Native.
 */
@ReactModule(name = HealthConnectModule.NAME)
class HealthConnectModule(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    companion object {
        const val NAME = "HealthConnectModule"
    }

    private val scope = CoroutineScope(Dispatchers.Main)
    private var healthConnectClient: HealthConnectClient? = null

    // Permission request handling
    private var pendingPermissionPromise: Promise? = null
    private var permissionLauncher: ActivityResultLauncher<Set<String>>? = null

    init {
        // Initialize Health Connect client if available
        if (HealthConnectClient.getSdkStatus(reactContext) == HealthConnectClient.SDK_AVAILABLE) {
            healthConnectClient = HealthConnectClient.getOrCreate(reactContext)
        }
    }

    override fun getName(): String = NAME

    /**
     * Check Health Connect availability
     */
    @ReactMethod
    fun checkAvailability(promise: Promise) {
        scope.launch {
            try {
                val status = when (HealthConnectClient.getSdkStatus(reactApplicationContext)) {
                    HealthConnectClient.SDK_AVAILABLE -> "installed"
                    HealthConnectClient.SDK_UNAVAILABLE -> "not_installed"
                    HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> "not_installed"
                    else -> "not_supported"
                }
                promise.resolve(status)
            } catch (e: Exception) {
                promise.reject("ERROR", e.message, e)
            }
        }
    }

    /**
     * Check permissions
     */
    @ReactMethod
    fun checkPermissions(permissions: ReadableArray, promise: Promise) {
        scope.launch {
            try {
                val client = healthConnectClient
                if (client == null) {
                    promise.resolve(Arguments.createArray())
                    return@launch
                }

                val permList = permissions.toArrayList().mapNotNull { it as? String }
                val grantedPermissions = client.permissionController.getGrantedPermissions()

                val statuses = WritableNativeArray()
                permList.forEach { permission ->
                    val recordClass = permissionToRecordClass(permission)
                    val isGranted = recordClass?.let {
                        grantedPermissions.contains(HealthPermission.getReadPermission(it))
                    } ?: false

                    val statusMap = WritableNativeMap().apply {
                        putString("permission", permission)
                        putBoolean("granted", isGranted)
                        putString("checkedAt", Instant.now().toString())
                    }
                    statuses.pushMap(statusMap)
                }

                promise.resolve(statuses)
            } catch (e: Exception) {
                promise.reject("ERROR", "Failed to check permissions: ${e.message}", e)
            }
        }
    }

    /**
     * Request permissions
     *
     * CRITICAL: This requires MainActivity to extend ComponentActivity
     */
    @ReactMethod
    fun requestPermissions(permissions: ReadableArray, promise: Promise) {
        scope.launch {
            try {
                val client = healthConnectClient
                if (client == null) {
                    promise.reject("ERROR", "Health Connect not available")
                    return@launch
                }

                val permList = permissions.toArrayList().mapNotNull { it as? String }
                val permissionsToRequest = permList.mapNotNull { permName ->
                    permissionToRecordClass(permName)?.let { HealthPermission.getReadPermission(it) }
                }.toSet()

                if (permissionsToRequest.isEmpty()) {
                    promise.reject("NO_VALID_PERMISSIONS", "No valid permissions to request")
                    return@launch
                }

                // Store promise for callback
                pendingPermissionPromise = promise

                // Get current activity
                val currentActivity = currentActivity
                if (currentActivity == null) {
                    promise.reject("NO_ACTIVITY", "Activity not available")
                    pendingPermissionPromise = null
                    return@launch
                }

                // Cast to ComponentActivity (required for registerForActivityResult)
                val componentActivity = currentActivity as? ComponentActivity
                if (componentActivity == null) {
                    promise.reject(
                        "INVALID_ACTIVITY",
                        "Activity must extend ComponentActivity. Ensure MainActivity extends ReactFragmentActivity."
                    )
                    pendingPermissionPromise = null
                    return@launch
                }

                // Create permission launcher if not exists
                if (permissionLauncher == null) {
                    val permissionContract = PermissionController.createRequestPermissionResultContract()

                    permissionLauncher = componentActivity.registerForActivityResult(permissionContract) { granted ->
                        val grantedPermissionNames = permList.filter { permName ->
                            permissionToRecordClass(permName)?.let { recordClass ->
                                granted.contains(HealthPermission.getReadPermission(recordClass))
                            } ?: false
                        }

                        val resultArray = WritableNativeArray()
                        grantedPermissionNames.forEach { resultArray.pushString(it) }

                        pendingPermissionPromise?.resolve(resultArray)
                        pendingPermissionPromise = null
                    }
                }

                // Launch permission request
                permissionLauncher?.launch(permissionsToRequest)

            } catch (e: Exception) {
                promise.reject("ERROR", "Failed to request permissions: ${e.message}", e)
                pendingPermissionPromise = null
            }
        }
    }

    /**
     * Read records from Health Connect
     */
    @ReactMethod
    fun readRecords(options: ReadableMap, promise: Promise) {
        scope.launch {
            try {
                val client = healthConnectClient
                if (client == null) {
                    promise.reject("ERROR", "Health Connect not available")
                    return@launch
                }

                val recordType = options.getString("recordType")
                    ?: run {
                        promise.reject("ERROR", "recordType is required")
                        return@launch
                    }

                // CRITICAL: Parse ISO 8601 timestamps WITH timezone (Z suffix)
                // These come from JavaScript Date.toISOString() which always includes 'Z'
                val startTimeStr = options.getString("startTime")
                    ?: run {
                        promise.reject("ERROR", "startTime is required")
                        return@launch
                    }

                val endTimeStr = options.getString("endTime")
                    ?: run {
                        promise.reject("ERROR", "endTime is required")
                        return@launch
                    }

                val startTime = Instant.parse(startTimeStr)
                val endTime = Instant.parse(endTimeStr)

                val recordClass = getRecordClass(recordType)
                    ?: run {
                        promise.reject("ERROR", "Unsupported record type: $recordType")
                        return@launch
                    }

                val request = ReadRecordsRequest(
                    recordType = recordClass,
                    timeRangeFilter = TimeRangeFilter.between(startTime, endTime)
                )

                val response = client.readRecords(request)

                val records = WritableNativeArray()
                response.records.forEach { record ->
                    val recordMap = convertRecordToMap(record)
                    records.pushMap(recordMap)
                }

                promise.resolve(records)

            } catch (e: Exception) {
                promise.reject("ERROR", "Failed to read records: ${e.message}", e)
            }
        }
    }

    // ============================================================================
    // Helper Methods (same logic as Flutter implementation)
    // ============================================================================

    private fun getRecordClass(recordType: String): KClass<out Record>? {
        return when (recordType) {
            "StepsRecord" -> StepsRecord::class
            "HeartRateRecord" -> HeartRateRecord::class
            "SleepSessionRecord" -> SleepSessionRecord::class
            "DistanceRecord" -> DistanceRecord::class
            "ExerciseSessionRecord" -> ExerciseSessionRecord::class
            "TotalCaloriesBurnedRecord" -> TotalCaloriesBurnedRecord::class
            "ActiveCaloriesBurnedRecord" -> ActiveCaloriesBurnedRecord::class
            "OxygenSaturationRecord" -> OxygenSaturationRecord::class
            "BloodPressureRecord" -> BloodPressureRecord::class
            "BodyTemperatureRecord" -> BodyTemperatureRecord::class
            "WeightRecord" -> WeightRecord::class
            "HeightRecord" -> HeightRecord::class
            "HeartRateVariabilityRmssdRecord" -> HeartRateVariabilityRmssdRecord::class
            else -> null
        }
    }

    private fun permissionToRecordClass(permission: String): KClass<out Record>? {
        return when (permission) {
            "android.permission.health.READ_STEPS" -> StepsRecord::class
            "android.permission.health.READ_DISTANCE" -> DistanceRecord::class
            "android.permission.health.READ_EXERCISE" -> ExerciseSessionRecord::class
            "android.permission.health.READ_ACTIVE_CALORIES_BURNED" -> ActiveCaloriesBurnedRecord::class
            "android.permission.health.READ_TOTAL_CALORIES_BURNED" -> TotalCaloriesBurnedRecord::class
            "android.permission.health.READ_HEART_RATE" -> HeartRateRecord::class
            "android.permission.health.READ_HEART_RATE_VARIABILITY" -> HeartRateVariabilityRmssdRecord::class
            "android.permission.health.READ_BLOOD_PRESSURE" -> BloodPressureRecord::class
            "android.permission.health.READ_OXYGEN_SATURATION" -> OxygenSaturationRecord::class
            "android.permission.health.READ_BODY_TEMPERATURE" -> BodyTemperatureRecord::class
            "android.permission.health.READ_WEIGHT" -> WeightRecord::class
            "android.permission.health.READ_HEIGHT" -> HeightRecord::class
            "android.permission.health.READ_SLEEP" -> SleepSessionRecord::class
            else -> null
        }
    }

    private fun convertRecordToMap(record: Record): WritableMap {
        val map = WritableNativeMap()

        when (record) {
            is StepsRecord -> {
                map.putString("id", record.metadata.id)
                map.putString("startTime", record.startTime.toString())
                map.putString("endTime", record.endTime.toString())
                map.putDouble("count", record.count.toDouble())
            }
            is HeartRateRecord -> {
                map.putString("id", record.metadata.id)
                map.putString("time", record.time.toString())

                val samples = WritableNativeArray()
                record.samples.forEach { sample ->
                    val sampleMap = WritableNativeMap()
                    sampleMap.putString("time", sample.time.toString())
                    sampleMap.putInt("beatsPerMinute", sample.beatsPerMinute.toInt())
                    samples.pushMap(sampleMap)
                }
                map.putArray("samples", samples)
            }
            is DistanceRecord -> {
                map.putString("id", record.metadata.id)
                map.putString("startTime", record.startTime.toString())
                map.putString("endTime", record.endTime.toString())
                map.putDouble("distanceMeters", record.distance.inMeters)
            }
            is WeightRecord -> {
                map.putString("id", record.metadata.id)
                map.putString("time", record.time.toString())
                map.putDouble("weightKg", record.weight.inKilograms)
            }
            // Add more record types as needed
            else -> {
                map.putString("id", record.metadata.id)
                map.putString("type", record::class.simpleName)
            }
        }

        return map
    }
}
