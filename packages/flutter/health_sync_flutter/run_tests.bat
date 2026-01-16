@echo off
REM HealthSync Flutter Test Runner (Windows)
REM Convenient script to run different test configurations

setlocal enabledelayedexpansion

echo ╔═══════════════════════════════════════════════════╗
echo ║      HealthSync Flutter Test Runner              ║
echo ╚═══════════════════════════════════════════════════╝
echo.

set "command=%~1"
if "%command%"=="" set "command=all"

if /i "%command%"=="all" (
    echo Running all tests...
    echo.
    flutter test
    goto :end
)

if /i "%command%"=="rate-limiter" (
    call :run_test "test/src/utils/rate_limiter_test.dart" "Rate Limiter Tests"
    goto :end
)

if /i "%command%"=="changes-api" (
    call :run_test "test/src/utils/changes_api_test.dart" "Changes API Tests"
    goto :end
)

if /i "%command%"=="aggregate-reader" (
    call :run_test "test/src/utils/aggregate_reader_test.dart" "Aggregate Reader Tests"
    goto :end
)

if /i "%command%"=="device-info" (
    call :run_test "test/src/background_sync/device_info_test.dart" "Device Info Tests"
    goto :end
)

if /i "%command%"=="background-sync-stats" (
    call :run_test "test/src/background_sync/background_sync_stats_test.dart" "Background Sync Stats Tests"
    goto :end
)

if /i "%command%"=="background-sync-service" (
    call :run_test "test/src/background_sync/background_sync_service_test.dart" "Background Sync Service Tests"
    goto :end
)

if /i "%command%"=="conflict-detector" (
    call :run_test "test/src/conflict_detection/conflict_detector_test.dart" "Conflict Detector Tests"
    goto :end
)

if /i "%command%"=="utils" (
    echo Running all utility tests...
    echo.
    call :run_test "test/src/utils/rate_limiter_test.dart" "Rate Limiter Tests"
    call :run_test "test/src/utils/changes_api_test.dart" "Changes API Tests"
    call :run_test "test/src/utils/aggregate_reader_test.dart" "Aggregate Reader Tests"
    goto :end
)

if /i "%command%"=="background-sync" (
    echo Running all background sync tests...
    echo.
    call :run_test "test/src/background_sync/device_info_test.dart" "Device Info Tests"
    call :run_test "test/src/background_sync/background_sync_stats_test.dart" "Background Sync Stats Tests"
    call :run_test "test/src/background_sync/background_sync_service_test.dart" "Background Sync Service Tests"
    goto :end
)

if /i "%command%"=="conflict-detection" (
    echo Running all conflict detection tests...
    echo.
    call :run_test "test/src/conflict_detection/conflict_detector_test.dart" "Conflict Detector Tests"
    goto :end
)

if /i "%command%"=="coverage" (
    echo Running tests with coverage...
    echo.
    flutter test --coverage
    echo.
    echo Coverage report generated at coverage/lcov.info
    echo.
    echo To generate HTML report, install lcov and run:
    echo   genhtml coverage/lcov.info -o coverage/html
    goto :end
)

if /i "%command%"=="watch" (
    echo Running tests in watch mode...
    echo.
    flutter test --watch
    goto :end
)

if /i "%command%"=="help" goto :help
if /i "%command%"=="--help" goto :help
if /i "%command%"=="-h" goto :help
if /i "%command%"=="/?" goto :help

echo Unknown command: %command%
echo Run 'run_tests.bat help' for usage information
exit /b 1

:help
echo Usage: run_tests.bat [command]
echo.
echo Commands:
echo   all                      Run all tests (default)
echo   rate-limiter             Run rate limiter tests
echo   changes-api              Run changes API tests
echo   aggregate-reader         Run aggregate reader tests
echo   device-info              Run device info tests
echo   background-sync-stats    Run background sync stats tests
echo   background-sync-service  Run background sync service tests
echo   conflict-detector        Run conflict detector tests
echo   utils                    Run all utility tests
echo   background-sync          Run all background sync tests
echo   conflict-detection       Run all conflict detection tests
echo   coverage                 Run tests with coverage
echo   watch                    Run tests in watch mode
echo   help                     Show this help message
goto :end

:run_test
echo Running %~2...
flutter test %~1
if errorlevel 1 (
    echo [FAIL] %~2 failed
    echo.
) else (
    echo [PASS] %~2 passed
    echo.
)
exit /b 0

:end
echo.
echo ╔═══════════════════════════════════════════════════╗
echo ║              Test Run Complete                    ║
echo ╚═══════════════════════════════════════════════════╝
