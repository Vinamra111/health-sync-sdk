@echo off
echo.
echo ========================================
echo  Flutter Installation Helper
echo ========================================
echo.
echo Checking for Flutter installation...
echo.

REM Check if Flutter is in PATH
where flutter >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    echo [OK] Flutter is installed and in PATH!
    flutter --version
    echo.
    echo You can now run BUILD-APK.bat
    pause
    exit /b 0
)

echo [ERROR] Flutter not found in PATH
echo.
echo Let's check common installation locations...
echo.

REM Check common Flutter installation paths
set FLUTTER_FOUND=0

if exist "C:\flutter\bin\flutter.bat" (
    echo [FOUND] Flutter at: C:\flutter
    set FLUTTER_PATH=C:\flutter\bin
    set FLUTTER_FOUND=1
)

if exist "C:\src\flutter\bin\flutter.bat" (
    echo [FOUND] Flutter at: C:\src\flutter
    set FLUTTER_PATH=C:\src\flutter\bin
    set FLUTTER_FOUND=1
)

if exist "%USERPROFILE%\flutter\bin\flutter.bat" (
    echo [FOUND] Flutter at: %USERPROFILE%\flutter
    set FLUTTER_PATH=%USERPROFILE%\flutter\bin
    set FLUTTER_FOUND=1
)

if exist "D:\flutter\bin\flutter.bat" (
    echo [FOUND] Flutter at: D:\flutter
    set FLUTTER_PATH=D:\flutter\bin
    set FLUTTER_FOUND=1
)

if %FLUTTER_FOUND% EQU 1 (
    echo.
    echo ========================================
    echo  Flutter Found! Adding to PATH...
    echo ========================================
    echo.
    echo Adding: %FLUTTER_PATH%
    echo.

    REM Add to PATH for current session
    set PATH=%FLUTTER_PATH%;%PATH%

    REM Test it
    flutter --version

    echo.
    echo ========================================
    echo  TEMPORARY FIX APPLIED
    echo ========================================
    echo.
    echo Flutter is now available for this session.
    echo.
    echo To make this permanent:
    echo 1. Press Windows Key
    echo 2. Type "Environment Variables"
    echo 3. Click "Edit system environment variables"
    echo 4. Click "Environment Variables" button
    echo 5. Under "User variables", select "Path"
    echo 6. Click "Edit"
    echo 7. Click "New"
    echo 8. Add: %FLUTTER_PATH%
    echo 9. Click OK on all windows
    echo.
    echo OR run this command as Administrator:
    echo setx PATH "%%PATH%%;%FLUTTER_PATH%"
    echo.

    set /p RUN_BUILD="Do you want to build the APK now? (y/n): "
    if /i "%RUN_BUILD%"=="y" (
        echo.
        echo Building APK...
        cd test-app
        call build-to-desktop.bat
    )

) else (
    echo.
    echo ========================================
    echo  Flutter Not Found Anywhere
    echo ========================================
    echo.
    echo You need to install Flutter first.
    echo.
    echo OPTION 1: Quick Install (Recommended)
    echo =====================================
    echo.
    echo 1. Download Flutter:
    echo    https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.16.9-stable.zip
    echo.
    echo 2. Extract to C:\flutter
    echo.
    echo 3. Run this script again
    echo.
    echo.
    echo OPTION 2: Official Guide
    echo ========================
    echo.
    echo Follow the official installation guide:
    echo https://flutter.dev/docs/get-started/install/windows
    echo.
    echo After installation, run this script again.
    echo.

    set /p OPEN_BROWSER="Open Flutter download page? (y/n): "
    if /i "%OPEN_BROWSER%"=="y" (
        start https://docs.flutter.dev/get-started/install/windows
    )
)

echo.
pause
