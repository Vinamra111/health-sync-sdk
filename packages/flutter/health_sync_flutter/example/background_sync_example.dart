import 'package:flutter/material.dart';
import 'package:health_sync_flutter/health_sync_flutter.dart';

/// Example: Background Sync with WorkManager
///
/// Demonstrates how to set up automatic background syncing
/// of health data even when the app is closed.

// IMPORTANT: Background dispatcher must be a top-level function
@pragma('vm:entry-point')
void backgroundDispatcher() {
  createBackgroundSyncDispatcher(
    onSync: (dataType, records) async {
      // Called for each data type that gets synced
      print('[Background] Synced ${dataType.toValue()}: ${records.length} records');

      // Your custom logic here:
      // - Upload to server
      // - Save to local database
      // - Update analytics
      // - etc.

      // Example: Simulate upload
      await Future.delayed(Duration(milliseconds: 500));
      print('[Background] Uploaded ${dataType.toValue()} to server');
    },
    onComplete: (result) async {
      // Called when sync completes successfully
      print('[Background] ✓ Sync complete!');
      print('  Total records: ${result.totalRecords}');
      print('  Duration: ${result.duration.inSeconds}s');
      print('  Types synced: ${result.dataTypes.length}');
      print('  Incremental: ${result.wasIncremental}');
    },
    onFailed: (error) async {
      // Called if sync fails
      print('[Background] ✗ Sync failed: $error');

      // Your error handling:
      // - Log to analytics
      // - Schedule retry
      // - Send notification
    },
  );
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize background sync service
  backgroundSyncService.initialize(
    callbackDispatcher: backgroundDispatcher,
    isInDebugMode: true,  // Enable detailed logs during development
  );

  runApp(BackgroundSyncExampleApp());
}

class BackgroundSyncExampleApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Background Sync Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isScheduled = false;
  BackgroundSyncInfo? _syncInfo;
  String _selectedPreset = 'balanced';

  final List<DataType> _selectedTypes = [
    DataType.steps,
    DataType.heartRate,
    DataType.sleep,
  ];

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    final isScheduled = await backgroundSyncService.isScheduled();
    final syncInfo = await backgroundSyncService.getSyncInfo();

    setState(() {
      _isScheduled = isScheduled;
      _syncInfo = syncInfo;
    });
  }

  Future<void> _startSync() async {
    try {
      BackgroundSyncConfig config;

      switch (_selectedPreset) {
        case 'conservative':
          config = BackgroundSyncConfig.conservative(
            dataTypes: _selectedTypes,
            frequency: Duration(hours: 1),
          );
          break;
        case 'aggressive':
          config = BackgroundSyncConfig.aggressive(
            dataTypes: _selectedTypes,
            frequency: Duration(minutes: 15),
          );
          break;
        case 'balanced':
        default:
          config = BackgroundSyncConfig.balanced(
            dataTypes: _selectedTypes,
            frequency: Duration(minutes: 30),
          );
      }

      await backgroundSyncService.schedulePeriodicSync(config: config);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Background sync started (${_selectedPreset})'),
          backgroundColor: Colors.green,
        ),
      );

      await _refreshStatus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start sync: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _stopSync() async {
    try {
      await backgroundSyncService.cancelPeriodicSync();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Background sync stopped'),
          backgroundColor: Colors.orange,
        ),
      );

      await _refreshStatus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to stop sync: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _triggerOneTimeSync() async {
    try {
      await backgroundSyncService.scheduleOneTimeSync(
        config: BackgroundSyncConfig(
          dataTypes: _selectedTypes,
        ),
        delay: Duration(seconds: 5),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('One-time sync scheduled (5 seconds)'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to schedule sync: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Background Sync Example'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshStatus,
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // Status Card
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isScheduled ? Icons.check_circle : Icons.cancel,
                        color: _isScheduled ? Colors.green : Colors.red,
                        size: 32,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Background Sync Status',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  _buildStatusRow(
                    'Status',
                    _isScheduled ? 'Active' : 'Not Active',
                    _isScheduled ? Colors.green : Colors.red,
                  ),
                  if (_syncInfo != null) ...[
                    SizedBox(height: 8),
                    _buildStatusRow(
                      'Frequency',
                      '${_syncInfo!.config.frequency.inMinutes} minutes',
                      Colors.blue,
                    ),
                    _buildStatusRow(
                      'Data Types',
                      '${_syncInfo!.config.dataTypes.length} types',
                      Colors.blue,
                    ),
                    _buildStatusRow(
                      'Incremental Sync',
                      _syncInfo!.config.useIncrementalSync ? 'Yes' : 'No',
                      Colors.blue,
                    ),
                    _buildStatusRow(
                      'Requires Charging',
                      _syncInfo!.config.requiresCharging ? 'Yes' : 'No',
                      Colors.blue,
                    ),
                    _buildStatusRow(
                      'Requires WiFi',
                      _syncInfo!.config.requiresWiFi ? 'Yes' : 'No',
                      Colors.blue,
                    ),
                  ],
                ],
              ),
            ),
          ),

          SizedBox(height: 24),

          // Configuration Card
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configuration',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text('Select Preset:'),
                  RadioListTile<String>(
                    title: Text('Conservative (1 hour, charging + WiFi)'),
                    subtitle: Text('Best battery life'),
                    value: 'conservative',
                    groupValue: _selectedPreset,
                    onChanged: (value) {
                      setState(() {
                        _selectedPreset = value!;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: Text('Balanced (30 minutes, normal)'),
                    subtitle: Text('Recommended'),
                    value: 'balanced',
                    groupValue: _selectedPreset,
                    onChanged: (value) {
                      setState(() {
                        _selectedPreset = value!;
                      });
                    },
                  ),
                  RadioListTile<String>(
                    title: Text('Aggressive (15 minutes, always)'),
                    subtitle: Text('Higher battery usage'),
                    value: 'aggressive',
                    groupValue: _selectedPreset,
                    onChanged: (value) {
                      setState(() {
                        _selectedPreset = value!;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 24),

          // Action Buttons
          ElevatedButton.icon(
            onPressed: _isScheduled ? null : _startSync,
            icon: Icon(Icons.play_arrow),
            label: Text('Start Background Sync'),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.all(16),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),

          SizedBox(height: 12),

          ElevatedButton.icon(
            onPressed: _isScheduled ? _stopSync : null,
            icon: Icon(Icons.stop),
            label: Text('Stop Background Sync'),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.all(16),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
          ),

          SizedBox(height: 12),

          OutlinedButton.icon(
            onPressed: _triggerOneTimeSync,
            icon: Icon(Icons.sync),
            label: Text('Trigger One-Time Sync'),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.all(16),
            ),
          ),

          SizedBox(height: 24),

          // Info Card
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'How It Works',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    '• Background sync runs even when app is closed\n'
                    '• Uses WorkManager for battery-efficient scheduling\n'
                    '• Minimum frequency: 15 minutes (Android restriction)\n'
                    '• Actual timing may vary by a few minutes\n'
                    '• Check Logcat for "[Background]" logs\n'
                    '• Disable battery optimization for best results',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Advanced Example: Custom dispatcher with server upload
@pragma('vm:entry-point')
void advancedBackgroundDispatcher() {
  createBackgroundSyncDispatcher(
    onSync: (dataType, records) async {
      print('[Background] Processing ${dataType.toValue()}...');

      try {
        // Simulate uploading to server
        await Future.delayed(Duration(seconds: 1));

        // In real app, do something like:
        // await http.post(
        //   'https://api.example.com/health-data',
        //   body: jsonEncode({
        //     'dataType': dataType.toValue(),
        //     'records': records,
        //   }),
        // );

        print('[Background] ✓ Uploaded ${dataType.toValue()}');
      } catch (e) {
        print('[Background] ✗ Upload failed: $e');
        // Save for retry later
        // await saveFailedUpload(dataType, records);
      }
    },
    onComplete: (result) async {
      print('[Background] All syncs complete!');
      print('  Total: ${result.totalRecords} records');
      print('  Duration: ${result.duration.inSeconds}s');

      // Send completion notification or update UI state
    },
    onFailed: (error) async {
      print('[Background] Sync failed: $error');

      // Schedule retry
      // await backgroundSyncService.scheduleOneTimeSync(
      //   config: BackgroundSyncConfig(dataTypes: [...]),
      //   delay: Duration(minutes: 5),
      // );
    },
  );
}
