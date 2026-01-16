# Health Connect Plugin Examples

This directory contains example implementations and usage guides for the Health Connect plugin.

## Available Examples

### 1. Quick Start Example (`health-connect-quickstart.ts`)

A complete, runnable example showing:
- How to implement the `HealthConnectBridge` interface
- Plugin initialization and setup
- Connecting to Health Connect
- Fetching different types of health data
- Subscribing to data updates
- Error handling
- Cleanup and disposal
- Advanced usage patterns (pagination, date ranges, etc.)

**Perfect for:** Getting started quickly and understanding the basic flow.

### 2. Native Bridge Implementation Guide (`../docs/health-connect-bridge-guide.md`)

Comprehensive guide covering:
- Bridge interface specification
- Complete Android/Kotlin implementation
- React Native integration
- TypeScript bridge connection
- Testing strategies
- Troubleshooting common issues

**Perfect for:** Implementing the native bridge for your platform.

## Running the Examples

### Quick Start Example

The quick start example uses a simulated bridge for demonstration. To run it:

```bash
cd examples
npx ts-node health-connect-quickstart.ts
```

To adapt it for your real application:

1. Replace `ExampleHealthConnectBridge` with your actual native bridge implementation
2. Follow the "Usage in a Real React Native App" section in the file
3. See the native bridge guide for platform-specific implementation details

## Example Usage Patterns

### Basic Usage

```typescript
import { HealthConnectPlugin, DataType } from '@healthsync/core';
import { YourNativeBridge } from './bridge';

// Create and initialize
const plugin = new HealthConnectPlugin();
plugin.setPlatformBridge(new YourNativeBridge());
await plugin.initialize({});

// Connect
await plugin.connect();

// Fetch data
const data = await plugin.fetchData({
  dataType: DataType.STEPS,
  startDate: new Date('2024-01-01').toISOString(),
  endDate: new Date().toISOString(),
});

console.log(`Fetched ${data.length} records`);
```

### With Error Handling

```typescript
try {
  const data = await plugin.fetchData({
    dataType: DataType.HEART_RATE,
    startDate: startDate.toISOString(),
    endDate: endDate.toISOString(),
  });
} catch (error) {
  const action = plugin.handleError(error as Error);

  if (action === 'retry') {
    // Retry with exponential backoff
    await retryWithBackoff(() => plugin.fetchData(...));
  } else if (action === 'fail') {
    // Log and notify user
    console.error('Failed permanently:', error);
  }
}
```

### Pagination

```typescript
const pageSize = 100;
let offset = 0;
let allRecords = [];

while (true) {
  const batch = await plugin.fetchData({
    dataType: DataType.STEPS,
    startDate: startDate.toISOString(),
    endDate: endDate.toISOString(),
    limit: pageSize,
    offset: offset,
  });

  if (batch.length === 0) break;

  allRecords.push(...batch);
  offset += pageSize;
}
```

### Real-time Updates

```typescript
const subscription = await plugin.subscribeToUpdates(async (data) => {
  console.log(`Received ${data.length} new records`);
  // Process updates
});

// Later...
await subscription.unsubscribe();
```

## Implementation Checklist

When implementing the Health Connect plugin in your app:

### 1. Setup
- [ ] Install `@healthsync/core` package
- [ ] Add Health Connect dependencies to Android project
- [ ] Add required permissions to `AndroidManifest.xml`
- [ ] Configure Health Connect intent filter

### 2. Native Bridge
- [ ] Implement `HealthConnectBridge` interface
- [ ] Create native module (React Native/Capacitor/etc.)
- [ ] Implement `checkAvailability()` method
- [ ] Implement `checkPermissions()` method
- [ ] Implement `requestPermissions()` method
- [ ] Implement `readRecords()` method for each data type

### 3. TypeScript Integration
- [ ] Create bridge class implementing `HealthConnectBridge`
- [ ] Connect bridge to native module
- [ ] Initialize plugin with bridge
- [ ] Test connection flow
- [ ] Test data fetching

### 4. Error Handling
- [ ] Handle "not installed" errors
- [ ] Handle permission errors
- [ ] Handle network/timeout errors
- [ ] Implement retry logic
- [ ] Add user-friendly error messages

### 5. Testing
- [ ] Unit tests for bridge implementation
- [ ] Integration tests with mock data
- [ ] Integration tests with real Health Connect data
- [ ] Test on different Android versions
- [ ] Test permission flows

### 6. Production
- [ ] Add logging for debugging
- [ ] Implement analytics/monitoring
- [ ] Add user documentation
- [ ] Test on variety of devices
- [ ] Monitor for crashes/errors

## Common Data Types

### Steps
```typescript
await plugin.fetchData({
  dataType: DataType.STEPS,
  startDate: '2024-01-01T00:00:00Z',
  endDate: '2024-01-31T23:59:59Z',
});
```

### Heart Rate
```typescript
await plugin.fetchData({
  dataType: DataType.HEART_RATE,
  startDate: '2024-01-15T00:00:00Z',
  endDate: '2024-01-15T23:59:59Z',
});
```

### Sleep
```typescript
await plugin.fetchData({
  dataType: DataType.SLEEP,
  startDate: '2024-01-01T00:00:00Z',
  endDate: '2024-01-31T23:59:59Z',
});
```

### Activity/Exercise
```typescript
await plugin.fetchData({
  dataType: DataType.ACTIVITY,
  startDate: '2024-01-01T00:00:00Z',
  endDate: '2024-01-31T23:59:59Z',
});
```

### Distance
```typescript
await plugin.fetchData({
  dataType: DataType.DISTANCE,
  startDate: '2024-01-01T00:00:00Z',
  endDate: '2024-01-31T23:59:59Z',
});
```

## Supported Data Types

The Health Connect plugin supports 13 data types:

✅ **Supported:**
- Steps
- Heart Rate
- Resting Heart Rate
- Sleep
- Activity/Exercise
- Calories
- Distance
- Blood Oxygen (SpO2)
- Blood Pressure
- Body Temperature
- Weight
- Height
- Heart Rate Variability (HRV)

❌ **Not Supported by Health Connect:**
- Active Minutes (use Activity/Exercise instead)
- Blood Glucose
- BMI (calculate from weight/height)
- Body Fat Percentage
- Hydration
- Nutrition
- Respiratory Rate
- VO2 Max

## Tips and Best Practices

### 1. Permission Management
- Request only the permissions you actually need
- Explain to users why you need each permission
- Handle permission denials gracefully
- Re-check permissions periodically

### 2. Data Fetching
- Use appropriate date ranges (avoid fetching all-time data)
- Implement pagination for large datasets
- Cache data locally to reduce API calls
- Handle empty results gracefully

### 3. Error Handling
- Always wrap API calls in try-catch blocks
- Use the plugin's `handleError()` method for recommended actions
- Implement exponential backoff for retries
- Log errors for debugging

### 4. Performance
- Fetch only the data you need
- Use appropriate batch sizes (default: 1000)
- Implement pagination for large queries
- Cache results when appropriate

### 5. Testing
- Test with mock data first
- Test with real Health Connect data
- Test permission flows thoroughly
- Test on different Android versions
- Test error scenarios

## Troubleshooting

See the [Native Bridge Implementation Guide](../docs/health-connect-bridge-guide.md#troubleshooting) for detailed troubleshooting steps.

### Quick Fixes

**No data returned:**
- Check permissions are granted
- Verify Health Connect has data for the date range
- Ensure record type is correct

**Permission errors:**
- Check `AndroidManifest.xml` has all required permissions
- Verify permission strings match exactly
- Check Health Connect app itself has permissions

**Connection errors:**
- Verify Health Connect is installed
- Check Android version compatibility
- Ensure app has necessary permissions

## Additional Resources

- [Health Connect Plugin Documentation](../packages/core/README.md)
- [Native Bridge Guide](../docs/health-connect-bridge-guide.md)
- [API Reference](../packages/core/docs/api.md)
- [Android Health Connect Docs](https://developer.android.com/health-and-fitness/guides/health-connect)

## Contributing

Have a great example to share? Please submit a pull request!

## License

MIT
