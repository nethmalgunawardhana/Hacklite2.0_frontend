import 'package:flutter/material.dart';
import '../services/landmark_storage.dart';
import '../services/knn_classifier.dart';

/// UI for capturing hand landmark examples
class HandCaptureWidget extends StatefulWidget {
  final Function(List<double>)? onLandmarks;
  final bool isCapturing;
  final VoidCallback? onStartCapture;
  final VoidCallback? onStopCapture;

  const HandCaptureWidget({
    super.key,
    this.onLandmarks,
    this.isCapturing = false,
    this.onStartCapture,
    this.onStopCapture,
  });

  @override
  State<HandCaptureWidget> createState() => _HandCaptureWidgetState();
}

class _HandCaptureWidgetState extends State<HandCaptureWidget> {
  final LandmarkStorage _storage = LandmarkStorage();
  final KnnClassifier _classifier = KnnClassifier();
  final PredictionSmoother _smoother = PredictionSmoother();
  final TextEditingController _labelController = TextEditingController();

  Map<String, int> _exampleCounts = {};
  bool _isInferenceEnabled = false;
  String _currentPrediction = '';
  double _currentConfidence = 0.0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      _exampleCounts = await _storage.getExampleCounts();
      await _classifier.loadExamples(_storage);
    } catch (e) {
      _showError('Error loading data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _captureExample(List<double> landmarks) async {
    final label = _labelController.text.trim();
    if (label.isEmpty) {
      _showError('Please enter a label first');
      return;
    }

    try {
      await _storage.saveExample(label: label, landmarks: landmarks);
      await _loadData(); // Refresh counts and classifier

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Captured example for "$label"'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      _showError('Error capturing example: $e');
    }
  }

  void _processLandmarks(List<double> landmarks) {
    if (widget.isCapturing && landmarks.isNotEmpty) {
      _captureExample(landmarks);
    }

    if (_isInferenceEnabled && _classifier.isReady) {
      final prediction = _classifier.predict(landmarks);
      if (prediction != null) {
        final smoothed = _smoother.addPrediction(prediction);
        if (smoothed != null) {
          setState(() {
            _currentPrediction = smoothed.label;
            _currentConfidence = smoothed.confidence;
          });
        }
      }
    }
  }

  Future<void> _exportData() async {
    try {
      final data = await _storage.exportData();
      // In a real app, you'd use share_plus or file picker
      _showInfo('Export data (${data.length} chars) - copy from debug console');
      print('EXPORT DATA:\n$data');
    } catch (e) {
      _showError('Error exporting data: $e');
    }
  }

  Future<void> _clearData() async {
    final confirmed = await _showConfirmDialog(
      'Clear All Data',
      'This will delete all captured examples. Are you sure?',
    );

    if (confirmed) {
      try {
        await _storage.clearData();
        await _loadData();
        _smoother.clear();
        setState(() {
          _currentPrediction = '';
          _currentConfidence = 0.0;
        });
        _showInfo('All data cleared');
      } catch (e) {
        _showError('Error clearing data: $e');
      }
    }
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('❌ $message'), backgroundColor: Colors.red),
    );
  }

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ℹ️ $message'), backgroundColor: Colors.blue),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Process landmarks if available
    if (widget.onLandmarks != null) {
      // This would be called from the parent with actual landmarks
      // For now, we'll process when landmarks are provided via callback
    }

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.gesture, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Hand Landmark Capture',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const Spacer(),
                if (_isLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Label input
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Label for capture',
                hintText: 'e.g., hello, thanks, yes',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label),
              ),
            ),
            const SizedBox(height: 16),

            // Capture controls
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.isCapturing
                        ? null
                        : widget.onStartCapture,
                    icon: const Icon(Icons.fiber_manual_record),
                    label: const Text('Start Capture'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: widget.isCapturing ? widget.onStopCapture : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop Capture'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Example counts
            if (_exampleCounts.isNotEmpty) ...[
              const Text(
                'Captured Examples:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _exampleCounts.entries.map((entry) {
                  return Chip(
                    label: Text('${entry.key}: ${entry.value}'),
                    backgroundColor: Colors.blue.withOpacity(0.1),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Inference controls
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    title: const Text('Enable Inference'),
                    value: _isInferenceEnabled,
                    onChanged: _classifier.isReady
                        ? (value) {
                            setState(() {
                              _isInferenceEnabled = value ?? false;
                              if (!_isInferenceEnabled) {
                                _currentPrediction = '';
                                _currentConfidence = 0.0;
                                _smoother.clear();
                              }
                            });
                          }
                        : null,
                    dense: true,
                  ),
                ),
              ],
            ),

            // Current prediction
            if (_isInferenceEnabled && _currentPrediction.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _currentPrediction == 'unknown'
                      ? Colors.orange.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _currentPrediction == 'unknown'
                        ? Colors.orange
                        : Colors.green,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '🤟 $_currentPrediction',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _currentConfidence > 0.8
                            ? Colors.green
                            : _currentConfidence > 0.6
                            ? Colors.orange
                            : Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${(_currentConfidence * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Data management
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _exportData,
                    icon: const Icon(Icons.download),
                    label: const Text('Export'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _exampleCounts.isEmpty ? null : _clearData,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear All'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ),
              ],
            ),

            // Stats
            if (_classifier.isReady) ...[
              const SizedBox(height: 8),
              Text(
                'Classifier: ${_exampleCounts.length} labels, '
                '${_exampleCounts.values.fold(0, (a, b) => a + b)} examples',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Method to be called from parent when landmarks are available
  void processLandmarks(List<double> landmarks) {
    _processLandmarks(landmarks);
  }
}
