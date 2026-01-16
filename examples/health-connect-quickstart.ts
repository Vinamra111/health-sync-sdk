/**
 * Health Connect Quick Start Example
 *
 * This example shows the simplest way to get started with the Health Connect plugin.
 */

import {
  HealthConnectPlugin,
  HealthConnectBridge,
  HealthConnectAvailability,
  HealthConnectPermission,
  PermissionStatus,
  HealthConnectRecord,
  DataType,
  HealthSource,
} from '@healthsync/core';

// ============================================================================
// Step 1: Implement the Bridge Interface
// ============================================================================

/**
 * Example bridge implementation that uses a native module
 * In a real app, this would call your React Native/Capacitor/etc. native module
 */
class ExampleHealthConnectBridge implements HealthConnectBridge {
  /**
   * Check if Health Connect is installed on the device
   */
  async checkAvailability(): Promise<HealthConnectAvailability> {
    // In a real implementation, this would call native code:
    // const result = await NativeModules.HealthConnectModule.checkAvailability();
    // return result;

    // For this example, we'll simulate it:
    return HealthConnectAvailability.INSTALLED;
  }

  /**
   * Check which permissions are granted
   */
  async checkPermissions(
    permissions: HealthConnectPermission[]
  ): Promise<PermissionStatus[]> {
    // In a real implementation:
    // const result = await NativeModules.HealthConnectModule.checkPermissions(permissions);
    // return result;

    // Simulated response:
    return permissions.map(permission => ({
      permission,
      granted: true,
      checkedAt: new Date().toISOString(),
    }));
  }

  /**
   * Request permissions from the user
   */
  async requestPermissions(
    permissions: HealthConnectPermission[]
  ): Promise<HealthConnectPermission[]> {
    // In a real implementation:
    // const granted = await NativeModules.HealthConnectModule.requestPermissions(permissions);
    // return granted;

    // Simulated: all permissions granted
    return permissions;
  }

  /**
   * Read health records from Health Connect
   */
  async readRecords(request: {
    recordType: string;
    startTime: Date;
    endTime: Date;
    limit?: number;
    offset?: number;
  }): Promise<HealthConnectRecord[]> {
    // In a real implementation:
    // const records = await NativeModules.HealthConnectModule.readRecords({
    //   recordType: request.recordType,
    //   startTime: request.startTime.toISOString(),
    //   endTime: request.endTime.toISOString(),
    //   limit: request.limit,
    //   offset: request.offset,
    // });
    // return records;

    // Simulated response with sample data:
    return [
      {
        id: 'sample-1',
        startTime: request.startTime.toISOString(),
        endTime: request.endTime.toISOString(),
        count: 5000,
      },
      {
        id: 'sample-2',
        startTime: request.startTime.toISOString(),
        endTime: request.endTime.toISOString(),
        count: 3500,
      },
    ];
  }
}

// ============================================================================
// Step 2: Create and Initialize the Plugin
// ============================================================================

async function initializeHealthConnect() {
  console.log('Initializing Health Connect plugin...');

  // Create the plugin instance
  const plugin = new HealthConnectPlugin({
    autoRequestPermissions: true, // Automatically request missing permissions
    batchSize: 1000, // Number of records to fetch per request
  });

  // Create and attach the bridge
  const bridge = new ExampleHealthConnectBridge();
  plugin.setPlatformBridge(bridge);

  // Initialize the plugin
  await plugin.initialize({
    custom: {
      logger: console, // Optional: use console for logging
    },
  });

  console.log('Plugin initialized successfully!');
  return plugin;
}

// ============================================================================
// Step 3: Connect to Health Connect
// ============================================================================

async function connectToHealthConnect(plugin: HealthConnectPlugin) {
  console.log('Connecting to Health Connect...');

  const result = await plugin.connect();

  if (result.success) {
    console.log('✓ Connected successfully:', result.message);
    return true;
  } else {
    console.error('✗ Connection failed:', result.message);
    if (result.error) {
      console.error('Error details:', result.error);
    }
    return false;
  }
}

// ============================================================================
// Step 4: Fetch Health Data
// ============================================================================

async function fetchStepsData(plugin: HealthConnectPlugin) {
  console.log('Fetching steps data...');

  try {
    const data = await plugin.fetchData({
      dataType: DataType.STEPS,
      startDate: new Date('2024-01-01').toISOString(),
      endDate: new Date().toISOString(),
      limit: 100,
    });

    console.log(`✓ Fetched ${data.length} step records`);

    // Process the data
    data.forEach((record, index) => {
      console.log(`Record ${index + 1}:`, {
        source: record.source,
        type: record.sourceDataType,
        timestamp: record.timestamp,
        endTimestamp: record.endTimestamp,
        data: record.raw,
      });
    });

    return data;
  } catch (error) {
    console.error('✗ Failed to fetch data:', error);
    throw error;
  }
}

// ============================================================================
// Step 5: Subscribe to Updates (Optional)
// ============================================================================

async function subscribeToUpdates(plugin: HealthConnectPlugin) {
  console.log('Setting up data update subscription...');

  const subscription = await plugin.subscribeToUpdates(async data => {
    console.log(`Received ${data.length} new/updated records`);
    // Handle the updated data here
  });

  console.log(`✓ Subscription created: ${subscription.id}`);

  // You can unsubscribe later:
  // await subscription.unsubscribe();

  return subscription;
}

// ============================================================================
// Step 6: Fetch Different Data Types
// ============================================================================

async function fetchMultipleDataTypes(plugin: HealthConnectPlugin) {
  const today = new Date();
  const lastWeek = new Date(today.getTime() - 7 * 24 * 60 * 60 * 1000);

  console.log('Fetching multiple data types...');

  // Fetch steps
  const steps = await plugin.fetchData({
    dataType: DataType.STEPS,
    startDate: lastWeek.toISOString(),
    endDate: today.toISOString(),
  });
  console.log(`✓ Steps: ${steps.length} records`);

  // Fetch heart rate
  const heartRate = await plugin.fetchData({
    dataType: DataType.HEART_RATE,
    startDate: lastWeek.toISOString(),
    endDate: today.toISOString(),
  });
  console.log(`✓ Heart Rate: ${heartRate.length} records`);

  // Fetch sleep
  const sleep = await plugin.fetchData({
    dataType: DataType.SLEEP,
    startDate: lastWeek.toISOString(),
    endDate: today.toISOString(),
  });
  console.log(`✓ Sleep: ${sleep.length} records`);

  return { steps, heartRate, sleep };
}

// ============================================================================
// Step 7: Error Handling
// ============================================================================

async function handleErrors(plugin: HealthConnectPlugin) {
  try {
    await plugin.fetchData({
      dataType: DataType.STEPS,
      startDate: new Date('2024-01-01').toISOString(),
      endDate: new Date().toISOString(),
    });
  } catch (error: any) {
    // Check error type
    if (error.name === 'ConnectionError') {
      console.error('Not connected to Health Connect');
      // Try reconnecting
      await plugin.connect();
    } else if (error.name === 'AuthenticationError') {
      console.error('Missing permissions');
      // Handle permission error
    } else if (error.name === 'DataFetchError') {
      console.error('Failed to fetch data');
      // Handle fetch error
    } else {
      console.error('Unknown error:', error.message);
    }

    // Get recommended action from plugin
    const action = plugin.handleError(error);
    console.log(`Recommended action: ${action}`);

    if (action === 'retry') {
      // Retry the operation
      console.log('Retrying...');
    } else if (action === 'fail') {
      // Give up
      console.log('Operation failed permanently');
    }
  }
}

// ============================================================================
// Step 8: Cleanup
// ============================================================================

async function cleanup(plugin: HealthConnectPlugin) {
  console.log('Cleaning up...');

  // Disconnect from Health Connect
  await plugin.disconnect();

  // Dispose of plugin resources
  await plugin.dispose();

  console.log('✓ Cleanup complete');
}

// ============================================================================
// Main Example Flow
// ============================================================================

async function main() {
  try {
    // 1. Initialize
    const plugin = await initializeHealthConnect();

    // 2. Connect
    const connected = await connectToHealthConnect(plugin);

    if (!connected) {
      console.error('Failed to connect. Exiting.');
      return;
    }

    // 3. Fetch data
    await fetchStepsData(plugin);

    // 4. Subscribe to updates (optional)
    const subscription = await subscribeToUpdates(plugin);

    // 5. Fetch multiple data types
    await fetchMultipleDataTypes(plugin);

    // 6. Show error handling
    await handleErrors(plugin);

    // 7. Cleanup when done
    await cleanup(plugin);

    console.log('\n✓ Example completed successfully!');
  } catch (error) {
    console.error('\n✗ Example failed:', error);
  }
}

// Run the example
main();

// ============================================================================
// Usage in a Real React Native App
// ============================================================================

/**
 * In a real React Native application, you would:
 *
 * 1. Install the dependencies:
 *    npm install @healthsync/core
 *
 * 2. Implement the native module (see health-connect-bridge-guide.md)
 *
 * 3. Create the bridge:
 *    import { NativeModules } from 'react-native';
 *
 *    class RNHealthConnectBridge implements HealthConnectBridge {
 *      async checkAvailability() {
 *        return await NativeModules.HealthConnectModule.checkAvailability();
 *      }
 *      // ... implement other methods
 *    }
 *
 * 4. Use it in your component:
 *    const plugin = new HealthConnectPlugin();
 *    plugin.setPlatformBridge(new RNHealthConnectBridge());
 *    await plugin.initialize({});
 *    await plugin.connect();
 *
 * 5. Fetch data:
 *    const data = await plugin.fetchData({
 *      dataType: DataType.STEPS,
 *      startDate: new Date('2024-01-01').toISOString(),
 *      endDate: new Date().toISOString(),
 *    });
 */

// ============================================================================
// Advanced Usage Examples
// ============================================================================

/**
 * Example: Pagination
 */
async function paginationExample(plugin: HealthConnectPlugin) {
  const pageSize = 100;
  let offset = 0;
  let allRecords: any[] = [];
  let hasMore = true;

  while (hasMore) {
    const batch = await plugin.fetchData({
      dataType: DataType.STEPS,
      startDate: new Date('2024-01-01').toISOString(),
      endDate: new Date().toISOString(),
      limit: pageSize,
      offset: offset,
    });

    allRecords = allRecords.concat(batch);
    hasMore = batch.length === pageSize;
    offset += pageSize;

    console.log(`Fetched ${batch.length} records (total: ${allRecords.length})`);
  }

  return allRecords;
}

/**
 * Example: Date Range Query
 */
async function dateRangeExample(plugin: HealthConnectPlugin) {
  // Last 30 days
  const endDate = new Date();
  const startDate = new Date(endDate.getTime() - 30 * 24 * 60 * 60 * 1000);

  const data = await plugin.fetchData({
    dataType: DataType.HEART_RATE,
    startDate: startDate.toISOString(),
    endDate: endDate.toISOString(),
  });

  console.log(`Heart rate data for last 30 days: ${data.length} records`);
  return data;
}

/**
 * Example: Check Plugin Info
 */
async function pluginInfoExample(plugin: HealthConnectPlugin) {
  const info = await plugin.getInfo();

  console.log('Plugin Information:');
  console.log(`  ID: ${info.id}`);
  console.log(`  Name: ${info.name}`);
  console.log(`  Version: ${info.version}`);
  console.log(`  Requires Auth: ${info.requiresAuthentication}`);
  console.log(`  Cloud-based: ${info.isCloudBased}`);
  console.log(`  Supported Data Types (${info.supportedDataTypes.length}):`);
  info.supportedDataTypes.forEach(type => {
    console.log(`    - ${type}`);
  });
}

/**
 * Example: Connection Status Check
 */
async function connectionStatusExample(plugin: HealthConnectPlugin) {
  const status = await plugin.getConnectionStatus();
  const isConnected = await plugin.isConnected();

  console.log(`Connection Status: ${status}`);
  console.log(`Is Connected: ${isConnected}`);

  // Possible statuses: 'connected', 'disconnected', 'connecting', 'disconnecting', 'error', 'requires_auth'
}

export {
  ExampleHealthConnectBridge,
  initializeHealthConnect,
  connectToHealthConnect,
  fetchStepsData,
  subscribeToUpdates,
  fetchMultipleDataTypes,
  handleErrors,
  cleanup,
  paginationExample,
  dateRangeExample,
  pluginInfoExample,
  connectionStatusExample,
};
