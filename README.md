# HealthSync SDK

> Universal health data integration SDK for TypeScript, React Native, and Flutter

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![npm core](https://img.shields.io/npm/v/@healthsync/core?label=core)](https://www.npmjs.com/package/@healthsync/core)
[![npm react-native](https://img.shields.io/npm/v/@healthsync/react-native?label=react-native)](https://www.npmjs.com/package/@healthsync/react-native)
[![pub flutter](https://img.shields.io/pub/v/health_sync_flutter?label=flutter)](https://pub.dev/packages/health_sync_flutter)

Integrate health data from multiple platforms with a unified API. Built for production with enterprise-grade features including Health Connect stub detection, OEM-specific optimizations, and comprehensive test coverage.

## 🚀 Quick Start

### TypeScript/JavaScript
```bash
npm install @healthsync/core
```

### React Native
```bash
npm install @healthsync/react-native @healthsync/core
```

### Flutter
```bash
flutter pub add health_sync_flutter
```

## 📦 Packages

| Package | Platform | Description | Version |
|---------|----------|-------------|---------|
| [`@healthsync/core`](packages/core) | Universal | Core TypeScript SDK with unified data models | [![npm](https://img.shields.io/npm/v/@healthsync/core)](https://www.npmjs.com/package/@healthsync/core) |
| [`@healthsync/react-native`](packages/react-native) | React Native | Android Health Connect integration | [![npm](https://img.shields.io/npm/v/@healthsync/react-native)](https://www.npmjs.com/package/@healthsync/react-native) |
| [`health_sync_flutter`](packages/flutter/health_sync_flutter) | Flutter | Health Connect with enterprise onboarding | [![pub](https://img.shields.io/pub/v/health_sync_flutter)](https://pub.dev/packages/health_sync_flutter) |

## ✨ Features

### Core SDK (`@healthsync/core`)
- **Zero Dependencies** - Lightweight and portable
- **Plugin Architecture** - Extensible for any health platform
- **Unified Data Models** - Consistent API across all sources
- **TypeScript First** - Full type safety with strict mode

### React Native (`@healthsync/react-native`)
- **Health Connect Integration** - Android health data access
- **13+ Data Types** - Steps, heart rate, sleep, activity, etc.
- **Permission Management** - Built-in permission handling
- **Battle-Tested** - Production-ready Kotlin implementation

### Flutter (`health_sync_flutter`)
- **Enterprise Onboarding** - Automatic Health Connect stub detection
- **OEM Intelligence** - Device-specific optimizations for 10+ manufacturers
- **Update Loop Mitigation** - Handles Android 14/15 caching bugs
- **Background Sync** - Reliable background data synchronization
- **117+ Tests** - Comprehensive test coverage

## 🎯 Usage Examples

### TypeScript/JavaScript

```typescript
import { HealthSyncSDK, DataType } from '@healthsync/core';

const sdk = await HealthSyncSDK.initialize();
sdk.registerPlugin(healthConnectPlugin);

const steps = await sdk.query({
  dataType: DataType.STEPS,
  startDate: '2024-01-01T00:00:00Z',
  endDate: '2024-01-07T23:59:59Z'
});
```

### React Native

```typescript
import { HealthConnectPlugin, DataType } from '@healthsync/react-native';

const plugin = new HealthConnectPlugin();
await plugin.initialize({});
await plugin.connect();

await plugin.requestPermissions([
  HealthConnectPermission.READ_STEPS,
  HealthConnectPermission.READ_HEART_RATE
]);

const data = await plugin.fetchData({
  dataType: DataType.STEPS,
  startDate: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString(),
  endDate: new Date().toISOString(),
});
```

### Flutter

```dart
import 'package:health_sync_flutter/health_sync_flutter.dart';

final plugin = HealthConnectPlugin();

// Check availability
final available = await plugin.isHealthConnectAvailable();

// Request permissions
final permissions = await plugin.requestPermissions([
  HealthPermission.readSteps,
  HealthPermission.readHeartRate,
]);

// Fetch data
final steps = await plugin.readStepData(
  startDate: DateTime.now().subtract(Duration(days: 7)),
  endDate: DateTime.now(),
);
```

## 🏥 Supported Data Types

- **Activity**: Steps, Distance, Calories, Exercise
- **Vitals**: Heart Rate, Blood Pressure, Blood Oxygen, Body Temperature
- **Sleep**: Sleep duration and stages
- **Body**: Weight, Height
- **Advanced**: Heart Rate Variability, Resting Heart Rate

## 🔧 Requirements

### TypeScript/JavaScript
- Node.js ≥ 16.0.0

### React Native
- React Native ≥ 0.60.0
- Android SDK 26+ (Android 8.0+)

### Flutter
- Flutter SDK ≥ 3.0.0
- Android SDK 26+ (Android 8.0+)
- Kotlin 1.9+

## 📱 Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| Android (Health Connect) | ✅ Available | Full support with stub detection |
| iOS (HealthKit) | 🚧 Coming Soon | Planned for v1.1.0 |
| Web | ⏳ Future | Planned for future release |

## 🧪 Testing

All packages include comprehensive test coverage:

```bash
# Core SDK
cd packages/core && npm test

# React Native
cd packages/react-native && npm test

# Flutter (117+ tests)
cd packages/flutter/health_sync_flutter && flutter test
```

## 📚 Documentation

- [Core SDK Documentation](packages/core/README.md)
- [React Native Documentation](packages/react-native/README.md)
- [Flutter Documentation](packages/flutter/health_sync_flutter/README.md)
- [Publishing Guide](PUBLISHING.md)

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🏢 About

Developed and maintained by the **HCL Healthcare Product Team**.

For questions, issues, or feedback:
- **Issues**: [GitHub Issues](https://github.com/Vinamra111/health-sync-sdk/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Vinamra111/health-sync-sdk/discussions)

## 🔗 Links

- **NPM (Core)**: https://www.npmjs.com/package/@healthsync/core
- **NPM (React Native)**: https://www.npmjs.com/package/@healthsync/react-native
- **pub.dev (Flutter)**: https://pub.dev/packages/health_sync_flutter

---

Made with ❤️ by the HCL Healthcare Product Team
