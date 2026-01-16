@echo off
echo.
echo Searching entire system for Flutter...
echo This may take 1-2 minutes...
echo.

REM Search C drive for flutter.bat
for /f "tokens=*" %%i in ('dir /s /b C:\flutter.bat 2^>nul') do (
    echo FOUND: %%i
    set FLUTTER_FOUND=%%i
)

if defined FLUTTER_FOUND (
    echo.
    echo Flutter found!
    echo Location: %FLUTTER_FOUND%
    echo.
    set FLUTTER_DIR=%FLUTTER_FOUND:\bin\flutter.bat=%
    echo Flutter directory: %FLUTTER_DIR%
    echo.
    echo Copy this path and edit BUILD-APK-NO-PATH.bat
    echo Add this line after "set FLUTTER_EXE=" :
    echo set FLUTTER_EXE=%FLUTTER_FOUND%
) else (
    echo.
    echo Flutter NOT found on C: drive
    echo.
    echo Checking if you have Android Studio...
    if exist "C:\Program Files\Android\Android Studio" (
        echo [FOUND] Android Studio installed
        echo Flutter can be installed from Android Studio
    )
)

echo.
pause
