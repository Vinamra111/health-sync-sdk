@echo off
echo.
echo ========================================
echo  Building APK via Mobile Hotspot
echo ========================================
echo.
echo IMPORTANT: Make sure you are connected to mobile hotspot!
echo.
echo Check your Wi-Fi connection now.
echo If not connected to mobile hotspot, press Ctrl+C to cancel.
echo.
pause

echo.
echo Checking internet connection...
ping -n 1 google.com >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] No internet connection detected!
    echo Please connect to mobile hotspot and try again.
    pause
    exit /b 1
)

echo [OK] Internet connection detected
echo.

cd test-app

echo ========================================
echo  Step 1: Clean Project
echo ========================================
C:\flutter\bin\flutter.bat clean

echo.
echo ========================================
echo  Step 2: Get Dependencies
echo ========================================
C:\flutter\bin\flutter.bat pub get

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Failed to get dependencies
    echo Make sure you're connected to mobile hotspot
    pause
    exit /b 1
)

echo.
echo ========================================
echo  Step 3: Building APK
echo  This will take 2-3 minutes...
echo ========================================
echo.

C:\flutter\bin\flutter.bat build apk --debug

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ========================================
    echo  Build Failed
    echo ========================================
    echo.
    echo Possible issues:
    echo 1. Still on corporate/home network
    echo 2. Antivirus blocking even on hotspot
    echo 3. VPN is active
    echo.
    echo Try:
    echo - Verify you're on mobile hotspot
    echo - Disable antivirus temporarily
    echo - Disconnect VPN if active
    echo.
    pause
    exit /b 1
)

echo.
echo ========================================
echo  Build Successful!
echo ========================================
echo.

if exist "build\app\outputs\flutter-apk\app-debug.apk" (
    echo Copying APK to Desktop...
    copy build\app\outputs\flutter-apk\app-debug.apk %USERPROFILE%\Desktop\HealthSync-Test-App.apk

    echo.
    echo ========================================
    echo  SUCCESS!
    echo ========================================
    echo.
    echo APK Location: %USERPROFILE%\Desktop\HealthSync-Test-App.apk
    echo.
    for %%A in ("%USERPROFILE%\Desktop\HealthSync-Test-App.apk") do set APK_SIZE=%%~zA
    set /a APK_SIZE_MB=!APK_SIZE! / 1048576
    echo APK Size: !APK_SIZE_MB! MB
    echo.
    echo You can now:
    echo 1. Disconnect from mobile hotspot
    echo 2. Reconnect to your regular Wi-Fi
    echo 3. Send APK via WhatsApp to your phone
    echo.
    echo Opening Desktop folder...
    explorer %USERPROFILE%\Desktop
) else (
    echo [ERROR] APK file not found after build
    echo This shouldn't happen if build succeeded.
)

echo.
pause
