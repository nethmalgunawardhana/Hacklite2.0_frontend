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
  bool _isSwitching = false;

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
    try {
      if (_isDetecting) {
        _stopDetection();
      }

      _predictionSubscription?.cancel();
      _assembledTextSubscription?.cancel();
      _networkStatsSubscription?.cancel();
      _networkStatsTimer?.cancel();

      _disposeControllerSafely();
      _aslService.dispose();
    } catch (e) {
      print('Warning: Dispose error (ignored): $e');
    } finally {
      super.dispose();
    }
  }

  Future<void> _disposeControllerSafely() async {
    if (_controller != null) {
      try {
        if (_controller!.value.isStreamingImages) {
          await _controller!.stopImageStream();
        }
      } catch (e) {
        print('Info: Image stream stop error (ignored): $e');
      }

      try {
        await Future.delayed(const Duration(milliseconds: 100));

        if (_controller != null && !_controller!.value.isInitialized) {
          _controller = null;
          return;
        }

        await _controller!.dispose();
      } catch (e) {
        print('Warning: Controller dispose error (ignored): $e');
      } finally {
        _controller = null;
      }
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleReassemble();
    });
  }

  Future<void> _handleReassemble() async {
    final wasDetecting = _isDetecting;

    try {
      if (wasDetecting) {
        _stopDetection();
      }

      _predictionSubscription?.cancel();
      _assembledTextSubscription?.cancel();
      _networkStatsSubscription?.cancel();
      _networkStatsTimer?.cancel();

      await _disposeControllerSafely();

      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
          _statusText = 'Reinitializing camera after restart...';
          _isSwitching = false;
          _currentPrediction = "";
          _currentConfidence = 0.0;
        });
      }

      await Future.delayed(const Duration(milliseconds: 1000));

      if (mounted) {
        await _initializeCamera();

        if (wasDetecting && _isCameraInitialized && mounted) {
          await Future.delayed(const Duration(milliseconds: 500));
          _startDetection();
        }
      }
    } catch (e) {
      print('Warning: Reassemble error (ignored): $e');
      if (mounted) {
        setState(() {
          _statusText = 'Camera reinitialization failed. Please restart app.';
        });
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
        // Set front camera as default if this is the first initialization
        if (_currentCameraIndex == 0 && !_isCameraInitialized) {
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
          ResolutionPreset.high,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.jpeg,
        );

        await _controller!.initialize();

        setState(() {
          _isCameraInitialized = true;
          final cameraDirection =
              cameras![_currentCameraIndex].lensDirection ==
                  CameraLensDirection.front
              ? "front"
              : "back";
          _statusText =
              "Camera initialized ($cameraDirection camera). Ready for ASL detection.";
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

    final wasDetecting = _isDetecting;
    if (wasDetecting) {
      _stopDetection();
    }

    setState(() {
      _isCameraInitialized = false;
      _statusText = 'Switching camera...';
    });

    await _disposeControllerSafely();

    _currentCameraIndex = (_currentCameraIndex + 1) % cameras!.length;
    await _initializeCamera();

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
    _aslService.clearAssembledText();
  }

  void _startDetection() async {
    if (!_isCameraInitialized || _isDetecting) return;

    _clearAssembledText();

    setState(() {
      _isDetecting = true;
      _currentPrediction = "";
      _currentConfidence = 0.0;
    });

    try {
      late StreamController<CameraImage> cameraStreamController;
      cameraStreamController = StreamController<CameraImage>.broadcast();

      await _controller!.startImageStream((CameraImage image) {
        cameraStreamController.add(image);
      });

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

      final success = await _aslService.startDetection(
        cameraStream: cameraStreamController.stream,
      );

      if (!success) {
        throw Exception('Failed to start backend detection');
      }

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

  Color _getBackendStatusColor() {
    if (_networkStats.isEmpty) return Colors.grey;
    final isHealthy = _networkStats['isServerHealthy'] ?? true;
    return isHealthy ? Colors.green : Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      body: SafeArea(
        child: Stack(
          children: [
            // Main content column
            Column(
              children: [
                // Header
                Container(
                  height: 80,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'ASL Detection',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      // Backend status indicator (compact)
                      if (_networkStats.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getBackendStatusColor().withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.circle,
                                size: 8,
                                color: _getBackendStatusColor(),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _networkStats['isServerHealthy'] == true
                                    ? 'Online'
                                    : 'Offline',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(width: 8),
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
                      if (cameras != null && cameras!.length > 1)
                        IconButton(
                          onPressed: (_isSwitching || !_isCameraInitialized)
                              ? null
                              : _switchCamera,
                          icon: Icon(
                            Icons.flip_camera_ios,
                            color: (_isSwitching || !_isCameraInitialized)
                                ? Colors.white54
                                : Colors.white,
                            size: 24,
                          ),
                          tooltip: _isSwitching
                              ? 'Switching...'
                              : 'Switch Camera',
                        ),
                    ],
                  ),
                ),

                // Camera Preview Area
                Expanded(
                  flex: 1,
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: _isCameraInitialized
                          ? Stack(
                              children: [
                                // Camera Preview
                                Positioned.fill(
                                  child: FittedBox(
                                    fit: BoxFit.cover,
                                    child: SizedBox(
                                      width: _controller!
                                          .value
                                          .previewSize!
                                          .height,
                                      height:
                                          _controller!.value.previewSize!.width,
                                      child: CameraPreview(_controller!),
                                    ),
                                  ),
                                ),

                                // Detection area overlay
                                Center(
                                  child: Container(
                                    width: screenWidth * 0.65,
                                    height: screenWidth * 0.65,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.9),
                                        width: 3,
                                      ),
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                    child: Stack(
                                      children: [
                                        // Corner indicators removed to clean up camera view
                                        // _buildCornerIndicator(Alignment.topLeft),
                                        // _buildCornerIndicator(Alignment.topRight),
                                        // _buildCornerIndicator(Alignment.bottomLeft),
                                        // _buildCornerIndicator(Alignment.bottomRight),

                                        // Center instruction
                                        Center(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(
                                                0.7,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Text(
                                              'Keep your hand\nin this area',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Live prediction overlay - compact corner display
                                if (_isDetecting &&
                                    _currentPrediction.isNotEmpty)
                                  Positioned(
                                    top: 15,
                                    left: 15,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.7),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.green.withOpacity(0.6),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _currentPrediction.toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${(_currentConfidence * 100).toStringAsFixed(0)}%',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                // Detection status indicator
                                if (_isDetecting)
                                  Positioned(
                                    top: 20,
                                    right: 20,
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
                                          SizedBox(width: 6),
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

                                // Toggle Button - Bottom left corner of camera area
                                Positioned(
                                  bottom: 15,
                                  left: 15,
                                  child: Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: _isDetecting
                                          ? Colors.red
                                          : Colors.green,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              (_isDetecting
                                                      ? Colors.red
                                                      : Colors.green)
                                                  .withOpacity(0.2),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(25),
                                        onTap: _isCameraInitialized
                                            ? (_isDetecting
                                                  ? _stopDetection
                                                  : _startDetection)
                                            : null,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: _isCameraInitialized
                                                  ? Colors.white
                                                  : Colors.white.withOpacity(
                                                      0.5,
                                                    ),
                                              width: 2,
                                            ),
                                          ),
                                          child: Icon(
                                            _isDetecting
                                                ? Icons.stop
                                                : Icons.play_arrow,
                                            color: _isCameraInitialized
                                                ? Colors.white
                                                : Colors.white.withOpacity(0.5),
                                            size: 24,
                                          ),
                                        ),
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
                                      'Initializing Camera...',
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
                    ),
                  ),
                ),

                // Status message
                if (_statusText.isNotEmpty && !_isCameraInitialized)
                  Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _statusText,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Bottom Panel: show expanded panel only when we have assembled text,
                // otherwise show a compact control bar to avoid empty white space.
                _assembledText.isNotEmpty
                    ? Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(25),
                            topRight: Radius.circular(25),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, -5),
                            ),
                          ],
                        ),
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
                            const SizedBox(height: 20),

                            // Assembled Text Display (existing full panel)
                            Container(
                              width: double.infinity,
                              constraints: const BoxConstraints(maxHeight: 120),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
                                ),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header with clear button
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        const Text(
                                          'Translated Text:',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const Spacer(),
                                        GestureDetector(
                                          onTap: _clearAssembledText,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.clear, size: 16, color: Colors.white),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Clear',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Text content
                                  Expanded(
                                    child: SingleChildScrollView(
                                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                          ],
                        ),
                      )
                    : // Compact control bar when no translated text
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(25),
                            topRight: Radius.circular(25),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 10,
                              offset: const Offset(0, -3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // drag handle + hint
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'No translated text',
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),

                            // Small action area: keep a compact clear/controls area
                            Row(
                              children: [
                                // Small toggle hint (not functional when camera not ready)
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _isDetecting ? Colors.red : Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _isDetecting ? Icons.stop : Icons.play_arrow,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Small settings icon to match header options
                                GestureDetector(
                                  onTap: () => Navigator.pushNamed(context, '/settings'),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.settings, size: 18, color: Colors.black54),
                                  ),
                                ),
                              ],
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
}
