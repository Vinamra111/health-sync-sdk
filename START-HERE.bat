@echo off
title HealthSync APK Builder - Choose Option
color 0A

:menu
cls
echo.
echo  ========================================
echo   HealthSync APK Builder
echo  ========================================
echo.
echo  Flutter is NOT installed on your system.
echo.
echo  Choose an option:
echo.
echo  1. Quick Install Flutter + Build APK (10 minutes)
echo     - Downloads Flutter automatically
echo     - Installs to C:\flutter
echo     - Builds APK immediately
echo.
echo  2. Search entire system for Flutter (2 minutes)
echo     - In case Flutter is installed elsewhere
echo.
echo  3. Manual installation guide
echo     - I'll install Flutter myself
echo.
echo  4. Exit
echo.
echo  ========================================
echo.

set /p choice="Enter your choice (1-4): "

if "%choice%"=="1" goto :auto_install
if "%choice%"=="2" goto :search
if "%choice%"=="3" goto :manual
if "%choice%"=="4" exit

echo Invalid choice. Please try again.
timeout /t 2 >nul
goto :menu

:auto_install
cls
echo.
echo  ========================================
echo   Automatic Installation
echo  ========================================
echo.
echo  This will:
echo  1. Download Flutter (~1.5 GB)
echo  2. Install to C:\flutter
echo  3. Build the APK
echo  4. Put APK on your Desktop
echo.
echo  Time required: 10 minutes
echo  Internet required: Yes
echo.
set /p confirm="Continue? (y/n): "
if /i not "%confirm%"=="y" goto :menu

call INSTALL-FLUTTER-QUICK.bat
pause
goto :menu

:search
cls
echo.
echo  ========================================
echo   Searching for Flutter...
echo  ========================================
echo.
call find-flutter-anywhere.bat
goto :menu

:manual
cls
echo.
echo  ========================================
echo   Manual Installation Guide
echo  ========================================
echo.
echo  Step 1: Download Flutter
echo  -------------------------
echo  Go to: https://docs.flutter.dev/get-started/install/windows
echo.
echo  Or direct download:
echo  https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.19.6-stable.zip
echo.
echo  Step 2: Extract
echo  ---------------
echo  Extract the ZIP file to C:\flutter
echo  (Right-click ZIP -^> Extract All -^> Choose C:\)
echo.
echo  Step 3: Verify
echo  --------------
echo  Open NEW Command Prompt and run:
echo    C:\flutter\bin\flutter doctor
echo.
echo  Step 4: Build APK
echo  -----------------
echo  Run this script again or run:
echo    BUILD-APK-NO-PATH.bat
echo.
echo  ========================================
echo.
set /p open="Open download page in browser? (y/n): "
if /i "%open%"=="y" start https://docs.flutter.dev/get-started/install/windows
echo.
pause
goto :menu
