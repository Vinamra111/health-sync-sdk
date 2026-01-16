import 'dart:async';
import 'package:flutter/material.dart';
import 'package:health_sync_flutter/health_sync_flutter.dart';
import 'package:app_links/app_links.dart';
import 'fitbit_settings_screen.dart';

/// Fitbit Integration Tab
///
/// Professional UI matching Health Connect quality
class FitbitTab extends StatefulWidget {
  const FitbitTab({super.key});

  @override
  State<FitbitTab> createState() => _FitbitTabState();
}

class _FitbitTabState extends State<FitbitTab> {
  FitbitPlugin? _fitbit;
  bool _hasCredentials = false;

  // Deep link handling
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  // State
  bool _isInitialized = false;
  bool _isLoading = false;
  String _statusMessage = 'Not initialized';
  List<RawHealthData> _stepsData = [];
  List<RawHealthData> _sleepData = [];
  bool _showDayWiseSteps = false;
  bool _showSleepDetails = false;

  @override
  void initState() {
    super.initState();
    _initialize();
    _initDeepLinks();
  }

  /// Initialize deep link listener for OAuth callback
  void _initDeepLinks() {
    _appLinks = AppLinks();

    // Listen for incoming deep links
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        _handleDeepLink(uri);
      },
      onError: (err) {
        _showError('Deep link error: $err');
      },
    );
  }

  /// Handle incoming deep link from OAuth callback
  Future<void> _handleDeepLink(Uri uri) async {
    // Check if this is a Fitbit OAuth callback
    if (uri.scheme == 'healthsync' &&
        uri.host == 'fitbit' &&
        uri.path == '/callback') {

      // Extract authorization code and state from query parameters
      final code = uri.queryParameters['code'];
      final state = uri.queryParameters['state'];

      if (code != null && code.isNotEmpty) {
        setState(() {
          _isLoading = true;
          _statusMessage = 'Completing authorization...';
        });

        try {
          // Complete authorization with state validation
          await _fitbit!.completeAuthorization(code, state: state);

          setState(() {
            _statusMessage = 'Connected to Fitbit successfully!';
          });

          _showSuccess('Connected to Fitbit successfully!');
        } catch (e) {
          setState(() {
            _statusMessage = 'Authorization failed';
          });

          // Show more specific error message for CSRF attacks
          if (e.toString().contains('CSRF')) {
            _showError('Security validation failed. Please try connecting again.');
          } else {
            _showError('Authorization failed: ${_cleanErrorMessage(e.toString())}');
          }
        } finally {
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        // Check for error in callback
        final error = uri.queryParameters['error'];
        final errorDescription = uri.queryParameters['error_description'];

        if (error != null) {
          _showError('OAuth error: $error${errorDescription != null ? " - $errorDescription" : ""}');
        } else {
          _showError('No authorization code received');
        }
      }
    }
  }

  Future<void> _initialize() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Loading configuration...';
    });

    try {
      // Load credentials from settings
      final credentials = await FitbitSettingsScreen.loadCredentials();

      if (credentials == null) {
        setState(() {
          _hasCredentials = false;
          _statusMessage = 'Please configure Fitbit credentials in Settings';
          _isLoading = false;
        });
        return;
      }

      // Initialize plugin with loaded credentials
      _fitbit = FitbitPlugin(
        config: FitbitConfig(
          clientId: credentials.clientId,
          clientSecret: credentials.clientSecret,
          redirectUri: credentials.redirectUri,
        ),
      );

      setState(() {
        _hasCredentials = true;
        _statusMessage = 'Initializing Fitbit plugin...';
      });

      await _fitbit!.initialize();

      setState(() {
        _isInitialized = true;
        _statusMessage = _fitbit!.connectionStatus == ConnectionStatus.connected
            ? 'Connected to Fitbit'
            : 'Ready - Click "Connect to Fitbit" below';
      });

      if (_fitbit!.connectionStatus == ConnectionStatus.connected) {
        _showSuccess('Fitbit plugin initialized and connected!');
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Initialization failed: ${_cleanErrorMessage(e.toString())}';
      });
      _showError('Initialization error: ${_cleanErrorMessage(e.toString())}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _openSettings() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const FitbitSettingsScreen()),
    );

    // Reload if settings changed
    if (result == true) {
      _initialize();
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_fitbit == null) {
      _showError('Plugin not initialized. Please configure Fitbit credentials first.');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Starting OAuth authorization...';
    });

    try {
      // Launch OAuth
      await _fitbit!.launchOAuth();

      _showInfo(
          'Complete authorization in your browser. The app will automatically handle the redirect.');

      setState(() {
        _statusMessage = 'Waiting for authorization in browser...';
        _isLoading = false; // Don't block UI while waiting for OAuth
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Connection failed';
        _isLoading = false;
      });

      // Parse error message for better user feedback
      String errorMessage = e.toString();

      if (errorMessage.contains('Invalid Client ID')) {
        _showError('Invalid credentials. Please check your Client ID in Settings.');
      } else if (errorMessage.contains('Invalid Client Secret')) {
        _showError('Invalid credentials. Please check your Client Secret in Settings.');
      } else if (errorMessage.contains('Invalid Redirect URI')) {
        _showError('Invalid Redirect URI. Please check Settings.');
      } else if (errorMessage.contains('Could not open browser') ||
          errorMessage.contains('launch')) {
        _showError(
          'Could not open browser. Please ensure you have Chrome or another browser installed.'
        );
      } else {
        _showError('Connection error: ${_cleanErrorMessage(errorMessage)}');
      }
    }
  }

  Future<void> _fetchSteps() async {
    if (_fitbit == null) {
      _showError('Plugin not initialized');
      return;
    }

    if (!_isConnected) {
      _showError('Not connected. Please connect to Fitbit first.');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Fetching steps data from Fitbit...';
    });

    try {
      final now = DateTime.now();
      final data = await _fitbit!.fetchData(
        DataQuery(
          dataType: DataType.steps,
          startDate: now.subtract(const Duration(days: 7)),
          endDate: now.add(const Duration(days: 1)), // Include all of today
        ),
      );

      setState(() {
        _stepsData = data;
        _statusMessage = 'Fetched ${data.length} step records';
      });

      if (data.isEmpty) {
        _showWarning('No steps data found in the last 7 days');
      } else {
        _showSuccess('Fetched ${data.length} step records from Fitbit!');
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to fetch steps';
      });
      _handleFetchError(e, 'steps');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchSleep() async {
    if (_fitbit == null) {
      _showError('Plugin not initialized');
      return;
    }

    if (!_isConnected) {
      _showError('Not connected. Please connect to Fitbit first.');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Fetching sleep data from Fitbit...';
    });

    try {
      final now = DateTime.now();
      final data = await _fitbit!.fetchData(
        DataQuery(
          dataType: DataType.sleep,
          startDate: now.subtract(const Duration(days: 7)),
          endDate: now.add(const Duration(days: 1)), // Include all of today
        ),
      );

      setState(() {
        _sleepData = data;
        _statusMessage = 'Fetched ${data.length} sleep records';
      });

      if (data.isEmpty) {
        _showWarning('No sleep data found in the last 7 days');
      } else {
        _showSuccess('Fetched ${data.length} sleep records from Fitbit!');
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to fetch sleep';
      });
      _handleFetchError(e, 'sleep');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handleFetchError(dynamic e, String dataType) {
    String errorMessage = e.toString();

    if (errorMessage.contains('Authentication expired')) {
      _showError('Session expired. Please reconnect to Fitbit.');
    } else if (errorMessage.contains('Rate limit exceeded')) {
      _showError('Too many requests. Please wait a few minutes before trying again.');
    } else if (errorMessage.contains('Network error')) {
      _showError('Network error. Please check your internet connection.');
    } else if (errorMessage.contains('timed out')) {
      _showError('Request timed out. Please try again.');
    } else if (errorMessage.contains('Not authenticated')) {
      _showError('Not connected. Please connect to Fitbit first.');
    } else {
      _showError('Failed to fetch $dataType: ${_cleanErrorMessage(errorMessage)}');
    }
  }

  Future<void> _disconnect() async {
    if (_fitbit == null) {
      _showError('Plugin not initialized');
      return;
    }

    // Confirm disconnect
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect from Fitbit?'),
        content: const Text('This will revoke access and clear all fetched data. You will need to authorize again to reconnect.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Disconnecting from Fitbit...';
    });

    try {
      await _fitbit!.disconnect();

      setState(() {
        _stepsData = [];
        _sleepData = [];
        _statusMessage = 'Disconnected from Fitbit';
      });

      _showSuccess('Disconnected successfully');
    } catch (e) {
      _showError('Disconnect error: ${_cleanErrorMessage(e.toString())}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _viewLogs() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LogViewerScreen(),
      ),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showWarning(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showInfo(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  bool get _isConnected => _fitbit?.connectionStatus == ConnectionStatus.connected;

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

  /// Clean error message by removing type prefixes
  String _cleanErrorMessage(String error) {
    // Remove error type prefixes
    final patterns = [
      'HealthSyncApiError: ',
      'HealthSyncConnectionError: ',
      'HealthSyncAuthenticationError: ',
      'HealthSyncRateLimitError: ',
      'HealthSyncValidationError: ',
      'HealthSyncError: ',
    ];

    String cleaned = error;
    for (final pattern in patterns) {
      cleaned = cleaned.replaceFirst(pattern, '');
    }

    return cleaned;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fitbit Integration'),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Fitbit Settings',
            onPressed: _openSettings,
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
                  _buildStatusCard(),
                  const SizedBox(height: 16),

                  // Configuration Warning
                  if (!_hasCredentials) ...[
                    _buildConfigurationWarning(),
                    const SizedBox(height: 16),
                  ],

                  // SDK Test Actions
                  _buildActionsCard(),
                  const SizedBox(height: 16),

                  // Steps Data Card
                  _buildStepsCard(),
                  const SizedBox(height: 16),

                  // Sleep Data Card
                  _buildSleepCard(),
                  const SizedBox(height: 16),

                  // Data Summary Card
                  if (_stepsData.isNotEmpty || _sleepData.isNotEmpty) ...[
                    _buildDataSummaryCard(),
                    const SizedBox(height: 16),
                  ],

                  // SDK Info Card
                  _buildSDKInfoCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
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
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationWarning() {
    return Card(
      elevation: 4,
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.warning_amber, size: 48, color: Colors.orange.shade700),
            const SizedBox(height: 12),
            Text(
              'Fitbit Not Configured',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.orange.shade900,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please configure your Fitbit API credentials to use this integration.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.orange.shade900),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _openSettings,
              icon: const Icon(Icons.settings),
              label: const Text('Open Settings'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fitbit Actions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: (_hasCredentials && _isInitialized && !_isConnected)
                  ? _connect
                  : null,
              icon: const Icon(Icons.link),
              label: const Text('Connect to Fitbit (OAuth 2.0)'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: (_hasCredentials && _isConnected) ? _fetchSteps : null,
              icon: const Icon(Icons.directions_walk),
              label: const Text('Fetch Steps (Last 7 Days)'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: (_hasCredentials && _isConnected) ? _fetchSleep : null,
              icon: const Icon(Icons.bedtime),
              label: const Text('Fetch Sleep (Last 7 Days)'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: (_hasCredentials && _isConnected) ? _disconnect : null,
              icon: const Icon(Icons.link_off),
              label: const Text('Disconnect from Fitbit'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
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
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepsCard() {
    return Card(
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
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_stepsData.length} records',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
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
                            value: _showDayWiseSteps,
                            onChanged: (value) {
                              setState(() {
                                _showDayWiseSteps = value;
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
                ? _buildEmptyState(
                    icon: Icons.directions_walk,
                    title: 'No steps data yet',
                    subtitle: 'Tap "Fetch Steps" above to load your Fitbit steps data',
                  )
                : _showDayWiseSteps
                    ? _buildDayWiseSteps()
                    : _buildStepsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSleepCard() {
    return Card(
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
                  'Sleep Data',
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
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_sleepData.length} records',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (_sleepData.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Details', style: TextStyle(fontSize: 11)),
                          Switch(
                            value: _showSleepDetails,
                            onChanged: (value) {
                              setState(() {
                                _showSleepDetails = value;
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
            _sleepData.isEmpty
                ? _buildEmptyState(
                    icon: Icons.bedtime,
                    title: 'No sleep data yet',
                    subtitle: 'Tap "Fetch Sleep" above to load your Fitbit sleep data',
                  )
                : _buildSleepList(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(
              icon,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepsList() {
    return SizedBox(
      height: 300,
      child: ListView.separated(
        itemCount: _stepsData.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final record = _stepsData[index];
          final timestamp = record.timestamp is String
              ? DateTime.parse(record.timestamp as String)
              : record.timestamp as DateTime;
          final steps = record.raw['steps'] ?? 0;

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.directions_walk,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            title: Text(
              '$steps steps',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              '${timestamp.day}/${timestamp.month}/${timestamp.year}',
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSleepList() {
    return SizedBox(
      height: 300,
      child: ListView.separated(
        itemCount: _sleepData.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final record = _sleepData[index];
          final timestamp = record.timestamp is String
              ? DateTime.parse(record.timestamp as String)
              : record.timestamp as DateTime;
          final endTimestamp = record.endTimestamp is String
              ? DateTime.parse(record.endTimestamp as String)
              : record.endTimestamp as DateTime?;

          final duration = record.raw['duration'] as int?;
          final minutesAsleep = record.raw['minutesAsleep'] as int?;
          final efficiency = record.raw['efficiency'] as int?;
          final logType = record.raw['logType'] as String? ?? 'unknown';
          final type = record.raw['type'] as String? ?? 'unknown';
          final isMainSleep = record.raw['isMainSleep'] as bool? ?? false;

          final durationHours = duration != null ? (duration / 1000 / 60 / 60).toStringAsFixed(1) : '?';
          final hoursAsleep = minutesAsleep != null ? (minutesAsleep / 60).toStringAsFixed(1) : '?';

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: logType == 'manual'
                  ? Colors.orange[100]
                  : Theme.of(context).colorScheme.secondaryContainer,
              child: Icon(
                isMainSleep ? Icons.bedtime : Icons.hotel,
                color: logType == 'manual'
                    ? Colors.orange[700]
                    : Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
            title: Row(
              children: [
                Text(
                  '$hoursAsleep hrs sleep',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 8),
                if (logType == 'manual')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit, size: 12, color: Colors.orange[700]),
                        const SizedBox(width: 4),
                        Text(
                          'Manual',
                          style: TextStyle(fontSize: 10, color: Colors.orange[700]),
                        ),
                      ],
                    ),
                  ),
                if (logType == 'auto_detected')
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
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${timestamp.day}/${timestamp.month}/${timestamp.year} '
                  '${timestamp.hour.toString().padLeft(2, '0')}:'
                  '${timestamp.minute.toString().padLeft(2, '0')} - '
                  '${endTimestamp != null ? "${endTimestamp.hour.toString().padLeft(2, '0')}:${endTimestamp.minute.toString().padLeft(2, '0')}" : "?"}',
                ),
                if (_showSleepDetails && efficiency != null)
                  Text(
                    'Efficiency: $efficiency% • Type: $type',
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

  Widget _buildDataSummaryCard() {
    final totalRecords = _stepsData.length + _sleepData.length;

    // Count manual vs auto sleep
    int manualSleep = 0;
    int autoSleep = 0;

    for (final record in _sleepData) {
      final logType = record.raw['logType'] as String? ?? 'unknown';
      if (logType == 'manual') {
        manualSleep++;
      } else if (logType == 'auto_detected') {
        autoSleep++;
      }
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Data Summary',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            _buildInfoRow('Total Records', '$totalRecords'),
            _buildInfoRow('Steps Records', '${_stepsData.length}'),
            _buildInfoRow('Sleep Records', '${_sleepData.length}'),
            if (_sleepData.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Sleep Breakdown',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.verified, size: 16, color: Colors.green[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: const Text('Auto-detected', style: TextStyle(fontSize: 13)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$autoSleep',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.edit, size: 16, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: const Text('Manual Entry', style: TextStyle(fontSize: 13)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$manualSleep',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[700],
                      ),
                    ),
                  ),
                ],
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
                      'Fitbit keeps ALL manual entries as they are legitimate health data',
                      style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSDKInfoCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fitbit Plugin Information',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Plugin', 'FitbitPlugin'),
            _buildInfoRow('Version', '1.0.0'),
            _buildInfoRow('Authentication', 'OAuth 2.0 + PKCE'),
            _buildInfoRow('Platform', 'Cloud-based (Fitbit Web API)'),
            _buildInfoRow('Data Source', 'Fitbit devices & manual entries'),
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
            width: 120,
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
}

/// Log Viewer Screen - Shows all SDK logs (reused from main.dart)
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
