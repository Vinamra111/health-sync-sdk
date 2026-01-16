@echo off
echo =========================================
echo HealthSync SDK - Package Publication
echo =========================================
echo.

REM Check NPM authentication
echo Checking NPM authentication...
call npm whoami
if errorlevel 1 (
    echo.
    echo ERROR: Not logged in to NPM!
    echo Please run: npm login
    echo Then run this script again.
    pause
    exit /b 1
)

echo.
echo Authenticated as:
call npm whoami
echo.

REM Confirm publication
set /p confirm="This will publish all packages to NPM and pub.dev. Continue? (y/n): "
if /i not "%confirm%"=="y" (
    echo Publication cancelled.
    pause
    exit /b 1
)

echo.
echo =========================================
echo Publishing @healthsync/core...
echo =========================================
cd packages\core
call npm publish --access public
if errorlevel 1 (
    echo ERROR: Failed to publish @healthsync/core
    pause
    exit /b 1
)
echo SUCCESS: @healthsync/core published!
cd ..\..

echo.
echo =========================================
echo Publishing @healthsync/react-native...
echo =========================================
cd packages\react-native
call npm install
if errorlevel 1 (
    echo ERROR: Failed to install dependencies for react-native
    pause
    exit /b 1
)
call npm run build 2>nul
call npm publish --access public
if errorlevel 1 (
    echo ERROR: Failed to publish @healthsync/react-native
    pause
    exit /b 1
)
echo SUCCESS: @healthsync/react-native published!
cd ..\..

echo.
echo =========================================
echo Publishing health_sync_flutter...
echo =========================================
cd packages\flutter\health_sync_flutter
call C:\flutter\bin\flutter pub get
if errorlevel 1 (
    echo ERROR: Failed to get Flutter dependencies
    pause
    exit /b 1
)
call C:\flutter\bin\flutter test
if errorlevel 1 (
    echo ERROR: Flutter tests failed
    pause
    exit /b 1
)
echo.
echo IMPORTANT: Flutter publication requires Google account authentication.
echo Follow the prompts in your terminal to complete authentication.
echo.
call C:\flutter\bin\flutter pub publish
if errorlevel 1 (
    echo ERROR: Failed to publish health_sync_flutter
    pause
    exit /b 1
)
echo SUCCESS: health_sync_flutter published!
cd ..\..\..

echo.
echo =========================================
echo Verifying Publications
echo =========================================
echo.
echo Checking NPM packages...
call npm info @healthsync/core version
call npm info @healthsync/react-native version
echo.
echo Check Flutter package at: https://pub.dev/packages/health_sync_flutter
echo.

echo.
echo =========================================
echo All packages published successfully!
echo =========================================
echo.
echo Next steps:
echo 1. Verify packages on registries:
echo    - https://www.npmjs.com/package/@healthsync/core
echo    - https://www.npmjs.com/package/@healthsync/react-native
echo    - https://pub.dev/packages/health_sync_flutter
echo.
echo 2. Create Git tag:
echo    git tag -a v1.0.0 -m "Release v1.0.0"
echo    git push origin v1.0.0
echo.
echo 3. Create GitHub release at:
echo    https://github.com/healthsync/sdk/releases/new
echo.
pause
