@echo off
echo.
echo Building APK...
echo.

cd C:\SDK_StandardizingHealthDataV0\test-app

echo [1/4] Cleaning...
C:\flutter\bin\flutter.bat clean

echo.
echo [2/4] Getting dependencies...
C:\flutter\bin\flutter.bat pub get

echo.
echo [3/4] Building APK (this takes 2-3 minutes)...
C:\flutter\bin\flutter.bat build apk --debug

echo.
echo [4/4] Copying to Desktop...
if exist "build\app\outputs\flutter-apk\app-debug.apk" (
    copy build\app\outputs\flutter-apk\app-debug.apk %USERPROFILE%\Desktop\HealthSync-Test-App.apk
    echo.
    echo SUCCESS! APK is on your Desktop.
    echo.
    explorer %USERPROFILE%\Desktop
) else (
    echo.
    echo ERROR: APK not found
)

echo.
pause
