@echo off
REM One-click APK builder
REM Double-click this file to build APK and place it on Desktop

title HealthSync Test App - APK Builder

echo.
echo  =============================================
echo   HealthSync SDK Test App
echo   One-Click APK Builder
echo  =============================================
echo.
echo  This will:
echo   1. Build the test app APK
echo   2. Copy it to your Desktop
echo   3. Create installation instructions
echo.
echo  Time required: 2-3 minutes
echo.
pause

cd test-app
call build-to-desktop.bat

echo.
echo  Done! Check your Desktop for:
echo   - HealthSync-Test-App.apk
echo   - HealthSync-Installation-Instructions.txt
echo.
pause
