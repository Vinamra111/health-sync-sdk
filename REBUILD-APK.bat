@echo off
echo.
echo ========================================
echo  Rebuilding APK (Gradle Fixed)
echo ========================================
echo.

cd test-app

echo Cleaning...
C:\flutter\bin\flutter.bat clean

echo.
echo Getting dependencies...
C:\flutter\bin\flutter.bat pub get

echo.
echo Building APK with updated Gradle...
C:\flutter\bin\flutter.bat build apk --debug

if exist "build\app\outputs\flutter-apk\app-debug.apk" (
    echo.
    echo [OK] Build successful!
    copy build\app\outputs\flutter-apk\app-debug.apk %USERPROFILE%\Desktop\HealthSync-Test-App.apk
    echo.
    echo APK saved to Desktop!
) else (
    echo [ERROR] Build failed
)

pause
