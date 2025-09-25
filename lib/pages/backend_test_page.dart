import 'package:flutter/material.dart';
import '../services/asl_backend_service.dart';

class BackendTestPage extends StatefulWidget {
  const BackendTestPage({super.key});

  @override
  State<BackendTestPage> createState() => _BackendTestPageState();
}

class _BackendTestPageState extends State<BackendTestPage> {
  final _backendService = ASLBackendService.instance;
  String _statusText = "Backend service not tested yet";
  List<String> _testResults = [];
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  void _initializeService() {
    _backendService.initialize(baseUrl: 'http://localhost:5000');
  }

  Future<void> _testHealthEndpoint() async {
    setState(() {
      _isTesting = true;
      _testResults.clear();
    });

    try {
      _addTestResult("🔄 Testing health endpoint...");
      final isHealthy = await _backendService.checkHealth();

      if (isHealthy) {
        _addTestResult("✅ Health check passed!");
        final status = await _backendService.getStatus();
        _addTestResult("📊 Backend Status:");
        _addTestResult("  - Base URL: ${status['base_url']}");
        _addTestResult("  - Session ID: ${status['session_id']}");
        _addTestResult("  - Is Healthy: ${status['is_healthy']}");
      } else {
        _addTestResult("❌ Health check failed");
      }
    } catch (e) {
      _addTestResult("❌ Health test error: $e");
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }

  Future<void> _testWithSampleImage() async {
    setState(() {
      _isTesting = true;
    });

    try {
      _addTestResult("🔄 Testing with sample image...");
      _addTestResult("ℹ️ This would normally use a real camera image");
      _addTestResult("📝 For now, we're testing the service infrastructure");

      // Test session management
      _backendService.clearSession();
      _addTestResult("🔄 Session cleared, new session started");

      final status = await _backendService.getStatus();
      _addTestResult("📊 Current session: ${status['session_id']}");
    } catch (e) {
      _addTestResult("❌ Sample image test error: $e");
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }

  void _addTestResult(String result) {
    setState(() {
      _testResults.add(
        "${DateTime.now().toString().substring(11, 19)} - $result",
      );
      _statusText = _testResults.last;
    });
  }

  Future<void> _updateBackendUrl() async {
    final controller = TextEditingController(text: 'http://localhost:5000');

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Backend URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the backend server URL:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'http://localhost:5000',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Common URLs:\n'
              '• Local: http://localhost:5000\n'
              '• Network: http://YOUR_IP:5000\n'
              '• Production: https://your-domain.com',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _backendService.updateBaseUrl(controller.text.trim());
              _addTestResult(
                "🔄 Backend URL updated to: ${controller.text.trim()}",
              );
              Navigator.of(context).pop();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backend Connection Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _updateBackendUrl,
            tooltip: 'Update Backend URL',
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
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Card
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.network_check, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'Connection Status',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(_statusText, style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Test Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isTesting ? null : _testHealthEndpoint,
                      icon: _isTesting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.health_and_safety),
                      label: const Text('Test Health'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isTesting ? null : _testWithSampleImage,
                      icon: const Icon(Icons.image),
                      label: const Text('Test Session'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Test Results
              Expanded(
                child: Card(
                  elevation: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(Icons.assignment, color: Colors.blue),
                            SizedBox(width: 8),
                            Text(
                              'Test Results',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: _testResults.isEmpty
                            ? const Center(
                                child: Text(
                                  'No tests run yet.\nTap a button above to start testing.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: _testResults.length,
                                itemBuilder: (context, index) {
                                  final result = _testResults[index];
                                  Color textColor = Colors.black87;
                                  IconData? icon;

                                  if (result.contains('✅')) {
                                    textColor = Colors.green;
                                    icon = Icons.check_circle;
                                  } else if (result.contains('❌')) {
                                    textColor = Colors.red;
                                    icon = Icons.error;
                                  } else if (result.contains('🔄')) {
                                    textColor = Colors.blue;
                                    icon = Icons.sync;
                                  } else if (result.contains('ℹ️')) {
                                    textColor = Colors.orange;
                                    icon = Icons.info;
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (icon != null)
                                          Icon(icon, size: 16, color: textColor)
                                        else
                                          const SizedBox(width: 16),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            result,
                                            style: TextStyle(
                                              color: textColor,
                                              fontSize: 12,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),

              // Instructions
              Card(
                color: Colors.blue.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🚀 Getting Started',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '1. Start your ASL backend server\n'
                        '2. Update the backend URL if needed\n'
                        '3. Test the health endpoint\n'
                        '4. Test session management\n'
                        '5. Go to Enhanced Camera page for live detection',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
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
