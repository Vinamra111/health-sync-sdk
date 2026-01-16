@echo off
echo.
echo ========================================
echo  Flutter Quick Installer
echo ========================================
echo.
echo This will:
echo 1. Download Flutter (3.19.6 - Latest Stable)
echo 2. Extract to C:\flutter
echo 3. Build your APK
echo.
echo Download size: ~1.5 GB
echo Time required: 5-10 minutes (depending on internet)
echo.

set /p CONFIRM="Do you want to continue? (y/n): "
if /i not "%CONFIRM%"=="y" exit /b

echo.
echo ========================================
echo  Step 1: Downloading Flutter
echo ========================================
echo.
echo Downloading from Flutter.dev...
echo.

REM Download Flutter using PowerShell
powershell -Command "& {Invoke-WebRequest -Uri 'https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.19.6-stable.zip' -OutFile '%TEMP%\flutter.zip'}"

if not exist "%TEMP%\flutter.zip" (
    echo [ERROR] Download failed
    echo.
    echo Please download manually from:
    echo https://docs.flutter.dev/get-started/install/windows
    echo.
    pause
    exit /b 1
)

echo [OK] Download complete!

echo.
echo ========================================
echo  Step 2: Extracting Flutter to C:\flutter
echo ========================================
echo.

REM Extract using PowerShell
powershell -Command "& {Expand-Archive -Path '%TEMP%\flutter.zip' -DestinationPath 'C:\' -Force}"

if not exist "C:\flutter\bin\flutter.bat" (
    echo [ERROR] Extraction failed
    pause
    exit /b 1
)

echo [OK] Flutter extracted to C:\flutter

echo.
echo ========================================
echo  Step 3: Running Flutter Doctor
echo ========================================
echo.

C:\flutter\bin\flutter.bat doctor

echo.
echo ========================================
echo  Step 4: Accepting Android Licenses
echo ========================================
echo.
echo Please type 'y' and press Enter for each license...
echo.

C:\flutter\bin\flutter.bat doctor --android-licenses

echo.
echo ========================================
echo  Step 5: Building APK
echo ========================================
echo.

cd C:\SDK_StandardizingHealthDataV0\test-app

echo Cleaning...
C:\flutter\bin\flutter.bat clean

echo Getting dependencies...
C:\flutter\bin\flutter.bat pub get

echo Building APK (2-3 minutes)...
C:\flutter\bin\flutter.bat build apk --debug

if exist "build\app\outputs\flutter-apk\app-debug.apk" (
    echo.
    echo [OK] Build successful!

    copy build\app\outputs\flutter-apk\app-debug.apk %USERPROFILE%\Desktop\HealthSync-Test-App.apk

    echo.
    echo ========================================
    echo  SUCCESS!
    echo ========================================
    echo.
    echo APK saved to Desktop: HealthSync-Test-App.apk
    echo.
    echo Flutter installed at: C:\flutter
    echo.
    echo You can now send the APK via WhatsApp!
    echo.
) else (
    echo [ERROR] Build failed
)

echo.
pause
