# @healthsync/core

> Universal health data integration SDK for TypeScript/JavaScript

[![npm version](https://img.shields.io/npm/v/@healthsync/core)](https://www.npmjs.com/package/@healthsync/core)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

## Features

- **Zero Dependencies** - Lightweight core library
- **Plugin Architecture** - Extensible for any health platform
- **Unified Data Models** - Standardized across all sources
- **TypeScript First** - Fully typed with strict mode

## Installation

```bash
npm install @healthsync/core
```

## Quick Start

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

## Platform Packages

- [`@healthsync/react-native`](https://www.npmjs.com/package/@healthsync/react-native) - React Native integration
- [`health_sync_flutter`](https://pub.dev/packages/health_sync_flutter) - Flutter plugin

## License

MIT - see [LICENSE](./LICENSE)

**[GitHub](https://github.com/Vinamra111/health-sync-sdk)** • **[Issues](https://github.com/Vinamra111/health-sync-sdk/issues)**

---

Made with ❤️ by the HCL Healthcare Product Team
