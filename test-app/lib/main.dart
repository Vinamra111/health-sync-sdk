import 'package:flutter/material.dart';
import 'package:health_sync_flutter/health_sync_flutter.dart';
import 'fitbit_tab.dart';

void main() {
  runApp(const HealthSyncTestApp());
}

class HealthSyncTestApp extends StatelessWidget {
  const HealthSyncTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HealthSync SDK Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _healthConnect = HealthConnectPlugin(
    config: HealthConnectConfig(
      autoRequestPermissions: false, // Manual control for testing
      batchSize: 1000,
      fraudPrevention: FraudPreventionConfig(
        filterManualSteps: true,  // Filter manual steps (fraud prevention)
        filterUnknownSources: false,  // Not too strict for testing
        enableAnomalyDetection: true,  // Detect anomalous values
        maxDailySteps: 100000,
        maxHeartRate: 220,
        minHeartRate: 30,
      ),
      enableCaching: true, // Enable data caching
    ),
  );

  // Cache manager for demonstration
  late final SimpleCacheManager _cacheManager;

  // State
  bool _isInitialized = false;
  bool _isConnected = false;
  bool _isLoading = false;
  String _statusMessage = 'Not initialized';
  HealthConnectAvailability? _availability;
  List<RawHealthData> _stepsData = [];
  Map<HealthConnectPermission, bool> _permissionStatus = {};
  bool _showDayWiseAggregate = false;
  bool _showDataSourceInfo = false;

  // Fraud prevention statistics
  int _totalRecordsFetched = 0;
  int _manualEntriesFiltered = 0;
  int _anomaliesFiltered = 0;

  @override
  void initState() {
    super.initState();
    _initializeLogger();
    _cacheManager = SimpleCacheManager(ttl: Duration(minutes: 15));
    _initialize();
  }

  void _initializeLogger() {
    // Configure logger for enterprise use
    logger.setMinLevel(LogLevel.debug);
    logger.maxLogsInMemory = 1000;

    // In production, you would send logs to your backend
    logger.addLogCallback((entry) {
      // Example: Send to analytics service
      // analytics.logEvent(entry.toJson());
    });

    logger.info('Test app started', category: 'TestApp');
  }

  void _viewLogs() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LogViewerScreen(),
      ),
    );
  }

  void _viewDiagnostics() {
    final report = permissionTracker.generateDiagnosticReport();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DiagnosticsScreen(report: report),
      ),
    );
  }

  Future<void> _initialize() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Initializing SDK...';
    });

    try {
      // Initialize plugin
      await _healthConnect.initialize();

      // Check availability
      final availability = await _healthConnect.checkAvailability();

      setState(() {
        _isInitialized = true;
        _availability = availability;
        _statusMessage = 'SDK initialized - Health Connect: ${availability.name}';
      });

      if (availability == HealthConnectAvailability.installed) {
        _showSuccess('SDK initialized successfully!');
      } else {
        _showError('Health Connect is not available: ${availability.name}');
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Initialization failed: $e';
      });
      _showError('Initialization error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _connect() async {
    if (!_isInitialized) {
      _showError('Please initialize first');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Connecting to Health Connect...';
    });

    try {
      final result = await _healthConnect.connect();

      setState(() {
        _isConnected = result.success;
        _statusMessage = result.message;
      });

      if (result.success) {
        _showSuccess('Connected successfully!');
        await _checkAllPermissions();
      } else {
        _showError('Connection failed: ${result.message}');
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Connection error: $e';
      });
      _showError('Connection error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // ALL Health Connect Permissions (2025 Complete List)
  static const List<HealthConnectPermission> _allPermissions = [
    // Activity & Exercise
    HealthConnectPermission.readSteps,
    HealthConnectPermission.readDistance,
    HealthConnectPermission.readExercise,
    HealthConnectPermission.readActiveCaloriesBurned,
    HealthConnectPermission.readTotalCaloriesBurned,
    HealthConnectPermission.readElevationGained,
    HealthConnectPermission.readFloorsClimbed,
    HealthConnectPermission.readPower,
    HealthConnectPermission.readSpeed,
    HealthConnectPermission.readWheelchairPushes,

    // Body Measurements
    HealthConnectPermission.readWeight,
    HealthConnectPermission.readHeight,
    HealthConnectPermission.readBodyFat,
    HealthConnectPermission.readBodyWaterMass,
    HealthConnectPermission.readBoneMass,
    HealthConnectPermission.readLeanBodyMass,
    HealthConnectPermission.readBasalMetabolicRate,

    // Vitals
    HealthConnectPermission.readHeartRate,
    HealthConnectPermission.readHeartRateVariability,
    HealthConnectPermission.readRestingHeartRate,
    HealthConnectPermission.readBloodPressure,
    HealthConnectPermission.readBloodGlucose,
    HealthConnectPermission.readOxygenSaturation,
    HealthConnectPermission.readRespiratoryRate,
    HealthConnectPermission.readBodyTemperature,
    HealthConnectPermission.readBasalBodyTemperature,

    // Sleep
    HealthConnectPermission.readSleep,

    // Nutrition & Hydration
    HealthConnectPermission.readNutrition,
    HealthConnectPermission.readHydration,

    // Cycle Tracking
    HealthConnectPermission.readMenstruation,
    HealthConnectPermission.readOvulationTest,
    HealthConnectPermission.readCervicalMucus,
    HealthConnectPermission.readIntermenstrualBleeding,
    HealthConnectPermission.readSexualActivity,

    // Fitness
    HealthConnectPermission.readVo2Max,
  ];

  Future<void> _checkAllPermissions() async {
    try {
      final statuses = await _healthConnect.checkPermissions(_allPermissions);

      setState(() {
        _permissionStatus = {
          for (var status in statuses) status.permission: status.granted
        };
      });
    } catch (e) {
      _showError('Error checking permissions: $e');
    }
  }

  Future<void> _requestAllPermissions() async {
    if (!_isConnected) {
      _showError('Please connect first');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Requesting ALL Health Connect permissions...';
    });

    try {
      final granted = await _healthConnect.requestPermissions(_allPermissions);

      setState(() {
        _statusMessage = 'Permission request completed! Granted: ${granted.length}/${_allPermissions.length}';
      });

      // Refresh permission status
      await _checkAllPermissions();

      final grantedCount = _permissionStatus.values.where((v) => v).length;
      _showSuccess('Permissions updated! Granted: $grantedCount/${_allPermissions.length}');
    } catch (e) {
      setState(() {
        _statusMessage = 'Permission request error: $e';
      });
      _showError('Error requesting permissions: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchStepsData() async {
    if (!_isConnected) {
      _showError('Please connect first');
      return;
    }

    final hasPermission = _permissionStatus[HealthConnectPermission.readSteps] ?? false;
    if (!hasPermission) {
      _showWarning('Please grant steps permission first');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Fetching steps data...';
    });

    try {
      final now = DateTime.now();
      final endDate = now.add(const Duration(days: 1)); // Include all of today
      final startDate = now.subtract(const Duration(days: 7));

      final data = await _healthConnect.fetchData(
        DataQuery(
          dataType: DataType.steps,
          startDate: startDate,
          endDate: endDate,
          // No limit - SDK automatically paginates to fetch ALL records
        ),
      );

      setState(() {
        _stepsData = data;
        _statusMessage = 'Fetched ${data.length} step records';
      });

      if (data.isEmpty) {
        _showWarning('No steps data found in the last 7 days');
      } else {
        _showSuccess('Fetched ${data.length} step records!');
      }
    } on HealthSyncAuthenticationError catch (e) {
      setState(() {
        _statusMessage = 'Permission denied: $e';
      });
      _showError('Permission denied. Please grant steps permission.');
    } on HealthSyncConnectionError catch (e) {
      setState(() {
        _statusMessage = 'Connection error: $e';
      });
      _showError('Connection error: $e');
    } catch (e) {
      setState(() {
        _statusMessage = 'Error fetching data: $e';
      });
      _showError('Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showWarning(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Color _getStatusColor() {
    if (_isConnected) return Colors.green;
    if (_isInitialized) return Colors.orange;
    return Colors.grey;
  }

  IconData _getStatusIcon() {
    if (_isConnected) return Icons.check_circle;
    if (_isInitialized) return Icons.warning;
    return Icons.cancel;
  }

  String _getStatusText() {
    if (_isConnected) return 'Connected';
    if (_isInitialized) return 'Initialized (Not Connected)';
    return 'Not Initialized';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HealthSync SDK Test - Health Connect'),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.fitness_center),
            tooltip: 'Fitbit Integration',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => Scaffold(
                    appBar: AppBar(
                      title: const Text('Fitbit Integration'),
                    ),
                    body: const FitbitTab(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading...'),
                ],
              ),
            )
          : SingleChildScrollView(
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
                                _getStatusIcon(),
                                color: _getStatusColor(),
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _getStatusText(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            color: _getStatusColor(),
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _statusMessage,
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (_availability != null) ...[
                            const SizedBox(height: 12),
                            const Divider(),
                            const SizedBox(height: 8),
                            Text(
                              'Health Connect: ${_availability!.name}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // SDK Test Actions
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SDK Test Actions',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _isInitialized ? null : _initialize,
                            icon: const Icon(Icons.power_settings_new),
                            label: const Text('Initialize SDK'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: (_isInitialized && !_isConnected)
                                ? _connect
                                : null,
                            icon: const Icon(Icons.link),
                            label: const Text('Connect to Health Connect'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _isConnected ? _requestAllPermissions : null,
                            icon: const Icon(Icons.security),
                            label: const Text('Request ALL Permissions (42 total)'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _isConnected ? _fetchStepsData : null,
                            icon: const Icon(Icons.download),
                            label: const Text('Fetch Steps Data (Last 7 Days)'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          Text(
                            'Enterprise Features',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _viewLogs,
                            icon: const Icon(Icons.article),
                            label: const Text('View SDK Logs'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              backgroundColor: Colors.blueGrey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: _viewDiagnostics,
                            icon: const Icon(Icons.analytics),
                            label: const Text('Permission Diagnostics'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              backgroundColor: Colors.teal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Permissions Status
                  if (_permissionStatus.isNotEmpty) ...[
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Permission Status',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            ..._permissionStatus.entries.map((entry) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Row(
                                  children: [
                                    Icon(
                                      entry.value
                                          ? Icons.check_circle
                                          : Icons.cancel,
                                      color:
                                          entry.value ? Colors.green : Colors.red,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        entry.key
                                            .toString()
                                            .split('.')
                                            .last
                                            .replaceAll('read', '')
                                            .replaceAllMapped(
                                              RegExp(r'([A-Z])'),
                                              (match) => ' ${match.group(0)}',
                                            )
                                            .trim(),
                                      ),
                                    ),
                                    Text(
                                      entry.value ? 'Granted' : 'Denied',
                                      style: TextStyle(
                                        color: entry.value
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Steps Data
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Steps Data',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primaryContainer,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${_stepsData.length} records',
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (_stepsData.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('Day-wise', style: TextStyle(fontSize: 11)),
                                        Switch(
                                          value: _showDayWiseAggregate,
                                          onChanged: (value) {
                                            setState(() {
                                              _showDayWiseAggregate = value;
                                            });
                                          },
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('Show Source', style: TextStyle(fontSize: 11)),
                                        Switch(
                                          value: _showDataSourceInfo,
                                          onChanged: (value) {
                                            setState(() {
                                              _showDataSourceInfo = value;
                                            });
                                          },
                                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 8),
                          _stepsData.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.directions_walk,
                                          size: 48,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'No steps data yet',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Tap "Fetch Steps Data" above',
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : _showDayWiseAggregate
                                  ? _buildDayWiseSteps()
                                  : SizedBox(
                                      height: 300,
                                      child: ListView.separated(
                                        itemCount: _stepsData.length,
                                        separatorBuilder: (context, index) =>
                                            const Divider(),
                                        itemBuilder: (context, index) {
                                          final record = _stepsData[index];
                                          final timestamp = record.timestamp is String
                                              ? DateTime.parse(record.timestamp as String)
                                              : record.timestamp as DateTime;
                                          final steps = record.raw['count'] ?? 0;

                                          // Get fraud prevention metadata
                                          final recordingMethod = HealthConnectPlugin.getRecordingMethod(record);
                                          final dataSource = HealthConnectPlugin.getDataSource(record);
                                          final isManual = recordingMethod == RecordingMethod.manualEntry;

                                          return ListTile(
                                            leading: CircleAvatar(
                                              backgroundColor: isManual
                                                  ? Colors.orange[100]
                                                  : Theme.of(context).colorScheme.primaryContainer,
                                              child: Icon(
                                                isManual ? Icons.edit : Icons.directions_walk,
                                                color: isManual
                                                    ? Colors.orange[700]
                                                    : Theme.of(context).colorScheme.onPrimaryContainer,
                                              ),
                                            ),
                                            title: Row(
                                              children: [
                                                Text(
                                                  '$steps steps',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                if (recordingMethod == RecordingMethod.automaticallyRecorded)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.green[100],
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.verified, size: 12, color: Colors.green[700]),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          'Auto',
                                                          style: TextStyle(fontSize: 10, color: Colors.green[700]),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                if (recordingMethod == RecordingMethod.manualEntry)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.orange[100],
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.warning, size: 12, color: Colors.orange[700]),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          'Manual',
                                                          style: TextStyle(fontSize: 10, color: Colors.orange[700]),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            subtitle: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${timestamp.day}/${timestamp.month}/${timestamp.year} '
                                                  '${timestamp.hour.toString().padLeft(2, '0')}:'
                                                  '${timestamp.minute.toString().padLeft(2, '0')}',
                                                ),
                                                if (_showDataSourceInfo && dataSource['appName'] != null)
                                                  Text(
                                                    'Source: ${dataSource['appName']}',
                                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                                  ),
                                              ],
                                            ),
                                            trailing: Icon(
                                              Icons.chevron_right,
                                              color: Colors.grey[400],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Fraud Prevention Info
                  if (_stepsData.isNotEmpty) ...[
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
                                  Icons.security,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Fraud Prevention',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Divider(),
                            const SizedBox(height: 8),
                            _buildFraudPreventionStats(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // SDK Info
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SDK Information',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          _buildInfoRow('Package', 'health_sync_flutter'),
                          _buildInfoRow('Version', '1.0.0'),
                          _buildInfoRow('Platform', 'Android (Health Connect)'),
                          _buildInfoRow('Min SDK', 'Android 8.0 (API 26)'),
                          _buildInfoRow('Target SDK', 'Android 14 (API 34)'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildDayWiseSteps() {
    final aggregated = DataAggregator.aggregateStepsByDay(_stepsData);

    if (aggregated.isEmpty) {
      return const Center(child: Text('No steps data to aggregate'));
    }

    return SizedBox(
      height: 300,
      child: ListView.builder(
        itemCount: aggregated.length,
        itemBuilder: (context, index) {
          final day = aggregated[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue,
                child: Text(
                  day.date.split('-')[2], // Day number
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(
                '${day.totalSteps} steps',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(day.formattedDate),
              trailing: Text(
                '${day.recordCount} records',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFraudPreventionStats() {
    // Calculate statistics from current data
    int automaticCount = 0;
    int manualCount = 0;
    int activeCount = 0;
    int unknownCount = 0;
    final Set<String> uniqueSources = {};

    for (final record in _stepsData) {
      final recordingMethod = HealthConnectPlugin.getRecordingMethod(record);
      final dataSource = HealthConnectPlugin.getDataSource(record);

      switch (recordingMethod) {
        case RecordingMethod.automaticallyRecorded:
          automaticCount++;
          break;
        case RecordingMethod.manualEntry:
          manualCount++;
          break;
        case RecordingMethod.activelyRecorded:
          activeCount++;
          break;
        case RecordingMethod.unknown:
          unknownCount++;
          break;
      }

      if (dataSource['appName'] != null) {
        uniqueSources.add(dataSource['appName']!);
      }
    }

    final totalRecords = _stepsData.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recording Method Stats
        Text(
          'Recording Methods',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        _buildStatRow(
          'Automatically Recorded',
          automaticCount,
          totalRecords,
          Colors.green,
          Icons.verified,
        ),
        _buildStatRow(
          'Actively Recorded',
          activeCount,
          totalRecords,
          Colors.blue,
          Icons.fitness_center,
        ),
        _buildStatRow(
          'Manual Entry',
          manualCount,
          totalRecords,
          Colors.orange,
          Icons.edit,
        ),
        _buildStatRow(
          'Unknown',
          unknownCount,
          totalRecords,
          Colors.grey,
          Icons.help_outline,
        ),
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 8),
        // Summary
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Trusted Data',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
            Text(
              '${((automaticCount + activeCount) / totalRecords * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Data Sources:'),
            Text(
              '${uniqueSources.length} apps',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        if (uniqueSources.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: uniqueSources.take(5).map((source) {
              return Chip(
                label: Text(
                  source,
                  style: const TextStyle(fontSize: 11),
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: EdgeInsets.zero,
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 20, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Manual entries are filtered by default for fraud prevention',
                  style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(
    String label,
    int count,
    int total,
    Color color,
    IconData icon,
  ) {
    final percentage = total > 0 ? (count / total * 100) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count (${percentage.toStringAsFixed(0)}%)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Log Viewer Screen - Shows all SDK logs
class LogViewerScreen extends StatelessWidget {
  const LogViewerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final logs = logger.logs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SDK Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear Logs',
            onPressed: () {
              logger.clearLogs();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: logs.isEmpty
          ? const Center(
              child: Text('No logs available'),
            )
          : ListView.builder(
              itemCount: logs.length,
              reverse: true, // Show newest first
              itemBuilder: (context, index) {
                final log = logs[logs.length - 1 - index];
                return ListTile(
                  leading: _getLogIcon(log.level),
                  title: Text(
                    log.message,
                    style: TextStyle(
                      color: _getLogColor(log.level, context),
                      fontWeight: log.level.index >= LogLevel.error.index
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${log.timestamp.toLocal().toString().substring(0, 19)} | ${log.category ?? "General"}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (log.metadata != null && log.metadata!.isNotEmpty)
                        Text(
                          log.metadata.toString(),
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                  isThreeLine: log.metadata != null && log.metadata!.isNotEmpty,
                  onTap: () => _showLogDetails(context, log),
                );
              },
            ),
    );
  }

  Widget _getLogIcon(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return const Icon(Icons.bug_report, color: Colors.grey);
      case LogLevel.info:
        return const Icon(Icons.info_outline, color: Colors.blue);
      case LogLevel.warning:
        return const Icon(Icons.warning_amber, color: Colors.orange);
      case LogLevel.error:
        return const Icon(Icons.error_outline, color: Colors.red);
      case LogLevel.critical:
        return const Icon(Icons.dangerous, color: Colors.red);
    }
  }

  Color _getLogColor(LogLevel level, BuildContext context) {
    switch (level) {
      case LogLevel.debug:
        return Colors.grey;
      case LogLevel.info:
        return Theme.of(context).textTheme.bodyLarge!.color!;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
      case LogLevel.critical:
        return Colors.red;
    }
  }

  void _showLogDetails(BuildContext context, LogEntry log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Log Details - ${log.level.name.toUpperCase()}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Time: ${log.timestamp.toLocal()}'),
              const Divider(),
              Text('Message: ${log.message}'),
              if (log.category != null) ...[
                const Divider(),
                Text('Category: ${log.category}'),
              ],
              if (log.metadata != null && log.metadata!.isNotEmpty) ...[
                const Divider(),
                Text('Metadata:'),
                Text(log.metadata.toString()),
              ],
              if (log.error != null) ...[
                const Divider(),
                Text('Error: ${log.error}'),
              ],
              if (log.stackTrace != null) ...[
                const Divider(),
                Text('Stack Trace:'),
                Text(log.stackTrace.toString(), style: const TextStyle(fontSize: 10)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// Diagnostics Screen - Shows permission analytics
class DiagnosticsScreen extends StatelessWidget {
  final String report;

  const DiagnosticsScreen({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final analytics = permissionTracker.toJson();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Permission Diagnostics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Export Report',
            onPressed: () => _exportReport(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Overall Statistics',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildStatRow('Total Requests', '${analytics['totalRequests']}'),
                  _buildStatRow('Successes', '${analytics['totalSuccesses']}', Colors.green),
                  _buildStatRow('Failures', '${analytics['totalFailures']}', Colors.red),
                  if (analytics['totalRequests'] > 0)
                    _buildStatRow(
                      'Success Rate',
                      '${((analytics['totalSuccesses'] / analytics['totalRequests']) * 100).toStringAsFixed(1)}%',
                      Colors.blue,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Full Diagnostic Report',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SelectableText(
                      report,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  void _exportReport(BuildContext context) {
    // In production, this would export to file or send to backend
    logger.info('Diagnostic report exported', category: 'TestApp');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report exported to logs')),
    );
  }
}
