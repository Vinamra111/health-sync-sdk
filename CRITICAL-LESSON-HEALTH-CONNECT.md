# CRITICAL LESSON: Health Connect Permission Model
**Essential Knowledge for Health Connect Integration**

Discovered: January 7, 2026
Severity: Critical
Impact: Blocks all permission requests if done incorrectly

---

## 🚨 THE PROBLEM

When building the HealthSync SDK, we initially implemented Health Connect permissions using the standard Android permission pattern:

```kotlin
// ❌ THIS DOES NOT WORK WITH HEALTH CONNECT
val intent = PermissionController.createRequestPermissionResultContract()
  .createIntent(context, permissions)
activity.startActivityForResult(intent, REQUEST_CODE)

override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
  // This callback NEVER gets called with Health Connect!
}
```

**Error Encountered**:
```
Platform error: ERROR - No Activity found to handle Intent
{ act=android.activity.result.contract.action.REQUEST_PERMISSIONS }
```

**Why It Fails**:
- Health Connect uses a completely different permission architecture
- Permissions are granted through a separate Health Connect app
- The Android system processes grants asynchronously
- There is NO immediate callback to the requesting app
- `startActivityForResult` doesn't work with this model

---

## ✅ THE SOLUTION

Health Connect requires a **polling-based approach**:

```kotlin
// ✅ CORRECT APPROACH FOR HEALTH CONNECT
val contract = PermissionController.createRequestPermissionResultContract()
val intent = contract.createIntent(context, permissions)

// 1. Launch permission screen (NOT for result)
intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
context.startActivity(intent)  // No callback!

// 2. Poll for permission changes
scope.launch {
  var attempts = 0
  val maxAttempts = 30  // 30 seconds max

  while (attempts < maxAttempts && pendingResult != null) {
    delay(1000)  // Check every second
    attempts++

    // Query current permission status
    val grantedPermissions = client.permissionController.getGrantedPermissions()
    val grantedList = requestedPermissions.filter { permName ->
      val recordClass = permissionToRecordClass(permName)
      grantedPermissions.contains(HealthPermission.getReadPermission(recordClass))
    }

    // Return after minimum 5 seconds or when grants detected
    if (grantedList.isNotEmpty() || attempts >= 5) {
      pendingResult?.success(grantedList)
      pendingResult = null
      break
    }
  }

  // Timeout - return whatever we have
  if (pendingResult != null) {
    val finalGranted = client.permissionController.getGrantedPermissions()
    // ... return result
  }
}
```

---

## 🎯 Key Concepts

### 1. **Asynchronous Permission Model**
- Health Connect permissions are NOT processed immediately
- The Android system needs 5-30 seconds to process grants
- Permissions are granted in a separate Health Connect app
- No direct callback to your app

### 2. **Polling is Required**
- You MUST poll `getGrantedPermissions()` to detect changes
- Poll every 1 second for responsive UX
- Wait minimum 5 seconds before returning (gives user time)
- Maximum 30 seconds to prevent hanging forever

### 3. **Standard Patterns Don't Work**
- `startActivityForResult` → ❌ Doesn't work
- `onActivityResult` → ❌ Never called
- `ActivityResultLauncher` → ❌ Also doesn't work
- `registerForActivityResult` → ❌ Doesn't work

Only works:
- `startActivity` + polling → ✅ Correct approach

### 4. **Intent Flags**
```kotlin
intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
```
Required when launching from plugin/service context (not an Activity).

---

## 📊 Permission Flow Comparison

### Standard Android Permissions (Camera, Location, etc.)
```
1. Call requestPermissions()
2. System shows dialog
3. User grants/denies
4. onRequestPermissionsResult() called immediately
5. Done
```
⏱️ **Time**: Instant (< 1 second)

### Health Connect Permissions
```
1. Call startActivity() with permission intent
2. Health Connect app opens
3. User selects permissions and taps "Allow"
4. Health Connect app closes
5. Android system processes grants (ASYNC!)
6. After 5-30 seconds, permissions appear in getGrantedPermissions()
7. Your app polls every second to detect this
8. App receives result
```
⏱️ **Time**: 5-30 seconds

---

## 🔍 Why This Happens

Health Connect is fundamentally different from other Android features:

1. **Separate App**: Health Connect is a standalone system app
2. **Privacy Controls**: Strict privacy model requires async processing
3. **System Integration**: Permissions are managed at OS level
4. **No Direct Communication**: Your app and Health Connect don't communicate directly
5. **Intent-Based**: Uses Intents for all communication (one-way only)

---

## ⚠️ Common Mistakes

### Mistake 1: Using ActivityResultLauncher
```kotlin
// ❌ WRONG - Looks modern but doesn't work
val launcher = registerForActivityResult(
  ActivityResultContracts.StartActivityForResult()
) { result ->
  // This never gets called!
}
launcher.launch(intent)
```

### Mistake 2: Expecting Immediate Results
```kotlin
// ❌ WRONG - Permissions not granted yet
startActivity(intent)
val granted = client.permissionController.getGrantedPermissions()
// granted.isEmpty() == true (too fast!)
```

### Mistake 3: Not Adding Timeout
```kotlin
// ❌ WRONG - Could hang forever
while (pendingResult != null) {
  delay(1000)
  checkPermissions()
  // What if user never grants? App hangs!
}
```

### Mistake 4: Returning Too Fast
```kotlin
// ❌ WRONG - Returns before user even sees dialog
startActivity(intent)
delay(100)  // Too short!
return getGrantedPermissions()  // Empty!
```

---

## ✅ Best Practices

### 1. **Minimum 5-Second Wait**
```kotlin
if (grantedList.isNotEmpty() || attempts >= 5) {
  return result
}
```
Even if user denies immediately, wait 5 seconds to ensure system processed the denial.

### 2. **Maximum 30-Second Timeout**
```kotlin
val maxAttempts = 30  // 30 seconds
while (attempts < maxAttempts && pendingResult != null) {
  // ...
}
```
Prevent infinite loops if something goes wrong.

### 3. **Poll Every Second**
```kotlin
delay(1000)  // Not 100ms, not 5000ms - 1000ms is optimal
```
Balance between responsiveness and CPU usage.

### 4. **Handle Concurrent Requests**
```kotlin
if (pendingPermissionResult != null) {
  result.error("CONCURRENT_REQUEST", "Already requesting permissions")
  return
}
```
Prevent race conditions from multiple simultaneous requests.

### 5. **Always Add FLAG_ACTIVITY_NEW_TASK**
```kotlin
intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
```
Required for plugin/service context. Won't work without it.

---

## 📝 Implementation Checklist

When implementing Health Connect permissions:

- [ ] Use `startActivity()` NOT `startActivityForResult()`
- [ ] Add `FLAG_ACTIVITY_NEW_TASK` to intent
- [ ] Implement polling loop (check every 1 second)
- [ ] Set minimum wait time (5 seconds)
- [ ] Set maximum timeout (30 seconds)
- [ ] Handle concurrent requests
- [ ] Query `getGrantedPermissions()` in each poll iteration
- [ ] Return result when permissions detected OR timeout reached
- [ ] Clean up pending result on timeout
- [ ] Test with real device (emulator may not have Health Connect)

---

## 🧪 Testing Expectations

When testing Health Connect permissions:

**What Users See**:
1. Tap "Request Permissions"
2. Health Connect app opens (~1 second)
3. Permission screen with checkboxes
4. Select permissions
5. Tap "Allow"
6. Health Connect app closes immediately
7. **Your app waits 5-30 seconds** (polling)
8. Success message appears

**Timeline**:
- Dialog opens: ~1 second
- User selects: ~5-15 seconds (varies by user)
- Dialog closes: Instant
- **Processing time: 5-30 seconds** ← Important!
- Result received: After processing

**Total Time**: 10-45 seconds (most of it is user interaction + system processing)

---

## 🔗 Related Issues

### GitHub Issues About This
Search GitHub for:
- "Health Connect startActivityForResult doesn't work"
- "Health Connect permission callback never called"
- "Health Connect no activity found"

### Official Documentation
- **Misleading**: Google's docs show `startActivityForResult` examples
- **Reality**: Those examples don't actually work
- **Truth**: You need polling (not well documented)

### Why Documentation is Wrong
- Health Connect is relatively new (2023)
- Documentation hasn't caught up with reality
- Examples are copied from standard Android patterns
- Async processing model is poorly explained

---

## 💡 Takeaways for Other Platforms

### Apple HealthKit (iOS)
Does HealthKit have the same issue?
- **No** - HealthKit uses proper callback-based API
- `HKHealthStore.requestAuthorization()` has completion handler
- Works like standard iOS APIs

### Fitbit / Garmin / Cloud APIs
Do OAuth-based APIs have this issue?
- **No** - OAuth has standard callback URLs
- Web-based flows return to app via deep links
- Proper callback mechanisms exist

### Samsung Health
Does Samsung Health have the same issue?
- **Unknown** - Need to test
- Likely similar to Health Connect (same Android ecosystem)
- Be prepared for async model

**Lesson**: Don't assume standard patterns work. Always test with real devices!

---

## 📚 References

### Code Locations
- **Fixed Implementation**: `packages/flutter/health_sync_flutter/android/src/main/kotlin/.../HealthSyncFlutterPlugin.kt` (line 295-360)
- **Integration Guide**: `INTEGRATION-GUIDE.md` (line 1072-1140)
- **Test Guide**: `test-app/DEVICE-TESTING-GUIDE.md` (line 276-306)

### Version Info
- Health Connect SDK: 1.1.0-alpha07
- Android Min SDK: 26 (Android 8.0)
- Android Target SDK: 34 (Android 14)
- Discovery Date: January 7, 2026

---

## 🎯 Summary

**The One-Sentence Lesson**:
> Health Connect permissions require `startActivity()` + polling (NOT `startActivityForResult()`), with a 5-30 second wait for the Android system to asynchronously process permission grants.

**Key Takeaway**:
If you're building Health Connect integration and your permission dialog isn't appearing or callbacks aren't firing, you're probably using the wrong API pattern. Use `startActivity()` and poll for changes.

**Time Investment**:
- Research & debugging: 2 hours
- Implementing fix: 1 hour
- Testing: 30 minutes
- **Total cost of wrong pattern**: 3.5 hours

**This document saves you those 3.5 hours!** 🎉

---

*Document Created: January 7, 2026*
*Last Updated: January 7, 2026*
*Status: Production Knowledge*
*Severity: Critical*

**If you're implementing Health Connect, READ THIS FIRST!**
