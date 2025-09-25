import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

import '../services/asl_detection_service_v2.dart';
import '../models/asl_prediction.dart';
import 'asl_settings_page.dart';

class EnhancedCameraPage extends StatefulWidget {
  const EnhancedCameraPage({super.key});

  @override
  State<EnhancedCameraPage> createState() => _EnhancedCameraPageState();
}

class _EnhancedCameraPageState extends State<EnhancedCameraPage> {
  CameraController? _controller;
  List<CameraDescription>? cameras;
  bool _isCameraInitialized = false;
  String _translationText = "Sign language translation will appear here...";
  String _statusText = "Initializing camera...";
  int _currentCameraIndex = 0;

  // Enhanced ASL Detection variables
  late ASLDetectionServiceV2 _aslService;
  bool _isDetecting = false;
  String _currentPrediction = "";
  double _currentConfidence = 0.0;
  List<ASLPrediction> _detectionHistory = [];
  Timer? _detectionTimer;
  String _detectedSentence = "";
  String _backendAssembledText = "";
  CameraImage? _currentCameraImage;

  // Status indicators
  bool _backendAvailable = false;
  ASLDetectionMode _currentMode = ASLDetectionMode.hybrid;

  @override
  void initState() {
    super.initState();
    _aslService = ASLDetectionServiceV2.instance;
    _initializeASLService();
    _requestPermissions();
  }

  Future<void> _initializeASLService() async {
    try {
      final success = await _aslService.initialize(
        mode: ASLDetectionMode.hybrid,
      );
      if (success) {
        final status = await _aslService.getServiceStatus();
        setState(() {
          _backendAvailable = status['backend_available'] ?? false;
          _currentMode = _aslService.detectionMode;
          _statusText =
              "Enhanced ASL detection service initialized (${_currentMode.toString().split('.').last} mode).";
        });
      } else {
        setState(() {
          _statusText = "Failed to initialize ASL detection service.";
        });
      }
    } catch (e) {
      setState(() {
        _statusText = "Error initializing ASL service: $e";
      });
    }
  }

  Future<void> _requestPermissions() async {
    final cameraStatus = await Permission.camera.request();
    await Permission.microphone.request();

    if (cameraStatus.isGranted) {
      setState(() {
        _statusText = "Permissions granted. Initializing camera...";
      });
      _initializeCamera();
    } else {
      setState(() {
        _statusText =
            "Camera permission denied. Please grant permission to use camera.";
      });
    }
  }

  Future<void> _initializeCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras != null && cameras!.isNotEmpty) {
        // Find front camera for ASL detection
        if (_currentCameraIndex == 0 && cameras!.length > 1) {
          for (int i = 0; i < cameras!.length; i++) {
            if (cameras![i].lensDirection == CameraLensDirection.front) {
              _currentCameraIndex = i;
              break;
            }
          }
        }

        if (_currentCameraIndex >= cameras!.length) {
          _currentCameraIndex = 0;
        }

        _controller = CameraController(
          cameras![_currentCameraIndex],
          ResolutionPreset.medium,
          enableAudio: false,
        );

        await _controller!.initialize();
        setState(() {
          _isCameraInitialized = true;
          _statusText = "Camera initialized. Ready for ASL detection.";
        });
      } else {
        setState(() {
          _statusText = "No cameras available.";
        });
      }
    } catch (e) {
      setState(() {
        _statusText = "Error initializing camera: $e";
      });
    }
  }

  Future<void> _switchCamera() async {
    if (cameras == null || cameras!.length <= 1) return;

    setState(() {
      _isCameraInitialized = false;
      _statusText = "Switching camera...";
    });

    await _controller?.dispose();
    _currentCameraIndex = (_currentCameraIndex + 1) % cameras!.length;

    _controller = CameraController(
      cameras![_currentCameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      setState(() {
        _isCameraInitialized = true;
        _statusText = "Camera switched. Ready for ASL detection.";
      });
    } catch (e) {
      setState(() {
        _statusText = "Error switching camera: $e";
      });
    }
  }

  Future<void> _startDetection() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      setState(() {
        _statusText = "Camera not ready. Please wait...";
      });
      return;
    }

    setState(() {
      _isDetecting = true;
      _translationText =
          "Starting ASL detection...\nMode: ${_currentMode.toString().split('.').last}\nBackend: ${_backendAvailable ? '✅ Available' : '❌ Offline'}";
      _currentPrediction = "";
      _currentConfidence = 0.0;
      _detectionHistory.clear();
      _detectedSentence = "";
      _backendAssembledText = "";
    });

    // Start camera image stream
    await _controller!.startImageStream((CameraImage image) {
      _currentCameraImage = image;
    });

    // Start detection timer
    _detectionTimer = Timer.periodic(const Duration(milliseconds: 1500), (
      timer,
    ) {
      if (_isDetecting) {
        _processGesture();
      }
    });
  }

  Future<void> _stopDetection() async {
    setState(() {
      _isDetecting = false;
      _translationText =
          "ASL detection stopped.\n\nLocal sentence: $_detectedSentence\nBackend text: $_backendAssembledText";
    });
    _detectionTimer?.cancel();
    _detectionTimer = null;

    if (_controller != null) {
      _controller!.stopImageStream();
    }
    _currentCameraImage = null;
  }

  Future<void> _processGesture() async {
    if (!_isDetecting) return;

    try {
      ASLPrediction? prediction;

      if (_controller != null && _currentCameraImage != null) {
        try {
          prediction = await _aslService.detectGesture(
            cameraImage: _currentCameraImage,
          );
        } catch (e) {
          print('❌ Detection failed: $e');
          setState(() {
            _translationText = "❌ Detection error. Please try again.";
          });
          return;
        }
      } else {
        print('⚠️ No camera image available for detection');
        return;
      }

      if (prediction != null && prediction.isHighConfidence) {
        final currentPrediction =
            prediction; // Non-null assertion through flow analysis
        setState(() {
          _currentPrediction = currentPrediction.letter;
          _currentConfidence = currentPrediction.confidence;
          _detectionHistory.add(currentPrediction);

          // Update local sentence building
          if (currentPrediction.letter == "SPACE") {
            _detectedSentence += " ";
          } else if (currentPrediction.letter == "DEL") {
            if (_detectedSentence.isNotEmpty) {
              _detectedSentence = _detectedSentence.substring(
                0,
                _detectedSentence.length - 1,
              );
            }
          } else if (currentPrediction.letter != "NOTHING") {
            _detectedSentence += currentPrediction.letter;
          }

          // Get backend assembled text if available
          _backendAssembledText = _aslService.backendAssembledText;

          // Update display
          final backendText = _backendAssembledText.isNotEmpty
              ? "\n\nBackend text: $_backendAssembledText"
              : "";

          _translationText =
              "🤖 Current: ${currentPrediction.letter} (${(currentPrediction.confidence * 100).toStringAsFixed(1)}%)\n\n"
              "Mode: ${_currentMode.toString().split('.').last}\n"
              "Backend: ${_backendAvailable ? '✅ Online' : '❌ Offline'}\n\n"
              "Local sentence: $_detectedSentence"
              "$backendText";
        });

        // Keep only last 10 predictions for history
        if (_detectionHistory.length > 10) {
          _detectionHistory.removeAt(0);
        }
      } else {
        // No valid prediction
        setState(() {
          _currentPrediction = "";
          _currentConfidence = 0.0;
        });
      }
    } catch (e) {
      print('❌ Error in gesture processing: $e');
      setState(() {
        _translationText = "❌ Processing error: $e";
      });
    }
  }

  void _clearSentences() {
    setState(() {
      _detectedSentence = "";
      _backendAssembledText = "";
      _detectionHistory.clear();
      _currentPrediction = "";
      _currentConfidence = 0.0;
      _translationText = _isDetecting
          ? "Detection cleared. Continue signing..."
          : "Sentences cleared. Tap 'Start Detection' to begin.";
    });

    // Clear backend session
    _aslService.clearBackendSession();
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ASLSettingsPage()),
    ).then((_) {
      // Refresh service status after returning from settings
      _refreshServiceStatus();
    });
  }

  Future<void> _refreshServiceStatus() async {
    try {
      final status = await _aslService.getServiceStatus();
      setState(() {
        _backendAvailable = status['backend_available'] ?? false;
        _currentMode = _aslService.detectionMode;
      });
    } catch (e) {
      print('Error refreshing service status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // Header with title and settings button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.camera_alt, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Enhanced ASL Detection',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white),
                    onPressed: _openSettings,
                    tooltip: 'Settings',
                  ),
                ],
              ),
            ),

            // Status indicators
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: Row(
                children: [
                  _buildStatusChip(
                    "Mode: ${_currentMode.toString().split('.').last}",
                    Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(
                    _backendAvailable ? "Backend: Online" : "Backend: Offline",
                    _backendAvailable ? Colors.green : Colors.orange,
                  ),
                ],
              ),
            ),

            // Camera preview section
            Expanded(
              flex: 3,
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _isCameraInitialized
                      ? Stack(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: double.infinity,
                              child: AspectRatio(
                                aspectRatio: _controller!.value.aspectRatio,
                                child: CameraPreview(_controller!),
                              ),
                            ),

                            // Detection overlay
                            if (_isDetecting)
                              Positioned(
                                top: 16,
                                left: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Detecting...',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            // Current prediction overlay
                            if (_currentPrediction.isNotEmpty)
                              Positioned(
                                top: 16,
                                right: 16,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.blue,
                                      width: 2,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _currentPrediction,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue,
                                        ),
                                      ),
                                      Text(
                                        '${(_currentConfidence * 100).toStringAsFixed(1)}%',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            // Camera switch button
                            if (cameras != null && cameras!.length > 1)
                              Positioned(
                                bottom: 16,
                                right: 16,
                                child: FloatingActionButton(
                                  mini: true,
                                  onPressed: _switchCamera,
                                  backgroundColor: Colors.white,
                                  child: const Icon(
                                    Icons.flip_camera_ios,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                          ],
                        )
                      : Container(
                          color: Colors.black12,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: 16),
                                Text(
                                  _statusText,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            ),

            // Translation results section
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.translate, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Translation Results',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          _translationText,
                          style: const TextStyle(fontSize: 16, height: 1.4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Control buttons
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isDetecting
                          ? _stopDetection
                          : _startDetection,
                      icon: Icon(_isDetecting ? Icons.stop : Icons.play_arrow),
                      label: Text(
                        _isDetecting ? 'Stop Detection' : 'Start Detection',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isDetecting
                            ? Colors.red
                            : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _clearSentences,
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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

  Widget _buildStatusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }
}
