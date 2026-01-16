# HealthSync SDK Distribution Strategy

**YES! SDK will be published as packages that apps install as dependencies**

---

## 📦 Distribution Channels

### 1. TypeScript/JavaScript SDK → **npm**

**Package:** `@healthsync/core` or `healthsync-sdk`

**For:**
- React Native apps
- Expo apps
- Web apps
- Node.js backends

**Installation:**
```bash
npm install healthsync-sdk
# or
npm install @healthsync/core
```

**Usage in app:**
```typescript
import { HealthSyncManager, DataType } from 'healthsync-sdk';

const sdk = new HealthSyncManager(config);
await sdk.fetchData({ dataType: DataType.STEPS });
```

---

### 2. Flutter/Dart SDK → **pub.dev**

**Package:** `health_sync_flutter`

**For:**
- Flutter apps (Android & iOS)

**Installation:**
```bash
flutter pub add health_sync_flutter
```

**Or in `pubspec.yaml`:**
```yaml
dependencies:
  health_sync_flutter: ^1.0.0
```

**Usage in app:**
```dart
import 'package:health_sync_flutter/health_sync_flutter.dart';

final healthConnect = HealthConnectPlugin();
await healthConnect.fetchData(query);
```

---

## 🎯 Current vs Production

### Current State (Development/Testing)

**Test app uses LOCAL path:**

```yaml
# test-app/pubspec.yaml
dependencies:
  health_sync_flutter:
    path: ../packages/flutter/health_sync_flutter  # Local path
```

**Why?**
- ✅ Testing during development
- ✅ Makes changes immediately available
- ✅ No need to publish for every test

**This is ONLY for development!**

---

### Production (Real Apps)

**Apps will install from pub.dev:**

```yaml
# any-app/pubspec.yaml
dependencies:
  health_sync_flutter: ^1.0.0  # From pub.dev
```

**Why?**
- ✅ SDK is NOT hardcoded into app
- ✅ Apps just add dependency
- ✅ Version controlled
- ✅ Easy to update
- ✅ Same as any other package

---

## 📊 How It Works

### For TypeScript Apps

```
┌─────────────────────────────────┐
│  Developer's React Native App   │
│                                  │
│  package.json:                   │
│  {                               │
│    "dependencies": {             │
│      "healthsync-sdk": "^1.0.0"  │ ← Installed from npm
│    }                             │
│  }                               │
└─────────────────────────────────┘
                ↓
         npm install
                ↓
┌─────────────────────────────────┐
│     node_modules/               │
│     └── healthsync-sdk/         │ ← Downloaded from npm
│         ├── dist/               │
│         ├── types/              │
│         └── package.json        │
└─────────────────────────────────┘
                ↓
    App imports and uses SDK
```

---

### For Flutter Apps

```
┌─────────────────────────────────┐
│    Developer's Flutter App       │
│                                  │
│  pubspec.yaml:                   │
│  dependencies:                   │
│    health_sync_flutter: ^1.0.0   │ ← Installed from pub.dev
└─────────────────────────────────┘
                ↓
        flutter pub get
                ↓
┌─────────────────────────────────┐
│     .pub-cache/                 │
│     └── health_sync_flutter/    │ ← Downloaded from pub.dev
│         ├── lib/                │
│         ├── android/            │
│         └── pubspec.yaml        │
└─────────────────────────────────┘
                ↓
    App imports and uses SDK
```

---

## 🚀 Publishing Process

### TypeScript SDK to npm

**Step 1: Prepare Package**

```bash
cd packages/core

# Update package.json
{
  "name": "healthsync-sdk",  # or @healthsync/core
  "version": "1.0.0",
  "description": "Universal health data SDK",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "repository": "github:yourorg/healthsync-sdk",
  "license": "MIT"
}
```

**Step 2: Build**

```bash
npm run build
# Creates dist/ with compiled JavaScript
```

**Step 3: Publish**

```bash
npm login
npm publish
# or for scoped package
npm publish --access public
```

**Step 4: Apps Install**

```bash
npm install healthsync-sdk
```

---

### Flutter SDK to pub.dev

**Step 1: Prepare Package**

```yaml
# pubspec.yaml
name: health_sync_flutter
description: Flutter plugin for HealthSync SDK
version: 1.0.0
homepage: https://github.com/yourorg/healthsync-sdk
repository: https://github.com/yourorg/healthsync-sdk

environment:
  sdk: '>=3.0.0 <4.0.0'
  flutter: ">=3.0.0"
```

**Step 2: Validate**

```bash
cd packages/flutter/health_sync_flutter
flutter pub publish --dry-run
```

**Step 3: Publish**

```bash
flutter pub publish
```

**Step 4: Apps Install**

```bash
flutter pub add health_sync_flutter
```

---

## 📝 What Apps See

### npm Package

**On npmjs.com:**

```
healthsync-sdk

Universal health data integration SDK

Installation:
  npm install healthsync-sdk

Weekly Downloads: 10,000+
Version: 1.0.0
License: MIT
```

---

### pub.dev Package

**On pub.dev:**

```
health_sync_flutter

Flutter plugin for HealthSync SDK - Health Connect integration

Installing:
  flutter pub add health_sync_flutter

Pub Points: 130/130
Popularity: 95%
Version: 1.0.0
```

---

## 🎯 SDK is NOT Hardcoded

### ❌ What We DON'T Do (Bad):

```
App/
├── src/
│   ├── components/
│   ├── healthsync-sdk/  ← DON'T copy SDK code into app
│   │   ├── plugins/
│   │   ├── types/
│   │   └── index.ts
│   └── App.tsx
```

**Problems:**
- ❌ SDK code duplicated in every app
- ❌ Hard to update SDK
- ❌ No version control
- ❌ Increases app size

---

### ✅ What We DO (Good):

```
App/
├── package.json
│   dependencies:
│     healthsync-sdk: ^1.0.0  ← Just a dependency
├── src/
│   ├── components/
│   └── App.tsx
└── node_modules/
    └── healthsync-sdk/  ← npm installs it here
```

**Benefits:**
- ✅ SDK is external dependency
- ✅ Easy to update (npm update)
- ✅ Version controlled
- ✅ Smaller app code
- ✅ Same as React, Axios, etc.

---

## 🔍 How Apps Use It

### Example 1: React Native App

**Developer does:**

```bash
# 1. Create app
npx react-native init MyHealthApp

# 2. Install SDK (from npm)
cd MyHealthApp
npm install healthsync-sdk

# 3. Use in code
```

```typescript
// App.tsx
import { HealthSyncManager } from 'healthsync-sdk';

const sdk = new HealthSyncManager(config);
const data = await sdk.fetchData(query);
```

**That's it!** SDK is just a dependency.

---

### Example 2: Flutter App

**Developer does:**

```bash
# 1. Create app
flutter create my_health_app

# 2. Install SDK (from pub.dev)
cd my_health_app
flutter pub add health_sync_flutter

# 3. Use in code
```

```dart
// main.dart
import 'package:health_sync_flutter/health_sync_flutter.dart';

final sdk = HealthConnectPlugin();
final data = await sdk.fetchData(query);
```

**That's it!** SDK is just a dependency.

---

## 📦 Package Structure

### npm Package Contents

```
healthsync-sdk/
├── package.json
├── README.md
├── LICENSE
├── dist/              ← Compiled JavaScript
│   ├── index.js
│   ├── index.d.ts
│   ├── plugins/
│   └── types/
├── src/              ← TypeScript source (optional)
│   ├── index.ts
│   ├── plugins/
│   └── types/
└── docs/
```

**What gets published:** `dist/`, `package.json`, `README.md`, `LICENSE`

---

### pub.dev Package Contents

```
health_sync_flutter/
├── pubspec.yaml
├── README.md
├── LICENSE
├── CHANGELOG.md
├── lib/              ← Dart code
│   ├── health_sync_flutter.dart
│   └── src/
├── android/          ← Android native code
│   └── src/main/kotlin/
├── ios/              ← iOS native code (future)
│   └── Classes/
├── example/          ← Example app
└── test/             ← Tests
```

**What gets published:** Everything except `example/` and `test/`

---

## 🎯 Versioning

### Semantic Versioning (SemVer)

```
1.0.0
│ │ │
│ │ └─ Patch (bug fixes)
│ └─── Minor (new features, backward compatible)
└───── Major (breaking changes)
```

**Examples:**
- `1.0.0` → Initial release
- `1.0.1` → Bug fix
- `1.1.0` → New feature (add new data type)
- `2.0.0` → Breaking change (API redesign)

**Apps specify version:**

```json
// package.json
{
  "dependencies": {
    "healthsync-sdk": "^1.0.0"  // ← Any 1.x.x version
  }
}
```

```yaml
# pubspec.yaml
dependencies:
  health_sync_flutter: ^1.0.0  # Any 1.x.x version
```

---

## 🔄 Update Process

### For Apps Using npm

```bash
# Check for updates
npm outdated

# Update to latest compatible version
npm update healthsync-sdk

# Update to specific version
npm install healthsync-sdk@2.0.0
```

---

### For Apps Using pub.dev

```bash
# Check for updates
flutter pub outdated

# Update to latest compatible version
flutter pub upgrade health_sync_flutter

# Update to specific version
flutter pub add health_sync_flutter:2.0.0
```

---

## 📊 Comparison

### Local Path (Test App - Development Only)

```yaml
dependencies:
  health_sync_flutter:
    path: ../packages/flutter/health_sync_flutter
```

**Use when:**
- ✅ Developing the SDK itself
- ✅ Testing changes locally
- ✅ Before publishing

**DON'T use in production apps!**

---

### Published Package (Production Apps)

```yaml
dependencies:
  health_sync_flutter: ^1.0.0
```

**Use when:**
- ✅ Building real apps
- ✅ SDK is published
- ✅ Want automatic updates
- ✅ Sharing with other developers

**This is the normal way!**

---

## 🎯 Summary

### Current State

**Test App:**
- Uses `path:` dependency (local)
- For SDK development and testing
- Not how real apps will use it

**Production Apps:**
- Will use `^1.0.0` from npm/pub.dev
- SDK is external dependency
- Not hardcoded into app
- Just like React, Flutter, or any package

---

### Distribution Model

```
SDK Development → Publish → Apps Install
     (You)          │         (Developers)
                    │
         ┌──────────┴──────────┐
         ↓                     ↓
    npm publish          flutter pub publish
         ↓                     ↓
    npmjs.com              pub.dev
         ↓                     ↓
   npm install          flutter pub add
         ↓                     ↓
    Any JS App            Any Flutter App
```

---

## ✅ Answer to Your Question

**Q:** "So we are making our SDK as an npm package which can be installed by any application right?"

**A:**

✅ **Yes, exactly!**

**TypeScript SDK:**
- Published to **npm** as `healthsync-sdk`
- Apps install via `npm install healthsync-sdk`
- Just like React, Axios, or any npm package

**Flutter SDK:**
- Published to **pub.dev** as `health_sync_flutter`
- Apps install via `flutter pub add health_sync_flutter`
- Just like any Flutter package

**NOT hardcoded:**
- ✅ SDK is external dependency
- ✅ Apps just add to package.json/pubspec.yaml
- ✅ Version controlled
- ✅ Easy to update
- ✅ Same model as all popular libraries

**Test app uses local path ONLY for testing during development.**

**Real apps will install from npm/pub.dev!** 🚀

---

## 📋 Publishing Checklist

Before publishing:

### npm Package
- [ ] Tests pass
- [ ] Build succeeds
- [ ] README complete
- [ ] LICENSE file
- [ ] Version bumped
- [ ] CHANGELOG updated
- [ ] npm login done
- [ ] `npm publish --dry-run` works

### pub.dev Package
- [ ] Tests pass
- [ ] Example app works
- [ ] README complete
- [ ] LICENSE file
- [ ] Version bumped
- [ ] CHANGELOG updated
- [ ] `flutter pub publish --dry-run` works
- [ ] Pub points check passes

---

**Ready to publish once SDK is feature-complete!** 📦
