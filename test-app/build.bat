@echo off
REM HealthSync Test App - Build Script for Windows
REM This script builds and optionally installs the test app

echo.
echo HealthSync SDK Test App - Build Script
echo ==========================================
echo.

REM Check if Flutter is installed
where flutter >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Flutter is not installed or not in PATH
    exit /b 1
)

echo [OK] Flutter found
flutter --version
echo.

REM Clean previous builds
echo [INFO] Cleaning previous builds...
call flutter clean
echo [OK] Clean complete
echo.

REM Get dependencies
echo [INFO] Getting dependencies...
call flutter pub get
echo [OK] Dependencies installed
echo.

REM Analyze code
echo [INFO] Analyzing code...
call flutter analyze
echo [OK] Code analysis complete
echo.

REM Build type
set BUILD_TYPE=%1
if "%BUILD_TYPE%"=="" set BUILD_TYPE=debug

if "%BUILD_TYPE%"=="release" (
    echo [INFO] Building RELEASE APK...
    call flutter build apk --release
    set APK_PATH=build\app\outputs\flutter-apk\app-release.apk
) else (
    echo [INFO] Building DEBUG APK...
    call flutter build apk --debug
    set APK_PATH=build\app\outputs\flutter-apk\app-debug.apk
)

if exist "%APK_PATH%" (
    echo.
    echo [OK] Build complete!
    echo.
    echo [INFO] APK Location: %APK_PATH%

    REM Get APK size
    for %%A in ("%APK_PATH%") do set APK_SIZE=%%~zA
    echo [INFO] APK Size: %APK_SIZE% bytes
    echo.

    REM Ask to install
    set /p INSTALL="Do you want to install on connected device? (y/n) "
    if /i "%INSTALL%"=="y" (
        REM Check if device is connected
        adb devices | find "device" >nul
        if %ERRORLEVEL% EQU 0 (
            echo [INFO] Installing APK...
            adb install -r "%APK_PATH%"
            echo [OK] Installation complete!
            echo.
            echo [INFO] Launching app...
            adb shell am start -n com.healthsync.testapp/.MainActivity
            echo [OK] App launched!
        ) else (
            echo [ERROR] No device connected. Please connect a device and try again.
        )
    )
) else (
    echo [ERROR] Build failed - APK not found
    exit /b 1
)

echo.
echo [OK] All done!
pause
