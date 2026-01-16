# HealthSync SDK Test App

**Production-ready test application for validating the HealthSync Flutter SDK**

---

## Purpose

This app is designed to thoroughly test the HealthSync Flutter SDK in a real-world scenario. It validates:

✅ **SDK Integration** - Proper package installation and imports
✅ **Initialization** - SDK initialization flow
✅ **Connection** - Health Connect connection management
✅ **Permissions** - Permission request and status checking
✅ **Data Fetching** - Fetching steps data from Health Connect
✅ **Error Handling** - All error scenarios (connection, permission, data fetch)
✅ **UI/UX** - Production-quality user interface
✅ **Platform Integration** - Android Health Connect integration

---

## Features

### Test Coverage

- **SDK Initialization Test**
  - Initialize plugin
  - Check Health Connect availability
  - Error handling

- **Connection Test**
  - Connect to Health Connect
  - Connection state management
  - Connection error handling

- **Permission Test**
  - Request steps permission
  - Check permission status
  - Permission denial handling
  - Multiple permission checking

- **Data Fetching Test**
  - Fetch last 7 days of steps data
  - Display in scrollable list
  - Handle no data scenario
  - Error handling (authentication, connection)

### UI Features

- **Status Card** - Shows current SDK state (initialized/connected)
- **Health Connect Availability** - Displays availability status
- **Action Buttons** - Clear buttons for each test action
- **Permission Status** - Visual indicators for each permission
- **Steps Data List** - Beautiful display of fetched data
- **SDK Information** - Shows package and platform details
- **Loading States** - Proper loading indicators
- **Snackbar Notifications** - Success/error/warning messages

---

## Prerequisites

- Flutter 3.0.0+
- Dart 3.0.0+
- Android device/emulator with Android 14+ (API 34)
- Health Connect app installed on device

---

## Installation

### 1. Install Dependencies

```bash
cd test-app
flutter pub get
```

### 2. Verify Configuration

Check that `android/app/build.gradle` has:
- `compileSdkVersion 34`
- `minSdkVersion 26`
- `targetSdkVersion 34`
- Health Connect dependency

Check that `AndroidManifest.xml` has:
- All 13 Health Connect permissions
- Activity alias for permission rationale

### 3. Build APK

```bash
flutter build apk --debug
```

Or for release:
```bash
flutter build apk --release
```

---

## Running the App

### On Emulator

```bash
flutter run
```

### On Physical Device

1. Enable USB debugging on device
2. Connect device via USB
3. Run:
```bash
flutter run
```

### Install APK Directly

```bash
flutter build apk --debug
adb install build/app/outputs/flutter-apk/app-debug.apk
```

---

## Using the App

### Step-by-Step Test Flow

1. **Launch App**
   - App auto-initializes SDK on startup
   - Status card shows initialization result

2. **Check Health Connect Availability**
   - Look at status card
   - Should show "Health Connect: installed"
   - If not, install Health Connect from Play Store

3. **Connect to Health Connect**
   - Tap "Connect to Health Connect"
   - Wait for connection result
   - Status should change to "Connected"

4. **Request Steps Permission**
   - Tap "Request Steps Permission"
   - System permission dialog appears
   - Grant permission
   - Permission status card updates

5. **Fetch Steps Data**
   - Tap "Fetch Steps Data (Last 7 Days)"
   - Wait for data to load
   - Steps data appears in scrollable list

6. **Verify Results**
   - Check steps data accuracy
   - Verify timestamps
   - Check step counts

### Expected Behavior

**✅ Success Flow:**
```
Not Initialized
   ↓ [Initialize SDK]
Initialized
   ↓ [Connect to Health Connect]
Connected
   ↓ [Request Steps Permission]
Permission Granted
   ↓ [Fetch Steps Data]
Data Displayed (X records)
```

**❌ Error Scenarios:**

- **Health Connect Not Installed**
  - Shows "Health Connect: notAvailable"
  - Error snackbar
  - Cannot proceed

- **Permission Denied**
  - Shows "Permission denied" message
  - Data fetch fails with authentication error
  - Can retry permission request

- **No Data Available**
  - Shows "No steps data found"
  - Empty state in data card
  - Valid scenario (no steps recorded)

---

## Testing Checklist

### Basic Tests

- [ ] App launches successfully
- [ ] SDK initializes without errors
- [ ] Health Connect availability detected correctly
- [ ] Connection succeeds
- [ ] Permission request shows system dialog
- [ ] Permission grant is detected
- [ ] Steps data fetches successfully
- [ ] Data displays in correct format
- [ ] Timestamps are accurate

### Error Handling Tests

- [ ] Test with Health Connect not installed
- [ ] Test with permission denied
- [ ] Test with no internet connection
- [ ] Test with no Health Connect data
- [ ] Test connection failure
- [ ] Test data fetch failure

### UI/UX Tests

- [ ] Status card updates correctly
- [ ] Loading indicators appear
- [ ] Buttons enable/disable appropriately
- [ ] Snackbar messages are clear
- [ ] Permission status displays correctly
- [ ] Steps data list scrolls smoothly
- [ ] Empty state displays properly

### Platform Tests

- [ ] Test on Android 14
- [ ] Test on Android 13 (should fail gracefully)
- [ ] Test on emulator
- [ ] Test on physical device
- [ ] Test with different screen sizes
- [ ] Test in portrait/landscape

---

## Build Configuration

### Debug Build

```bash
flutter build apk --debug
```

**Output:** `build/app/outputs/flutter-apk/app-debug.apk`

**Features:**
- Debugging enabled
- Hot reload support
- Debug logging
- Larger APK size

### Release Build

```bash
flutter build apk --release
```

**Output:** `build/app/outputs/flutter-apk/app-release.apk`

**Features:**
- Optimized code
- Smaller APK size
- No debugging
- Production-ready

---

## Troubleshooting

### Issue: "Health Connect not available"

**Solution:**
1. Install Health Connect from Play Store
2. Ensure device is Android 14+
3. Restart app

### Issue: "Permission dialog not showing"

**Solution:**
1. Check `AndroidManifest.xml` has all permissions
2. Ensure activity alias is configured
3. Try reinstalling app

### Issue: "No steps data"

**Solution:**
1. Add test data in Health Connect app
2. Check date range (last 7 days)
3. Verify permission is granted
4. Check Health Connect has data sources

### Issue: "Build failed"

**Solution:**
```bash
flutter clean
flutter pub get
flutter build apk --debug
```

### Issue: "Plugin not found"

**Solution:**
1. Verify `pubspec.yaml` path is correct: `../packages/flutter/health_sync_flutter`
2. Run `flutter pub get`
3. Check SDK is in correct location

---

## Performance Metrics

### Expected Performance

| Metric | Expected Value |
|--------|---------------|
| App Size (Debug) | ~50 MB |
| App Size (Release) | ~20 MB |
| Startup Time | < 2 seconds |
| SDK Init Time | < 500 ms |
| Connection Time | < 1 second |
| Data Fetch (100 records) | < 2 seconds |
| Memory Usage | < 100 MB |

---

## Architecture

### App Structure

```
lib/
  └── main.dart          # Complete app implementation

android/
  ├── app/
  │   ├── build.gradle   # Android configuration
  │   └── src/
  │       └── main/
  │           ├── AndroidManifest.xml
  │           └── kotlin/
  │               └── MainActivity.kt
  ├── build.gradle       # Project gradle
  └── settings.gradle    # Settings
```

### State Management

- Uses StatefulWidget
- Direct state updates with setState()
- Simple and clear for testing purposes

### Error Handling

- Try-catch blocks for all async operations
- Specific error types caught (HealthSyncAuthenticationError, etc.)
- User-friendly error messages
- Snackbar notifications

---

## SDK Features Tested

### Tested APIs

- ✅ `HealthConnectPlugin()` - Constructor
- ✅ `initialize()` - SDK initialization
- ✅ `checkAvailability()` - Health Connect check
- ✅ `connect()` - Connection management
- ✅ `checkPermissions()` - Permission status
- ✅ `requestPermissions()` - Permission request
- ✅ `fetchData()` - Data fetching

### Tested Data Types

- ✅ Steps (DataType.steps)
- 🔜 Heart Rate (can be added)
- 🔜 Sleep (can be added)
- 🔜 Other data types

### Tested Error Types

- ✅ HealthSyncConnectionError
- ✅ HealthSyncAuthenticationError
- ✅ Generic exceptions

---

## Future Enhancements

Potential additions to make the test app even more comprehensive:

- [ ] Test all 13 data types
- [ ] Add heart rate fetch test
- [ ] Add sleep data fetch test
- [ ] Test pagination (limit/offset)
- [ ] Test date range filtering
- [ ] Add data visualization (charts)
- [ ] Add permission revocation test
- [ ] Add reconnection test
- [ ] Add offline mode test
- [ ] Add performance benchmarks
- [ ] Add automated UI tests
- [ ] Add integration tests

---

## Success Criteria

The SDK is considered **production-ready** if:

✅ **Installation** - Installs without errors via local path dependency
✅ **Initialization** - Initializes successfully on first run
✅ **Availability** - Correctly detects Health Connect status
✅ **Connection** - Connects without errors
✅ **Permissions** - Permission request flow works correctly
✅ **Data Fetch** - Successfully fetches and displays real data
✅ **Error Handling** - All error scenarios handled gracefully
✅ **UI Responsiveness** - No freezing or crashes
✅ **Documentation** - All APIs work as documented
✅ **Platform Integration** - Health Connect integration is seamless

---

## Results Reporting

After testing, document:

1. **Test Environment**
   - Device model
   - Android version
   - Health Connect version

2. **Test Results**
   - Pass/fail for each test
   - Screenshots of success
   - Error logs if any

3. **Performance**
   - Load times
   - Data fetch times
   - App size

4. **Issues Found**
   - Bug descriptions
   - Reproduction steps
   - Suggested fixes

---

## Conclusion

This test app provides comprehensive validation of the HealthSync SDK. It tests all critical paths and error scenarios in a production-like environment.

**Test Status:** Ready for Testing

**Last Updated:** January 2026
