import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/asl_detection_service_v2.dart';
import '../services/asl_backend_service.dart';

class ASLSettingsPage extends StatefulWidget {
  const ASLSettingsPage({super.key});

  @override
  State<ASLSettingsPage> createState() => _ASLSettingsPageState();
}

class _ASLSettingsPageState extends State<ASLSettingsPage> {
  final _backendUrlController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  ASLDetectionMode _selectedMode = ASLDetectionMode.hybrid;
  bool _isTestingConnection = false;
  String? _connectionStatus;
  Map<String, dynamic>? _serviceStatus;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
    _loadServiceStatus();
  }

  void _loadCurrentSettings() {
    final backendUrl = dotenv.env['ASL_BACKEND_URL'] ?? 'http://localhost:5000';
    _backendUrlController.text = backendUrl;
    _selectedMode = ASLDetectionServiceV2.instance.detectionMode;
  }

  Future<void> _loadServiceStatus() async {
    try {
      final status = await ASLDetectionServiceV2.instance.getServiceStatus();
      setState(() {
        _serviceStatus = status;
      });
    } catch (e) {
      print('Error loading service status: $e');
    }
  }

  Future<void> _testBackendConnection() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isTestingConnection = true;
      _connectionStatus = null;
    });

    try {
      // Update backend URL temporarily for testing
      final backendService = ASLBackendService.instance;
      backendService.updateBaseUrl(_backendUrlController.text.trim());

      final isHealthy = await backendService.checkHealth();

      setState(() {
        _connectionStatus = isHealthy
            ? '✅ Connection successful!'
            : '❌ Backend not responding';
      });

      if (isHealthy) {
        // Show backend status
        final status = await backendService.getStatus();
        _showStatusDialog(status);
      }
    } catch (e) {
      setState(() {
        _connectionStatus = '❌ Connection failed: $e';
      });
    } finally {
      setState(() {
        _isTestingConnection = false;
      });
    }
  }

  void _showStatusDialog(Map<String, dynamic> status) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Backend Connected'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusRow('Base URL', status['base_url'] ?? 'Unknown'),
            _buildStatusRow('Session ID', status['session_id'] ?? 'None'),
            _buildStatusRow(
              'Health Status',
              status['is_healthy'] ? '✅ Healthy' : '❌ Unhealthy',
            ),
            const SizedBox(height: 8),
            const Text(
              'Backend is ready for ASL recognition!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontFamily: 'monospace')),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      // Update backend URL
      final backendService = ASLBackendService.instance;
      backendService.updateBaseUrl(_backendUrlController.text.trim());

      // Switch detection mode
      await ASLDetectionServiceV2.instance.switchDetectionMode(_selectedMode);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh service status
      await _loadServiceStatus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving settings: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _resetToDefaults() async {
    setState(() {
      _backendUrlController.text = 'http://localhost:5000';
      _selectedMode = ASLDetectionMode.hybrid;
      _connectionStatus = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ASL Detection Settings'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadServiceStatus,
            tooltip: 'Refresh Status',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8F9FA), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Service Status Card
                if (_serviceStatus != null) _buildServiceStatusCard(),
                const SizedBox(height: 20),

                // Backend Configuration Section
                _buildSectionCard(
                  title: '🌐 Backend Configuration',
                  children: [
                    TextFormField(
                      controller: _backendUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Backend URL',
                        hintText: 'http://localhost:5000',
                        prefixIcon: Icon(Icons.link),
                        border: OutlineInputBorder(),
                        helperText:
                            'URL of your ASL recognition backend server',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a backend URL';
                        }
                        if (!value.startsWith('http://') &&
                            !value.startsWith('https://')) {
                          return 'URL must start with http:// or https://';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Test Connection Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isTestingConnection
                            ? null
                            : _testBackendConnection,
                        icon: _isTestingConnection
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.wifi_find),
                        label: Text(
                          _isTestingConnection
                              ? 'Testing...'
                              : 'Test Connection',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),

                    // Connection Status
                    if (_connectionStatus != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _connectionStatus!,
                          style: TextStyle(
                            color: _connectionStatus!.startsWith('✅')
                                ? Colors.green
                                : Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // Detection Mode Section
                _buildSectionCard(
                  title: '🤖 Detection Mode',
                  children: [
                    const Text(
                      'Choose how ASL detection should be performed:',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 12),

                    ...ASLDetectionMode.values.map(
                      (mode) => RadioListTile<ASLDetectionMode>(
                        title: Text(_getModeTitle(mode)),
                        subtitle: Text(_getModeDescription(mode)),
                        value: mode,
                        groupValue: _selectedMode,
                        onChanged: (value) {
                          setState(() {
                            _selectedMode = value!;
                          });
                        },
                        activeColor: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _resetToDefaults,
                        icon: const Icon(Icons.restore),
                        label: const Text('Reset to Defaults'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _saveSettings,
                        icon: const Icon(Icons.save),
                        label: const Text('Save Settings'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceStatusCard() {
    final status = _serviceStatus!;
    final isInitialized = status['is_initialized'] ?? false;
    final backendAvailable = status['backend_available'] ?? false;
    final mlKitAvailable = status['ml_kit_available'] ?? false;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Service Status',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _buildStatusIndicator('Service Initialized', isInitialized),
            _buildStatusIndicator('Backend Available', backendAvailable),
            _buildStatusIndicator('ML Kit Available', mlKitAvailable),

            if (status['detection_mode'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Current Mode: ${status['detection_mode']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.blue,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String label, bool isActive) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isActive ? Icons.check_circle : Icons.cancel,
            color: isActive ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  String _getModeTitle(ASLDetectionMode mode) {
    switch (mode) {
      case ASLDetectionMode.localMLKit:
        return 'Local ML Kit Only';
      case ASLDetectionMode.backendAPI:
        return 'Backend API Only';
      case ASLDetectionMode.hybrid:
        return 'Hybrid Mode (Recommended)';
    }
  }

  String _getModeDescription(ASLDetectionMode mode) {
    switch (mode) {
      case ASLDetectionMode.localMLKit:
        return 'Uses device ML Kit for processing (works offline)';
      case ASLDetectionMode.backendAPI:
        return 'Uses backend server for recognition (requires internet)';
      case ASLDetectionMode.hybrid:
        return 'Tries backend first, falls back to local processing';
    }
  }

  @override
  void dispose() {
    _backendUrlController.dispose();
    super.dispose();
  }
}
