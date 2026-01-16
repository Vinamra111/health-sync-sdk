@echo off
REM Build APK and copy to Desktop
REM This script builds the HealthSync test app and places the APK on Desktop

echo.
echo ========================================
echo  HealthSync SDK Test App Builder
echo  Building APK for Desktop...
echo ========================================
echo.

REM Check if Flutter is installed
where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Flutter is not installed or not in PATH
    echo Please install Flutter first: https://flutter.dev/docs/get-started/install
    pause
    exit /b 1
)

echo [OK] Flutter found
echo.

REM Get the Desktop path
set DESKTOP=%USERPROFILE%\Desktop
echo [INFO] Desktop path: %DESKTOP%
echo.

REM Clean previous builds
echo [1/5] Cleaning previous builds...
call flutter clean
echo [OK] Clean complete
echo.

REM Get dependencies
echo [2/5] Installing dependencies...
call flutter pub get
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to get dependencies
    pause
    exit /b 1
)
echo [OK] Dependencies installed
echo.

REM Build debug APK
echo [3/5] Building DEBUG APK...
echo This may take a few minutes...
call flutter build apk --debug
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Build failed
    pause
    exit /b 1
)
echo [OK] Build complete
echo.

REM Check if APK exists
set APK_PATH=build\app\outputs\flutter-apk\app-debug.apk
if not exist "%APK_PATH%" (
    echo [ERROR] APK not found at %APK_PATH%
    pause
    exit /b 1
)

REM Get APK size
for %%A in ("%APK_PATH%") do set APK_SIZE=%%~zA
set /a APK_SIZE_MB=%APK_SIZE% / 1048576
echo [INFO] APK Size: %APK_SIZE_MB% MB
echo.

REM Copy to Desktop with descriptive name
echo [4/5] Copying APK to Desktop...
set DESKTOP_APK=%DESKTOP%\HealthSync-Test-App.apk
copy /Y "%APK_PATH%" "%DESKTOP_APK%"
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to copy APK to Desktop
    pause
    exit /b 1
)
echo [OK] APK copied to Desktop
echo.

REM Create installation instructions file
echo [5/5] Creating installation instructions...
set INSTRUCTIONS=%DESKTOP%\HealthSync-Installation-Instructions.txt
(
echo ========================================
echo  HealthSync SDK Test App
echo  Installation Instructions
echo ========================================
echo.
echo APK File: HealthSync-Test-App.apk
echo Size: %APK_SIZE_MB% MB
echo Location: Desktop
echo.
echo ========================================
echo  Installation Methods
echo ========================================
echo.
echo METHOD 1: Direct Download to Phone
echo -----------------------------------
echo 1. Transfer "HealthSync-Test-App.apk" to your phone
echo    - Email it to yourself
echo    - Use Google Drive / Dropbox
echo    - Use USB cable
echo    - Use AirDroid / nearby share
echo.
echo 2. On your phone:
echo    - Locate the APK file
echo    - Tap to install
echo    - Allow "Install from Unknown Sources" if prompted
echo    - Tap "Install"
echo.
echo METHOD 2: USB Cable ^(ADB^)
echo -----------------------------------
echo 1. Connect phone via USB cable
echo 2. Enable USB Debugging on phone
echo 3. Open command prompt in Desktop folder
echo 4. Run: adb install HealthSync-Test-App.apk
echo.
echo METHOD 3: QR Code ^(Recommended^)
echo -----------------------------------
echo 1. Upload APK to Google Drive
echo 2. Get shareable link
echo 3. Create QR code from link
echo 4. Scan QR code with phone
echo 5. Download and install
echo.
echo ========================================
echo  Prerequisites on Phone
echo ========================================
echo.
echo - Android 8.0 or higher ^(required^)
echo - Android 14 recommended for Health Connect
echo - Health Connect app installed
echo - At least 100 MB free space
echo.
echo ========================================
echo  First Run
echo ========================================
echo.
echo After installation:
echo 1. Open "HealthSync Test" app
echo 2. Tap "Connect to Health Connect"
echo 3. Grant permissions
echo 4. Tap "Request Steps Permission"
echo 5. Grant steps permission
echo 6. Tap "Fetch Steps Data"
echo 7. View your steps data!
echo.
echo ========================================
echo  Troubleshooting
echo ========================================
echo.
echo Issue: "App not installed"
echo Solution: Enable "Install from Unknown Sources" in phone settings
echo.
echo Issue: "Parse error"
echo Solution: Re-download APK, file may be corrupted
echo.
echo Issue: "Health Connect not available"
echo Solution: Install Health Connect from Google Play Store
echo.
echo ========================================
echo  Support
echo ========================================
echo.
echo For issues, check:
echo - test-app/README.md
echo - test-app/QUICKSTART.md
echo - docs/flutter-installation-guide.md
echo.
echo Built: %date% %time%
echo.
) > "%INSTRUCTIONS%"

echo [OK] Instructions created
echo.

REM Success summary
echo ========================================
echo  BUILD SUCCESSFUL!
echo ========================================
echo.
echo Files created on Desktop:
echo.
echo 1. HealthSync-Test-App.apk
echo    - Size: %APK_SIZE_MB% MB
echo    - Ready to install on phone
echo.
echo 2. HealthSync-Installation-Instructions.txt
echo    - Step-by-step guide
echo    - Multiple installation methods
echo.
echo ========================================
echo  Next Steps
echo ========================================
echo.
echo 1. Go to your Desktop
echo 2. Find "HealthSync-Test-App.apk"
echo 3. Transfer to your phone using any method:
echo    - Email
echo    - USB cable
echo    - Cloud storage
echo    - Nearby share
echo.
echo 4. Install on phone
echo 5. Open app and test!
echo.
echo ========================================
echo  Quick Install via ADB
echo ========================================
echo.
echo If your phone is connected via USB:
echo.
set /p INSTALL="Install now via ADB? (y/n): "
if /i "%INSTALL%"=="y" (
    echo.
    echo Checking for connected devices...
    adb devices
    echo.
    echo Installing APK...
    adb install -r "%DESKTOP_APK%"
    if %ERRORLEVEL% EQU 0 (
        echo.
        echo [OK] Installation successful!
        echo Launching app...
        adb shell am start -n com.healthsync.testapp/.MainActivity
        echo.
        echo [OK] App launched on phone!
    ) else (
        echo.
        echo [ERROR] Installation failed
        echo Please check USB connection and try again
    )
)

echo.
echo All done! Check your Desktop.
echo.
pause
