@echo off
echo.
echo ========================================
echo  Finding Flutter and Building APK
echo ========================================
echo.

REM Check common Flutter locations
set FLUTTER_EXE=

if exist "C:\flutter\bin\flutter.bat" (
    echo [FOUND] Flutter at: C:\flutter
    set FLUTTER_EXE=C:\flutter\bin\flutter.bat
    goto :build
)

if exist "C:\src\flutter\bin\flutter.bat" (
    echo [FOUND] Flutter at: C:\src\flutter
    set FLUTTER_EXE=C:\src\flutter\bin\flutter.bat
    goto :build
)

if exist "%USERPROFILE%\flutter\bin\flutter.bat" (
    echo [FOUND] Flutter at: %USERPROFILE%\flutter
    set FLUTTER_EXE=%USERPROFILE%\flutter\bin\flutter.bat
    goto :build
)

if exist "D:\flutter\bin\flutter.bat" (
    echo [FOUND] Flutter at: D:\flutter
    set FLUTTER_EXE=D:\flutter\bin\flutter.bat
    goto :build
)

if exist "E:\flutter\bin\flutter.bat" (
    echo [FOUND] Flutter at: E:\flutter
    set FLUTTER_EXE=E:\flutter\bin\flutter.bat
    goto :build
)

if exist "C:\Users\%USERNAME%\AppData\Local\flutter\bin\flutter.bat" (
    echo [FOUND] Flutter at: C:\Users\%USERNAME%\AppData\Local\flutter
    set FLUTTER_EXE=C:\Users\%USERNAME%\AppData\Local\flutter\bin\flutter.bat
    goto :build
)

REM Check in Downloads
if exist "%USERPROFILE%\Downloads\flutter\bin\flutter.bat" (
    echo [FOUND] Flutter at: %USERPROFILE%\Downloads\flutter
    set FLUTTER_EXE=%USERPROFILE%\Downloads\flutter\bin\flutter.bat
    goto :build
)

REM Not found anywhere
echo [ERROR] Flutter not found in any common location
echo.
echo Please tell me where Flutter is installed.
echo Common locations checked:
echo   - C:\flutter
echo   - C:\src\flutter
echo   - %USERPROFILE%\flutter
echo   - D:\flutter
echo   - %USERPROFILE%\Downloads\flutter
echo.
echo If Flutter is installed elsewhere, please edit this script
echo or install Flutter to C:\flutter
echo.
echo Download Flutter: https://docs.flutter.dev/get-started/install/windows
echo.
pause
exit /b 1

:build
echo.
echo ========================================
echo  Building APK with Flutter
echo ========================================
echo.

cd test-app

echo [1/5] Cleaning...
call "%FLUTTER_EXE%" clean

echo.
echo [2/5] Getting dependencies...
call "%FLUTTER_EXE%" pub get

echo.
echo [3/5] Building APK (this takes 2-3 minutes)...
call "%FLUTTER_EXE%" build apk --debug

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Build failed!
    pause
    exit /b 1
)

echo.
echo [4/5] Copying to Desktop...
set APK_PATH=build\app\outputs\flutter-apk\app-debug.apk
set DESKTOP=%USERPROFILE%\Desktop\HealthSync-Test-App.apk

if exist "%APK_PATH%" (
    copy /Y "%APK_PATH%" "%DESKTOP%"
    echo [OK] APK copied to Desktop!

    for %%A in ("%DESKTOP%") do set APK_SIZE=%%~zA
    set /a APK_SIZE_MB=!APK_SIZE! / 1048576
    echo [INFO] APK Size: !APK_SIZE_MB! MB
) else (
    echo [ERROR] APK not found after build
    pause
    exit /b 1
)

echo.
echo [5/5] Creating instructions...
set INSTRUCTIONS=%USERPROFILE%\Desktop\Install-Instructions.txt
(
echo ========================================
echo  HealthSync Test App - Quick Install
echo ========================================
echo.
echo FILE: HealthSync-Test-App.apk
echo.
echo INSTALL VIA WHATSAPP:
echo 1. Open WhatsApp on PC
echo 2. Message yourself
echo 3. Attach this APK file
echo 4. Send to your phone
echo 5. Download on phone
echo 6. Tap to install
echo 7. Allow installation
echo.
echo INSTALL VIA USB:
echo 1. Connect phone via USB
echo 2. Run: adb install HealthSync-Test-App.apk
echo.
echo FIRST USE:
echo 1. Open app
echo 2. Tap "Connect to Health Connect"
echo 3. Grant permissions
echo 4. Tap "Request Steps Permission"
echo 5. Tap "Fetch Steps Data"
echo 6. View your steps!
echo.
) > "%INSTRUCTIONS%"

echo.
echo ========================================
echo  SUCCESS!
echo ========================================
echo.
echo APK Location: %DESKTOP%
echo.
echo Next Steps:
echo 1. Go to your Desktop
echo 2. Find: HealthSync-Test-App.apk
echo 3. Send via WhatsApp to your phone
echo 4. Install and test!
echo.
pause
