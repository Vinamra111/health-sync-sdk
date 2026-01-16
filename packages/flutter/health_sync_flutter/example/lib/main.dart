import 'package:flutter/material.dart';
import 'package:health_sync_flutter/health_sync_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _healthConnect = HealthConnectPlugin();
  String _status = 'Not initialized';
  List<RawHealthData> _data = [];
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _initializeHealthConnect();
  }

  Future<void> _initializeHealthConnect() async {
    try {
      setState(() => _status = 'Initializing...');

      // Initialize the plugin
      await _healthConnect.initialize();

      setState(() => _status = 'Initialized');
    } catch (e) {
      setState(() => _status = 'Initialization failed: $e');
    }
  }

  Future<void> _connect() async {
    try {
      setState(() => _status = 'Connecting...');

      final result = await _healthConnect.connect();

      setState(() {
        _status = result.message;
        _isConnected = result.success;
      });

      if (result.success) {
        _showSnackBar('Connected successfully!', Colors.green);
      } else {
        _showSnackBar('Connection failed', Colors.red);
      }
    } catch (e) {
      setState(() {
        _status = 'Connection error: $e';
        _isConnected = false;
      });
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  Future<void> _fetchSteps() async {
    if (!_isConnected) {
      _showSnackBar('Please connect first', Colors.orange);
      return;
    }

    try {
      setState(() => _status = 'Fetching steps data...');

      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 7));

      final data = await _healthConnect.fetchData(
        DataQuery(
          dataType: DataType.steps,
          startDate: startDate,
          endDate: endDate,
          limit: 100,
        ),
      );

      setState(() {
        _data = data;
        _status = 'Fetched ${data.length} step records';
      });

      _showSnackBar('Fetched ${data.length} records', Colors.green);
    } catch (e) {
      setState(() => _status = 'Fetch error: $e');
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  Future<void> _fetchHeartRate() async {
    if (!_isConnected) {
      _showSnackBar('Please connect first', Colors.orange);
      return;
    }

    try {
      setState(() => _status = 'Fetching heart rate data...');

      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 7));

      final data = await _healthConnect.fetchData(
        DataQuery(
          dataType: DataType.heartRate,
          startDate: startDate,
          endDate: endDate,
          limit: 100,
        ),
      );

      setState(() {
        _data = data;
        _status = 'Fetched ${data.length} heart rate records';
      });

      _showSnackBar('Fetched ${data.length} records', Colors.green);
    } catch (e) {
      setState(() => _status = 'Fetch error: $e');
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  Future<void> _fetchSleep() async {
    if (!_isConnected) {
      _showSnackBar('Please connect first', Colors.orange);
      return;
    }

    try {
      setState(() => _status = 'Fetching sleep data...');

      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 7));

      final data = await _healthConnect.fetchData(
        DataQuery(
          dataType: DataType.sleep,
          startDate: startDate,
          endDate: endDate,
          limit: 100,
        ),
      );

      setState(() {
        _data = data;
        _status = 'Fetched ${data.length} sleep records';
      });

      _showSnackBar('Fetched ${data.length} records', Colors.green);
    } catch (e) {
      setState(() => _status = 'Fetch error: $e');
      _showSnackBar('Error: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('HealthSync Flutter Example'),
          backgroundColor: Colors.blue,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status Card
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isConnected ? Icons.check_circle : Icons.cancel,
                            color: _isConnected ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Status',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(_status),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Connect Button
              ElevatedButton.icon(
                onPressed: _isConnected ? null : _connect,
                icon: const Icon(Icons.link),
                label: const Text('Connect to Health Connect'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 8),

              // Data Type Buttons
              ElevatedButton.icon(
                onPressed: _fetchSteps,
                icon: const Icon(Icons.directions_walk),
                label: const Text('Fetch Steps (Last 7 Days)'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 8),

              ElevatedButton.icon(
                onPressed: _fetchHeartRate,
                icon: const Icon(Icons.favorite),
                label: const Text('Fetch Heart Rate (Last 7 Days)'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 8),

              ElevatedButton.icon(
                onPressed: _fetchSleep,
                icon: const Icon(Icons.bedtime),
                label: const Text('Fetch Sleep (Last 7 Days)'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 16),

              // Data List
              Expanded(
                child: Card(
                  elevation: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'Data (${_data.length} records)',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: _data.isEmpty
                            ? const Center(
                                child: Text('No data fetched yet'),
                              )
                            : ListView.builder(
                                itemCount: _data.length,
                                itemBuilder: (context, index) {
                                  final record = _data[index];
                                  return ListTile(
                                    title: Text(record.sourceDataType),
                                    subtitle: Text(
                                      '${record.timestamp.toString()}\n${record.raw}',
                                    ),
                                    dense: true,
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
