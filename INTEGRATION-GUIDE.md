# HealthSync SDK - Integration Guide
**The Complete Reference for Adding New Health Platform Integrations**

Version: 1.0.0
Last Updated: January 2026
Status: Production-Ready

---

## 🎯 What is HealthSync SDK?

HealthSync is a **world-class, production-grade SDK** that provides a **unified API** for accessing health data from multiple wearables and fitness platforms. Apps using HealthSync SDK **never need to write integration code** - we handle everything.

**Think of us like [Terra API](https://tryterra.co), but as an open-source SDK.**

### Key Value Proposition

✅ **One API, All Devices** - Single interface for Apple Health, Google Health Connect, Fitbit, Garmin, Oura, Whoop, Strava, etc.
✅ **Zero Integration Complexity** - Apps just install our npm/pub.dev package
✅ **Unified Data Model** - All health data normalized to consistent format
✅ **Enterprise-Grade** - Permission management, error handling, logging, analytics
✅ **Platform Agnostic** - Works on iOS, Android, Web, React Native, Flutter

---

## 🏗️ SDK Architecture Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      APP LAYER                               │
│  (React Native App / Flutter App / Any Mobile App)          │
│  - Just installs: npm install healthsync-sdk                │
│  - Never touches platform-specific APIs                     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                  HEALTHSYNC SDK CORE                         │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Unified API Layer                                   │  │
│  │  - fetchData(query)                                  │  │
│  │  - requestPermissions(permissions)                   │  │
│  │  - connect(platform)                                 │  │
│  └──────────────────────────────────────────────────────┘  │
│                            ↓                                 │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Plugin Registry (Manages all integrations)         │  │
│  │  - registerPlugin(plugin)                           │  │
│  │  - getPlugin(platformName)                          │  │
│  │  - Plugin lifecycle management                       │  │
│  └──────────────────────────────────────────────────────┘  │
│                            ↓                                 │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Data Normalizer (Converts all to unified format)   │  │
│  │  - transform(rawData) → UnifiedHealthData           │  │
│  │  - Unit conversions, quality scoring                │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                 PLUGIN LAYER (Integrations)                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Health       │  │ Apple        │  │ Fitbit       │     │
│  │ Connect      │  │ HealthKit    │  │ Plugin       │     │
│  │ Plugin       │  │ Plugin       │  │              │     │
│  │ (Android)    │  │ (iOS)        │  │ (Cloud API)  │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Garmin       │  │ Oura         │  │ Whoop        │     │
│  │ Plugin       │  │ Plugin       │  │ Plugin       │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│              NATIVE PLATFORM LAYER                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Health       │  │ HealthKit    │  │ REST APIs    │     │
│  │ Connect API  │  │ Framework    │  │ (OAuth)      │     │
│  │ (Kotlin)     │  │ (Swift)      │  │              │     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

---

## 📂 Project Structure

```
SDK_StandardizingHealthDataV0/
├── packages/
│   ├── core/                          # TypeScript Core SDK
│   │   ├── src/
│   │   │   ├── index.ts               # Main entry point
│   │   │   ├── models/                # Unified data models
│   │   │   │   └── unified-data.ts    # UnifiedHealthData, DataType, HealthSource
│   │   │   ├── plugins/               # Plugin system
│   │   │   │   ├── plugin-interface.ts    # IHealthDataPlugin interface
│   │   │   │   └── plugin-registry.ts     # Plugin management
│   │   │   ├── types/                 # Configuration types
│   │   │   │   └── config.ts          # SDKConfig, Error classes
│   │   │   ├── normalizer/            # Data transformation
│   │   │   ├── cache/                 # Caching layer
│   │   │   └── errors/                # Error handling
│   │   └── package.json               # Published to npm
│   │
│   └── flutter/
│       └── health_sync_flutter/       # Flutter/Dart SDK
│           ├── lib/
│           │   ├── health_sync_flutter.dart    # Main entry
│           │   └── src/
│           │       ├── models/                  # Dart models
│           │       ├── plugins/                 # Flutter plugins
│           │       │   └── health_connect/      # Health Connect integration
│           │       │       ├── health_connect_plugin.dart
│           │       │       └── health_connect_types.dart
│           │       ├── types/                   # Type definitions
│           │       └── utils/                   # Utilities
│           │           ├── logger.dart          # Logging system
│           │           └── permission_tracker.dart  # Analytics
│           └── android/
│               └── src/main/kotlin/
│                   └── HealthSyncFlutterPlugin.kt  # Native Android bridge
│
├── plugins/                           # Additional integrations
│   ├── fitbit/                       # Fitbit integration
│   ├── garmin/                       # Garmin integration
│   ├── oura/                         # Oura integration
│   └── apple-health/                 # Apple HealthKit integration
│
├── examples/                          # Example apps
│   └── react-native-example/
│
├── test-app/                          # Flutter test app
│   └── lib/main.dart                 # Demonstrates SDK usage
│
└── docs/                              # Documentation
    ├── API.md                        # API reference
    └── INTEGRATION-GUIDE.md          # This file
```

---

## 🔌 Plugin System Deep Dive

### How Plugins Work

Every health platform integration is a **plugin** that implements the `IHealthDataPlugin` interface. This ensures consistency across all integrations.

### Plugin Interface (TypeScript)

```typescript
// packages/core/src/plugins/plugin-interface.ts

export interface IHealthDataPlugin {
  // === Metadata ===
  readonly id: string;                    // Unique identifier (e.g., "health-connect")
  readonly name: string;                  // Display name (e.g., "Google Health Connect")
  readonly version: string;               // Plugin version
  readonly supportedDataTypes: DataType[]; // What data types this plugin supports
  readonly requiresAuthentication: boolean; // OAuth required?
  readonly isCloudBased: boolean;         // API-based or local?

  // === Lifecycle ===
  initialize(): Promise<void>;            // Setup, validate credentials
  dispose(): Promise<void>;               // Cleanup resources

  // === Connection Management ===
  connect(credentials?: PluginCredentials): Promise<ConnectionResult>;
  disconnect(): Promise<void>;
  isConnected(): Promise<boolean>;
  getConnectionStatus(): Promise<ConnectionStatus>;

  // === Permissions ===
  checkPermissions(dataTypes: DataType[]): Promise<PermissionStatus[]>;
  requestPermissions(dataTypes: DataType[]): Promise<DataType[]>;

  // === Data Operations ===
  fetchData(query: DataQuery): Promise<RawHealthData[]>;
  subscribeToUpdates?(callback: DataUpdateCallback): Subscription;

  // === Error Handling ===
  onError?(error: Error): Promise<ErrorHandlingStrategy>;

  // === Rate Limiting (for cloud APIs) ===
  getRateLimitStatus?(): Promise<RateLimitInfo>;
}
```

### Base Plugin Class (Optional Helper)

```typescript
// Plugins can extend BasePlugin to get default implementations

export abstract class BasePlugin implements IHealthDataPlugin {
  abstract id: string;
  abstract name: string;
  abstract version: string;
  abstract supportedDataTypes: DataType[];

  requiresAuthentication = false;
  isCloudBased = false;

  // Default implementations
  async initialize(): Promise<void> {
    // Base initialization logic
  }

  async dispose(): Promise<void> {
    // Base cleanup logic
  }

  // Subclasses must implement:
  abstract connect(credentials?: PluginCredentials): Promise<ConnectionResult>;
  abstract fetchData(query: DataQuery): Promise<RawHealthData[]>;
  // ... other required methods
}
```

---

## 🚀 How to Add a New Integration

### Step-by-Step Guide: Adding Fitbit Plugin

Let's walk through adding a **Fitbit integration** as a complete example.

---

#### **Step 1: Create Plugin Directory Structure**

```bash
mkdir -p plugins/fitbit/src
cd plugins/fitbit
```

```
plugins/fitbit/
├── src/
│   ├── fitbit-plugin.ts          # Main plugin implementation
│   ├── fitbit-types.ts           # Fitbit-specific types
│   ├── fitbit-api-client.ts      # API wrapper
│   └── fitbit-data-mapper.ts     # Maps Fitbit data to UnifiedHealthData
├── package.json
├── tsconfig.json
└── README.md
```

---

#### **Step 2: Define Fitbit-Specific Types**

```typescript
// plugins/fitbit/src/fitbit-types.ts

export interface FitbitCredentials {
  accessToken: string;
  refreshToken: string;
  expiresAt: Date;
  userId: string;
}

export interface FitbitApiConfig {
  clientId: string;
  clientSecret: string;
  redirectUri: string;
  scopes: FitbitScope[];
}

export enum FitbitScope {
  ACTIVITY = 'activity',
  HEARTRATE = 'heartrate',
  SLEEP = 'sleep',
  WEIGHT = 'weight',
  NUTRITION = 'nutrition',
  // ... other scopes
}

export interface FitbitActivityData {
  activities: Array<{
    activityId: number;
    activityName: string;
    startTime: string;
    duration: number;
    calories: number;
    steps?: number;
    distance?: number;
  }>;
}

// ... more Fitbit-specific types
```

---

#### **Step 3: Implement the Plugin**

```typescript
// plugins/fitbit/src/fitbit-plugin.ts

import { BasePlugin, DataQuery, RawHealthData, DataType, ConnectionResult } from '@healthsync/core';
import { FitbitApiClient } from './fitbit-api-client';
import { FitbitDataMapper } from './fitbit-data-mapper';
import { FitbitCredentials, FitbitScope } from './fitbit-types';

export class FitbitPlugin extends BasePlugin {
  // === Metadata ===
  readonly id = 'fitbit';
  readonly name = 'Fitbit';
  readonly version = '1.0.0';
  readonly supportedDataTypes = [
    DataType.STEPS,
    DataType.HEART_RATE,
    DataType.SLEEP,
    DataType.CALORIES,
    DataType.DISTANCE,
    DataType.ACTIVITY,
    // ... all supported types
  ];
  readonly requiresAuthentication = true;
  readonly isCloudBased = true;

  // Private members
  private apiClient: FitbitApiClient;
  private dataMapper: FitbitDataMapper;
  private credentials?: FitbitCredentials;
  private isInitialized = false;

  constructor(config: FitbitApiConfig) {
    super();
    this.apiClient = new FitbitApiClient(config);
    this.dataMapper = new FitbitDataMapper();
  }

  // === Lifecycle ===
  async initialize(): Promise<void> {
    if (this.isInitialized) return;

    // Validate configuration
    await this.apiClient.validateConfig();

    this.isInitialized = true;
    console.log('Fitbit plugin initialized');
  }

  async dispose(): Promise<void> {
    this.credentials = undefined;
    this.isInitialized = false;
  }

  // === Connection Management ===
  async connect(credentials?: FitbitCredentials): Promise<ConnectionResult> {
    if (!credentials) {
      return {
        success: false,
        message: 'Fitbit requires OAuth credentials',
        metadata: {
          authUrl: this.apiClient.getAuthorizationUrl(),
        },
      };
    }

    try {
      // Validate credentials
      await this.apiClient.validateToken(credentials.accessToken);

      this.credentials = credentials;

      return {
        success: true,
        message: 'Connected to Fitbit',
        metadata: {
          userId: credentials.userId,
          scopes: await this.apiClient.getGrantedScopes(),
        },
      };
    } catch (error) {
      return {
        success: false,
        message: `Connection failed: ${error.message}`,
      };
    }
  }

  async disconnect(): Promise<void> {
    if (this.credentials) {
      await this.apiClient.revokeToken(this.credentials.accessToken);
      this.credentials = undefined;
    }
  }

  async isConnected(): Promise<boolean> {
    if (!this.credentials) return false;

    // Check if token is still valid
    try {
      await this.apiClient.validateToken(this.credentials.accessToken);
      return true;
    } catch {
      return false;
    }
  }

  // === Permissions ===
  async checkPermissions(dataTypes: DataType[]): Promise<PermissionStatus[]> {
    if (!this.credentials) {
      return dataTypes.map(dt => ({
        dataType: dt,
        granted: false,
        reason: 'Not connected',
      }));
    }

    const grantedScopes = await this.apiClient.getGrantedScopes();

    return dataTypes.map(dataType => {
      const requiredScope = this.mapDataTypeToScope(dataType);
      const granted = grantedScopes.includes(requiredScope);

      return {
        dataType,
        granted,
        reason: granted ? undefined : 'Permission not granted',
      };
    });
  }

  async requestPermissions(dataTypes: DataType[]): Promise<DataType[]> {
    // Fitbit requires re-authorization with new scopes
    const requiredScopes = dataTypes.map(dt => this.mapDataTypeToScope(dt));
    const authUrl = this.apiClient.getAuthorizationUrl(requiredScopes);

    throw new Error(
      `Please re-authorize with Fitbit: ${authUrl}`
    );
  }

  // === Data Operations ===
  async fetchData(query: DataQuery): Promise<RawHealthData[]> {
    if (!this.credentials) {
      throw new Error('Not connected to Fitbit');
    }

    try {
      // Map SDK DataType to Fitbit API endpoint
      const endpoint = this.mapDataTypeToEndpoint(query.dataType);

      // Fetch raw data from Fitbit API
      const fitbitData = await this.apiClient.fetchData({
        endpoint,
        userId: this.credentials.userId,
        startDate: query.startDate,
        endDate: query.endDate,
        accessToken: this.credentials.accessToken,
      });

      // Transform Fitbit data to UnifiedHealthData format
      const unifiedData = this.dataMapper.transform(
        fitbitData,
        query.dataType
      );

      return unifiedData;
    } catch (error) {
      throw new Error(`Failed to fetch Fitbit data: ${error.message}`);
    }
  }

  // === Helper Methods ===
  private mapDataTypeToScope(dataType: DataType): FitbitScope {
    const mapping: Record<DataType, FitbitScope> = {
      [DataType.STEPS]: FitbitScope.ACTIVITY,
      [DataType.HEART_RATE]: FitbitScope.HEARTRATE,
      [DataType.SLEEP]: FitbitScope.SLEEP,
      [DataType.CALORIES]: FitbitScope.ACTIVITY,
      // ... complete mapping
    };
    return mapping[dataType];
  }

  private mapDataTypeToEndpoint(dataType: DataType): string {
    const endpoints: Record<DataType, string> = {
      [DataType.STEPS]: '/1/user/-/activities/steps/date',
      [DataType.HEART_RATE]: '/1/user/-/activities/heart/date',
      [DataType.SLEEP]: '/1.2/user/-/sleep/date',
      // ... complete mapping
    };
    return endpoints[dataType];
  }
}
```

---

#### **Step 4: Implement API Client**

```typescript
// plugins/fitbit/src/fitbit-api-client.ts

import axios, { AxiosInstance } from 'axios';
import { FitbitApiConfig } from './fitbit-types';

export class FitbitApiClient {
  private httpClient: AxiosInstance;
  private config: FitbitApiConfig;

  constructor(config: FitbitApiConfig) {
    this.config = config;
    this.httpClient = axios.create({
      baseURL: 'https://api.fitbit.com',
      headers: {
        'Accept': 'application/json',
      },
    });
  }

  async validateConfig(): Promise<void> {
    if (!this.config.clientId || !this.config.clientSecret) {
      throw new Error('Fitbit API credentials required');
    }
  }

  getAuthorizationUrl(scopes?: FitbitScope[]): string {
    const scopeString = (scopes || this.config.scopes).join(' ');
    return `https://www.fitbit.com/oauth2/authorize?` +
      `client_id=${this.config.clientId}&` +
      `response_type=code&` +
      `scope=${encodeURIComponent(scopeString)}&` +
      `redirect_uri=${encodeURIComponent(this.config.redirectUri)}`;
  }

  async exchangeCodeForToken(code: string): Promise<FitbitCredentials> {
    const response = await this.httpClient.post('/oauth2/token', {
      client_id: this.config.clientId,
      client_secret: this.config.clientSecret,
      code,
      grant_type: 'authorization_code',
      redirect_uri: this.config.redirectUri,
    });

    return {
      accessToken: response.data.access_token,
      refreshToken: response.data.refresh_token,
      expiresAt: new Date(Date.now() + response.data.expires_in * 1000),
      userId: response.data.user_id,
    };
  }

  async refreshToken(refreshToken: string): Promise<FitbitCredentials> {
    const response = await this.httpClient.post('/oauth2/token', {
      client_id: this.config.clientId,
      client_secret: this.config.clientSecret,
      refresh_token: refreshToken,
      grant_type: 'refresh_token',
    });

    return {
      accessToken: response.data.access_token,
      refreshToken: response.data.refresh_token,
      expiresAt: new Date(Date.now() + response.data.expires_in * 1000),
      userId: response.data.user_id,
    };
  }

  async fetchData(params: {
    endpoint: string;
    userId: string;
    startDate: Date;
    endDate: Date;
    accessToken: string;
  }): Promise<any> {
    const response = await this.httpClient.get(params.endpoint, {
      headers: {
        Authorization: `Bearer ${params.accessToken}`,
      },
      params: {
        date: params.startDate.toISOString().split('T')[0],
        end_date: params.endDate.toISOString().split('T')[0],
      },
    });

    return response.data;
  }

  async validateToken(accessToken: string): Promise<boolean> {
    try {
      await this.httpClient.get('/1/user/-/profile.json', {
        headers: { Authorization: `Bearer ${accessToken}` },
      });
      return true;
    } catch {
      return false;
    }
  }

  async getGrantedScopes(): Promise<FitbitScope[]> {
    // Implementation depends on Fitbit API
    // Check what scopes are currently granted
    return [];
  }
}
```

---

#### **Step 5: Implement Data Mapper**

```typescript
// plugins/fitbit/src/fitbit-data-mapper.ts

import { RawHealthData, DataType, HealthSource } from '@healthsync/core';
import { FitbitActivityData } from './fitbit-types';

export class FitbitDataMapper {
  /**
   * Transforms Fitbit API response to UnifiedHealthData format
   */
  transform(fitbitData: any, dataType: DataType): RawHealthData[] {
    switch (dataType) {
      case DataType.STEPS:
        return this.mapStepsData(fitbitData);
      case DataType.HEART_RATE:
        return this.mapHeartRateData(fitbitData);
      case DataType.SLEEP:
        return this.mapSleepData(fitbitData);
      // ... other data types
      default:
        throw new Error(`Unsupported data type: ${dataType}`);
    }
  }

  private mapStepsData(data: FitbitActivityData): RawHealthData[] {
    return data.activities.map(activity => ({
      sourceDataType: 'Steps',
      source: HealthSource.FITBIT,
      timestamp: new Date(activity.startTime),
      endTimestamp: new Date(
        new Date(activity.startTime).getTime() + activity.duration * 1000
      ),
      raw: {
        activityId: activity.activityId,
        activityName: activity.activityName,
        steps: activity.steps,
        calories: activity.calories,
        distance: activity.distance,
        // Include all original Fitbit fields
        _original: activity,
      },
    }));
  }

  private mapHeartRateData(data: any): RawHealthData[] {
    // Transform Fitbit heart rate format to our format
    return data['activities-heart'][0].value.heartRateZones.map((zone: any) => ({
      sourceDataType: 'HeartRate',
      source: HealthSource.FITBIT,
      timestamp: new Date(data['activities-heart'][0].dateTime),
      raw: {
        min: zone.min,
        max: zone.max,
        minutes: zone.minutes,
        caloriesOut: zone.caloriesOut,
        _original: zone,
      },
    }));
  }

  private mapSleepData(data: any): RawHealthData[] {
    // Transform Fitbit sleep data
    return data.sleep.map((session: any) => ({
      sourceDataType: 'Sleep',
      source: HealthSource.FITBIT,
      timestamp: new Date(session.startTime),
      endTimestamp: new Date(session.endTime),
      raw: {
        duration: session.duration,
        efficiency: session.efficiency,
        minutesAsleep: session.minutesAsleep,
        minutesAwake: session.minutesAwake,
        stages: session.levels?.data || [],
        _original: session,
      },
    }));
  }
}
```

---

#### **Step 6: Package Configuration**

```json
// plugins/fitbit/package.json

{
  "name": "@healthsync/plugin-fitbit",
  "version": "1.0.0",
  "description": "Fitbit integration plugin for HealthSync SDK",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "scripts": {
    "build": "tsc",
    "test": "jest"
  },
  "peerDependencies": {
    "@healthsync/core": "^1.0.0"
  },
  "dependencies": {
    "axios": "^1.6.0"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "typescript": "^5.2.0"
  },
  "keywords": [
    "fitbit",
    "health",
    "healthsync",
    "plugin"
  ]
}
```

---

#### **Step 7: Export Plugin**

```typescript
// plugins/fitbit/src/index.ts

export { FitbitPlugin } from './fitbit-plugin';
export * from './fitbit-types';
export { FitbitApiClient } from './fitbit-api-client';
export { FitbitDataMapper } from './fitbit-data-mapper';
```

---

#### **Step 8: Register Plugin in Core SDK**

```typescript
// In the app code:

import { HealthSyncManager } from '@healthsync/core';
import { FitbitPlugin } from '@healthsync/plugin-fitbit';

const sdk = new HealthSyncManager({
  plugins: [
    new FitbitPlugin({
      clientId: process.env.FITBIT_CLIENT_ID,
      clientSecret: process.env.FITBIT_CLIENT_SECRET,
      redirectUri: 'myapp://fitbit/callback',
      scopes: [FitbitScope.ACTIVITY, FitbitScope.HEARTRATE],
    }),
  ],
});

// Now app can use Fitbit like any other integration
await sdk.connect('fitbit', credentials);
const data = await sdk.fetchData({
  source: 'fitbit',
  dataType: DataType.STEPS,
  startDate: new Date('2024-01-01'),
  endDate: new Date(),
});
```

---

## 📋 Integration Checklist

When adding a new health platform integration, ensure you complete all these steps:

### **Phase 1: Research & Planning**
- [ ] Study the platform's API documentation
- [ ] Identify authentication method (OAuth, API key, etc.)
- [ ] List all supported data types
- [ ] Understand rate limits and quotas
- [ ] Check if it's cloud-based or local SDK
- [ ] Review data format and structure

### **Phase 2: Setup**
- [ ] Create plugin directory structure
- [ ] Setup TypeScript/Dart project
- [ ] Install required dependencies
- [ ] Configure build tools

### **Phase 3: Implementation**
- [ ] Define platform-specific types
- [ ] Implement `IHealthDataPlugin` interface
- [ ] Create API client wrapper
- [ ] Implement data mapper
- [ ] Handle authentication flow
- [ ] Implement permission management
- [ ] Add error handling
- [ ] Add retry logic for API failures
- [ ] Implement rate limit handling

### **Phase 4: Data Mapping**
- [ ] Map all data types to `UnifiedHealthData`
- [ ] Handle unit conversions
- [ ] Add data quality scoring
- [ ] Preserve original data in `raw` field
- [ ] Handle edge cases and missing data

### **Phase 5: Testing**
- [ ] Write unit tests for data mapper
- [ ] Write integration tests with API
- [ ] Test error scenarios
- [ ] Test rate limiting
- [ ] Test token refresh flow
- [ ] Test with real devices/accounts

### **Phase 6: Documentation**
- [ ] Write plugin README
- [ ] Document setup instructions
- [ ] Add code examples
- [ ] Document known limitations
- [ ] Add troubleshooting guide

### **Phase 7: Publishing**
- [ ] Version your plugin (semver)
- [ ] Publish to npm (or private registry)
- [ ] Update main SDK docs
- [ ] Add to examples

---

## 🔍 Existing Integrations Reference

### Health Connect (Android) - PRODUCTION READY ✅

**Location**: `packages/flutter/health_sync_flutter/lib/src/plugins/health_connect/`

**Key Files**:
- `health_connect_plugin.dart` - Dart implementation
- `HealthSyncFlutterPlugin.kt` - Kotlin native bridge

**Features**:
- ✅ 42 permissions supported
- ✅ Local data access (no OAuth)
- ✅ Permission request flow
- ✅ Concurrent request protection
- ✅ 60-second timeout
- ✅ Comprehensive error handling
- ✅ Permission analytics

**Data Types**: Steps, Heart Rate, Sleep, Distance, Exercise, Calories, Blood Pressure, Oxygen Saturation, Temperature, Weight, Height, HRV, and 30+ more

**Permission Pattern**:
```dart
// Check permissions
final statuses = await plugin.checkPermissions([
  HealthConnectPermission.readSteps,
  HealthConnectPermission.readHeartRate,
]);

// Request permissions
final granted = await plugin.requestPermissions([
  HealthConnectPermission.readSteps,
]);

// Fetch data
final data = await plugin.fetchData(DataQuery(
  dataType: DataType.steps,
  startDate: startDate,
  endDate: endDate,
));
```

**Key Learnings**:
1. **Permission Mapping**: Each permission maps to a Record class
2. **Async Permission Model**: Health Connect uses `startActivity` + polling (NOT `startActivityForResult`)
3. **Race Conditions**: Must prevent concurrent permission requests
4. **Polling Required**: Must poll `getGrantedPermissions()` to detect changes (5-30 second wait)
5. **Timeouts**: Always add timeout for user interactions
6. **Validation**: Validate permissions before requesting
7. **Logging**: Log everything for debugging

**CRITICAL**: Health Connect permissions are processed asynchronously by the Android system. You MUST use `startActivity()` and then poll for permission changes. The standard `startActivityForResult()` pattern does NOT work with Health Connect.

---

## 🎨 Data Normalization Patterns

### Core Principle
**All platform-specific data must be transformed to `UnifiedHealthData` format**

### UnifiedHealthData Structure

```typescript
interface UnifiedHealthData {
  // Source identification
  sourceDataType: string;           // e.g., "Steps", "HeartRate"
  source: HealthSource;              // e.g., HEALTH_CONNECT, FITBIT

  // Temporal data
  timestamp: Date | string;          // ISO 8601 string or Date
  endTimestamp?: Date | string;      // For range-based data

  // Quality metadata
  quality?: DataQuality;             // HIGH, MEDIUM, LOW
  confidence?: number;               // 0-1 confidence score

  // Device info
  device?: {
    manufacturer?: string;
    model?: string;
    type?: string;
  };

  // Original data (preserve everything!)
  raw: Record<string, any>;          // Complete original response
}
```

### Data Type-Specific Schemas

```typescript
// Steps Data
interface StepsData extends UnifiedHealthData {
  sourceDataType: 'Steps';
  raw: {
    count: number;                   // Total step count
    startTime: string;
    endTime: string;
    source?: string;                 // App/device that recorded
  };
}

// Heart Rate Data
interface HeartRateData extends UnifiedHealthData {
  sourceDataType: 'HeartRate';
  raw: {
    bpm: number;                     // Beats per minute
    context?: 'RESTING' | 'ACTIVE' | 'EXERCISE';
    confidence?: number;
  };
}

// Sleep Data
interface SleepData extends UnifiedHealthData {
  sourceDataType: 'Sleep';
  raw: {
    duration: number;                // Total sleep in minutes
    stages: Array<{
      stage: 'DEEP' | 'LIGHT' | 'REM' | 'AWAKE';
      startTime: string;
      endTime: string;
      duration: number;
    }>;
    efficiency?: number;             // 0-100 sleep score
  };
}
```

### Normalization Best Practices

#### 1. **Always Preserve Original Data**
```typescript
// ✅ GOOD - Keep original data
const normalized = {
  sourceDataType: 'Steps',
  source: HealthSource.FITBIT,
  timestamp: new Date(fitbitData.dateTime),
  raw: {
    count: fitbitData.value,
    _original: fitbitData,  // Keep entire original response
  },
};

// ❌ BAD - Lose original data
const normalized = {
  sourceDataType: 'Steps',
  source: HealthSource.FITBIT,
  timestamp: new Date(fitbitData.dateTime),
  raw: {
    count: fitbitData.value,  // Only one field, rest lost!
  },
};
```

#### 2. **Handle Unit Conversions**
```typescript
// Different platforms use different units
function normalizeDistance(value: number, unit: string): number {
  switch (unit) {
    case 'km':
      return value * 1000; // Convert to meters
    case 'mi':
      return value * 1609.34; // Convert to meters
    case 'm':
      return value;
    default:
      throw new Error(`Unknown unit: ${unit}`);
  }
}
```

#### 3. **Handle Missing Data Gracefully**
```typescript
function mapFitbitSleep(fitbitSleep: any): SleepData {
  return {
    sourceDataType: 'Sleep',
    source: HealthSource.FITBIT,
    timestamp: new Date(fitbitSleep.startTime),
    endTimestamp: new Date(fitbitSleep.endTime),
    raw: {
      duration: fitbitSleep.duration || 0,
      stages: fitbitSleep.levels?.data || [],  // Default to empty if missing
      efficiency: fitbitSleep.efficiency ?? null,  // null if not available
      _original: fitbitSleep,
    },
  };
}
```

#### 4. **Add Quality Scoring**
```typescript
function calculateDataQuality(data: any): DataQuality {
  // Heuristics for quality assessment
  if (data.confidence && data.confidence > 0.9) return DataQuality.HIGH;
  if (data.device?.manufacturer === 'Fitbit') return DataQuality.HIGH;
  if (!data.source) return DataQuality.LOW;
  return DataQuality.MEDIUM;
}
```

---

## 🔐 Permission Handling Patterns

### Permission Flow Architecture

```
1. APP: Check if permissions granted
   ↓
2. SDK: Query platform for permission status
   ↓
3. If NOT granted → Request permissions
   ↓
4. PLATFORM: Show permission dialog to user
   ↓
5. USER: Grant or Deny
   ↓
6. SDK: Verify actual granted permissions
   ↓
7. APP: Receive result, update UI
```

### Permission Pattern for Cloud APIs (OAuth)

```typescript
class FitbitPlugin extends BasePlugin {
  async requestPermissions(dataTypes: DataType[]): Promise<DataType[]> {
    // OAuth flow - redirect to authorization page
    const requiredScopes = dataTypes.map(dt => this.mapDataTypeToScope(dt));
    const authUrl = this.generateAuthUrl(requiredScopes);

    // Provide auth URL to app
    throw new OAuthRequiredException({
      authUrl,
      scopes: requiredScopes,
      instructions: 'Please authorize via browser',
    });
  }

  // After OAuth callback
  async handleOAuthCallback(code: string): Promise<void> {
    const tokens = await this.exchangeCodeForTokens(code);
    await this.saveTokens(tokens);
  }
}
```

### Permission Pattern for Local SDKs (Native)

```kotlin
// Health Connect pattern (IMPORTANT: Health Connect uses async permission model)
fun requestPermissions(permissions: List<String>) {
  // 1. Filter already granted
  val grantedPermissions = client.permissionController.getGrantedPermissions()
  val toRequest = permissions.filter { !grantedPermissions.contains(it) }

  // 2. Create Health Connect permission intent
  val contract = PermissionController.createRequestPermissionResultContract()
  val intent = contract.createIntent(context, toRequest)

  // 3. Launch permission screen
  // CRITICAL: Use startActivity (NOT startActivityForResult)
  // Health Connect processes permissions asynchronously
  intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
  context.startActivity(intent)

  // 4. Poll for permission changes (Health Connect doesn't provide callback)
  scope.launch {
    var attempts = 0
    val maxAttempts = 30 // 30 seconds max

    while (attempts < maxAttempts && pendingResult != null) {
      delay(1000) // Check every second
      attempts++

      // Query current permission status
      val currentGranted = client.permissionController.getGrantedPermissions()
      val grantedPermissionStrings = requestedPermissions.filter { permName ->
        val recordClass = permissionToRecordClass(permName)
        currentGranted.contains(HealthPermission.getReadPermission(recordClass))
      }

      // Return result after minimum 5 seconds or when permissions detected
      if (grantedPermissionStrings.isNotEmpty() || attempts >= 5) {
        pendingResult?.success(grantedPermissionStrings)
        pendingResult = null
        break
      }
    }

    // Timeout - return whatever we have
    if (pendingResult != null) {
      val finalGranted = client.permissionController.getGrantedPermissions()
      // ... return result
      pendingResult = null
    }
  }

  // 5. Dart/Flutter layer receives result after 5-30 seconds
}
```

**Key Differences from Standard Android Permissions**:
- ❌ `startActivityForResult` → Doesn't work with Health Connect
- ✅ `startActivity` + polling → Correct approach
- ⏱️ 5-30 second wait → Health Connect processes permissions asynchronously
- 🔄 Polling every 1 second → Only way to detect permission grants
- 📊 Return after minimum 5 seconds → Ensures user has time to grant

**Why This Pattern?**
Health Connect's permission model is fundamentally different:
1. Permission screen is separate app (Health Connect app)
2. Grants are processed asynchronously by Android system
3. No direct callback to requesting app
4. Must poll `getGrantedPermissions()` to detect changes
5. Takes 5-30 seconds for system to process grants

### Permission Tracking & Analytics

```typescript
// Track every permission request
class PermissionTracker {
  trackPermissionRequest(result: PermissionRequestResult) {
    this.analytics.track('permission_requested', {
      permission: result.permission,
      granted: result.granted,
      failureReason: result.failureReason,
      timestamp: result.timestamp,
      attemptNumber: result.attemptNumber,
    });
  }

  // Generate insights
  getProblematicPermissions(): Array<{permission: string, failureRate: number}> {
    // Identify permissions with high denial rates
  }
}
```

---

## 🚨 Error Handling Patterns

### Error Hierarchy

```typescript
// Base error
class SDKError extends Error {
  code: string;
  details?: any;

  constructor(message: string, code: string, details?: any) {
    super(message);
    this.code = code;
    this.details = details;
  }
}

// Specific error types
class AuthenticationError extends SDKError {
  constructor(message: string, details?: any) {
    super(message, 'AUTHENTICATION_ERROR', details);
  }
}

class RateLimitError extends SDKError {
  retryAfter?: number;

  constructor(message: string, retryAfter: number) {
    super(message, 'RATE_LIMIT_ERROR', { retryAfter });
    this.retryAfter = retryAfter;
  }
}

class DataFetchError extends SDKError {
  dataType: DataType;

  constructor(message: string, dataType: DataType) {
    super(message, 'DATA_FETCH_ERROR', { dataType });
    this.dataType = dataType;
  }
}
```

### Error Handling in Plugins

```typescript
class FitbitPlugin extends BasePlugin {
  async fetchData(query: DataQuery): Promise<RawHealthData[]> {
    try {
      const response = await this.apiClient.get(endpoint);
      return this.dataMapper.transform(response.data);
    } catch (error) {
      // Classify error and provide actionable response
      if (error.response?.status === 401) {
        throw new AuthenticationError(
          'Fitbit token expired. Please re-authenticate.',
          { authUrl: this.getAuthUrl() }
        );
      }

      if (error.response?.status === 429) {
        const retryAfter = parseInt(error.response.headers['retry-after']) || 60;
        throw new RateLimitError(
          'Fitbit rate limit exceeded',
          retryAfter
        );
      }

      if (error.code === 'ECONNABORTED') {
        throw new NetworkError('Request timed out. Please check connection.');
      }

      // Unknown error - provide as much context as possible
      throw new DataFetchError(
        `Failed to fetch ${query.dataType}: ${error.message}`,
        query.dataType
      );
    }
  }
}
```

### Retry Logic

```typescript
async function fetchWithRetry<T>(
  operation: () => Promise<T>,
  config: RetryConfig = DEFAULT_RETRY_CONFIG
): Promise<T> {
  let lastError: Error;

  for (let attempt = 1; attempt <= config.maxAttempts; attempt++) {
    try {
      return await operation();
    } catch (error) {
      lastError = error;

      // Don't retry on authentication errors
      if (error instanceof AuthenticationError) {
        throw error;
      }

      // Don't retry if we're out of attempts
      if (attempt === config.maxAttempts) {
        throw error;
      }

      // Calculate backoff delay (exponential with jitter)
      const delay = Math.min(
        config.baseDelay * Math.pow(2, attempt - 1) + Math.random() * 1000,
        config.maxDelay
      );

      console.log(`Retry ${attempt}/${config.maxAttempts} after ${delay}ms`);
      await sleep(delay);
    }
  }

  throw lastError!;
}
```

---

## 📊 Logging & Observability

### Structured Logging

```typescript
// Enterprise logging system (already implemented in Flutter SDK)
class Logger {
  log(level: LogLevel, message: string, options: {
    category?: string;
    metadata?: Record<string, any>;
    error?: Error;
    stackTrace?: string;
  }) {
    const entry = {
      timestamp: new Date().toISOString(),
      level,
      message,
      category: options.category || 'General',
      metadata: options.metadata,
      error: options.error?.message,
      stack: options.stackTrace || options.error?.stack,
    };

    // Write to console
    console[level](entry);

    // Send to analytics service (optional)
    if (this.analyticsCallback) {
      this.analyticsCallback(entry);
    }

    // Store in memory for diagnostics
    this.inMemoryLogs.push(entry);
  }

  // Convenience methods
  debug(message: string, options?) { this.log('debug', message, options); }
  info(message: string, options?) { this.log('info', message, options); }
  warn(message: string, options?) { this.log('warn', message, options); }
  error(message: string, options?) { this.log('error', message, options); }
  critical(message: string, options?) { this.log('critical', message, options); }
}
```

### Usage in Plugin

```typescript
class FitbitPlugin extends BasePlugin {
  private logger = new Logger('FitbitPlugin');

  async fetchData(query: DataQuery): Promise<RawHealthData[]> {
    this.logger.info('Fetching Fitbit data', {
      metadata: {
        dataType: query.dataType,
        startDate: query.startDate,
        endDate: query.endDate,
      },
    });

    try {
      const data = await this.apiClient.fetch(query);

      this.logger.info('Successfully fetched Fitbit data', {
        metadata: {
          recordCount: data.length,
        },
      });

      return data;
    } catch (error) {
      this.logger.error('Failed to fetch Fitbit data', {
        error,
        metadata: {
          dataType: query.dataType,
        },
      });
      throw error;
    }
  }
}
```

---

## 🧪 Testing Strategies

### Unit Tests

```typescript
// Test data mapper
describe('FitbitDataMapper', () => {
  const mapper = new FitbitDataMapper();

  it('should transform Fitbit steps to UnifiedHealthData', () => {
    const fitbitResponse = {
      activities: [{
        activityId: 12345,
        activityName: 'Walk',
        startTime: '2024-01-01T10:00:00',
        duration: 1800,
        steps: 2500,
        calories: 150,
      }],
    };

    const result = mapper.transform(fitbitResponse, DataType.STEPS);

    expect(result).toHaveLength(1);
    expect(result[0].sourceDataType).toBe('Steps');
    expect(result[0].source).toBe(HealthSource.FITBIT);
    expect(result[0].raw.steps).toBe(2500);
    expect(result[0].raw._original).toEqual(fitbitResponse.activities[0]);
  });

  it('should handle missing optional fields', () => {
    const fitbitResponse = {
      activities: [{
        activityId: 12345,
        activityName: 'Walk',
        startTime: '2024-01-01T10:00:00',
        duration: 1800,
        // steps missing
      }],
    };

    const result = mapper.transform(fitbitResponse, DataType.STEPS);
    expect(result[0].raw.steps).toBeUndefined();
  });
});
```

### Integration Tests

```typescript
// Test with real API (in controlled test environment)
describe('FitbitPlugin Integration', () => {
  let plugin: FitbitPlugin;
  let testCredentials: FitbitCredentials;

  beforeAll(async () => {
    plugin = new FitbitPlugin(testConfig);
    await plugin.initialize();

    // Use test account credentials
    testCredentials = {
      accessToken: process.env.TEST_FITBIT_TOKEN,
      refreshToken: process.env.TEST_FITBIT_REFRESH,
      expiresAt: new Date(Date.now() + 3600000),
      userId: process.env.TEST_FITBIT_USER_ID,
    };
  });

  it('should connect with valid credentials', async () => {
    const result = await plugin.connect(testCredentials);
    expect(result.success).toBe(true);
  });

  it('should fetch real steps data', async () => {
    await plugin.connect(testCredentials);

    const data = await plugin.fetchData({
      dataType: DataType.STEPS,
      startDate: new Date('2024-01-01'),
      endDate: new Date('2024-01-07'),
    });

    expect(data).toBeDefined();
    expect(Array.isArray(data)).toBe(true);
  });
});
```

---

## 📦 Publishing & Distribution

### npm Package (TypeScript SDK)

```bash
# Build
npm run build

# Test
npm test

# Version bump (semver)
npm version patch  # 1.0.0 → 1.0.1
npm version minor  # 1.0.0 → 1.1.0
npm version major  # 1.0.0 → 2.0.0

# Publish to npm
npm publish --access public
```

### pub.dev Package (Flutter SDK)

```bash
# Validate package
flutter pub publish --dry-run

# Check pub points
dart pub publish --dry-run

# Publish
flutter pub publish
```

### Plugin as Separate Package

```bash
# Fitbit plugin published separately
cd plugins/fitbit
npm publish --access public

# Apps can install:
npm install @healthsync/plugin-fitbit
```

---

## 🌟 Best Practices Summary

### 1. **Consistency is Key**
- All plugins implement `IHealthDataPlugin`
- All data maps to `UnifiedHealthData`
- All errors extend `SDKError`

### 2. **Preserve Original Data**
- Always include `_original` in `raw` field
- Never lose information during transformation

### 3. **Handle Errors Gracefully**
- Classify errors properly
- Provide actionable error messages
- Include retry guidance

### 4. **Log Everything**
- Log all operations with context
- Include metadata for debugging
- Use structured logging

### 5. **Test Thoroughly**
- Unit test data mappers
- Integration test with real APIs
- Test error scenarios

### 6. **Document Well**
- Clear setup instructions
- Code examples
- Known limitations
- Troubleshooting guide

### 7. **Version Properly**
- Follow semantic versioning
- Document breaking changes
- Maintain changelog

---

## 📚 Reference: All Health Platforms

### Native SDKs (Local Access)
| Platform | OS | Plugin Status | Data Types |
|----------|-----|---------------|------------|
| **Health Connect** | Android | ✅ Production | 42 types |
| **HealthKit** | iOS | 🔄 Planned | 60+ types |
| **Samsung Health** | Android | 📋 Planned | 30+ types |

### Cloud APIs (OAuth Required)
| Platform | Type | Plugin Status | Data Types |
|----------|------|---------------|------------|
| **Fitbit** | Wearable | 📋 Example above | 20+ types |
| **Garmin** | Wearable | 📋 Planned | 25+ types |
| **Oura** | Ring | 📋 Planned | 15+ types |
| **Whoop** | Strap | 📋 Planned | 10+ types |
| **Strava** | Fitness | 📋 Planned | 8+ types |
| **MyFitnessPal** | Nutrition | 📋 Planned | Nutrition only |
| **Withings** | Scale/Watch | 📋 Planned | 12+ types |

---

## 🔗 Quick Links

- **Core SDK**: `packages/core/`
- **Flutter SDK**: `packages/flutter/health_sync_flutter/`
- **Health Connect Plugin**: `packages/flutter/health_sync_flutter/lib/src/plugins/health_connect/`
- **Test App**: `test-app/`
- **Examples**: `examples/`
- **API Docs**: `docs/API.md`

---

## 🤝 Contributing

When contributing a new integration:

1. Fork the repository
2. Create feature branch: `git checkout -b plugin/platform-name`
3. Follow this integration guide
4. Write tests (>80% coverage)
5. Update documentation
6. Submit pull request

---

## 📄 License

MIT License - See LICENSE file for details

---

**Remember**: This SDK is enterprise-grade. Every integration should meet the same high standards as Health Connect integration. Think Terra API quality, but open-source.

**Questions?** Open an issue on GitHub

**Need help?** Join our Discord community

---

*Last Updated: January 7, 2026*
*Version: 1.0.0*
*Maintained by: HealthSync Team*
