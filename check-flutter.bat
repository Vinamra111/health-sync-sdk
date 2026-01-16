@echo off
echo Checking Flutter...
echo.

where flutter
if %ERRORLEVEL% EQU 0 (
    echo Flutter found!
    flutter --version
) else (
    echo Flutter NOT in PATH
    echo.
    echo Checking common locations...
    echo.

    if exist "C:\flutter\bin\flutter.bat" echo FOUND: C:\flutter\bin
    if exist "C:\src\flutter\bin\flutter.bat" echo FOUND: C:\src\flutter\bin
    if exist "%USERPROFILE%\flutter\bin\flutter.bat" echo FOUND: %USERPROFILE%\flutter\bin
    if exist "D:\flutter\bin\flutter.bat" echo FOUND: D:\flutter\bin
)

echo.
pause
