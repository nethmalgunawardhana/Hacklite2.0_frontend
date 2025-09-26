import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:math' as math;

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
  bool _isSwitching = false;

  // Backend ASL Detection variables
  late ASLDetectionServiceV2 _aslService;
  bool _isDetecting = false;
  String _currentPrediction = "";
  double _currentConfidence = 0.0;
  String _assembledText = "";
  bool _isAssembledTextExpanded =
    false; // Controls assembled text panel visibility

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
    // Stop detection and streams first to avoid observer issues
    if (_isDetecting) {
      _stopDetection();
    }

    _predictionSubscription?.cancel();
    _assembledTextSubscription?.cancel();
    _networkStatsSubscription?.cancel();
    _networkStatsTimer?.cancel();

    // Dispose controller safely
    _disposeControllerSafely();
    _aslService.dispose();
    super.dispose();
  }

  Future<void> _disposeControllerSafely() async {
    if (_controller != null) {
      try {
        // Stop image stream first to remove observers
        await _controller!.stopImageStream();
      } catch (e) {
        // Ignore errors - stream may not be active
      }

      try {
        // Small delay to allow observers to detach
        await Future.delayed(const Duration(milliseconds: 50));
        await _controller!.dispose();
      } catch (e) {
        // Ignore dispose errors to prevent crashes
        print('Warning: Controller dispose error (ignored): $e');
      }

      _controller = null;
    }
  }

  @override
  void reassemble() {
    // Called on hot reload/restart. Clean up camera resources more aggressively
    // to prevent CameraX Observer serialization issues
    super.reassemble();
    _handleReassemble();
  }

  Future<void> _handleReassemble() async {
    final wasDetecting = _isDetecting;

    if (wasDetecting) {
      // stop detection which will stop image stream and backend threads
      _stopDetection();
    }

    // Force cleanup of all camera resources
    await _disposeControllerSafely();

    // Reset camera state
    setState(() {
      _isCameraInitialized = false;
      _statusText = 'Reinitializing camera after restart...';
      _isSwitching = false;
    });

    // Reinitialize camera after a longer delay on Android to prevent observer issues
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      await _initializeCamera();

      // Restart detection if it was running before reload
      if (wasDetecting && _isCameraInitialized) {
        await Future.delayed(const Duration(milliseconds: 250));
        _startDetection();
      }
    }
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
        // Ensure current index is valid. Do not auto-change the selected camera
        // here — automatic selection interferes with manual switching. Keep the
        // previously chosen index when re-initializing.
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

    if (_isSwitching) return;
    setState(() {
      _isSwitching = true;
    });

    // If detection is running, stop it and remember to restart after switching
    final wasDetecting = _isDetecting;
    if (wasDetecting) {
      _stopDetection();
    }

    // Hide the preview while switching to avoid using a disposed controller
    setState(() {
      _isCameraInitialized = false;
      _statusText = 'Switching camera...';
    });

    // Stop any active image stream and dispose the controller safely
    await _disposeControllerSafely();

    // Cycle to next camera and reinitialize
    _currentCameraIndex = (_currentCameraIndex + 1) % cameras!.length;
    await _initializeCamera(); // Small delay to ensure new controller is ready before restarting streams
    if (wasDetecting) {
      await Future.delayed(const Duration(milliseconds: 250));
      _startDetection();
    }
    setState(() {
      _isSwitching = false;
    });
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

  String _getBackendStatusText() {
    if (_networkStats.isEmpty) return "Backend Status: Unknown";

    final isHealthy = _networkStats['isServerHealthy'] ?? true;
    return isHealthy ? "Backend: Online" : "Backend: Offline";
  }

  Color _getBackendStatusColor() {
    if (_networkStats.isEmpty) return Colors.grey;

    final isHealthy = _networkStats['isServerHealthy'] ?? true;
    return isHealthy ? Colors.green : Colors.red;
  }

  /// Calculate the actual capture size that matches backend processing
  /// The backend center-crops the image to a square based on the smaller dimension
  double _getActualCaptureSize(BuildContext context) {
    if (!_isCameraInitialized || _controller == null) {
      // Fallback to 75% of screen width when camera not ready
      return MediaQuery.of(context).size.width * 0.75;
    }

    final screenSize = MediaQuery.of(context).size;
    final cameraAspectRatio = _controller!.value.aspectRatio;

    // Calculate how the camera preview is displayed on screen
    // The CameraPreview widget fills the available space while maintaining aspect ratio
    double previewWidth, previewHeight;

    // Determine the actual preview size based on how Flutter's CameraPreview scales
    if (cameraAspectRatio > (screenSize.width / screenSize.height)) {
      // Camera is wider - preview fills height, width extends beyond screen
      previewHeight = screenSize.height;
      previewWidth = screenSize.height * cameraAspectRatio;
    } else {
      // Camera is taller - preview fills width, height extends beyond screen
      previewWidth = screenSize.width;
      previewHeight = screenSize.width / cameraAspectRatio;
    }

    // The backend processing does:
    // 1. Takes the camera image (which has the original camera resolution)
    // 2. Rotates it -90 degrees (so width/height swap)
    // 3. Center-crops to a square using the smaller dimension
    // 4. Resizes to 200x200

    // Since we're showing the preview, we need to calculate what portion
    // of the preview corresponds to the center-cropped square
    final double captureSize = math.min(previewWidth, previewHeight);

    // Scale down slightly to account for the fact that we want to show
    // a more conservative area that will definitely be captured
    final double displaySize = captureSize * 0.8;

    // Ensure the size is reasonable for display
    final double minSize = screenSize.width * 0.4;
    final double maxSize = screenSize.width * 0.85;

    return displaySize.clamp(minSize, maxSize);
  }

  @override
  Widget build(BuildContext context) {
    // Calculate some layout metrics so we can nudge the camera preview up
    final screenHeight = MediaQuery.of(context).size.height;
    // Small negative top offset to lift the preview a little (adjustable)
    final cameraTopOffset = -screenHeight * 0.04; // move up 4% of screen
    // Reserve a smaller bottom panel so it doesn't cover too much of the preview
    final bottomPanelHeight = screenHeight * 0.32; // ~32% of screen height

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
        // Camera Preview (slightly lifted and stops above bottom panel)
        _isCameraInitialized
          ? Positioned(
            top: cameraTopOffset,
            left: 0,
            right: 0,
            bottom: bottomPanelHeight,
            child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(0),
                            child: CameraPreview(_controller!),
                          ),
                          // Detection area overlay - matches actual image processing area
                          Center(
                            child: Container(
                              width: _getActualCaptureSize(context),
                              height: _getActualCaptureSize(context),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.8),
                                  width: 3,
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Stack(
                                children: [
                                  // Corner indicators
                                  Positioned(
                                    top: -1,
                                    left: -1,
                                    child: Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          top: BorderSide(
                                            color: Colors.green.withOpacity(
                                              0.9,
                                            ),
                                            width: 4,
                                          ),
                                          left: BorderSide(
                                            color: Colors.green.withOpacity(
                                              0.9,
                                            ),
                                            width: 4,
                                          ),
                                        ),
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(20),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: -1,
                                    right: -1,
                                    child: Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          top: BorderSide(
                                            color: Colors.green.withOpacity(
                                              0.9,
                                            ),
                                            width: 4,
                                          ),
                                          right: BorderSide(
                                            color: Colors.green.withOpacity(
                                              0.9,
                                            ),
                                            width: 4,
                                          ),
                                        ),
                                        borderRadius: const BorderRadius.only(
                                          topRight: Radius.circular(20),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: -1,
                                    left: -1,
                                    child: Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Colors.green.withOpacity(
                                              0.9,
                                            ),
                                            width: 4,
                                          ),
                                          left: BorderSide(
                                            color: Colors.green.withOpacity(
                                              0.9,
                                            ),
                                            width: 4,
                                          ),
                                        ),
                                        borderRadius: const BorderRadius.only(
                                          bottomLeft: Radius.circular(20),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: -1,
                                    right: -1,
                                    child: Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Colors.green.withOpacity(
                                              0.9,
                                            ),
                                            width: 4,
                                          ),
                                          right: BorderSide(
                                            color: Colors.green.withOpacity(
                                              0.9,
                                            ),
                                            width: 4,
                                          ),
                                        ),
                                        borderRadius: const BorderRadius.only(
                                          bottomRight: Radius.circular(20),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Center instruction text
                                  Center(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.6),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Text(
                                        'Keep your hand\nin this area',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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
                          onPressed: (_isSwitching || !_isCameraInitialized)
                              ? null
                              : _switchCamera,
                          icon: const Icon(
                            Icons.flip_camera_ios,
                            color: Colors.white,
                            size: 24,
                          ),
                          tooltip: _isSwitching
                              ? 'Switching...'
                              : 'Switch Camera',
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

              // Bottom Panel with Controls and Results (constrained height)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: bottomPanelHeight,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        // Drag Handle
                        Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Control Buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isCameraInitialized && !_isDetecting
                                    ? _startDetection
                                    : null,
                                icon: const Icon(Icons.play_arrow, size: 22),
                                label: const Text(
                                  'Start Detection',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _isDetecting ? _stopDetection : null,
                                icon: const Icon(Icons.stop, size: 22),
                                label: const Text(
                                  'Stop',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
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

                        const SizedBox(height: 10),

                        // Assembled Text Display with collapsible panel (now scrollable)
                        if (_assembledText.isNotEmpty)
                          Flexible(
                            child: Container(
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
                                      padding: const EdgeInsets.all(12),
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
                                    Expanded(
                                      child: SingleChildScrollView(
                                        padding: const EdgeInsets.fromLTRB(
                                          12,
                                          0,
                                          12,
                                          12,
                                        ),
                                        child: Text(
                                          _assembledText,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),

                        // Simple Backend Status
                        if (_networkStats.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _getBackendStatusColor().withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _getBackendStatusColor().withOpacity(
                                  0.3,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: _getBackendStatusColor(),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _getBackendStatusText(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _getBackendStatusColor().withOpacity(
                                      0.8,
                                    ),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
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
