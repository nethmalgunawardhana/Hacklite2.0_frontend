import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

import 'services/asl_detection_service_v2.dart';
import 'services/environment_config.dart';
import 'models/asl_prediction.dart';

class CameraPageV2 extends StatefulWidget {
  const CameraPageV2({super.key});

  @override
  State<CameraPageV2> createState() => _CameraPageV2State();
}

class _CameraPageV2State extends State<CameraPageV2> {
  CameraController? _controller;
  List<CameraDescription>? cameras;
  bool _isCameraInitialized = false;
  bool _isPermissionGranted = false;
  String _translationText = "Backend ASL prediction ready...";
  String _statusText = "Initializing camera...";
  int _currentCameraIndex = 0;

  // Backend ASL Detection variables
  late ASLDetectionServiceV2 _aslService;
  bool _isDetecting = false;
  String _currentPrediction = "";
  double _currentConfidence = 0.0;
  String _assembledText = "";

  // Network status
  Map<String, dynamic> _networkStats = {};
  Timer? _networkStatsTimer;

  // Stream subscriptions
  StreamSubscription<ASLPrediction>? _predictionSubscription;
  StreamSubscription<String>? _assembledTextSubscription;
  StreamSubscription<Map<String, dynamic>>? _networkStatsSubscription;

  @override
  void initState() {
    super.initState();
    _aslService = ASLDetectionServiceV2.instance;
    _initializeASLService();
    _requestPermissions();
  }

  @override
  void dispose() {
    _predictionSubscription?.cancel();
    _assembledTextSubscription?.cancel();
    _networkStatsSubscription?.cancel();
    _networkStatsTimer?.cancel();
    _controller?.dispose();
    _aslService.dispose();
    super.dispose();
  }

  Future<void> _initializeASLService() async {
    try {
      final success = await _aslService.initialize();
      if (success) {
        setState(() {
          final mockMode = _aslService.isUsingMockMode ? " (Mock Mode)" : "";
          _statusText = "Backend ASL detection service initialized$mockMode.";
        });
      } else {
        setState(() {
          _statusText = "Failed to initialize backend ASL detection service.";
        });
      }
    } catch (e) {
      setState(() {
        _statusText = "Error initializing backend ASL service: $e";
      });
    }
  }

  Future<void> _requestPermissions() async {
    final cameraStatus = await Permission.camera.request();
    await Permission.microphone.request();

    if (cameraStatus.isGranted) {
      setState(() {
        _isPermissionGranted = true;
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

        _currentCameraIndex = _currentCameraIndex.clamp(0, cameras!.length - 1);

        _controller = CameraController(
          cameras![_currentCameraIndex],
          ResolutionPreset.medium, // Medium resolution for better performance
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
        _statusText = "Camera initialization failed: $e";
      });
    }
  }

  Future<void> _switchCamera() async {
    if (cameras == null || cameras!.length <= 1) return;

    await _controller?.dispose();
    _currentCameraIndex = (_currentCameraIndex + 1) % cameras!.length;
    await _initializeCamera();
  }

  void _startDetection() async {
    if (!_isCameraInitialized || _isDetecting) return;

    setState(() {
      _isDetecting = true;
      _translationText =
          "🔍 Starting backend ASL detection...\nShow your hand signs to the camera.";
      _assembledText = "";
      _currentPrediction = "";
      _currentConfidence = 0.0;
    });

    try {
      // Create camera image stream
      late StreamController<CameraImage> cameraStreamController;
      cameraStreamController = StreamController<CameraImage>.broadcast();

      // Start camera image stream
      await _controller!.startImageStream((CameraImage image) {
        cameraStreamController.add(image);
      });

      // Subscribe to prediction results
      _predictionSubscription = _aslService.predictionStream?.listen((
        prediction,
      ) {
        setState(() {
          _currentPrediction = prediction.letter;
          _currentConfidence = prediction.confidence;
          _updateTranslationText(prediction);
        });
      });

      _assembledTextSubscription = _aslService.assembledTextStream?.listen((
        text,
      ) {
        setState(() {
          _assembledText = text;
          _updateAssembledTextDisplay();
        });
      });

      // Start backend detection
      final success = await _aslService.startDetection(
        cameraStream: cameraStreamController.stream,
      );

      if (!success) {
        throw Exception('Failed to start backend detection');
      }

      // Start network stats monitoring
      _startNetworkStatsMonitoring();
    } catch (e) {
      print('❌ Error starting detection: $e');
      setState(() {
        _isDetecting = false;
        _translationText = "❌ Failed to start detection: $e";
      });
      _controller?.stopImageStream();
    }
  }

  void _stopDetection() {
    if (!_isDetecting) return;

    setState(() {
      _isDetecting = false;
      _translationText =
          "Backend ASL detection stopped.\n\nFinal text: $_assembledText";
    });

    _aslService.stopDetection();
    _controller?.stopImageStream();

    // Cancel subscriptions
    _predictionSubscription?.cancel();
    _assembledTextSubscription?.cancel();
    _networkStatsSubscription?.cancel();
    _networkStatsTimer?.cancel();
  }

  void _updateTranslationText(ASLPrediction prediction) {
    final networkInfo = _formatNetworkStats();
    _translationText =
        "🎯 Current: ${prediction.letter}\n"
        "📈 Confidence: ${(prediction.confidence * 100).toStringAsFixed(1)}%\n"
        "🕒 Time: ${prediction.timestamp.toString().substring(11, 19)}\n"
        "$networkInfo";
  }

  void _updateAssembledTextDisplay() {
    // Update translation text to show assembled text
    final networkInfo = _formatNetworkStats();
    _translationText =
        "📝 Assembled Text: $_assembledText\n"
        "🎯 Last: $_currentPrediction (${(_currentConfidence * 100).toStringAsFixed(1)}%)\n"
        "$networkInfo";
  }

  void _startNetworkStatsMonitoring() {
    _networkStatsTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!_isDetecting) {
        timer.cancel();
        return;
      }
      setState(() {
        _networkStats = _aslService.networkStats;
      });
    });
  }

  String _formatNetworkStats() {
    if (_networkStats.isEmpty) return "";

    final isHealthy = _networkStats['isServerHealthy'] ?? true;
    final latency = _networkStats['averageLatency'] ?? 0;
    final successRate = _networkStats['successRate'] ?? 0;
    final interval = 2000; // Fixed 2000ms interval

    final healthIcon = isHealthy ? "🟢" : "🔴";
    return "$healthIcon ${latency}ms • ${successRate}% • ${interval}ms";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.camera_alt, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Backend ASL Detection',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (_aslService.isUsingMockMode)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'MOCK',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Camera Preview
              Expanded(
                flex: 2,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _isCameraInitialized
                        ? Stack(
                            children: [
                              CameraPreview(_controller!),
                              // Status overlay
                              if (_statusText.isNotEmpty)
                                Positioned(
                                  top: 16,
                                  left: 16,
                                  right: 16,
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _statusText,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              // Detection status
                              if (_isDetecting)
                                Positioned(
                                  bottom: 16,
                                  right: 16,
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.fiber_manual_record,
                                          color: Colors.white,
                                          size: 12,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'LIVE',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              // Camera switch button
                              if (cameras != null && cameras!.length > 1)
                                Positioned(
                                  top: 16,
                                  right: 16,
                                  child: GestureDetector(
                                    onTap: _switchCamera,
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Icon(
                                        Icons.flip_camera_ios,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          )
                        : Container(
                            color: Colors.black,
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 64,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'Camera Initializing...',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                ),
              ),

              // Controls and Results
              Expanded(
                flex: 2,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header with network status
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4facfe).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.translate,
                                color: Color(0xFF4facfe),
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Text(
                                'Backend Translation',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            if (_networkStats.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (_networkStats['isServerHealthy'] ?? true)
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _formatNetworkStats(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        (_networkStats['isServerHealthy'] ??
                                            true)
                                        ? Colors.green.shade700
                                        : Colors.red.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Translation Results
                        Container(
                          height: 100,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: SingleChildScrollView(
                            child: Text(
                              _translationText,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Assembled Text Display
                        if (_assembledText.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Assembled Text:',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _assembledText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const Spacer(),

                        // Control Buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isCameraInitialized && !_isDetecting
                                    ? _startDetection
                                    : null,
                                icon: const Icon(Icons.play_arrow, size: 20),
                                label: const Text('Start Detection'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isDetecting ? _stopDetection : null,
                                icon: const Icon(Icons.stop, size: 20),
                                label: const Text('Stop'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 3,
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
            ],
          ),
        ),
      ),
    );
  }
}
