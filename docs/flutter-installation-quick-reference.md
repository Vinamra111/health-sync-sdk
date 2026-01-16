# HealthSync Flutter - Installation Quick Reference

**Print this page for quick reference during setup**

---

## ✅ Prerequisites

- [ ] Flutter 3.0.0+
- [ ] Dart 3.0.0+
- [ ] Android device/emulator with Android 14+ (API 34)
- [ ] Health Connect app installed

---

## 📦 Step 1: Add Dependency

**`pubspec.yaml`:**
```yaml
dependencies:
  health_sync_flutter: ^1.0.0
```

**Command:**
```bash
flutter pub get
```

---

## 🔧 Step 2: Configure Android

### 2.1 `android/app/build.gradle`

```gradle
android {
    compileSdkVersion 34

    defaultConfig {
        minSdkVersion 26
        targetSdkVersion 34
    }
}

dependencies {
    implementation "androidx.health.connect:connect-client:1.1.0-alpha07"
    implementation "org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3"
}
```

### 2.2 `android/build.gradle`

```gradle
buildscript {
    ext.kotlin_version = '1.8.0'
}
```

### 2.3 `android/app/src/main/AndroidManifest.xml`

**Add permissions before `<application>`:**
```xml
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
```

**Add inside `<application>` after `<activity>`:**
```xml
<activity-alias
    android:name="ViewPermissionUsageActivity"
    android:exported="true"
    android:targetActivity=".MainActivity"
    android:permission="android.permission.START_VIEW_PERMISSION_USAGE">
    <intent-filter>
        <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />
    </intent-filter>
</activity-alias>
```

---

## ✅ Step 3: Build & Verify

```bash
flutter clean
flutter pub get
flutter build apk --debug
```

---

## 🧪 Step 4: Test

**Minimal test code:**

```dart
import 'package:health_sync_flutter/health_sync_flutter.dart';

final plugin = HealthConnectPlugin();

// Initialize
await plugin.initialize();

// Connect
final result = await plugin.connect();

// Fetch data
if (result.success) {
  final data = await plugin.fetchData(
    DataQuery(
      dataType: DataType.steps,
      startDate: DateTime.now().subtract(Duration(days: 7)),
      endDate: DateTime.now(),
    ),
  );
  print('Fetched ${data.length} records');
}
```

---

## 🐛 Common Issues

| Issue | Solution |
|-------|----------|
| "Health Connect not available" | Install Health Connect app from Play Store |
| Gradle sync fails | Check `compileSdkVersion 34` |
| Permission denied | Verify AndroidManifest.xml has all permissions |
| Plugin not found | Do `flutter clean` then `flutter run` |
| No data returned | Check Health Connect app has data |

---

## 📱 Required Versions

| Component | Version |
|-----------|---------|
| compileSdkVersion | **34** |
| minSdkVersion | **26** |
| targetSdkVersion | **34** |
| Kotlin | **1.8.0+** |
| Health Connect | **1.1.0-alpha07** |

---

## 🔍 Verification Commands

```bash
# Check Flutter version
flutter --version

# Check Android version on device
adb shell getprop ro.build.version.sdk

# Verify permissions in manifest
cat android/app/src/main/AndroidManifest.xml | grep "health.READ"

# Check if plugin installed
flutter pub deps | grep health_sync_flutter

# Build test
flutter build apk --debug
```

---

## 📚 Full Documentation

[Complete Installation Guide →](flutter-installation-guide.md)

---

**Last Updated:** January 2026
