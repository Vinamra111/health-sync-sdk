#!/bin/bash

# HealthSync Flutter Test Runner
# Convenient script to run different test configurations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      HealthSync Flutter Test Runner              ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
echo ""

# Function to run tests
run_tests() {
    local test_path=$1
    local test_name=$2

    echo -e "${YELLOW}Running ${test_name}...${NC}"
    if flutter test "$test_path"; then
        echo -e "${GREEN}✓ ${test_name} passed${NC}\n"
        return 0
    else
        echo -e "${RED}✗ ${test_name} failed${NC}\n"
        return 1
    fi
}

# Parse arguments
case "${1:-all}" in
    all)
        echo -e "${BLUE}Running all tests...${NC}\n"
        flutter test
        ;;

    rate-limiter)
        run_tests "test/src/utils/rate_limiter_test.dart" "Rate Limiter Tests"
        ;;

    changes-api)
        run_tests "test/src/utils/changes_api_test.dart" "Changes API Tests"
        ;;

    aggregate-reader)
        run_tests "test/src/utils/aggregate_reader_test.dart" "Aggregate Reader Tests"
        ;;

    device-info)
        run_tests "test/src/background_sync/device_info_test.dart" "Device Info Tests"
        ;;

    background-sync-stats)
        run_tests "test/src/background_sync/background_sync_stats_test.dart" "Background Sync Stats Tests"
        ;;

    background-sync-service)
        run_tests "test/src/background_sync/background_sync_service_test.dart" "Background Sync Service Tests"
        ;;

    conflict-detector)
        run_tests "test/src/conflict_detection/conflict_detector_test.dart" "Conflict Detector Tests"
        ;;

    utils)
        echo -e "${BLUE}Running all utility tests...${NC}\n"
        run_tests "test/src/utils/rate_limiter_test.dart" "Rate Limiter Tests"
        run_tests "test/src/utils/changes_api_test.dart" "Changes API Tests"
        run_tests "test/src/utils/aggregate_reader_test.dart" "Aggregate Reader Tests"
        ;;

    background-sync)
        echo -e "${BLUE}Running all background sync tests...${NC}\n"
        run_tests "test/src/background_sync/device_info_test.dart" "Device Info Tests"
        run_tests "test/src/background_sync/background_sync_stats_test.dart" "Background Sync Stats Tests"
        run_tests "test/src/background_sync/background_sync_service_test.dart" "Background Sync Service Tests"
        ;;

    conflict-detection)
        echo -e "${BLUE}Running all conflict detection tests...${NC}\n"
        run_tests "test/src/conflict_detection/conflict_detector_test.dart" "Conflict Detector Tests"
        ;;

    coverage)
        echo -e "${BLUE}Running tests with coverage...${NC}\n"
        flutter test --coverage
        echo -e "${GREEN}✓ Coverage report generated at coverage/lcov.info${NC}"

        if command -v genhtml &> /dev/null; then
            echo -e "${YELLOW}Generating HTML coverage report...${NC}"
            genhtml coverage/lcov.info -o coverage/html
            echo -e "${GREEN}✓ HTML report generated at coverage/html/index.html${NC}"
        else
            echo -e "${YELLOW}⚠ genhtml not found. Install lcov to generate HTML reports.${NC}"
        fi
        ;;

    watch)
        echo -e "${BLUE}Running tests in watch mode...${NC}\n"
        flutter test --watch
        ;;

    help|--help|-h)
        echo "Usage: ./run_tests.sh [command]"
        echo ""
        echo "Commands:"
        echo "  all                      Run all tests (default)"
        echo "  rate-limiter             Run rate limiter tests"
        echo "  changes-api              Run changes API tests"
        echo "  aggregate-reader         Run aggregate reader tests"
        echo "  device-info              Run device info tests"
        echo "  background-sync-stats    Run background sync stats tests"
        echo "  background-sync-service  Run background sync service tests"
        echo "  conflict-detector        Run conflict detector tests"
        echo "  utils                    Run all utility tests"
        echo "  background-sync          Run all background sync tests"
        echo "  conflict-detection       Run all conflict detection tests"
        echo "  coverage                 Run tests with coverage"
        echo "  watch                    Run tests in watch mode"
        echo "  help                     Show this help message"
        ;;

    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo "Run './run_tests.sh help' for usage information"
        exit 1
        ;;
esac

echo ""
echo -e "${BLUE}╔═══════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              Test Run Complete                    ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════╝${NC}"
