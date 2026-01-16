# @healthsync/core

Core TypeScript SDK for HealthSync - Universal health data integration platform.

## Overview

HealthSync SDK provides a unified, plugin-based architecture for integrating with multiple health data sources including Apple HealthKit, Google Health Connect, Fitbit, Garmin, and more.

## Features

- **Zero Dependencies**: Lightweight core with no external runtime dependencies
- **Strict TypeScript**: Fully typed with strict mode enabled
- **Plugin Architecture**: Extensible design for easy integration of new health platforms
- **Unified Data Models**: Standardized data structures across all health sources
- **Production-Ready**: Built with error handling, retry logic, and caching

## Installation

```bash
npm install @healthsync/core
```

## Quick Start

```typescript
import { HealthSyncSDK, DataType, HealthSource } from '@healthsync/core';

// Initialize SDK
const sdk = await HealthSyncSDK.initialize({
  logLevel: LogLevel.INFO,
  cache: {
    enabled: true,
    layers: [CacheLayer.MEMORY, CacheLayer.LOCAL_DB]
  }
});

// Register plugins
sdk.registerPlugin(healthConnectPlugin);
sdk.registerPlugin(fitbitPlugin);

// Connect to a health source
const result = await sdk.connect(HealthSource.HEALTH_CONNECT);

// Query health data
const steps = await sdk.query({
  dataType: DataType.STEPS,
  startDate: '2024-01-01T00:00:00Z',
  endDate: '2024-01-07T23:59:59Z'
});
```

## Architecture

### Core Components

1. **Unified Data Models** (`models/unified-data.ts`)
   - Standardized interfaces for all health data types
   - Type-safe enums for data sources and types
   - Comprehensive data quality metadata

2. **Plugin Interface** (`plugins/plugin-interface.ts`)
   - Contract for all health platform integrations
   - Lifecycle management (init, connect, disconnect, dispose)
   - Data fetching and real-time updates

3. **Configuration** (`types/config.ts`)
   - SDK configuration options
   - Sync options and callbacks
   - Error types and handling

## Data Types

Supported health data types:

- Steps, Distance, Calories
- Heart Rate, Heart Rate Variability, Resting Heart Rate
- Sleep (with stage tracking)
- Activities/Workouts
- Blood Oxygen, Blood Pressure, Blood Glucose
- Body Metrics (Weight, Height, BMI, Body Fat)
- Hydration, Nutrition
- Respiratory Rate, VO2 Max

## Creating a Custom Plugin

```typescript
import { BasePlugin, DataType, PluginConfig } from '@healthsync/core';

export class CustomHealthPlugin extends BasePlugin {
  readonly id = 'custom-health';
  readonly name = 'Custom Health Provider';
  readonly version = '1.0.0';
  readonly supportedDataTypes = [DataType.STEPS, DataType.HEART_RATE];
  readonly requiresAuthentication = true;
  readonly isCloudBased = true;

  async initialize(config: PluginConfig): Promise<void> {
    // Setup plugin
  }

  async connect(): Promise<ConnectionResult> {
    // Handle connection/auth
  }

  async fetchData(query: DataQuery): Promise<RawHealthData[]> {
    // Fetch data from source
  }

  // ... implement other interface methods
}
```

## TypeScript Configuration

This package uses strict TypeScript configuration:

- `strict`: true
- `noImplicitAny`: true
- `strictNullChecks`: true
- `noUnusedLocals`: true
- `noUnusedParameters`: true

## Development

```bash
# Install dependencies
npm install

# Build
npm run build

# Watch mode
npm run dev

# Run tests
npm test

# Lint
npm run lint

# Format
npm run format
```

## License

MIT

## Contributing

See the main repository for contribution guidelines.
