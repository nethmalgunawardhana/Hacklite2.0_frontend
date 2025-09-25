import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

import 'services/asl_detection_service_v2.dart';
import 'models/asl_prediction.dart';
import 'settings_page.dart';

class CameraPageV2 extends StatefulWidget {
  const CameraPageV2({super.key});

  @override
  State<CameraPageV2> createState() => _CameraPageV2State();
}

class _CameraPageV2State extends State<CameraPageV2> {
  CameraController? _controller;
  List<CameraDescription>? cameras;
  bool _isCameraInitialized = false;
  String _statusText = "Initializing camera...";
  int _currentCameraIndex = 0;

  // Backend ASL Detection variables
  late ASLDetectionServiceV2 _aslService;
  bool _isDetecting = false;
  String _currentPrediction = "";
  double _currentConfidence = 0.0;
  String _assembledText = "";
  bool _isAssembledTextExpanded =
      true; // Controls assembled text panel visibility

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
          ResolutionPreset.high, // High resolution for better ASL detection
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.jpeg, // Ensure color JPEG format
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

  void _clearAssembledText() {
    setState(() {
      _assembledText = "";
    });
    // Clear the backend service's assembled text state
    _aslService.clearAssembledText();
  }

  void _startDetection() async {
    if (!_isCameraInitialized || _isDetecting) return;

    // Clear previous assembled text when starting new detection
    _clearAssembledText();

    setState(() {
      _isDetecting = true;
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
        });
      });

      _assembledTextSubscription = _aslService.assembledTextStream?.listen((
        text,
      ) {
        setState(() {
          _assembledText = text;
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
      });
      _controller?.stopImageStream();
    }
  }

  void _stopDetection() {
    if (!_isDetecting) return;

    setState(() {
      _isDetecting = false;
    });

    _aslService.stopDetection();
    _controller?.stopImageStream();

    // Cancel subscriptions
    _predictionSubscription?.cancel();
    _assembledTextSubscription?.cancel();
    _networkStatsSubscription?.cancel();
    _networkStatsTimer?.cancel();
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
    final fps = _networkStats['currentFPS'] ?? 2;
    final backendUrl = _networkStats['backendUrl'] ?? 'Unknown';

    final healthIcon = isHealthy ? "🟢" : "🔴";
    return "$healthIcon ${latency}ms • ${successRate}% • ${fps}FPS\n🌐 ${_shortenUrl(backendUrl)}";
  }

  String _shortenUrl(String url) {
    if (url.length > 30) {
      return '${url.substring(0, 27)}...';
    }
    return url;
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
          child: Stack(
            children: [
              // Full Screen Camera Preview
              _isCameraInitialized
                  ? Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(0),
                        child: CameraPreview(_controller!),
                      ),
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
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

              // Header Overlay
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'ASL Detection',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      // Settings button
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SettingsPage(),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.settings,
                          color: Colors.white,
                          size: 24,
                        ),
                        tooltip: 'Settings',
                      ),
                      // Camera switch button
                      if (cameras != null && cameras!.length > 1)
                        IconButton(
                          onPressed: _switchCamera,
                          icon: const Icon(
                            Icons.flip_camera_ios,
                            color: Colors.white,
                            size: 24,
                          ),
                          tooltip: 'Switch Camera',
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
              ),

              // Status and Prediction Overlay
              Positioned(
                top: 80,
                left: 16,
                right: 16,
                child: Column(
                  children: [
                    // Status message
                    if (_statusText.isNotEmpty && !_isCameraInitialized)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _statusText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // Live prediction display
                    if (_isDetecting && _currentPrediction.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Text(
                              _currentPrediction.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${(_currentConfidence * 100).toStringAsFixed(1)}% confidence',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // Detection Status Indicator
              if (_isDetecting)
                Positioned(
                  top: 80,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
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

              // Bottom Panel with Controls and Results
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Drag Handle
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Control Buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isCameraInitialized && !_isDetecting
                                    ? _startDetection
                                    : null,
                                icon: const Icon(Icons.play_arrow, size: 24),
                                label: const Text(
                                  'Start Detection',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
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
                                icon: const Icon(Icons.stop, size: 24),
                                label: const Text(
                                  'Stop',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
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

                        const SizedBox(height: 16),

                        // Assembled Text Display with collapsible panel
                        if (_assembledText.isNotEmpty)
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header with expand/collapse and clear button
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _isAssembledTextExpanded =
                                          !_isAssembledTextExpanded;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        const Text(
                                          'Translated Text:',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const Spacer(),
                                        // Clear button
                                        InkWell(
                                          onTap: _clearAssembledText,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(
                                                0.2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.clear,
                                                  size: 14,
                                                  color: Colors.white,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Clear',
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
                                        const SizedBox(width: 8),
                                        // Expand/collapse button
                                        Icon(
                                          _isAssembledTextExpanded
                                              ? Icons.expand_less
                                              : Icons.expand_more,
                                          color: Colors.white70,
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Collapsible text content
                                if (_isAssembledTextExpanded)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      16,
                                    ),
                                    child: Text(
                                      _assembledText,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                        // Network Status
                        if (_networkStats.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: (_networkStats['isServerHealthy'] ?? true)
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    (_networkStats['isServerHealthy'] ?? true)
                                    ? Colors.green.withOpacity(0.3)
                                    : Colors.red.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              _formatNetworkStats(),
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    (_networkStats['isServerHealthy'] ?? true)
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
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
