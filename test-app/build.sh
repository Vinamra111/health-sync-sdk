#!/bin/bash

# HealthSync Test App - Build Script
# This script builds and optionally installs the test app

set -e

echo "🚀 HealthSync SDK Test App - Build Script"
echo "=========================================="
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    print_error "Flutter is not installed or not in PATH"
    exit 1
fi

print_success "Flutter found"
flutter --version
echo ""

# Clean previous builds
print_info "Cleaning previous builds..."
flutter clean
print_success "Clean complete"
echo ""

# Get dependencies
print_info "Getting dependencies..."
flutter pub get
print_success "Dependencies installed"
echo ""

# Analyze code
print_info "Analyzing code..."
if flutter analyze; then
    print_success "Code analysis passed"
else
    print_warning "Code analysis found issues (continuing anyway)"
fi
echo ""

# Build type selection
BUILD_TYPE="${1:-debug}"

if [ "$BUILD_TYPE" == "release" ]; then
    print_info "Building RELEASE APK..."
    flutter build apk --release
    APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
else
    print_info "Building DEBUG APK..."
    flutter build apk --debug
    APK_PATH="build/app/outputs/flutter-apk/app-debug.apk"
fi

if [ -f "$APK_PATH" ]; then
    print_success "Build complete!"
    echo ""
    print_info "APK Location: $APK_PATH"

    # Get APK size
    APK_SIZE=$(du -h "$APK_PATH" | cut -f1)
    print_info "APK Size: $APK_SIZE"
    echo ""

    # Ask to install
    read -p "Do you want to install on connected device? (y/n) " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Check if device is connected
        if adb devices | grep -q "device$"; then
            print_info "Installing APK..."
            adb install -r "$APK_PATH"
            print_success "Installation complete!"
            echo ""
            print_info "Launching app..."
            adb shell am start -n com.healthsync.testapp/.MainActivity
            print_success "App launched!"
        else
            print_error "No device connected. Please connect a device and try again."
        fi
    fi
else
    print_error "Build failed - APK not found"
    exit 1
fi

echo ""
print_success "All done! 🎉"
