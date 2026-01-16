@echo off
echo.
echo ========================================
echo  Building APK (Offline Mode)
echo ========================================
echo.
echo This will try to build using cached artifacts
echo.

cd test-app

echo Step 1: Precache Flutter artifacts...
C:\flutter\bin\flutter.bat precache --android

echo.
echo Step 2: Clean project...
C:\flutter\bin\flutter.bat clean

echo.
echo Step 3: Get dependencies (offline)...
C:\flutter\bin\flutter.bat pub get --offline

echo.
echo Step 4: Build APK with network retry...
set JAVA_OPTS=-Djavax.net.ssl.trustStoreType=Windows-ROOT
C:\flutter\bin\flutter.bat build apk --debug

if exist "build\app\outputs\flutter-apk\app-debug.apk" (
    echo.
    echo ========================================
    echo  SUCCESS!
    echo ========================================
    echo.
    copy build\app\outputs\flutter-apk\app-debug.apk %USERPROFILE%\Desktop\HealthSync-Test-App.apk
    echo APK saved to Desktop!
    echo.
) else (
    echo.
    echo ========================================
    echo  Build failed - Try manual solution
    echo ========================================
    echo.
    echo The issue is SSL certificate validation.
    echo.
    echo Solution 1: Disable antivirus temporarily
    echo Solution 2: Check firewall settings
    echo Solution 3: Try on different network
    echo.
    echo OR run this command manually:
    echo   cd test-app
    echo   flutter doctor
    echo   flutter precache
    echo   flutter build apk --debug
    echo.
)

pause
