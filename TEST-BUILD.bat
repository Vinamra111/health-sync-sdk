@echo off
title HealthSync APK Builder - Testing
color 0A

echo.
echo ================================================
echo  HealthSync APK Builder - Diagnostic Test
echo ================================================
echo.

echo Testing Flutter installation...
echo.

C:\flutter\bin\flutter.bat --version
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Flutter not found at C:\flutter\bin\flutter.bat
    echo.
    echo Please check Flutter installation.
    pause
    exit /b 1
)

echo.
echo [OK] Flutter found!
echo.

echo Testing project directory...
if not exist "C:\SDK_StandardizingHealthDataV0\test-app" (
    echo [ERROR] Project directory not found
    pause
    exit /b 1
)

echo [OK] Project directory exists
echo.

echo Changing to project directory...
cd C:\SDK_StandardizingHealthDataV0\test-app
echo Current directory: %CD%
echo.

echo.
echo ================================================
echo  Ready to build!
echo ================================================
echo.
echo This will now:
echo   1. Clean the project
echo   2. Get dependencies
echo   3. Build APK (2-3 minutes)
echo   4. Copy to Desktop
echo.
set /p CONTINUE="Continue with build? (y/n): "

if /i not "%CONTINUE%"=="y" (
    echo Build cancelled.
    pause
    exit /b 0
)

echo.
echo ================================================
echo  Starting Build Process
echo ================================================
echo.

echo [Step 1/4] Cleaning project...
C:\flutter\bin\flutter.bat clean
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Clean failed
    pause
    exit /b 1
)
echo [OK] Clean complete
echo.

echo [Step 2/4] Getting dependencies...
C:\flutter\bin\flutter.bat pub get
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Pub get failed
    pause
    exit /b 1
)
echo [OK] Dependencies installed
echo.

echo [Step 3/4] Building APK...
echo This will take 2-3 minutes. Please wait...
echo.
C:\flutter\bin\flutter.bat build apk --debug
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Build failed
    echo.
    echo Please check the error messages above.
    pause
    exit /b 1
)
echo.
echo [OK] Build complete!
echo.

echo [Step 4/4] Copying APK to Desktop...
if exist "build\app\outputs\flutter-apk\app-debug.apk" (
    copy /Y build\app\outputs\flutter-apk\app-debug.apk %USERPROFILE%\Desktop\HealthSync-Test-App.apk

    if %ERRORLEVEL% EQU 0 (
        echo [OK] APK copied successfully!
        echo.
        echo ================================================
        echo  BUILD SUCCESSFUL!
        echo ================================================
        echo.
        echo APK Location: %USERPROFILE%\Desktop\HealthSync-Test-App.apk
        echo.

        for %%A in ("%USERPROFILE%\Desktop\HealthSync-Test-App.apk") do (
            set APK_SIZE=%%~zA
            set /a APK_MB=%%~zA/1048576
        )

        echo APK Size: %APK_MB% MB
        echo.
        echo Opening Desktop folder...
        start explorer %USERPROFILE%\Desktop
        echo.
        echo You can now send this APK via WhatsApp!
    ) else (
        echo [ERROR] Failed to copy APK
    )
) else (
    echo [ERROR] APK file not found at expected location
    echo Expected: build\app\outputs\flutter-apk\app-debug.apk
    echo.
    dir build\app\outputs\flutter-apk\ 2>nul
)

echo.
echo.
pause
