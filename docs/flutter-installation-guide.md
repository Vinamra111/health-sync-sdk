# HealthSync Flutter - Complete Installation Guide

This guide walks you through installing and configuring the HealthSync Flutter plugin step-by-step.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Step 1: Add Package Dependency](#step-1-add-package-dependency)
- [Step 2: Android Configuration](#step-2-android-configuration)
- [Step 3: Verify Installation](#step-3-verify-installation)
- [Step 4: Test Basic Functionality](#step-4-test-basic-functionality)
- [Troubleshooting](#troubleshooting)

## Prerequisites

Before installing, ensure you have:

- ✅ Flutter SDK 3.0.0 or higher
- ✅ Dart SDK 3.0.0 or higher
- ✅ Android Studio or VS Code with Flutter extensions
- ✅ Android device or emulator running Android 14+ (API 34)
- ✅ Health Connect app installed on test device

### Check Your Flutter Version

```bash
flutter --version
```

Should show Flutter 3.0.0 or higher.

### Check Dart Version

```bash
dart --version
```

Should show Dart 3.0.0 or higher.

---

## Step 1: Add Package Dependency

### 1.1 Open `pubspec.yaml`

Navigate to your Flutter project and open `pubspec.yaml`.

### 1.2 Add the Dependency

Add `health_sync_flutter` under `dependencies`:

```yaml
dependencies:
  flutter:
    sdk: flutter

  # HealthSync Flutter Plugin
  health_sync_flutter: ^1.0.0
```

### 1.3 Install the Package

Run one of the following commands:

**Using command line:**
```bash
flutter pub get
```

**Using VS Code:**
- Save `pubspec.yaml`
- VS Code will automatically run `flutter pub get`

**Using Android Studio:**
- Click "Pub get" in the notification banner
- Or run from terminal

### 1.4 Verify Installation

Check that the package is installed:

```bash
flutter pub deps | grep health_sync_flutter
```

You should see:
```
└── health_sync_flutter 1.0.0
```

---

## Step 2: Android Configuration

### 2.1 Update `android/app/build.gradle`

Open `android/app/build.gradle` and make the following changes:

#### Set Compile SDK Version

```gradle
android {
    // Change compileSdkVersion to 34 (Android 14)
    compileSdkVersion 34

    // ... rest of android block
}
```

#### Update Default Config

```gradle
android {
    compileSdkVersion 34

    defaultConfig {
        applicationId "com.yourcompany.yourapp"  // Your app ID

        // Update these versions
        minSdkVersion 26      // Minimum for Health Connect
        targetSdkVersion 34   // Target Android 14

        versionCode flutterVersionCode.toInteger()
        versionName flutterVersionName
    }

    // ... rest of configuration
}
```

#### Add Health Connect Dependency

Add at the bottom of the `dependencies` block:

```gradle
dependencies {
    implementation "org.jetbrains.kotlin:kotlin-stdlib-jdk7:$kotlin_version"

    // Add Health Connect dependency
    implementation "androidx.health.connect:connect-client:1.1.0-alpha07"

    // Ensure you have coroutines support
    implementation "org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3"
}
```

**Complete `android/app/build.gradle` example:**

```gradle
def localProperties = new Properties()
def localPropertiesFile = rootProject.file('local.properties')
if (localPropertiesFile.exists()) {
    localPropertiesFile.withReader('UTF-8') { reader ->
        localProperties.load(reader)
    }
}

def flutterRoot = localProperties.getProperty('flutter.sdk')
if (flutterRoot == null) {
    throw new GradleException("Flutter SDK not found. Define location with flutter.sdk in the local.properties file.")
}

def flutterVersionCode = localProperties.getProperty('flutter.versionCode')
if (flutterVersionCode == null) {
    flutterVersionCode = '1'
}

def flutterVersionName = localProperties.getProperty('flutter.versionName')
if (flutterVersionName == null) {
    flutterVersionName = '1.0'
}

apply plugin: 'com.android.application'
apply plugin: 'kotlin-android'
apply from: "$flutterRoot/packages/flutter_tools/gradle/flutter.gradle"

android {
    compileSdkVersion 34

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = '1.8'
    }

    sourceSets {
        main.java.srcDirs += 'src/main/kotlin'
    }

    defaultConfig {
        applicationId "com.yourcompany.yourapp"
        minSdkVersion 26
        targetSdkVersion 34
        versionCode flutterVersionCode.toInteger()
        versionName flutterVersionName
    }

    buildTypes {
        release {
            signingConfig signingConfigs.debug
        }
    }
}

flutter {
    source '../..'
}

dependencies {
    implementation "org.jetbrains.kotlin:kotlin-stdlib-jdk7:$kotlin_version"
    implementation "androidx.health.connect:connect-client:1.1.0-alpha07"
    implementation "org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3"
}
```

### 2.2 Update `android/build.gradle` (Project Level)

Open `android/build.gradle` and ensure you have the correct Kotlin version:

```gradle
buildscript {
    ext.kotlin_version = '1.8.0'  // Use 1.8.0 or higher

    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath 'com.android.tools.build:gradle:7.4.2'
        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version"
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
```

### 2.3 Update `AndroidManifest.xml`

Open `android/app/src/main/AndroidManifest.xml` and add permissions and intent filter:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.yourcompany.yourapp">

    <!-- ========================================== -->
    <!-- Health Connect Permissions                 -->
    <!-- ========================================== -->

    <!-- Core health metrics -->
    <uses-permission android:name="android.permission.health.READ_STEPS"/>
    <uses-permission android:name="android.permission.health.READ_HEART_RATE"/>
    <uses-permission android:name="android.permission.health.READ_SLEEP"/>
    <uses-permission android:name="android.permission.health.READ_DISTANCE"/>
    <uses-permission android:name="android.permission.health.READ_EXERCISE"/>

    <!-- Calories -->
    <uses-permission android:name="android.permission.health.READ_TOTAL_CALORIES_BURNED"/>
    <uses-permission android:name="android.permission.health.READ_ACTIVE_CALORIES_BURNED"/>

    <!-- Vital signs -->
    <uses-permission android:name="android.permission.health.READ_OXYGEN_SATURATION"/>
    <uses-permission android:name="android.permission.health.READ_BLOOD_PRESSURE"/>
    <uses-permission android:name="android.permission.health.READ_BODY_TEMPERATURE"/>

    <!-- Body measurements -->
    <uses-permission android:name="android.permission.health.READ_WEIGHT"/>
    <uses-permission android:name="android.permission.health.READ_HEIGHT"/>

    <!-- Advanced metrics -->
    <uses-permission android:name="android.permission.health.READ_HEART_RATE_VARIABILITY"/>

    <!-- ========================================== -->

    <application
        android:label="Your App Name"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">

            <meta-data
                android:name="io.flutter.embedding.android.NormalTheme"
                android:resource="@style/NormalTheme"
            />

            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>

        <!-- ========================================== -->
        <!-- Health Connect Intent Filter               -->
        <!-- Required for permission rationale display  -->
        <!-- ========================================== -->

        <activity-alias
            android:name="ViewPermissionUsageActivity"
            android:exported="true"
            android:targetActivity=".MainActivity"
            android:permission="android.permission.START_VIEW_PERMISSION_USAGE">
            <intent-filter>
                <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />
            </intent-filter>
        </activity-alias>

        <!-- ========================================== -->

        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>
```

**Important Notes:**

1. **Only add permissions you need** - Remove unused permissions to reduce permission requests
2. **Activity alias is required** - This allows Health Connect to show permission rationale
3. **Package name** - Replace `com.yourcompany.yourapp` with your actual package name

### 2.4 Sync Gradle Files

After making all changes, sync your Gradle files:

**Android Studio:**
- Click "Sync Now" in the notification banner
- Or: File → Sync Project with Gradle Files

**Command Line:**
```bash
cd android
./gradlew clean
./gradlew build
cd ..
```

---

## Step 3: Verify Installation

### 3.1 Check for Compilation Errors

Run a build to ensure everything compiles:

```bash
flutter clean
flutter pub get
flutter build apk --debug
```

You should see:
```
✓ Built build/app/outputs/flutter-apk/app-debug.apk
```

### 3.2 Verify Health Connect is Available

Create a test file `test_health_connect.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:health_sync_flutter/health_sync_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final plugin = HealthConnectPlugin();

  try {
    final availability = await plugin.checkAvailability();
    print('Health Connect Status: $availability');

    if (availability == HealthConnectAvailability.installed) {
      print('✅ Health Connect is available!');
    } else {
      print('❌ Health Connect is not available: $availability');
    }
  } catch (e) {
    print('❌ Error checking availability: $e');
  }
}
```

Run it:
```bash
flutter run
```

### 3.3 Check Permissions in AndroidManifest

Verify permissions were added correctly:

```bash
cat android/app/src/main/AndroidManifest.xml | grep "health.READ"
```

You should see all 13 permission lines.

---

## Step 4: Test Basic Functionality

### 4.1 Create a Test Widget

Create `lib/health_test_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:health_sync_flutter/health_sync_flutter.dart';

class HealthTestPage extends StatefulWidget {
  const HealthTestPage({super.key});

  @override
  State<HealthTestPage> createState() => _HealthTestPageState();
}

class _HealthTestPageState extends State<HealthTestPage> {
  final _plugin = HealthConnectPlugin();
  String _status = 'Not initialized';

  @override
  void initState() {
    super.initState();
    _testHealthConnect();
  }

  Future<void> _testHealthConnect() async {
    try {
      // Step 1: Initialize
      setState(() => _status = 'Initializing...');
      await _plugin.initialize();
      setState(() => _status = 'Initialized ✓');

      await Future.delayed(const Duration(seconds: 1));

      // Step 2: Connect
      setState(() => _status = 'Connecting...');
      final result = await _plugin.connect();

      if (result.success) {
        setState(() => _status = 'Connected ✓\n${result.message}');

        await Future.delayed(const Duration(seconds: 1));

        // Step 3: Fetch data
        setState(() => _status = 'Fetching steps data...');
        final data = await _plugin.fetchData(
          DataQuery(
            dataType: DataType.steps,
            startDate: DateTime.now().subtract(const Duration(days: 7)),
            endDate: DateTime.now(),
          ),
        );

        setState(() => _status = 'Success! Fetched ${data.length} records ✓');
      } else {
        setState(() => _status = 'Connection failed:\n${result.message}');
      }
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Connect Test'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.favorite,
                size: 100,
                color: Colors.red,
              ),
              const SizedBox(height: 32),
              Text(
                _status,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _testHealthConnect,
                child: const Text('Test Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

### 4.2 Update `main.dart`

```dart
import 'package:flutter/material.dart';
import 'health_test_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HealthSync Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HealthTestPage(),
    );
  }
}
```

### 4.3 Run on Device

```bash
# Connect your Android device or start emulator
flutter devices

# Run the app
flutter run
```

**Expected Flow:**

1. App launches
2. Shows "Initializing..."
3. Shows "Initialized ✓"
4. Shows "Connecting..."
5. Health Connect permission dialog appears
6. After granting permissions, shows "Connected ✓"
7. Shows "Fetching steps data..."
8. Shows "Success! Fetched X records ✓"

---

## Troubleshooting

### Issue: "Health Connect not available"

**Causes:**
- Device is running Android < 14
- Health Connect app not installed
- Emulator doesn't have Health Connect

**Solutions:**

1. **Check Android Version:**
   ```bash
   adb shell getprop ro.build.version.sdk
   ```
   Should be 34 or higher.

2. **Install Health Connect:**
   - Open Google Play Store on device
   - Search for "Health Connect"
   - Install the official app from Google

3. **For Emulator:**
   - Use Android 14+ (API 34+) system image
   - Install Health Connect APK manually
   - Or test on physical device

### Issue: "Compilation Error: compileSdkVersion"

**Error Message:**
```
Execution failed for task ':app:checkDebugAarMetadata'.
```

**Solution:**

Ensure `compileSdkVersion` is set to 34 in `android/app/build.gradle`:

```gradle
android {
    compileSdkVersion 34  // Must be 34
    // ...
}
```

Then:
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

### Issue: "Permission Denied"

**Error Message:**
```
HealthSyncAuthenticationError: Missing permissions for steps
```

**Solutions:**

1. **Verify permissions in AndroidManifest.xml:**
   ```bash
   cat android/app/src/main/AndroidManifest.xml | grep "health.READ_STEPS"
   ```

2. **Check permissions in Health Connect app:**
   - Open Health Connect app
   - Go to "App permissions"
   - Find your app
   - Verify permissions are granted

3. **Manually request permissions:**
   ```dart
   await plugin.requestPermissions([
     HealthConnectPermission.readSteps,
     HealthConnectPermission.readHeartRate,
   ]);
   ```

### Issue: "Gradle Sync Failed"

**Error Message:**
```
Could not resolve androidx.health.connect:connect-client:1.1.0-alpha07
```

**Solution:**

1. **Check internet connection**

2. **Update repositories in `android/build.gradle`:**
   ```gradle
   allprojects {
       repositories {
           google()        // Must be present
           mavenCentral()  // Must be present
       }
   }
   ```

3. **Clear Gradle cache:**
   ```bash
   cd android
   ./gradlew clean --refresh-dependencies
   cd ..
   ```

### Issue: "Kotlin Version Conflict"

**Error Message:**
```
The Kotlin Gradle plugin was loaded multiple times
```

**Solution:**

Update Kotlin version in `android/build.gradle`:

```gradle
buildscript {
    ext.kotlin_version = '1.8.0'  // Use consistent version
    dependencies {
        classpath "org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version"
    }
}
```

### Issue: "No Records Returned"

**Symptoms:**
- Connection successful
- Permissions granted
- But `fetchData()` returns empty list

**Solutions:**

1. **Verify Health Connect has data:**
   - Open Health Connect app
   - Check if there's data for the date range

2. **Check date range:**
   ```dart
   final data = await plugin.fetchData(
     DataQuery(
       dataType: DataType.steps,
       startDate: DateTime.now().subtract(Duration(days: 30)), // Wider range
       endDate: DateTime.now(),
     ),
   );
   ```

3. **Test with different data types:**
   - Some data types may not have records
   - Try `DataType.steps`, `DataType.sleep`, `DataType.heartRate`

### Issue: "Plugin Not Found"

**Error Message:**
```
MissingPluginException(No implementation found for method checkAvailability)
```

**Solutions:**

1. **Hot restart instead of hot reload:**
   ```bash
   # Press 'R' in terminal where flutter run is running
   # Or
   flutter run
   ```

2. **Rebuild the app:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

3. **Check plugin registration:**
   - Verify `android/src/main/kotlin/.../HealthSyncFlutterPlugin.kt` exists
   - Rebuild native code

---

## Verification Checklist

Use this checklist to ensure everything is set up correctly:

- [ ] Flutter version is 3.0.0+
- [ ] Dart version is 3.0.0+
- [ ] `health_sync_flutter` added to `pubspec.yaml`
- [ ] `flutter pub get` completed successfully
- [ ] `compileSdkVersion` is 34 in `android/app/build.gradle`
- [ ] `minSdkVersion` is 26 in `android/app/build.gradle`
- [ ] `targetSdkVersion` is 34 in `android/app/build.gradle`
- [ ] Health Connect dependency added to `build.gradle`
- [ ] All 13 permissions added to `AndroidManifest.xml`
- [ ] Activity alias added to `AndroidManifest.xml`
- [ ] Gradle sync completed successfully
- [ ] App builds without errors
- [ ] Health Connect app installed on test device
- [ ] Device is running Android 14+ (API 34+)
- [ ] Test app runs and connects successfully
- [ ] Permissions can be requested and granted
- [ ] Data can be fetched successfully

---

## Next Steps

Once installation is complete:

1. ✅ Read the [Usage Guide](../packages/flutter/health_sync_flutter/README.md)
2. ✅ Explore the [Example App](../packages/flutter/health_sync_flutter/example/)
3. ✅ Check the [API Documentation](../packages/flutter/health_sync_flutter/README.md#api-reference)
4. ✅ Review [Error Handling](../packages/flutter/health_sync_flutter/README.md#error-handling)

---

## Getting Help

If you encounter issues not covered here:

1. **Check Logs:**
   ```bash
   flutter run --verbose
   ```

2. **Check Health Connect Status:**
   ```bash
   adb shell dumpsys health_connect
   ```

3. **File an Issue:**
   - [GitHub Issues](https://github.com/yourusername/health-sync-sdk/issues)
   - Include: Flutter version, Android version, error logs

4. **Community:**
   - [Stack Overflow](https://stackoverflow.com/questions/tagged/health-connect)
   - Tag: `health-connect`, `flutter`

---

## Success!

If all checks pass and the test app works, you're ready to integrate HealthSync into your Flutter application! 🎉

Next: [Usage Guide →](../packages/flutter/health_sync_flutter/README.md)
