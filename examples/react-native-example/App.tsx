/**
 * React Native Health Connect Example
 *
 * Demonstrates usage of @healthsync/react-native package
 */

import React, { useEffect, useState } from 'react';
import {
  StyleSheet,
  View,
  Text,
  ScrollView,
  TouchableOpacity,
  Alert,
} from 'react-native';

import {
  HealthConnectPlugin,
  DataType,
  HealthConnectPermission,
  HealthConnectAvailability,
  type PermissionStatus,
} from '@healthsync/react-native';

export default function App() {
  const [plugin] = useState(() => new HealthConnectPlugin());
  const [availability, setAvailability] = useState<string>('');
  const [isConnected, setIsConnected] = useState(false);
  const [permissions, setPermissions] = useState<PermissionStatus[]>([]);
  const [stepsData, setStepsData] = useState<any[]>([]);

  useEffect(() => {
    checkAvailability();
  }, []);

  const checkAvailability = async () => {
    try {
      await plugin.initialize({});
      const status = await plugin.getConnectionStatus();
      setAvailability(status);

      // Auto-connect if available
      if (status === 'connected') {
        setIsConnected(true);
      }
    } catch (error: any) {
      Alert.alert('Error', error.message);
    }
  };

  const handleConnect = async () => {
    try {
      const result = await plugin.connect();
      setIsConnected(result.success);
      Alert.alert(
        result.success ? 'Success' : 'Error',
        result.message
      );
    } catch (error: any) {
      Alert.alert('Error', error.message);
    }
  };

  const handleCheckPermissions = async () => {
    try {
      const allPermissions = [
        HealthConnectPermission.READ_STEPS,
        HealthConnectPermission.READ_HEART_RATE,
        HealthConnectPermission.READ_SLEEP,
        HealthConnectPermission.READ_DISTANCE,
        HealthConnectPermission.READ_EXERCISE,
      ];

      // We need to access the bridge through the plugin
      // Since checkPermissions is private, we'll request permissions instead
      Alert.alert('Info', 'Use "Request Permissions" to check and request permissions');
    } catch (error: any) {
      Alert.alert('Error', error.message);
    }
  };

  const handleRequestPermissions = async () => {
    try {
      // For testing, we directly call the private method via the bridge
      // In production, the connect() method with autoRequestPermissions=true would handle this
      Alert.alert(
        'Requesting Permissions',
        'The Health Connect permission dialog should appear now'
      );

      // Manually trigger permission request
      // Note: This would normally be handled automatically by connect()
      // But for demonstration, we show the explicit flow

      // Since we can't access private methods, we'll reconnect with auto-request enabled
      const configuredPlugin = new HealthConnectPlugin({
        autoRequestPermissions: true,
      });

      await configuredPlugin.initialize({});
      const result = await configuredPlugin.connect();

      if (result.success) {
        Alert.alert('Success', 'Permissions granted!');
      }
    } catch (error: any) {
      Alert.alert('Error', error.message);
    }
  };

  const handleFetchSteps = async () => {
    if (!isConnected) {
      Alert.alert('Error', 'Please connect first');
      return;
    }

    try {
      const endDate = new Date();
      const startDate = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000); // Last 7 days

      console.log('Fetching steps from', startDate, 'to', endDate);

      const data = await plugin.fetchData({
        dataType: DataType.STEPS,
        startDate: startDate.toISOString(),
        endDate: endDate.toISOString(),
        limit: 100,
      });

      setStepsData(data);
      Alert.alert('Success', `Fetched ${data.length} step records`);
      console.log('Steps data:', data);
    } catch (error: any) {
      console.error('Fetch error:', error);
      Alert.alert('Error', error.message);
    }
  };

  return (
    <ScrollView style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.title}>HealthSync React Native</Text>
        <Text style={styles.subtitle}>Health Connect Integration</Text>
      </View>

      {/* Status Section */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Status</Text>
        <View style={styles.statusItem}>
          <Text style={styles.label}>Availability:</Text>
          <Text style={styles.value}>{availability || 'Checking...'}</Text>
        </View>
        <View style={styles.statusItem}>
          <Text style={styles.label}>Connected:</Text>
          <Text style={[styles.value, isConnected && styles.success]}>
            {isConnected ? 'Yes' : 'No'}
          </Text>
        </View>
      </View>

      {/* Actions Section */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Actions</Text>

        <TouchableOpacity
          style={[styles.button, !isConnected && styles.buttonPrimary]}
          onPress={handleConnect}
          disabled={isConnected}
        >
          <Text style={styles.buttonText}>
            {isConnected ? 'Connected' : 'Connect'}
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.button, styles.buttonPrimary]}
          onPress={handleRequestPermissions}
        >
          <Text style={styles.buttonText}>Request ALL Permissions</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.button, isConnected && styles.buttonPrimary]}
          onPress={handleFetchSteps}
          disabled={!isConnected}
        >
          <Text style={styles.buttonText}>Fetch Steps (Last 7 Days)</Text>
        </TouchableOpacity>
      </View>

      {/* Data Section */}
      {stepsData.length > 0 && (
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>
            Steps Data ({stepsData.length} records)
          </Text>
          {stepsData.slice(0, 5).map((item, index) => (
            <View key={index} style={styles.dataItem}>
              <Text style={styles.dataText}>
                {new Date(item.timestamp).toLocaleDateString()}
              </Text>
              <Text style={styles.dataText}>
                Source: {item.source}
              </Text>
            </View>
          ))}
          {stepsData.length > 5 && (
            <Text style={styles.moreText}>
              ... and {stepsData.length - 5} more
            </Text>
          )}
        </View>
      )}

      {/* Instructions */}
      <View style={styles.section}>
        <Text style={styles.sectionTitle}>Instructions</Text>
        <Text style={styles.instructionText}>
          1. Tap "Connect" to initialize Health Connect{'\n'}
          2. Tap "Request ALL Permissions" to grant access{'\n'}
          3. Tap "Fetch Steps" to retrieve your step data{'\n'}
          {'\n'}
          Note: Health Connect must be installed on your device.
        </Text>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  header: {
    backgroundColor: '#2196F3',
    padding: 24,
    paddingTop: 48,
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    color: 'white',
  },
  subtitle: {
    fontSize: 16,
    color: 'white',
    marginTop: 4,
  },
  section: {
    backgroundColor: 'white',
    margin: 16,
    padding: 16,
    borderRadius: 8,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    marginBottom: 12,
    color: '#333',
  },
  statusItem: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 8,
  },
  label: {
    fontSize: 16,
    color: '#666',
  },
  value: {
    fontSize: 16,
    fontWeight: '600',
    color: '#333',
  },
  success: {
    color: '#4CAF50',
  },
  button: {
    backgroundColor: '#ccc',
    padding: 16,
    borderRadius: 8,
    marginBottom: 12,
    alignItems: 'center',
  },
  buttonPrimary: {
    backgroundColor: '#2196F3',
  },
  buttonText: {
    color: 'white',
    fontSize: 16,
    fontWeight: '600',
  },
  dataItem: {
    padding: 12,
    backgroundColor: '#f9f9f9',
    borderRadius: 4,
    marginBottom: 8,
  },
  dataText: {
    fontSize: 14,
    color: '#666',
  },
  moreText: {
    fontSize: 14,
    color: '#999',
    textAlign: 'center',
    marginTop: 8,
  },
  instructionText: {
    fontSize: 14,
    color: '#666',
    lineHeight: 22,
  },
});
