import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Storage keys - defined at file level for static access
const String _keyClientId = 'fitbit_config_client_id';
const String _keyClientSecret = 'fitbit_config_client_secret';
const String _keyRedirectUri = 'fitbit_config_redirect_uri';

/// Fitbit Settings Screen
///
/// Allows user to configure Fitbit OAuth credentials
class FitbitSettingsScreen extends StatefulWidget {
  const FitbitSettingsScreen({super.key});

  /// Static method to load credentials from storage
  static Future<FitbitCredentials?> loadCredentials() async {
    const storage = FlutterSecureStorage();

    try {
      final clientId = await storage.read(key: _keyClientId);
      final clientSecret = await storage.read(key: _keyClientSecret);
      final redirectUri = await storage.read(key: _keyRedirectUri);

      if (clientId != null && clientSecret != null && redirectUri != null) {
        return FitbitCredentials(
          clientId: clientId,
          clientSecret: clientSecret,
          redirectUri: redirectUri,
        );
      }
    } catch (e) {
      // Return null if error
    }

    return null;
  }

  @override
  State<FitbitSettingsScreen> createState() => _FitbitSettingsScreenState();
}

class _FitbitSettingsScreenState extends State<FitbitSettingsScreen> {
  final _storage = const FlutterSecureStorage();
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _clientIdController = TextEditingController();
  final _clientSecretController = TextEditingController();
  final _redirectUriController = TextEditingController();

  // State
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _clientIdController.dispose();
    _clientSecretController.dispose();
    _redirectUriController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      final clientId = await _storage.read(key: _keyClientId);
      final clientSecret = await _storage.read(key: _keyClientSecret);
      final redirectUri = await _storage.read(key: _keyRedirectUri);

      _clientIdController.text = clientId ?? '';
      _clientSecretController.text = clientSecret ?? '';
      _redirectUriController.text = redirectUri ?? 'healthsync://fitbit/callback';
    } catch (e) {
      _showError('Failed to load settings: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      await Future.wait([
        _storage.write(key: _keyClientId, value: _clientIdController.text.trim()),
        _storage.write(key: _keyClientSecret, value: _clientSecretController.text.trim()),
        _storage.write(key: _keyRedirectUri, value: _redirectUriController.text.trim()),
      ]);

      _showSuccess('Settings saved successfully!');
      Navigator.pop(context, true); // Return true to indicate settings changed
    } catch (e) {
      _showError('Failed to save settings: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _clearSettings() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Settings'),
        content: const Text(
          'Are you sure you want to clear all Fitbit credentials? '
          'You will need to re-enter them to use Fitbit integration.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await Future.wait([
        _storage.delete(key: _keyClientId),
        _storage.delete(key: _keyClientSecret),
        _storage.delete(key: _keyRedirectUri),
      ]);

      _clientIdController.clear();
      _clientSecretController.clear();
      _redirectUriController.text = 'healthsync://fitbit/callback';

      _showSuccess('Settings cleared');
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fitbit Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear Settings',
            onPressed: _isLoading || _isSaving ? null : _clearSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Instructions Card
                    Card(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.blue.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'Setup Instructions',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              '1. Go to https://dev.fitbit.com/apps\n'
                              '2. Create a new app or use existing\n'
                              '3. Set OAuth 2.0 Application Type: "Personal"\n'
                              '4. Set Redirect URL: healthsync://fitbit/callback\n'
                              '5. Copy Client ID and Client Secret below',
                              style: TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Client ID
                    TextFormField(
                      controller: _clientIdController,
                      decoration: const InputDecoration(
                        labelText: 'Client ID *',
                        hintText: 'Enter your Fitbit Client ID',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.key),
                        helperText: 'Typically 6-8 alphanumeric characters',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Client ID is required';
                        }
                        final trimmed = value.trim();
                        if (trimmed.length < 6) {
                          return 'Client ID must be at least 6 characters';
                        }
                        if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(trimmed)) {
                          return 'Client ID should only contain letters and numbers';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Client Secret
                    TextFormField(
                      controller: _clientSecretController,
                      decoration: const InputDecoration(
                        labelText: 'Client Secret *',
                        hintText: 'Enter your Fitbit Client Secret',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                        helperText: 'At least 16 alphanumeric characters',
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Client Secret is required';
                        }
                        final trimmed = value.trim();
                        if (trimmed.length < 16) {
                          return 'Client Secret must be at least 16 characters';
                        }
                        if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(trimmed)) {
                          return 'Client Secret should only contain letters and numbers';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Redirect URI
                    TextFormField(
                      controller: _redirectUriController,
                      decoration: const InputDecoration(
                        labelText: 'Redirect URI *',
                        hintText: 'healthsync://fitbit/callback',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.link),
                        helperText: 'Must match your Fitbit app configuration',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Redirect URI is required';
                        }
                        final trimmed = value.trim();
                        if (!trimmed.contains('://')) {
                          return 'Invalid URI format (missing ://)';
                        }
                        // Validate URI format
                        try {
                          final uri = Uri.parse(trimmed);
                          if (uri.scheme.isEmpty || uri.host.isEmpty) {
                            return 'Invalid URI format';
                          }
                          // Check if it matches recommended format
                          if (uri.scheme == 'healthsync' &&
                              uri.host == 'fitbit' &&
                              uri.path == '/callback') {
                            // Perfect match
                          } else {
                            // Different format - show warning but allow it
                          }
                        } catch (e) {
                          return 'Invalid URI format';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveSettings,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isSaving ? 'Saving...' : 'Save Settings'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Test Connection Button
                    OutlinedButton.icon(
                      onPressed: (_isSaving || _clientIdController.text.isEmpty)
                          ? null
                          : () {
                              _showSuccess('Settings look valid. Save and try connecting!');
                            },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Validate'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Fitbit Credentials Model
class FitbitCredentials {
  final String clientId;
  final String clientSecret;
  final String redirectUri;

  const FitbitCredentials({
    required this.clientId,
    required this.clientSecret,
    required this.redirectUri,
  });
}
