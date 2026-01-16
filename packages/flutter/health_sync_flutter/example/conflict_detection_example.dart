import 'package:flutter/material.dart';
import 'package:health_sync_flutter/health_sync_flutter.dart';

/// Example: Conflict Detection (Double-Count Detector)
///
/// Demonstrates how to detect when multiple apps are writing
/// duplicate health data, causing inflated counts.
void main() {
  runApp(ConflictDetectionExampleApp());
}

class ConflictDetectionExampleApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Conflict Detection Example',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        useMaterial3: true,
      ),
      home: ConflictDetectionPage(),
    );
  }
}

class ConflictDetectionPage extends StatefulWidget {
  @override
  _ConflictDetectionPageState createState() => _ConflictDetectionPageState();
}

class _ConflictDetectionPageState extends State<ConflictDetectionPage> {
  final _plugin = HealthConnectPlugin();
  ConflictSummary? _summary;
  bool _isLoading = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _plugin.initialize();
      await _plugin.connect();
      setState(() {
        _initialized = true;
      });
    } catch (e) {
      print('Initialization failed: $e');
    }
  }

  Future<void> _checkConflicts() async {
    if (!_initialized) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final summary = await _plugin.detectConflictsForTypes(
        dataTypes: [
          DataType.steps,
          DataType.heartRate,
          DataType.sleep,
          DataType.calories,
        ],
      );

      setState(() {
        _summary = summary;
        _isLoading = false;
      });

      // Show immediate warning for high severity conflicts
      if (summary.hasHighSeverityConflicts) {
        _showCriticalWarning();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to check conflicts: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCriticalWarning() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 32),
            SizedBox(width: 12),
            Expanded(child: Text('Critical Conflict Detected')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Multiple apps are creating duplicate health data!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              'This is causing inflated counts and may create a sync loop. '
              'You should disable duplicate tracking immediately.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('View Details'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Conflict Detection'),
        actions: [
          if (_summary?.hasAnyConflicts ?? false)
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: Icon(
                Icons.warning,
                color: Colors.red,
                size: 28,
              ),
            ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _initialized
          ? FloatingActionButton.extended(
              onPressed: _isLoading ? null : _checkConflicts,
              icon: Icon(Icons.search),
              label: Text('Check Conflicts'),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (!_initialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Initializing...'),
          ],
        ),
      );
    }

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Analyzing data sources...'),
          ],
        ),
      );
    }

    if (_summary == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Tap the button below to check for conflicts',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _buildSummaryCard(),
        SizedBox(height: 16),
        ..._summary!.results.entries.map((entry) {
          return _buildDataTypeCard(entry.key, entry.value);
        }),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final hasConflicts = _summary!.hasAnyConflicts;
    final color = hasConflicts ? Colors.orange : Colors.green;
    final icon = hasConflicts ? Icons.warning : Icons.check_circle;

    return Card(
      color: color.shade50,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 32),
                SizedBox(width: 12),
                Text(
                  'Summary',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildSummaryRow(
              'Data Types Analyzed',
              '${_summary!.results.length}',
            ),
            _buildSummaryRow(
              'Conflicts Found',
              '${_summary!.totalConflicts}',
            ),
            if (_summary!.hasHighSeverityConflicts)
              _buildSummaryRow(
                'High Severity',
                '${_summary!.allHighSeverityConflicts.length}',
                Colors.red,
              ),
            SizedBox(height: 12),
            Text(
              hasConflicts
                  ? '⚠ Multiple apps detected writing health data'
                  : '✓ No conflicts detected - data looks good!',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: color.shade900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, [Color? color]) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTypeCard(DataType dataType, ConflictDetectionResult result) {
    final hasConflict = result.hasConflicts;
    final color = hasConflict ? Colors.orange : Colors.grey;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(
          hasConflict ? Icons.warning : Icons.check_circle_outline,
          color: color,
        ),
        title: Text(
          dataType.toValue().toUpperCase(),
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${result.sources.length} source(s) - ${result.totalRecords} records',
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Data sources
                Text(
                  'Data Sources:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                ...result.sources.map((source) => _buildSourceItem(source)),

                if (hasConflict) ...[
                  SizedBox(height: 16),
                  Divider(),
                  SizedBox(height: 8),

                  // Conflicts
                  Text(
                    'Conflicts:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  SizedBox(height: 8),
                  ...result.conflicts.map((conflict) => _buildConflictItem(conflict)),
                ],

                SizedBox(height: 16),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (hasConflict)
                      ElevatedButton.icon(
                        onPressed: () => _showDetailedReport(result),
                        icon: Icon(Icons.article),
                        label: Text('View Report'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceItem(DataSourceInfo source) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            source.isSystemApp ? Icons.verified : Icons.apps,
            size: 20,
            color: source.isSystemApp ? Colors.blue : Colors.grey,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.displayName,
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  '${source.recordCount} records (${source.percentage.toStringAsFixed(1)}%)',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConflictItem(DataSourceConflict conflict) {
    final severityColor = conflict.isHighSeverity
        ? Colors.red
        : conflict.isMediumSeverity
            ? Colors.orange
            : Colors.yellow;

    return Container(
      padding: EdgeInsets.all(12),
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: severityColor.shade50,
        border: Border.all(color: severityColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error, color: severityColor, size: 20),
              SizedBox(width: 8),
              Text(
                'Severity: ${_getSeverityLabel(conflict.severity)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: severityColor.shade900,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text('Type: ${conflict.type.name}'),
          SizedBox(height: 4),
          Text(
            conflict.recommendation,
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  String _getSeverityLabel(double severity) {
    if (severity >= 0.7) return 'HIGH';
    if (severity >= 0.4) return 'MEDIUM';
    return 'LOW';
  }

  void _showDetailedReport(ConflictDetectionResult result) {
    final report = HealthConnectPlugin.generateConflictReport(result);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Conflict Report'),
        content: SingleChildScrollView(
          child: Text(
            report,
            style: TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}
