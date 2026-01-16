# Publishing Guide

This guide explains how to publish the HealthSync SDK packages to NPM and pub.dev.

## Prerequisites

### For NPM Packages (Core & React Native)

1. **NPM Account**: Create account at [npmjs.com](https://www.npmjs.com)
2. **NPM Organization**: Create `@healthsync` organization
3. **NPM Login**: Run `npm login` and authenticate
4. **Node.js**: Version 16+ installed
5. **Build Tools**: Ensure TypeScript and build dependencies installed

### For Flutter Package

1. **Pub.dev Account**: Link Google account at [pub.dev](https://pub.dev)
2. **Flutter SDK**: Version 3.0+ installed
3. **Google Account**: For pub.dev authentication

## Pre-Publication Checklist

- [x] All LICENSE files present
- [x] All README files comprehensive
- [x] All CHANGELOG.md files updated
- [x] All repository URLs updated
- [x] All package versions set correctly
- [x] .npmignore files added (NPM packages)
- [ ] Example apps tested
- [ ] All tests passing
- [ ] Build artifacts generated

## Publishing Steps

### 1. Core Package (@healthsync/core)

```bash
# Navigate to package
cd packages/core

# Install dependencies
npm install

# Run tests
npm test

# Build package
npm run build

# Verify package contents
npm pack
tar -tzf healthsync-core-1.0.0.tgz

# Dry run (validate without publishing)
npm publish --dry-run

# Publish to NPM
npm publish --access public

# Verify publication
npm info @healthsync/core
```

### 2. React Native Package (@healthsync/react-native)

```bash
# Navigate to package
cd packages/react-native

# Install dependencies
npm install

# Build package (if build script exists)
npm run build

# Verify package contents
npm pack
tar -tzf healthsync-react-native-1.0.0.tgz

# Dry run
npm publish --dry-run

# Publish to NPM
npm publish --access public

# Verify publication
npm info @healthsync/react-native
```

### 3. Flutter Package (health_sync_flutter)

```bash
# Navigate to package
cd packages/flutter/health_sync_flutter

# Ensure dependencies are fetched
flutter pub get

# Run tests
flutter test

# Analyze code
flutter analyze

# Dry run (validate without publishing)
flutter pub publish --dry-run

# Publish to pub.dev
flutter pub publish

# Follow prompts:
# 1. Review package contents
# 2. Confirm publication URL
# 3. Authenticate with Google account
# 4. Confirm publication

# Verify publication
flutter pub global activate health_sync_flutter
```

## Automation Scripts

### publish-all.sh (Unix/Mac/Linux)

Create this script in the repository root:

```bash
#!/bin/bash
set -e

echo "========================================="
echo "HealthSync SDK - Publish All Packages"
echo "========================================="
echo ""

# Function to publish NPM package
publish_npm() {
  local package_name=$1
  local package_dir=$2

  echo "Publishing $package_name..."
  cd "$package_dir"

  # Install and build
  npm install
  npm test
  npm run build 2>/dev/null || true

  # Publish
  npm publish --access public

  echo "✓ $package_name published successfully"
  echo ""
  cd -
}

# Function to publish Flutter package
publish_flutter() {
  local package_name=$1
  local package_dir=$2

  echo "Publishing $package_name..."
  cd "$package_dir"

  # Get dependencies and test
  flutter pub get
  flutter test
  flutter analyze

  # Publish
  flutter pub publish --force

  echo "✓ $package_name published successfully"
  echo ""
  cd -
}

# Confirm publication
read -p "This will publish all packages to NPM and pub.dev. Continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Publication cancelled."
  exit 1
fi

# Publish packages
publish_npm "@healthsync/core" "packages/core"
publish_npm "@healthsync/react-native" "packages/react-native"
publish_flutter "health_sync_flutter" "packages/flutter/health_sync_flutter"

echo "========================================="
echo "All packages published successfully!"
echo "========================================="
```

### publish-all.bat (Windows)

```batch
@echo off
echo =========================================
echo HealthSync SDK - Publish All Packages
echo =========================================
echo.

REM Confirm publication
set /p confirm="This will publish all packages. Continue? (y/n): "
if /i not "%confirm%"=="y" (
  echo Publication cancelled.
  exit /b 1
)

REM Publish core package
echo.
echo Publishing @healthsync/core...
cd packages\core
call npm install
call npm test
call npm run build
call npm publish --access public
if errorlevel 1 (
  echo Failed to publish @healthsync/core
  exit /b 1
)
cd ..\..

REM Publish React Native package
echo.
echo Publishing @healthsync/react-native...
cd packages\react-native
call npm install
call npm run build 2>nul
call npm publish --access public
if errorlevel 1 (
  echo Failed to publish @healthsync/react-native
  exit /b 1
)
cd ..\..

REM Publish Flutter package
echo.
echo Publishing health_sync_flutter...
cd packages\flutter\health_sync_flutter
call flutter pub get
call flutter test
call flutter analyze
call flutter pub publish --force
if errorlevel 1 (
  echo Failed to publish health_sync_flutter
  exit /b 1
)
cd ..\..\..

echo.
echo =========================================
echo All packages published successfully!
echo =========================================
```

## Post-Publication

### Verification

1. **NPM Packages**:
   ```bash
   npm info @healthsync/core
   npm info @healthsync/react-native
   ```

2. **Flutter Package**:
   - Visit https://pub.dev/packages/health_sync_flutter
   - Check package appears in search
   - Verify documentation rendered correctly

### Create Git Tags

```bash
# Tag the release
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# Create GitHub release
# Visit: https://github.com/Vinamra111/health-sync-sdk/releases/new
# - Tag: v1.0.0
# - Title: "v1.0.0 - Initial Release"
# - Description: Copy from CHANGELOG.md
```

### Update Documentation

1. Update main README.md with installation instructions
2. Update CHANGELOG.md in each package
3. Create blog post announcing release
4. Share on social media

## Troubleshooting

### NPM: "need to log in"

```bash
npm login
# Enter credentials
npm whoami  # Verify login
```

### NPM: "403 Forbidden"

- Ensure organization `@healthsync` exists
- Ensure you're a member of the organization
- Try `npm publish --access public`

### Flutter: "authentication required"

```bash
# Clear credentials and re-authenticate
rm ~/.pub-cache/credentials.json
flutter pub publish
```

### Flutter: "validation failed"

```bash
# Run dry-run to see issues
flutter pub publish --dry-run

# Common issues:
# - Missing homepage in pubspec.yaml
# - Missing repository in pubspec.yaml
# - Missing description
# - Invalid version format
```

### "Files too large"

- Check .npmignore (NPM) or .gitignore (Flutter)
- Ensure build artifacts excluded
- Ensure node_modules excluded

## Version Management

### Semantic Versioning

Follow [SemVer](https://semver.org):

- **MAJOR** (1.0.0 → 2.0.0): Breaking changes
- **MINOR** (1.0.0 → 1.1.0): New features (backwards compatible)
- **PATCH** (1.0.0 → 1.0.1): Bug fixes

### Update Package Versions

**NPM packages** (`package.json`):
```json
{
  "version": "1.0.1"
}
```

**Flutter package** (`pubspec.yaml`):
```yaml
version: 1.0.1
```

### Version Dependencies

When updating package versions, ensure inter-package dependencies are updated:

**React Native** depends on **Core**:
```json
{
  "dependencies": {
    "@healthsync/core": "^1.0.0"
  }
}
```

## Beta/Alpha Releases

### NPM Beta Release

```bash
# Update version in package.json
npm version 1.1.0-beta.1

# Publish with beta tag
npm publish --tag beta

# Install beta version
npm install @healthsync/core@beta
```

### Flutter Pre-Release

```yaml
# pubspec.yaml
version: 1.1.0-beta.1
```

```bash
flutter pub publish
```

## Support

- **NPM Issues**: [NPM Support](https://www.npmjs.com/support)
- **Pub.dev Issues**: [Pub.dev Help](https://pub.dev/help)
- **Repository Issues**: [GitHub Issues](https://github.com/Vinamra111/health-sync-sdk/issues)

---

Made with ❤️ by the HCL Healthcare Product Team
