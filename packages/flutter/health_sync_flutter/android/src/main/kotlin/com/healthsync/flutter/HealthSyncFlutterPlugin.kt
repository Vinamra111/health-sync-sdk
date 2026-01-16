package com.healthsync.flutter

import android.app.Activity
import android.content.Context
import android.content.Intent
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContract
import androidx.annotation.NonNull
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.*
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.time.Instant
import kotlin.reflect.KClass

/** HealthSyncFlutterPlugin */
class HealthSyncFlutterPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.ActivityResultListener {
  private lateinit var channel: MethodChannel
  private lateinit var context: Context
  private var activity: Activity? = null
  private var healthConnectClient: HealthConnectClient? = null
  private val scope = CoroutineScope(Dispatchers.Main)

  // Permission request handling
  private var pendingPermissionResult: Result? = null
  private var requestedPermissions: Set<String> = emptySet()
  private var permissionRequestStartTime: Long = 0
  private var activityPluginBinding: ActivityPluginBinding? = null

  // Health Connect permission launcher - CRITICAL for permission requests
  private var permissionLauncher: ActivityResultLauncher<Set<String>>? = null

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    context = flutterPluginBinding.applicationContext
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "health_sync_flutter/health_connect")
    channel.setMethodCallHandler(this)

    // Initialize Health Connect client if available
    if (HealthConnectClient.getSdkStatus(context) == HealthConnectClient.SDK_AVAILABLE) {
      healthConnectClient = HealthConnectClient.getOrCreate(context)
    }
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    when (call.method) {
      "checkAvailability" -> checkAvailability(result)
      "checkPermissions" -> checkPermissions(call, result)
      "requestPermissions" -> requestPermissions(call, result)
      "readRecords" -> readRecords(call, result)
      else -> result.notImplemented()
    }
  }

  private fun checkAvailability(result: Result) {
    scope.launch {
      try {
        val status = when (HealthConnectClient.getSdkStatus(context)) {
          HealthConnectClient.SDK_AVAILABLE -> "installed"
          HealthConnectClient.SDK_UNAVAILABLE -> "not_installed"
          HealthConnectClient.SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED -> "not_installed"
          else -> "not_supported"
        }
        result.success(status)
      } catch (e: Exception) {
        result.error("ERROR", e.message, null)
      }
    }
  }

  private fun getRecordClass(recordType: String): KClass<out Record>? {
    return when (recordType) {
      "StepsRecord" -> StepsRecord::class
      "HeartRateRecord" -> HeartRateRecord::class
      "SleepSessionRecord" -> SleepSessionRecord::class
      "DistanceRecord" -> DistanceRecord::class
      "ExerciseSessionRecord" -> ExerciseSessionRecord::class
      "TotalCaloriesBurnedRecord" -> TotalCaloriesBurnedRecord::class
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
      // Activity & Exercise
      "android.permission.health.READ_STEPS" -> StepsRecord::class
      "android.permission.health.READ_DISTANCE" -> DistanceRecord::class
      "android.permission.health.READ_EXERCISE" -> ExerciseSessionRecord::class
      "android.permission.health.READ_EXERCISE_ROUTE" -> ExerciseSessionRecord::class // Routes are part of exercise sessions
      "android.permission.health.READ_ACTIVE_CALORIES_BURNED" -> ActiveCaloriesBurnedRecord::class
      "android.permission.health.READ_TOTAL_CALORIES_BURNED" -> TotalCaloriesBurnedRecord::class
      "android.permission.health.READ_ELEVATION_GAINED" -> ElevationGainedRecord::class
      "android.permission.health.READ_FLOORS_CLIMBED" -> FloorsClimbedRecord::class
      "android.permission.health.READ_POWER" -> PowerRecord::class
      "android.permission.health.READ_SPEED" -> SpeedRecord::class
      "android.permission.health.READ_CYCLING_PEDALING_CADENCE" -> CyclingPedalingCadenceRecord::class
      "android.permission.health.READ_WHEELCHAIR_PUSHES" -> WheelchairPushesRecord::class
      // Note: PlannedExerciseSessionRecord not available in Health Connect SDK 1.1.0-alpha07
      // Will be available in future SDK versions
      "android.permission.health.READ_PLANNED_EXERCISE" -> null

      // Body Measurements
      "android.permission.health.READ_WEIGHT" -> WeightRecord::class
      "android.permission.health.READ_HEIGHT" -> HeightRecord::class
      "android.permission.health.READ_BODY_FAT" -> BodyFatRecord::class
      "android.permission.health.READ_BODY_WATER_MASS" -> BodyWaterMassRecord::class
      "android.permission.health.READ_BONE_MASS" -> BoneMassRecord::class
      "android.permission.health.READ_LEAN_BODY_MASS" -> LeanBodyMassRecord::class
      "android.permission.health.READ_BASAL_METABOLIC_RATE" -> BasalMetabolicRateRecord::class

      // Vitals
      "android.permission.health.READ_HEART_RATE" -> HeartRateRecord::class
      "android.permission.health.READ_HEART_RATE_VARIABILITY" -> HeartRateVariabilityRmssdRecord::class
      "android.permission.health.READ_RESTING_HEART_RATE" -> RestingHeartRateRecord::class
      "android.permission.health.READ_BLOOD_PRESSURE" -> BloodPressureRecord::class
      "android.permission.health.READ_BLOOD_GLUCOSE" -> BloodGlucoseRecord::class
      "android.permission.health.READ_OXYGEN_SATURATION" -> OxygenSaturationRecord::class
      "android.permission.health.READ_RESPIRATORY_RATE" -> RespiratoryRateRecord::class
      "android.permission.health.READ_BODY_TEMPERATURE" -> BodyTemperatureRecord::class
      "android.permission.health.READ_BASAL_BODY_TEMPERATURE" -> BasalBodyTemperatureRecord::class
      // Note: SkinTemperatureRecord not available in Health Connect SDK 1.1.0-alpha07
      // Will be available in future SDK versions
      "android.permission.health.READ_SKIN_TEMPERATURE" -> null

      // Sleep
      "android.permission.health.READ_SLEEP" -> SleepSessionRecord::class

      // Nutrition & Hydration
      "android.permission.health.READ_NUTRITION" -> NutritionRecord::class
      "android.permission.health.READ_HYDRATION" -> HydrationRecord::class

      // Cycle Tracking
      "android.permission.health.READ_MENSTRUATION" -> MenstruationFlowRecord::class
      "android.permission.health.READ_OVULATION_TEST" -> OvulationTestRecord::class
      "android.permission.health.READ_CERVICAL_MUCUS" -> CervicalMucusRecord::class
      "android.permission.health.READ_INTERMENSTRUAL_BLEEDING" -> IntermenstrualBleedingRecord::class
      "android.permission.health.READ_SEXUAL_ACTIVITY" -> SexualActivityRecord::class

      // Fitness
      "android.permission.health.READ_VO2_MAX" -> Vo2MaxRecord::class

      // Mindfulness
      // Note: MindfulnessSessionRecord not available in Health Connect SDK 1.1.0-alpha07
      // Will be available in future SDK versions
      "android.permission.health.READ_MINDFULNESS" -> null

      // Special Permissions (no specific Record class, but still valid permissions)
      // These are handled differently - they don't map to record types
      "android.permission.health.READ_HEALTH_DATA_IN_BACKGROUND" -> null
      "android.permission.health.READ_HEALTH_DATA_HISTORY" -> null

      else -> null
    }
  }

  private fun checkPermissions(call: MethodCall, result: Result) {
    scope.launch {
      try {
        val client = healthConnectClient
        if (client == null) {
          result.success(emptyList<Map<String, Any>>())
          return@launch
        }

        val permissions = call.argument<List<String>>("permissions") ?: emptyList()
        val healthPermissions = permissions.mapNotNull { permName ->
          permissionToRecordClass(permName)?.let { HealthPermission.getReadPermission(it) }
        }.toSet()

        val grantedPermissions = client.permissionController.getGrantedPermissions()

        val statuses = permissions.map { permission ->
          val recordClass = permissionToRecordClass(permission)
          val isGranted = recordClass?.let {
            grantedPermissions.contains(HealthPermission.getReadPermission(it))
          } ?: false

          mapOf(
            "permission" to permission,
            "granted" to isGranted,
            "checkedAt" to Instant.now().toString()
          )
        }

        result.success(statuses)
      } catch (e: Exception) {
        result.error("ERROR", e.message, null)
      }
    }
  }

  private fun requestPermissions(call: MethodCall, result: Result) {
    scope.launch {
      try {
        // CRITICAL FIX: Check for concurrent requests
        if (pendingPermissionResult != null) {
          result.error(
            "CONCURRENT_REQUEST",
            "Another permission request is already in progress. Please wait for it to complete.",
            mapOf(
              "suggestion" to "Wait for current request to finish or implement request queueing"
            )
          )
          return@launch
        }

        val client = healthConnectClient
        if (client == null) {
          result.error("ERROR", "Health Connect not available", null)
          return@launch
        }

        val currentActivity = activity
        if (currentActivity == null) {
          result.error("ERROR", "Activity not available", null)
          return@launch
        }

        val permissions = call.argument<List<String>>("permissions") ?: emptyList()

        // IMPROVEMENT: Track which permissions can't be mapped
        val unmappedPermissions = mutableListOf<String>()
        val mappedPermissions = mutableListOf<String>()

        val healthPermissions = permissions.mapNotNull { permName ->
          val recordClass = permissionToRecordClass(permName)
          when {
            // Special permissions that don't map to records are valid but handled differently
            permName == "android.permission.health.READ_HEALTH_DATA_IN_BACKGROUND" ||
            permName == "android.permission.health.READ_HEALTH_DATA_HISTORY" -> {
              mappedPermissions.add(permName)
              null // These don't map to record classes but are still valid
            }
            recordClass != null -> {
              mappedPermissions.add(permName)
              HealthPermission.getReadPermission(recordClass)
            }
            else -> {
              unmappedPermissions.add(permName)
              null
            }
          }
        }.toSet()

        // Log unmapped permissions for debugging
        if (unmappedPermissions.isNotEmpty()) {
          android.util.Log.w(
            "HealthSyncFlutter",
            "Unmapped permissions (will be skipped): ${unmappedPermissions.joinToString()}"
          )
        }

        // Check which permissions are already granted
        val grantedPermissions = client.permissionController.getGrantedPermissions()
        val permissionsToRequest = healthPermissions.filter { !grantedPermissions.contains(it) }.toSet()

        if (permissionsToRequest.isEmpty() && healthPermissions.isNotEmpty()) {
          // All mappable permissions already granted
          result.success(mappedPermissions)
          return@launch
        }

        if (healthPermissions.isEmpty()) {
          // No valid permissions to request
          result.error(
            "NO_VALID_PERMISSIONS",
            "None of the requested permissions could be mapped to Health Connect permissions",
            mapOf(
              "requestedCount" to permissions.size,
              "unmappedPermissions" to unmappedPermissions
            )
          )
          return@launch
        }

        // CORRECT APPROACH: Use ActivityResultLauncher
        // The launcher was registered in onAttachedToActivity() and will handle the callback
        try {
          // Check if launcher is available
          val launcher = permissionLauncher
          if (launcher == null) {
            result.error(
              "NO_ACTIVITY",
              "Activity not attached. Permission launcher not available.",
              null
            )
            return@launch
          }

          // Store the result callback and permissions for the launcher callback
          pendingPermissionResult = result
          requestedPermissions = permissions.toSet()
          permissionRequestStartTime = System.currentTimeMillis()

          // Launch the permission request using the ActivityResultLauncher
          // This will open Health Connect's permission screen
          // The result will come back to the callback registered in onAttachedToActivity()
          launcher.launch(permissionsToRequest)

        } catch (e: Exception) {
          result.error(
            "LAUNCH_ERROR",
            "Failed to launch Health Connect permission screen: ${e.message}",
            null
          )
          pendingPermissionResult = null
          requestedPermissions = emptySet()
          permissionRequestStartTime = 0
        }
      } catch (e: Exception) {
        pendingPermissionResult = null
        requestedPermissions = emptySet()
        permissionRequestStartTime = 0
        result.error("ERROR", e.message, null)
      }
    }
  }

  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
    if (requestCode == PERMISSION_REQUEST_CODE) {
      scope.launch {
        try {
          val client = healthConnectClient
          if (client == null) {
            pendingPermissionResult?.error("ERROR", "Health Connect not available", null)
            pendingPermissionResult = null
            requestedPermissions = emptySet()
            permissionRequestStartTime = 0
            return@launch
          }

          // Check which permissions were actually granted after the user responded
          val grantedPermissions = client.permissionController.getGrantedPermissions()
          val grantedPermissionStrings = requestedPermissions.filter { permName ->
            permissionToRecordClass(permName)?.let { recordClass ->
              grantedPermissions.contains(HealthPermission.getReadPermission(recordClass))
            } ?: false
          }

          pendingPermissionResult?.success(grantedPermissionStrings)
          pendingPermissionResult = null
          requestedPermissions = emptySet()
          permissionRequestStartTime = 0
        } catch (e: Exception) {
          pendingPermissionResult?.error("ERROR", e.message, null)
          pendingPermissionResult = null
          requestedPermissions = emptySet()
          permissionRequestStartTime = 0
        }
      }
      return true
    }
    return false
  }

  private fun readRecords(call: MethodCall, result: Result) {
    scope.launch {
      try {
        val client = healthConnectClient
        if (client == null) {
          result.success(emptyList<Map<String, Any>>())
          return@launch
        }

        val recordType = call.argument<String>("recordType") ?: ""
        val startTime = Instant.parse(call.argument<String>("startTime"))
        val endTime = Instant.parse(call.argument<String>("endTime"))
        val limit = call.argument<Int>("limit") ?: 0  // 0 = unlimited, pagination handles it

        val timeRange = TimeRangeFilter.between(startTime, endTime)

        val records = when (recordType) {
          // Activity & Exercise
          "Steps" -> readStepsRecords(client, timeRange, limit)
          "Distance" -> readDistanceRecords(client, timeRange, limit)
          "ExerciseSession" -> readExerciseRecords(client, timeRange, limit)
          "ActiveCaloriesBurned" -> readActiveCaloriesRecords(client, timeRange, limit)
          "TotalCaloriesBurned" -> readTotalCaloriesRecords(client, timeRange, limit)
          "ElevationGained" -> readElevationGainedRecords(client, timeRange, limit)
          "FloorsClimbed" -> readFloorsClimbedRecords(client, timeRange, limit)
          "Power" -> readPowerRecords(client, timeRange, limit)
          "Speed" -> readSpeedRecords(client, timeRange, limit)
          "WheelchairPushes" -> readWheelchairPushesRecords(client, timeRange, limit)

          // Body Measurements
          "Weight" -> readWeightRecords(client, timeRange, limit)
          "Height" -> readHeightRecords(client, timeRange, limit)
          "BodyFat" -> readBodyFatRecords(client, timeRange, limit)
          "BodyWaterMass" -> readBodyWaterMassRecords(client, timeRange, limit)
          "BoneMass" -> readBoneMassRecords(client, timeRange, limit)
          "LeanBodyMass" -> readLeanBodyMassRecords(client, timeRange, limit)
          "BasalMetabolicRate" -> readBasalMetabolicRateRecords(client, timeRange, limit)

          // Vitals
          "HeartRate" -> readHeartRateRecords(client, timeRange, limit)
          "HeartRateVariabilityRmssd" -> readHRVRecords(client, timeRange, limit)
          "RestingHeartRate" -> readRestingHeartRateRecords(client, timeRange, limit)
          "BloodPressure" -> readBloodPressureRecords(client, timeRange, limit)
          "BloodGlucose" -> readBloodGlucoseRecords(client, timeRange, limit)
          "OxygenSaturation" -> readOxygenSaturationRecords(client, timeRange, limit)
          "RespiratoryRate" -> readRespiratoryRateRecords(client, timeRange, limit)
          "BodyTemperature" -> readBodyTemperatureRecords(client, timeRange, limit)
          "BasalBodyTemperature" -> readBasalBodyTemperatureRecords(client, timeRange, limit)

          // Sleep
          "SleepSession" -> readSleepRecords(client, timeRange, limit)

          // Nutrition & Hydration
          "Nutrition" -> readNutritionRecords(client, timeRange, limit)
          "Hydration" -> readHydrationRecords(client, timeRange, limit)

          // Cycle Tracking
          "MenstruationFlow" -> readMenstruationFlowRecords(client, timeRange, limit)
          "OvulationTest" -> readOvulationTestRecords(client, timeRange, limit)
          "CervicalMucus" -> readCervicalMucusRecords(client, timeRange, limit)
          "IntermenstrualBleeding" -> readIntermenstrualBleedingRecords(client, timeRange, limit)
          "SexualActivity" -> readSexualActivityRecords(client, timeRange, limit)

          // Fitness
          "Vo2Max" -> readVo2MaxRecords(client, timeRange, limit)

          else -> emptyList()
        }

        result.success(records)
      } catch (e: Exception) {
        result.error("ERROR", e.message, null)
      }
    }
  }

  // Helper to extract metadata from Health Connect records
  // Extracts dataOrigin (which app created it), recordingMethod, and device info
  // Source: https://developer.android.com/health-and-fitness/health-connect/read-data
  private fun extractMetadata(metadata: androidx.health.connect.client.records.metadata.Metadata): Map<String, Any?> {
    // Map Android's RecordingMethod enum to our Dart-compatible format
    val recordingMethodString = when (metadata.recordingMethod) {
      0 -> "UNKNOWN"  // RECORDING_METHOD_UNKNOWN
      1 -> "MANUAL_ENTRY"  // RECORDING_METHOD_MANUALLY_ENTERED
      2 -> "AUTOMATICALLY_RECORDED"  // RECORDING_METHOD_AUTOMATICALLY_RECORDED
      3 -> "ACTIVELY_RECORDED"  // RECORDING_METHOD_ACTIVELY_RECORDED
      else -> "UNKNOWN"
    }

    return mapOf(
      "recordingMethod" to recordingMethodString,
      "dataOrigin" to mapOf(
        "packageName" to metadata.dataOrigin.packageName
      ),
      "device" to metadata.device?.let { device ->
        mapOf(
          "manufacturer" to (device.manufacturer ?: ""),
          "model" to (device.model ?: ""),
          "type" to device.type.toString()
        )
      }
    )
  }

  // Generic pagination helper for all Health Connect record types
  // This implements the official Android Health Connect pagination pattern:
  // https://developer.android.com/health-and-fitness/health-connect/read-data
  private suspend fun <T : Record> readRecordsWithPagination(
    client: HealthConnectClient,
    recordType: KClass<T>,
    timeRange: TimeRangeFilter,
    limit: Int,
    mapper: (T) -> Map<String, Any>
  ): List<Map<String, Any>> {
    val allRecords = mutableListOf<Map<String, Any>>()
    var pageToken: String? = null
    val pageSize = if (limit > 0) minOf(limit, 1000) else 1000

    // Pagination loop - fetches ALL records regardless of amount
    do {
      val request = ReadRecordsRequest(
        recordType = recordType,
        timeRangeFilter = timeRange,
        pageSize = pageSize,
        pageToken = pageToken
      )

      val response = client.readRecords(request)
      val pageRecords = response.records.map(mapper)

      allRecords.addAll(pageRecords)
      pageToken = response.pageToken

      // If limit is specified, stop when we reach it
      if (limit > 0 && allRecords.size >= limit) {
        break
      }
    } while (pageToken != null)

    // Apply limit if specified
    return if (limit > 0 && allRecords.size > limit) {
      allRecords.take(limit)
    } else {
      allRecords
    }
  }

  // Record-specific reading methods

  private suspend fun readStepsRecords(
    client: HealthConnectClient,
    timeRange: TimeRangeFilter,
    limit: Int
  ): List<Map<String, Any>> {
    return readRecordsWithPagination(
      client = client,
      recordType = StepsRecord::class,
      timeRange = timeRange,
      limit = limit
    ) { record ->
      mapOf(
        "sourceDataType" to "Steps",
        "source" to "health_connect",
        "timestamp" to record.startTime.toString(),
        "endTimestamp" to record.endTime.toString(),
        "raw" to mapOf(
          "id" to record.metadata.id,
          "startTime" to record.startTime.toString(),
          "endTime" to record.endTime.toString(),
          "count" to record.count,
          "metadata" to extractMetadata(record.metadata)  // ✅ Now includes full metadata
        )
      )
    }
  }

  private suspend fun readHeartRateRecords(
    client: HealthConnectClient,
    timeRange: TimeRangeFilter,
    limit: Int
  ): List<Map<String, Any>> {
    val request = ReadRecordsRequest(
      recordType = HeartRateRecord::class,
      timeRangeFilter = timeRange,
      pageSize = limit
    )

    val response = client.readRecords(request)
    return response.records.flatMap { record ->
      record.samples.map { sample ->
        mapOf(
          "sourceDataType" to "HeartRate",
          "source" to "health_connect",
          "timestamp" to sample.time.toString(),
          "raw" to mapOf(
            "id" to record.metadata.id,
            "time" to sample.time.toString(),
            "bpm" to sample.beatsPerMinute
          )
        )
      }
    }
  }

  private suspend fun readSleepRecords(
    client: HealthConnectClient,
    timeRange: TimeRangeFilter,
    limit: Int
  ): List<Map<String, Any>> {
    return readRecordsWithPagination(
      client = client,
      recordType = SleepSessionRecord::class,
      timeRange = timeRange,
      limit = limit
    ) { record ->
      mapOf(
        "sourceDataType" to "SleepSession",
        "source" to "health_connect",
        "timestamp" to record.startTime.toString(),
        "endTimestamp" to record.endTime.toString(),
        "raw" to mapOf(
          "id" to record.metadata.id,
          "startTime" to record.startTime.toString(),
          "endTime" to record.endTime.toString(),
          "title" to (record.title ?: ""),
          "stages" to record.stages.map { stage ->
            mapOf(
              "stage" to stage.stage,
              "startTime" to stage.startTime.toString(),
              "endTime" to stage.endTime.toString()
            )
          },
          "metadata" to extractMetadata(record.metadata)  // ✅ Now includes full metadata
        )
      )
    }
  }

  private suspend fun readDistanceRecords(
    client: HealthConnectClient,
    timeRange: TimeRangeFilter,
    limit: Int
  ): List<Map<String, Any>> {
    val request = ReadRecordsRequest(
      recordType = DistanceRecord::class,
      timeRangeFilter = timeRange,
      pageSize = limit
    )

    val response = client.readRecords(request)
    return response.records.map { record ->
      mapOf(
        "sourceDataType" to "Distance",
        "source" to "health_connect",
        "timestamp" to record.startTime.toString(),
        "endTimestamp" to record.endTime.toString(),
        "raw" to mapOf(
          "id" to record.metadata.id,
          "startTime" to record.startTime.toString(),
          "endTime" to record.endTime.toString(),
          "distance" to record.distance.inMeters
        )
      )
    }
  }

  private suspend fun readExerciseRecords(
    client: HealthConnectClient,
    timeRange: TimeRangeFilter,
    limit: Int
  ): List<Map<String, Any>> {
    val request = ReadRecordsRequest(
      recordType = ExerciseSessionRecord::class,
      timeRangeFilter = timeRange,
      pageSize = limit
    )

    val response = client.readRecords(request)
    return response.records.map { record ->
      mapOf(
        "sourceDataType" to "ExerciseSession",
        "source" to "health_connect",
        "timestamp" to record.startTime.toString(),
        "endTimestamp" to record.endTime.toString(),
        "raw" to mapOf(
          "id" to record.metadata.id,
          "startTime" to record.startTime.toString(),
          "endTime" to record.endTime.toString(),
          "exerciseType" to record.exerciseType,
          "title" to (record.title ?: "")
        )
      )
    }
  }

  private suspend fun readCaloriesRecords(
    client: HealthConnectClient,
    timeRange: TimeRangeFilter,
    limit: Int
  ): List<Map<String, Any>> {
    val request = ReadRecordsRequest(
      recordType = TotalCaloriesBurnedRecord::class,
      timeRangeFilter = timeRange,
      pageSize = limit
    )

    val response = client.readRecords(request)
    return response.records.map { record ->
      mapOf(
        "sourceDataType" to "TotalCaloriesBurned",
        "source" to "health_connect",
        "timestamp" to record.startTime.toString(),
        "endTimestamp" to record.endTime.toString(),
        "raw" to mapOf(
          "id" to record.metadata.id,
          "startTime" to record.startTime.toString(),
          "endTime" to record.endTime.toString(),
          "energy" to record.energy.inKilocalories
        )
      )
    }
  }

  private suspend fun readOxygenSaturationRecords(
    client: HealthConnectClient,
    timeRange: TimeRangeFilter,
    limit: Int
  ): List<Map<String, Any>> {
    val request = ReadRecordsRequest(
      recordType = OxygenSaturationRecord::class,
      timeRangeFilter = timeRange,
      pageSize = limit
    )

    val response = client.readRecords(request)
    return response.records.map { record ->
      mapOf(
        "sourceDataType" to "OxygenSaturation",
        "source" to "health_connect",
        "timestamp" to record.time.toString(),
        "raw" to mapOf(
          "id" to record.metadata.id,
          "time" to record.time.toString(),
          "percentage" to record.percentage.value
        )
      )
    }
  }

  private suspend fun readBloodPressureRecords(
    client: HealthConnectClient,
    timeRange: TimeRangeFilter,
    limit: Int
  ): List<Map<String, Any>> {
    val request = ReadRecordsRequest(
      recordType = BloodPressureRecord::class,
      timeRangeFilter = timeRange,
      pageSize = limit
    )

    val response = client.readRecords(request)
    return response.records.map { record ->
      mapOf(
        "sourceDataType" to "BloodPressure",
        "source" to "health_connect",
        "timestamp" to record.time.toString(),
        "raw" to mapOf(
          "id" to record.metadata.id,
          "time" to record.time.toString(),
          "systolic" to record.systolic.inMillimetersOfMercury,
          "diastolic" to record.diastolic.inMillimetersOfMercury
        )
      )
    }
  }

  private suspend fun readBodyTemperatureRecords(
    client: HealthConnectClient,
    timeRange: TimeRangeFilter,
    limit: Int
  ): List<Map<String, Any>> {
    val request = ReadRecordsRequest(
      recordType = BodyTemperatureRecord::class,
      timeRangeFilter = timeRange,
      pageSize = limit
    )

    val response = client.readRecords(request)
    return response.records.map { record ->
      mapOf(
        "sourceDataType" to "BodyTemperature",
        "source" to "health_connect",
        "timestamp" to record.time.toString(),
        "raw" to mapOf(
          "id" to record.metadata.id,
          "time" to record.time.toString(),
          "temperature" to record.temperature.inCelsius
        )
      )
    }
  }

  private suspend fun readWeightRecords(
    client: HealthConnectClient,
    timeRange: TimeRangeFilter,
    limit: Int
  ): List<Map<String, Any>> {
    val request = ReadRecordsRequest(
      recordType = WeightRecord::class,
      timeRangeFilter = timeRange,
      pageSize = limit
    )

    val response = client.readRecords(request)
    return response.records.map { record ->
      mapOf(
        "sourceDataType" to "Weight",
        "source" to "health_connect",
        "timestamp" to record.time.toString(),
        "raw" to mapOf(
          "id" to record.metadata.id,
          "time" to record.time.toString(),
          "weight" to record.weight.inKilograms
        )
      )
    }
  }

  private suspend fun readHeightRecords(
    client: HealthConnectClient,
    timeRange: TimeRangeFilter,
    limit: Int
  ): List<Map<String, Any>> {
    val request = ReadRecordsRequest(
      recordType = HeightRecord::class,
      timeRangeFilter = timeRange,
      pageSize = limit
    )

    val response = client.readRecords(request)
    return response.records.map { record ->
      mapOf(
        "sourceDataType" to "Height",
        "source" to "health_connect",
        "timestamp" to record.time.toString(),
        "raw" to mapOf(
          "id" to record.metadata.id,
          "time" to record.time.toString(),
          "height" to record.height.inMeters
        )
      )
    }
  }

  private suspend fun readHRVRecords(
    client: HealthConnectClient,
    timeRange: TimeRangeFilter,
    limit: Int
  ): List<Map<String, Any>> {
    val request = ReadRecordsRequest(
      recordType = HeartRateVariabilityRmssdRecord::class,
      timeRangeFilter = timeRange,
      pageSize = limit
    )

    val response = client.readRecords(request)
    return response.records.map { record ->
      mapOf(
        "sourceDataType" to "HeartRateVariabilityRmssd",
        "source" to "health_connect",
        "timestamp" to record.time.toString(),
        "raw" to mapOf(
          "id" to record.metadata.id,
          "time" to record.time.toString(),
          "heartRateVariability" to record.heartRateVariabilityMillis
        )
      )
    }
  }

  // Additional Activity & Exercise Records

  private suspend fun readActiveCaloriesRecords(
    client: HealthConnectClient,
    timeRange: TimeRangeFilter,
    limit: Int
  ): List<Map<String, Any>> {
    val request = ReadRecordsRequest(
      recordType = ActiveCaloriesBurnedRecord::class,
      timeRangeFilter = timeRange,
      pageSize = limit
    )
    val response = client.readRecords(request)
    return response.records.map { record ->
      mapOf(
        "sourceDataType" to "ActiveCaloriesBurned",
        "source" to "health_connect",
        "timestamp" to record.startTime.toString(),
        "endTimestamp" to record.endTime.toString(),
        "raw" to mapOf(
          "id" to record.metadata.id,
          "startTime" to record.startTime.toString(),
          "endTime" to record.endTime.toString(),
          "energy" to record.energy.inKilocalories
        )
      )
    }
  }

  private suspend fun readTotalCaloriesRecords(
    client: HealthConnectClient,
    timeRange: TimeRangeFilter,
    limit: Int
  ): List<Map<String, Any>> = readCaloriesRecords(client, timeRange, limit)

  private suspend fun readElevationGainedRecords(
    client: HealthConnectClient,
    timeRange: TimeRangeFilter,
    limit: Int
  ): List<Map<String, Any>> {
    val request = ReadRecordsRequest(
      recordType = ElevationGainedRecord::class,
      timeRangeFilter = timeRange,
      pageSize = limit
    )
    val response = client.readRecords(request)
    return response.records.map { record ->
      mapOf(
        "sourceDataType" to "ElevationGained",
        "source" to "health_connect",
        "timestamp" to record.startTime.toString(),
        "endTimestamp" to record.endTime.toString(),
        "raw" to mapOf(
          "id" to record.metadata.id,
          "startTime" to record.startTime.toString(),
          "endTime" to record.endTime.toString(),
          "elevation" to record.elevation.inMeters
        )
      )
    }
  }

  private suspend fun readFloorsClimbedRecords(
    client: HealthConnectClient,
    timeRange: TimeRangeFilter,
    limit: Int
  ): List<Map<String, Any>> {
    val request = ReadRecordsRequest(
      recordType = FloorsClimbedRecord::class,
      timeRangeFilter = timeRange,
      pageSize = limit
    )
    val response = client.readRecords(request)
    return response.records.map { record ->
      mapOf(
        "sourceDataType" to "FloorsClimbed",
        "source" to "health_connect",
        "timestamp" to record.startTime.toString(),
        "endTimestamp" to record.endTime.toString(),
        "raw" to mapOf(
          "id" to record.metadata.id,
          "startTime" to record.startTime.toString(),
          "endTime" to record.endTime.toString(),
          "floors" to record.floors
        )
      )
    }
  }

  private suspend fun readPowerRecords(
    client: HealthConnectClient,
    timeRange: TimeRangeFilter,
    limit: Int
  ): List<Map<String, Any>> {
    val request = ReadRecordsRequest(
      recordType = PowerRecord::class,
      timeRangeFilter = timeRange,
      pageSize = limit
    )
    val response = client.readRecords(request)
    return response.records.flatMap { record ->
      record.samples.map { sample ->
        mapOf(
          "sourceDataType" to "Power",
          "source" to "health_connect",
          "timestamp" to sample.time.toString(),
          "raw" to mapOf(
            "id" to record.metadata.id,
            "time" to sample.time.toString(),
            "power" to sample.power.inWatts
          )
        )
      }
    }
  }

  private suspend fun readSpeedRecords(
    client: HealthConnectClient,
    timeRange: TimeRangeFilter,
    limit: Int
  ): List<Map<String, Any>> {
    val request = ReadRecordsRequest(
      recordType = SpeedRecord::class,
      timeRangeFilter = timeRange,
      pageSize = limit
    )
    val response = client.readRecords(request)
    return response.records.flatMap { record ->
      record.samples.map { sample ->
        mapOf(
          "sourceDataType" to "Speed",
          "source" to "health_connect",
          "timestamp" to sample.time.toString(),
          "raw" to mapOf(
            "id" to record.metadata.id,
            "time" to sample.time.toString(),
            "speed" to sample.speed.inMetersPerSecond
          )
        )
      }
    }
  }

  private suspend fun readWheelchairPushesRecords(
    client: HealthConnectClient,
    timeRange: TimeRangeFilter,
    limit: Int
  ): List<Map<String, Any>> {
    val request = ReadRecordsRequest(
      recordType = WheelchairPushesRecord::class,
      timeRangeFilter = timeRange,
      pageSize = limit
    )
    val response = client.readRecords(request)
    return response.records.map { record ->
      mapOf(
        "sourceDataType" to "WheelchairPushes",
        "source" to "health_connect",
        "timestamp" to record.startTime.toString(),
        "endTimestamp" to record.endTime.toString(),
        "raw" to mapOf(
          "id" to record.metadata.id,
          "startTime" to record.startTime.toString(),
          "endTime" to record.endTime.toString(),
          "count" to record.count
        )
      )
    }
  }

  // Body Measurement Records

  private suspend fun readBodyFatRecords(
    client: HealthConnectClient,
    timeRange: TimeRangeFilter,
    limit: Int
  ): List<Map<String, Any>> {
    val request = ReadRecordsRequest(
      recordType = BodyFatRecord::class,
      timeRangeFilter = timeRange,
      pageSize = limit
    )
    val response = client.readRecords(request)
    return response.records.map { record ->
      mapOf(
        "sourceDataType" to "BodyFat",
        "source" to "health_connect",
        "timestamp" to record.time.toString(),
        "raw" to mapOf(
          "id" to record.metadata.id,
          "time" to record.time.toString(),
          "percentage" to record.percentage.value
        )
      )
    }
  }

  private suspend fun readBodyWaterMassRecords(
    client: HealthConnectClient,
    timeRange: TimeRangeFilter,
    limit: Int
  ): List<Map<String, Any>> {
    val request = ReadRecordsRequest(
      recordType = BodyWaterMassRecord::class,
      timeRangeFilter = timeRange,
      pageSize = limit
    )
    val response = client.readRecords(request)
    return response.records.map { record ->
      mapOf(
        "sourceDataType" to "BodyWaterMass",
        "source" to "health_connect",
        "timestamp" to record.time.toString(),
        "raw" to mapOf(
          "id" to record.metadata.id,
          "time" to record.time.toString(),
          "mass" to record.mass.inKilograms
        )
      )
    }
  }

  private suspend fun readBoneMassRecords(
    client: HealthConnectClient,
    timeRange: TimeRangeFilter,
    limit: Int
  ): List<Map<String, Any>> {
    val request = ReadRecordsRequest(
      recordType = BoneMassRecord::class,
      timeRangeFilter = timeRange,
      pageSize = limit
    )
    val response = client.readRecords(request)
    return response.records.map { record ->
      mapOf(
        "sourceDataType" to "BoneMass",
        "source" to "health_connect",
        "timestamp" to record.time.toString(),
        "raw" to mapOf(
          "id" to record.metadata.id,
          "time" to record.time.toString(),
          "mass" to record.mass.inKilograms
        )
      )
    }
  }

  private suspend fun readLeanBodyMassRecords(
    client: HealthConnectClient,
    timeRange: TimeRangeFilter,
    limit: Int
  ): List<Map<String, Any>> {
    val request = ReadRecordsRequest(
      recordType = LeanBodyMassRecord::class,
      timeRangeFilter = timeRange,
      pageSize = limit
    )
    val response = client.readRecords(request)
    return response.records.map { record ->
      mapOf(
        "sourceDataType" to "LeanBodyMass",
        "source" to "health_connect",
        "timestamp" to record.time.toString(),
        "raw" to mapOf(
          "id" to record.metadata.id,
          "time" to record.time.toString(),
          "mass" to record.mass.inKilograms
        )
      )
    }
  }

  private suspend fun readBasalMetabolicRateRecords(
    client: HealthConnectClient,
    timeRange: TimeRangeFilter,
    limit: Int
  ): List<Map<String, Any>> {
    val request = ReadRecordsRequest(
      recordType = BasalMetabolicRateRecord::class,
      timeRangeFilter = timeRange,
      pageSize = limit
    )
    val response = client.readRecords(request)
    return response.records.map { record ->
      mapOf(
        "sourceDataType" to "BasalMetabolicRate",
        "source" to "health_connect",
        "timestamp" to record.time.toString(),
        "raw" to mapOf(
          "id" to record.metadata.id,
          "time" to record.time.toString(),
          "bmr" to record.basalMetabolicRate.inKilocaloriesPerDay
        )
      )
    }
  }

  // Vitals Records

  private suspend fun readRestingHeartRateRecords(
    client: HealthConnectClient,
    timeRange: TimeRangeFilter,
    limit: Int
  ): List<Map<String, Any>> {
    val request = ReadRecordsRequest(
      recordType = RestingHeartRateRecord::class,
      timeRangeFilter = timeRange,
      pageSize = limit
    )
    val response = client.readRecords(request)
    return response.records.map { record ->
      mapOf(
        "sourceDataType" to "RestingHeartRate",
        "source" to "health_connect",
        "timestamp" to record.time.toString(),
        "raw" to mapOf(
          "id" to record.metadata.id,
          "time" to record.time.toString(),
          "bpm" to record.beatsPerMinute
        )
      )
    }
  }

  private suspend fun readBloodGlucoseRecords(
    client: HealthConnectClient,
    timeRange: TimeRangeFilter,
    limit: Int
  ): List<Map<String, Any>> {
    val request = ReadRecordsRequest(
      recordType = BloodGlucoseRecord::class,
      timeRangeFilter = timeRange,
      pageSize = limit
    )
    val response = client.readRecords(request)
    return response.records.map { record ->
      mapOf(
        "sourceDataType" to "BloodGlucose",
        "source" to "health_connect",
        "timestamp" to record.time.toString(),
        "raw" to mapOf(
          "id" to record.metadata.id,
          "time" to record.time.toString(),
          "level" to record.level.inMillimolesPerLiter,
          "specimenSource" to record.specimenSource,
          "mealType" to record.mealType,
          "relationToMeal" to record.relationToMeal
        )
      )
    }
  }

  private suspend fun readRespiratoryRateRecords(
    client: HealthConnectClient,
    timeRange: TimeRangeFilter,
    limit: Int
  ): List<Map<String, Any>> {
    val request = ReadRecordsRequest(
      recordType = RespiratoryRateRecord::class,
      timeRangeFilter = timeRange,
      pageSize = limit
    )
    val response = client.readRecords(request)
    return response.records.map { record ->
      mapOf(
        "sourceDataType" to "RespiratoryRate",
        "source" to "health_connect",
        "timestamp" to record.time.toString(),
        "raw" to mapOf(
          "id" to record.metadata.id,
          "time" to record.time.toString(),
          "rate" to record.rate
        )
      )
    }
  }

  private suspend fun readBasalBodyTemperatureRecords(
    client: HealthConnectClient,
    timeRange: TimeRangeFilter,
    limit: Int
  ): List<Map<String, Any>> {
    val request = ReadRecordsRequest(
      recordType = BasalBodyTemperatureRecord::class,
      timeRangeFilter = timeRange,
      pageSize = limit
    )
    val response = client.readRecords(request)
    return response.records.map { record ->
      mapOf(
        "sourceDataType" to "BasalBodyTemperature",
        "source" to "health_connect",
        "timestamp" to record.time.toString(),
        "raw" to mapOf(
          "id" to record.metadata.id,
          "time" to record.time.toString(),
          "temperature" to record.temperature.inCelsius,
          "measurementLocation" to record.measurementLocation
        )
      )
    }
  }

  // Nutrition & Hydration Records

  private suspend fun readNutritionRecords(
    client: HealthConnectClient,
    timeRange: TimeRangeFilter,
    limit: Int
  ): List<Map<String, Any>> {
    val request = ReadRecordsRequest(
      recordType = NutritionRecord::class,
      timeRangeFilter = timeRange,
      pageSize = limit
    )
    val response = client.readRecords(request)
    return response.records.map { record ->
      mapOf(
        "sourceDataType" to "Nutrition",
        "source" to "health_connect",
        "timestamp" to record.startTime.toString(),
        "endTimestamp" to record.endTime.toString(),
        "raw" to mapOf(
          "id" to record.metadata.id,
          "startTime" to record.startTime.toString(),
          "endTime" to record.endTime.toString(),
          "name" to (record.name ?: ""),
          "mealType" to record.mealType,
          "energy" to record.energy?.inKilocalories,
          "protein" to record.protein?.inGrams,
          "totalCarbohydrate" to record.totalCarbohydrate?.inGrams,
          "totalFat" to record.totalFat?.inGrams
        )
      )
    }
  }

  private suspend fun readHydrationRecords(
    client: HealthConnectClient,
    timeRange: TimeRangeFilter,
    limit: Int
  ): List<Map<String, Any>> {
    val request = ReadRecordsRequest(
      recordType = HydrationRecord::class,
      timeRangeFilter = timeRange,
      pageSize = limit
    )
    val response = client.readRecords(request)
    return response.records.map { record ->
      mapOf(
        "sourceDataType" to "Hydration",
        "source" to "health_connect",
        "timestamp" to record.startTime.toString(),
        "endTimestamp" to record.endTime.toString(),
        "raw" to mapOf(
          "id" to record.metadata.id,
          "startTime" to record.startTime.toString(),
          "endTime" to record.endTime.toString(),
          "volume" to record.volume.inLiters
        )
      )
    }
  }

  // Cycle Tracking Records

  private suspend fun readMenstruationFlowRecords(
    client: HealthConnectClient,
    timeRange: TimeRangeFilter,
    limit: Int
  ): List<Map<String, Any>> {
    val request = ReadRecordsRequest(
      recordType = MenstruationFlowRecord::class,
      timeRangeFilter = timeRange,
      pageSize = limit
    )
    val response = client.readRecords(request)
    return response.records.map { record ->
      mapOf(
        "sourceDataType" to "MenstruationFlow",
        "source" to "health_connect",
        "timestamp" to record.time.toString(),
        "raw" to mapOf(
          "id" to record.metadata.id,
          "time" to record.time.toString(),
          "flow" to record.flow
        )
      )
    }
  }

  private suspend fun readOvulationTestRecords(
    client: HealthConnectClient,
    timeRange: TimeRangeFilter,
    limit: Int
  ): List<Map<String, Any>> {
    val request = ReadRecordsRequest(
      recordType = OvulationTestRecord::class,
      timeRangeFilter = timeRange,
      pageSize = limit
    )
    val response = client.readRecords(request)
    return response.records.map { record ->
      mapOf(
        "sourceDataType" to "OvulationTest",
        "source" to "health_connect",
        "timestamp" to record.time.toString(),
        "raw" to mapOf(
          "id" to record.metadata.id,
          "time" to record.time.toString(),
          "result" to record.result
        )
      )
    }
  }

  private suspend fun readCervicalMucusRecords(
    client: HealthConnectClient,
    timeRange: TimeRangeFilter,
    limit: Int
  ): List<Map<String, Any>> {
    val request = ReadRecordsRequest(
      recordType = CervicalMucusRecord::class,
      timeRangeFilter = timeRange,
      pageSize = limit
    )
    val response = client.readRecords(request)
    return response.records.map { record ->
      mapOf(
        "sourceDataType" to "CervicalMucus",
        "source" to "health_connect",
        "timestamp" to record.time.toString(),
        "raw" to mapOf(
          "id" to record.metadata.id,
          "time" to record.time.toString(),
          "appearance" to record.appearance,
          "sensation" to record.sensation
        )
      )
    }
  }

  private suspend fun readIntermenstrualBleedingRecords(
    client: HealthConnectClient,
    timeRange: TimeRangeFilter,
    limit: Int
  ): List<Map<String, Any>> {
    val request = ReadRecordsRequest(
      recordType = IntermenstrualBleedingRecord::class,
      timeRangeFilter = timeRange,
      pageSize = limit
    )
    val response = client.readRecords(request)
    return response.records.map { record ->
      mapOf(
        "sourceDataType" to "IntermenstrualBleeding",
        "source" to "health_connect",
        "timestamp" to record.time.toString(),
        "raw" to mapOf(
          "id" to record.metadata.id,
          "time" to record.time.toString()
        )
      )
    }
  }

  private suspend fun readSexualActivityRecords(
    client: HealthConnectClient,
    timeRange: TimeRangeFilter,
    limit: Int
  ): List<Map<String, Any>> {
    val request = ReadRecordsRequest(
      recordType = SexualActivityRecord::class,
      timeRangeFilter = timeRange,
      pageSize = limit
    )
    val response = client.readRecords(request)
    return response.records.map { record ->
      mapOf(
        "sourceDataType" to "SexualActivity",
        "source" to "health_connect",
        "timestamp" to record.time.toString(),
        "raw" to mapOf(
          "id" to record.metadata.id,
          "time" to record.time.toString(),
          "protectionUsed" to record.protectionUsed
        )
      )
    }
  }

  // Fitness Records

  private suspend fun readVo2MaxRecords(
    client: HealthConnectClient,
    timeRange: TimeRangeFilter,
    limit: Int
  ): List<Map<String, Any>> {
    val request = ReadRecordsRequest(
      recordType = Vo2MaxRecord::class,
      timeRangeFilter = timeRange,
      pageSize = limit
    )
    val response = client.readRecords(request)
    return response.records.map { record ->
      mapOf(
        "sourceDataType" to "Vo2Max",
        "source" to "health_connect",
        "timestamp" to record.time.toString(),
        "raw" to mapOf(
          "id" to record.metadata.id,
          "time" to record.time.toString(),
          "vo2" to record.vo2MillilitersPerMinuteKilogram,
          "measurementMethod" to record.measurementMethod
        )
      )
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity
    activityPluginBinding = binding
    binding.addActivityResultListener(this)

    // CRITICAL: Register ActivityResultLauncher for Health Connect permissions
    // This MUST be done in onAttachedToActivity, before the activity is created
    // Using the official Health Connect permission contract
    // IMPORTANT: MainActivity must extend FlutterFragmentActivity (which is a ComponentActivity)
    val componentActivity = binding.activity as? ComponentActivity
    if (componentActivity == null) {
      android.util.Log.e(
        "HealthSyncFlutter",
        "Activity is not a ComponentActivity. MainActivity must extend FlutterFragmentActivity!"
      )
      return
    }

    val permissionContract = PermissionController.createRequestPermissionResultContract()

    permissionLauncher = componentActivity.registerForActivityResult(permissionContract) { grantedPermissions ->
      // This callback is invoked when user completes the permission flow
      // grantedPermissions is a Set<String> of Health Connect permission strings

      // Convert granted Health Connect permissions back to our permission names
      val grantedPermissionNames = requestedPermissions.filter { permName ->
        permissionToRecordClass(permName)?.let { recordClass ->
          grantedPermissions.contains(HealthPermission.getReadPermission(recordClass))
        } ?: false
      }

      // Return result to Flutter
      pendingPermissionResult?.success(grantedPermissionNames)
      pendingPermissionResult = null
      requestedPermissions = emptySet()
      permissionRequestStartTime = 0
    }
  }

  override fun onDetachedFromActivityForConfigChanges() {
    activityPluginBinding?.removeActivityResultListener(this)
    activity = null
    activityPluginBinding = null
    permissionLauncher = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    activity = binding.activity
    activityPluginBinding = binding
    binding.addActivityResultListener(this)

    // Re-register the permission launcher after config changes
    val componentActivity = binding.activity as? ComponentActivity
    if (componentActivity == null) {
      android.util.Log.e(
        "HealthSyncFlutter",
        "Activity is not a ComponentActivity on reattach. MainActivity must extend FlutterFragmentActivity!"
      )
      return
    }

    val permissionContract = PermissionController.createRequestPermissionResultContract()
    permissionLauncher = componentActivity.registerForActivityResult(permissionContract) { grantedPermissions ->
      val grantedPermissionNames = requestedPermissions.filter { permName ->
        permissionToRecordClass(permName)?.let { recordClass ->
          grantedPermissions.contains(HealthPermission.getReadPermission(recordClass))
        } ?: false
      }

      pendingPermissionResult?.success(grantedPermissionNames)
      pendingPermissionResult = null
      requestedPermissions = emptySet()
      permissionRequestStartTime = 0
    }
  }

  override fun onDetachedFromActivity() {
    activityPluginBinding?.removeActivityResultListener(this)
    activity = null
    activityPluginBinding = null
    permissionLauncher = null
  }

  companion object {
    private const val PERMISSION_REQUEST_CODE = 10001
    private const val PERMISSION_REQUEST_TIMEOUT_MS = 60000L // 60 seconds
  }
}
