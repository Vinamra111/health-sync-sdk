# Device Testing Guide - HealthSync SDK
**Complete Testing Procedure for Android Device**

Generated: January 7, 2026
APK Location: `test-app/build/app/outputs/flutter-apk/app-debug.apk`
APK Size: 190 MB (181 MB)
Build Type: Debug

---

## 📱 Prerequisites

### Required Hardware
- ✅ Android device with Android 8.0 (API 26) or higher
- ✅ USB cable for device connection
- ✅ Computer with ADB installed

### Required Software on Device
- ✅ **Google Health Connect** app installed
  - Download from: [Google Play Store](https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata)
  - Minimum version: 1.0.0+

### Device Setup
1. Enable **Developer Options**:
   - Go to Settings → About phone
   - Tap "Build number" 7 times
   - Developer options enabled!

2. Enable **USB Debugging**:
   - Settings → System → Developer options
   - Toggle "USB debugging" ON

3. Enable **Install via USB**:
   - Settings → System → Developer options
   - Toggle "Install via USB" ON

4. Install **Health Connect**:
   - Open Google Play Store
   - Search for "Health Connect"
   - Install the app
   - Open and complete setup

---

## 🚀 Installation Instructions

### Method 1: Via ADB (Recommended)

```bash
# 1. Connect device via USB

# 2. Verify device is connected
adb devices

# Expected output:
# List of devices attached
# ABC123XYZ    device

# 3. Install APK
adb install "C:\SDK_StandardizingHealthDataV0\test-app\build\app\outputs\flutter-apk\app-debug.apk"

# 4. Launch app
adb shell am start -n com.example.test_app/.MainActivity
```

### Method 2: Direct Transfer

```bash
# 1. Copy APK to device
adb push "C:\SDK_StandardizingHealthDataV0\test-app\build\app\outputs\flutter-apk\app-debug.apk" /sdcard/Download/

# 2. On device:
#    - Open "Files" or "My Files" app
#    - Navigate to Downloads
#    - Tap app-debug.apk
#    - Tap "Install"
#    - If prompted, allow installation from unknown sources
```

### Method 3: Via Email/Cloud

1. Email the APK to yourself
2. Open email on device
3. Download attachment
4. Tap to install
5. Allow installation from unknown sources if prompted

---

## 🧪 Test Plan Overview

```
Test Flow:
├── Phase 1: Installation & Launch        [5 min]
├── Phase 2: SDK Initialization           [5 min]
├── Phase 3: Health Connect Connection    [5 min]
├── Phase 4: Permission Check             [5 min]
├── Phase 5: Permission Request           [10 min]
├── Phase 6: Data Fetching                [10 min]
├── Phase 7: Error Scenarios              [10 min]
└── Phase 8: Results Documentation        [10 min]

Total Estimated Time: 60 minutes
```

---

## 📋 Detailed Test Cases

### Phase 1: Installation & Launch ✅

**Objective**: Verify app installs and launches successfully

**Test Cases**:

#### TC1.1: Install APK
- **Steps**:
  1. Install APK using one of the methods above
- **Expected Result**:
  - ✅ APK installs without errors
  - ✅ App icon appears in launcher
  - ✅ App name: "HealthSync Test"

#### TC1.2: Launch App
- **Steps**:
  1. Tap app icon in launcher
- **Expected Result**:
  - ✅ App opens without crash
  - ✅ Splash screen (if any) displays
  - ✅ Main screen loads
  - ✅ UI renders correctly
  - ✅ No error dialogs appear

#### TC1.3: UI Elements Visible
- **Steps**:
  1. Observe main screen
- **Expected Result**:
  - ✅ Logo/header visible
  - ✅ Connection status card visible
  - ✅ "Initialize SDK" button visible
  - ✅ All UI elements properly sized
  - ✅ No overlapping elements

**Pass Criteria**: All 3 test cases pass

---

### Phase 2: SDK Initialization ✅

**Objective**: Verify SDK initializes correctly

**Test Cases**:

#### TC2.1: Initial State
- **Steps**:
  1. Observe initial connection status
- **Expected Result**:
  - ✅ Status shows: "Disconnected"
  - ✅ Status color: Grey or Red
  - ✅ "Initialize SDK" button enabled
  - ✅ Other buttons disabled

#### TC2.2: Initialize SDK
- **Steps**:
  1. Tap "Initialize SDK" button
  2. Wait for response
- **Expected Result**:
  - ✅ Button becomes disabled during init
  - ✅ Status changes to "Connecting" (brief)
  - ✅ No crash or error
  - ✅ Success message or state change
  - ✅ Logs appear (if visible)

#### TC2.3: Post-Initialization State
- **Steps**:
  1. Observe UI after initialization
- **Expected Result**:
  - ✅ "Connect to Health Connect" button enabled
  - ✅ "Initialize SDK" button stays disabled
  - ✅ Status reflects initialized state

**Pass Criteria**: All 3 test cases pass

---

### Phase 3: Health Connect Connection ✅

**Objective**: Verify app connects to Health Connect

**Test Cases**:

#### TC3.1: Check Health Connect Availability
- **Steps**:
  1. Observe logs or status indicators
- **Expected Result**:
  - ✅ App detects Health Connect is installed
  - ✅ No "not installed" errors
  - ✅ SDK version detected (1.1.0-alpha07)

#### TC3.2: Connect to Health Connect
- **Steps**:
  1. Tap "Connect to Health Connect" button
  2. Wait for response
- **Expected Result**:
  - ✅ Button becomes disabled during connection
  - ✅ Status changes to "Connecting"
  - ✅ Status then changes to "Connected" (green)
  - ✅ No error dialogs
  - ✅ Success message displayed

#### TC3.3: Post-Connection State
- **Steps**:
  1. Observe UI after connection
- **Expected Result**:
  - ✅ Status shows "Connected" with green indicator
  - ✅ Permission buttons become enabled
  - ✅ "Check Permission Status" button enabled
  - ✅ "Request ALL Permissions" button enabled

**Pass Criteria**: All 3 test cases pass

---

### Phase 4: Permission Check ✅

**Objective**: Verify app can check permission status

**Test Cases**:

#### TC4.1: Check Permission Status (Initial)
- **Steps**:
  1. Tap "Check Permission Status" button
  2. Wait for response
- **Expected Result**:
  - ✅ Permission list displays
  - ✅ Shows ~39-42 permissions (based on SDK support)
  - ✅ All permissions show "Denied" (❌) initially
  - ✅ No crash or error

#### TC4.2: Permission List Display
- **Steps**:
  1. Scroll through permission list
- **Expected Result**:
  - ✅ Permission names are readable
  - ✅ Status icons visible (✅ or ❌)
  - ✅ List is scrollable
  - ✅ All permissions listed:
    - Steps
    - Heart Rate
    - Sleep
    - Distance
    - Exercise
    - Calories (Active + Total)
    - Blood Oxygen
    - Blood Pressure
    - Body Temperature
    - Weight
    - Height
    - Heart Rate Variability
    - Resting Heart Rate
    - And 26+ more...

#### TC4.3: Re-check Permissions
- **Steps**:
  1. Tap "Check Permission Status" again
  2. Observe changes
- **Expected Result**:
  - ✅ List updates correctly
  - ✅ Status reflects current state
  - ✅ No stale data

**Pass Criteria**: All 3 test cases pass

---

### Phase 5: Permission Request (Critical) ⚠️

**Objective**: Verify permission request flow works correctly

**IMPORTANT**: Health Connect uses an asynchronous permission model. After you tap "Allow" in the permission dialog, the app will wait **5-30 seconds** while polling for permission changes. This is normal and expected behavior. Health Connect processes permissions asynchronously through the Android system, so there's no immediate callback. The app checks every second to detect when permissions are granted.

**Test Cases**:

#### TC5.1: Request All Permissions
- **Steps**:
  1. Tap "Request ALL Permissions (42 total)" button
  2. Observe response
- **Expected Result**:
  - ✅ Health Connect permission dialog appears
  - ✅ Dialog shows list of permissions
  - ✅ Dialog allows selecting permissions
  - ✅ "Allow" and "Don't allow" buttons visible
  - ✅ No app crash

#### TC5.2: Grant Some Permissions
- **Steps**:
  1. In Health Connect dialog, select 5-10 permissions
  2. Tap "Allow"
  3. **Wait 5-30 seconds for result** (Health Connect processes permissions asynchronously)
- **Expected Result**:
  - ✅ Dialog closes immediately
  - ✅ App waits 5-30 seconds (polling for permission changes)
  - ✅ App receives callback after minimum 5 seconds
  - ✅ Success message or state update after permissions granted
  - ✅ No crash or timeout
- **NOTE**: The wait time is expected! Health Connect processes permissions asynchronously.
  The app polls every second to detect when permissions are granted.

#### TC5.3: Verify Granted Permissions
- **Steps**:
  1. Tap "Check Permission Status" again
  2. Scroll through list
- **Expected Result**:
  - ✅ Previously granted permissions show ✅
  - ✅ Denied permissions show ❌
  - ✅ Status accurately reflects grants
  - ✅ Count matches what was granted

#### TC5.4: Request Again (Should Skip Granted)
- **Steps**:
  1. Tap "Request ALL Permissions" again
  2. Observe dialog
- **Expected Result**:
  - ✅ Dialog only shows un-granted permissions
  - ✅ Already granted permissions not re-requested
  - ✅ Efficient filtering

#### TC5.5: Grant All Remaining
- **Steps**:
  1. In dialog, select all permissions
  2. Tap "Allow"
  3. Check status
- **Expected Result**:
  - ✅ All permissions granted
  - ✅ Check status shows all ✅
  - ✅ ~39 permissions granted (3 unavailable in SDK)

#### TC5.6: Concurrent Request Protection
- **Steps**:
  1. Tap "Request ALL Permissions"
  2. While dialog is open, tap button again rapidly
- **Expected Result**:
  - ✅ Second request shows error
  - ✅ Error: "Another permission request is in progress"
  - ✅ No crash
  - ✅ First dialog remains open

#### TC5.7: Timeout Test
- **Steps**:
  1. Tap "Request ALL Permissions"
  2. Don't interact with dialog for 60+ seconds
- **Expected Result**:
  - ✅ After 60 seconds, timeout error appears
  - ✅ Error: "Permission request timed out"
  - ✅ App recovers gracefully
  - ✅ Can request again

**Pass Criteria**: At least 5/7 test cases pass (TC5.1-5.5 critical)

---

### Phase 6: Data Fetching ✅

**Objective**: Verify app can fetch health data

**Prerequisites**: Steps permission granted

**Test Cases**:

#### TC6.1: Fetch Steps Data (No Data)
- **Steps**:
  1. Grant Steps permission if not already
  2. Tap "Fetch Steps Data" button
  3. Wait for response
- **Expected Result**:
  - ✅ Button becomes disabled during fetch
  - ✅ Loading indicator (optional)
  - ✅ Either:
    - Success with empty data (no steps recorded)
    - Success with data (if steps exist in Health Connect)
  - ✅ No crash

#### TC6.2: Add Sample Data in Health Connect
- **Steps**:
  1. Open Health Connect app
  2. Navigate to Steps data
  3. Add manual entry: 1000 steps for today
  4. Return to test app
  5. Tap "Fetch Steps Data"
- **Expected Result**:
  - ✅ Data fetched successfully
  - ✅ Shows 1000 steps
  - ✅ Timestamp correct
  - ✅ Data displayed in UI

#### TC6.3: Fetch Without Permission
- **Steps**:
  1. Revoke Steps permission in Health Connect
  2. Tap "Fetch Steps Data"
- **Expected Result**:
  - ✅ Error message displayed
  - ✅ Error: "Missing permissions" or similar
  - ✅ App doesn't crash
  - ✅ Error is user-friendly

#### TC6.4: Date Range Query
- **Steps**:
  1. Note current date range in app
  2. Fetch data
  3. Verify data is within range
- **Expected Result**:
  - ✅ Only data from specified range returned
  - ✅ No data from outside range

**Pass Criteria**: At least 3/4 test cases pass

---

### Phase 7: Error Scenarios ⚠️

**Objective**: Verify error handling works correctly

**Test Cases**:

#### TC7.1: Health Connect Not Installed
- **Setup**: (Cannot test without uninstalling Health Connect)
- **Skip**: Document as "Cannot test in current setup"

#### TC7.2: Permission Denial
- **Steps**:
  1. Request permissions
  2. Tap "Don't allow" in dialog
- **Expected Result**:
  - ✅ App handles denial gracefully
  - ✅ Error message or status update
  - ✅ No crash
  - ✅ Can retry

#### TC7.3: Network/Connection Loss
- **Steps**:
  1. Enable Airplane mode
  2. Try operations (should still work - local SDK)
- **Expected Result**:
  - ✅ Operations work (Health Connect is local)
  - ✅ No network errors
  - ✅ Data accessible offline

#### TC7.4: App Restart After Permissions
- **Steps**:
  1. Grant permissions
  2. Close app completely
  3. Relaunch app
  4. Check permission status
- **Expected Result**:
  - ✅ Permissions still granted
  - ✅ No need to re-grant
  - ✅ State persists

**Pass Criteria**: At least 2/4 test cases pass (TC7.2 and TC7.4 critical)

---

### Phase 8: Results Documentation 📝

**Objective**: Document all test results

**Tasks**:

1. **Take Screenshots**:
   - Initial screen
   - After initialization
   - After connection
   - Permission list
   - Permission dialog
   - After granting permissions
   - Data display
   - Any errors encountered

2. **Record Logcat Output**:
   ```bash
   # Capture logs during testing
   adb logcat -s "HealthSyncFlutter:*" "Flutter:*" > test-logs.txt
   ```

3. **Document Issues**:
   - Create file: `test-app/TEST-RESULTS-[DATE].md`
   - Log all failures
   - Note any unexpected behavior
   - Record error messages

4. **Performance Notes**:
   - App launch time
   - Permission dialog response time
   - Data fetch time
   - Any lag or freezes

---

## 🎯 Success Criteria

### Must Pass (Critical)
- ✅ App installs and launches
- ✅ SDK initializes
- ✅ Connects to Health Connect
- ✅ Permission dialog appears
- ✅ Can grant permissions
- ✅ Permissions persist after grant
- ✅ Can check permission status
- ✅ Can fetch data with granted permissions

### Should Pass (Important)
- ✅ All 39 available permissions mappable
- ✅ Permission list updates correctly
- ✅ Error messages are clear
- ✅ No crashes during normal use
- ✅ Concurrent request protection works
- ✅ Timeout mechanism works

### Nice to Have (Optional)
- ✅ UI animations smooth
- ✅ Fast response times
- ✅ Detailed logging visible

---

## 📊 Test Results Template

```markdown
# Test Results - HealthSync SDK
**Date**: [Date]
**Tester**: [Name]
**Device**: [Model]
**Android Version**: [Version]
**Health Connect Version**: [Version]

## Summary
- Total Test Cases: 27
- Passed: [X]
- Failed: [Y]
- Skipped: [Z]
- Pass Rate: [X/27 * 100]%

## Phase 1: Installation & Launch
- TC1.1: ☐ Pass ☐ Fail - [Notes]
- TC1.2: ☐ Pass ☐ Fail - [Notes]
- TC1.3: ☐ Pass ☐ Fail - [Notes]

## Phase 2: SDK Initialization
- TC2.1: ☐ Pass ☐ Fail - [Notes]
- TC2.2: ☐ Pass ☐ Fail - [Notes]
- TC2.3: ☐ Pass ☐ Fail - [Notes]

## Phase 3: Health Connect Connection
- TC3.1: ☐ Pass ☐ Fail - [Notes]
- TC3.2: ☐ Pass ☐ Fail - [Notes]
- TC3.3: ☐ Pass ☐ Fail - [Notes]

## Phase 4: Permission Check
- TC4.1: ☐ Pass ☐ Fail - [Notes]
- TC4.2: ☐ Pass ☐ Fail - [Notes]
- TC4.3: ☐ Pass ☐ Fail - [Notes]

## Phase 5: Permission Request
- TC5.1: ☐ Pass ☐ Fail - [Notes]
- TC5.2: ☐ Pass ☐ Fail - [Notes]
- TC5.3: ☐ Pass ☐ Fail - [Notes]
- TC5.4: ☐ Pass ☐ Fail - [Notes]
- TC5.5: ☐ Pass ☐ Fail - [Notes]
- TC5.6: ☐ Pass ☐ Fail - [Notes]
- TC5.7: ☐ Pass ☐ Fail - [Notes]

## Phase 6: Data Fetching
- TC6.1: ☐ Pass ☐ Fail - [Notes]
- TC6.2: ☐ Pass ☐ Fail - [Notes]
- TC6.3: ☐ Pass ☐ Fail - [Notes]
- TC6.4: ☐ Pass ☐ Fail - [Notes]

## Phase 7: Error Scenarios
- TC7.1: ☐ Pass ☐ Fail ☐ Skip - [Notes]
- TC7.2: ☐ Pass ☐ Fail - [Notes]
- TC7.3: ☐ Pass ☐ Fail - [Notes]
- TC7.4: ☐ Pass ☐ Fail - [Notes]

## Issues Found
1. [Issue description]
   - Severity: High/Medium/Low
   - Steps to reproduce: [Steps]
   - Expected: [Expected]
   - Actual: [Actual]
   - Screenshot: [Link/Path]

2. [Issue description]
   ...

## Recommendations
- [Recommendation 1]
- [Recommendation 2]

## Screenshots
[Attach all screenshots here]

## Logs
[Attach log file or paste relevant logs]

## Conclusion
[Overall assessment: Pass/Fail with notes]
```

---

## 🔧 Troubleshooting

### Issue: APK Won't Install
**Solution**:
- Check device has enough storage (200+ MB free)
- Enable "Install from unknown sources"
- Try uninstalling previous version first

### Issue: App Crashes on Launch
**Solution**:
- Check logcat for errors: `adb logcat`
- Verify Android version (must be 8.0+)
- Reinstall the app

### Issue: Health Connect Dialog Doesn't Appear
**Solution**:
- Verify Health Connect app is installed
- Check Health Connect app is up to date
- Restart Health Connect app
- Grant notification permissions to test app

### Issue: Permissions Don't Persist
**Solution**:
- Check Health Connect settings
- Verify app signature (debug vs release)
- Clear Health Connect cache and retry

### Issue: Cannot Fetch Data
**Solution**:
- Verify permission is granted in Health Connect app
- Check if Health Connect has any data
- Add manual test data in Health Connect
- Check date range in query

---

## 📱 ADB Useful Commands

```bash
# Check device connection
adb devices

# Install APK
adb install path/to/app-debug.apk

# Reinstall (keep data)
adb install -r path/to/app-debug.apk

# Uninstall app
adb uninstall com.example.test_app

# Launch app
adb shell am start -n com.example.test_app/.MainActivity

# Stop app
adb shell am force-stop com.example.test_app

# View logs (filtered)
adb logcat -s "HealthSyncFlutter:*" "Flutter:*"

# Clear logs
adb logcat -c

# Save logs to file
adb logcat > test-logs.txt

# Take screenshot
adb shell screencap -p /sdcard/screenshot.png
adb pull /sdcard/screenshot.png

# View device info
adb shell getprop ro.build.version.release  # Android version
adb shell getprop ro.product.model           # Device model
```

---

## 📌 Important Notes

### Supported Permissions
**Currently Supported**: 39 permissions
- All core Health Connect permissions work
- 3 future permissions return null (SDK limitations):
  - `READ_PLANNED_EXERCISE` (coming in future SDK)
  - `READ_SKIN_TEMPERATURE` (coming in future SDK)
  - `READ_MINDFULNESS` (coming in future SDK)

### Known Limitations
1. **No iOS Support**: This is Android-only currently
2. **Debug Build**: APK is larger, includes debug symbols
3. **Local SDK**: No cloud APIs tested yet (Fitbit, Garmin, etc.)
4. **Test Data**: May need to manually add data in Health Connect

### Safety Notes
- ✅ This is a test app - safe to install
- ✅ No data leaves your device
- ✅ All data access is local
- ✅ No backend, no cloud sync
- ✅ Can uninstall anytime without side effects

---

## ✅ Post-Testing Checklist

After completing all tests:

- [ ] All screenshots captured
- [ ] Logs saved
- [ ] Test results documented
- [ ] Issues logged with details
- [ ] Performance notes recorded
- [ ] Recommendations documented
- [ ] Results shared with team
- [ ] APK archived for reference

---

## 🚀 Next Steps After Testing

1. **If all tests pass**:
   - Publish results
   - Update SDK-STATUS.md
   - Proceed to production build
   - Plan iOS development

2. **If issues found**:
   - Log all issues in detail
   - Prioritize fixes (critical → high → medium → low)
   - Fix critical issues first
   - Retest after fixes
   - Document workarounds for known issues

3. **Performance optimization** (if needed):
   - Profile memory usage
   - Optimize data queries
   - Reduce APK size
   - Improve load times

---

**Good luck with testing! 🎉**

For questions or issues, refer to:
- `INTEGRATION-GUIDE.md` - Technical details
- `SDK-STATUS.md` - Current status
- `TEST-PLAN.md` - Original test plan

---

*Last Updated: January 7, 2026*
*APK Version: Debug (v1.0.0)*
*Tester: [Your Name]*
