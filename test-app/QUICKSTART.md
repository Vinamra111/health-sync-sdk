# Quick Start Guide

**Get the test app running in 5 minutes**

---

## Prerequisites Check

Before starting, ensure you have:

- ✅ Flutter installed (`flutter --version`)
- ✅ Android device or emulator with Android 14+
- ✅ Health Connect app installed on device
- ✅ USB debugging enabled (for physical device)

---

## Option 1: Automated Build (Recommended)

### Windows

```bash
cd test-app
build.bat
```

### Linux/Mac

```bash
cd test-app
chmod +x build.sh
./build.sh
```

The script will:
1. Clean previous builds
2. Install dependencies
3. Analyze code
4. Build APK
5. Optionally install and launch

---

## Option 2: Manual Build

### Step 1: Install Dependencies

```bash
cd test-app
flutter pub get
```

### Step 2: Build APK

**Debug Build:**
```bash
flutter build apk --debug
```

**Release Build:**
```bash
flutter build apk --release
```

### Step 3: Install APK

```bash
# Debug
adb install build/app/outputs/flutter-apk/app-debug.apk

# Release
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Step 4: Launch App

```bash
adb shell am start -n com.healthsync.testapp/.MainActivity
```

---

## Option 3: Run Directly

```bash
cd test-app
flutter run
```

This will:
- Build the app
- Install on connected device
- Launch automatically
- Enable hot reload

---

## Verify Installation

### Check APK was built

```bash
# Windows
dir build\app\outputs\flutter-apk\

# Linux/Mac
ls -lh build/app/outputs/flutter-apk/
```

You should see:
- `app-debug.apk` (if debug build)
- `app-release.apk` (if release build)

### Check device is connected

```bash
adb devices
```

Should show:
```
List of devices attached
ABC123XYZ       device
```

### Check app is installed

```bash
adb shell pm list packages | grep healthsync
```

Should show:
```
package:com.healthsync.testapp
```

---

## First Run

### 1. Launch the App

The app will automatically:
- Initialize the SDK
- Show status card

### 2. Connect to Health Connect

Tap **"Connect to Health Connect"**

You should see:
- Connection status changes to "Connected"
- Green checkmark icon
- Success snackbar

### 3. Request Permission

Tap **"Request Steps Permission"**

You should see:
- System permission dialog
- Grant the permission
- Permission status updates

### 4. Fetch Data

Tap **"Fetch Steps Data (Last 7 Days)"**

You should see:
- Loading indicator
- Steps data appears
- Count shows number of records

---

## Troubleshooting

### "Flutter not found"

**Solution:**
```bash
# Check Flutter installation
flutter doctor

# Add to PATH if needed
export PATH="$PATH:/path/to/flutter/bin"
```

### "No device connected"

**Solution:**
1. Connect device via USB
2. Enable USB debugging
3. Accept debugging prompt on device
4. Run `adb devices` to verify

### "Health Connect not available"

**Solution:**
1. Install Health Connect from Play Store
2. Ensure device is Android 14+
3. Restart app

### "Build failed"

**Solution:**
```bash
flutter clean
flutter pub get
flutter build apk --debug
```

### "Permission dialog not showing"

**Solution:**
1. Uninstall app: `adb uninstall com.healthsync.testapp`
2. Rebuild and reinstall
3. Try again

---

## Expected Results

### ✅ Success Indicators

- SDK initializes without errors
- Status shows "Connected"
- Permission grant succeeds
- Steps data displays
- No red error messages

### 📊 Performance

- App launches in < 2 seconds
- SDK initializes in < 500ms
- Data fetch in < 2 seconds (for 100 records)

### 📱 UI

- Beautiful Material Design 3
- Smooth animations
- Clear status indicators
- Responsive buttons

---

## Next Steps

After successful test:

1. ✅ Test all buttons
2. ✅ Test permission denial
3. ✅ Test with no data
4. ✅ Test error scenarios
5. ✅ Check documentation accuracy
6. ✅ Report any issues

---

## Quick Commands Reference

```bash
# Build debug APK
flutter build apk --debug

# Build release APK
flutter build apk --release

# Run on device
flutter run

# Install APK
adb install -r app-debug.apk

# Uninstall app
adb uninstall com.healthsync.testapp

# View logs
adb logcat | grep flutter

# Check device
adb devices

# Launch app
adb shell am start -n com.healthsync.testapp/.MainActivity
```

---

## Support

If you encounter issues:

1. Check [README.md](README.md) troubleshooting section
2. Review [Flutter Installation Guide](../docs/flutter-installation-guide.md)
3. Check device logs: `adb logcat`
4. Report issue with:
   - Device model
   - Android version
   - Error message
   - Steps to reproduce

---

**Total Setup Time:** 5-10 minutes

**Last Updated:** January 2026
