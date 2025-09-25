import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

import 'services/asl_detection_service.dart';
import 'models/asl_prediction.dart';
import 'widgets/hand_capture_widget.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _controller;
  List<CameraDescription>? cameras;
  bool _isCameraInitialized = false;
  bool _isPermissionGranted = false;
  String _translationText = "Sign language translation will appear here...";
  String _statusText = "Initializing camera...";
  int _currentCameraIndex = 0; // Track current camera (0 = back, 1 = front)

  // ASL Detection variables
  late ASLDetectionService _aslService;
  bool _isDetecting = false;
  // Using ML detection only (no toggle)
  String _currentPrediction = "";
  double _currentConfidence = 0.0;
  List<ASLPrediction> _detectionHistory = [];
  Timer? _detectionTimer;
  String _detectedSentence = "";
  CameraImage? _currentCameraImage; // Store current camera frame

  // Hand capture variables
  bool _isCapturing = false;
  Timer? _captureTimer;
  final GlobalKey<State<HandCaptureWidget>> _captureWidgetKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _aslService = ASLDetectionService.instance;
    _initializeASLService();
    _requestPermissions();
  }

  Future<void> _initializeASLService() async {
    try {
      final success = await _aslService.initialize();
      if (success) {
        setState(() {
          _statusText = "ASL detection service initialized (ML Kit mode).";
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
        // For first initialization, try to find front camera for ASL detection
        if (_currentCameraIndex == 0 && cameras!.length > 1) {
          for (int i = 0; i < cameras!.length; i++) {
            if (cameras![i].lensDirection == CameraLensDirection.front) {
              _currentCameraIndex = i;
              break;
            }
          }
        }

        // Ensure we don't go out of bounds
        if (_currentCameraIndex >= cameras!.length) {
          _currentCameraIndex = 0;
        }

        _controller?.dispose(); // Dispose previous controller if it exists
        _controller = CameraController(
          cameras![_currentCameraIndex], // Use the selected camera
          ResolutionPreset.medium,
        );

        await _controller!.initialize();
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
            final cameraType =
                cameras![_currentCameraIndex].lensDirection ==
                    CameraLensDirection.front
                ? "Front"
                : "Back";
            _statusText =
                "Camera ready ($cameraType). Tap Start to begin detection.";
          });
        }
      } else {
        setState(() {
          _statusText = "No cameras found on this device.";
        });
      }
    } catch (e) {
      print('Error initializing camera: $e');
      setState(() {
        _statusText = "Error initializing camera: $e";
      });
    }
  }

  Future<void> _switchCamera() async {
    if (cameras == null || cameras!.length <= 1) return;

    // Stop detection if running
    if (_isDetecting) {
      _stopDetection();
    }

    setState(() {
      _isCameraInitialized = false;
      _statusText = "Switching camera...";
    });

    // Switch to the next camera
    _currentCameraIndex = (_currentCameraIndex + 1) % cameras!.length;

    // Reinitialize with new camera
    await _initializeCamera();
  }

  void _startDetection() {
    if (!_isCameraInitialized || _isDetecting) return;

    setState(() {
      _isDetecting = true;
      _translationText =
          "🔍 Starting ASL detection...\nShow your hand signs to the camera.";
      _detectedSentence = "";
    });

    // Start camera image stream for real-time detection
    // If capture is already running, the stream is already started
    if (!_isCapturing) {
      _controller!.startImageStream((CameraImage image) {
        _currentCameraImage = image;
      });
    }

    _detectionTimer = Timer.periodic(
      const Duration(milliseconds: 1500), // Process every 1.5 seconds
      (timer) => _processGesture(),
    );
  }

  void _stopDetection() {
    setState(() {
      _isDetecting = false;
      _translationText =
          "ASL detection stopped.\n\nDetected sentence: $_detectedSentence";
    });
    _detectionTimer?.cancel();
    _detectionTimer = null;

    // Stop camera image stream only if capture is not running
    if (!_isCapturing) {
      _controller!.stopImageStream();
      _currentCameraImage = null;
    }
  }

  Future<void> _processGesture() async {
    if (!_isDetecting) return;

    try {
      ASLPrediction? prediction;

      if (_controller != null && _currentCameraImage != null) {
        // Use real ML Kit detection with actual camera image
        try {
          prediction = await _aslService.detectGestureFromCamera(
            cameraImage: _currentCameraImage,
          );
        } catch (e) {
          print('❌ ML Kit detection failed: $e');
          setState(() {
            _translationText = "❌ Detection error. Please try again.";
          });
          return;
        }
      } else {
        // No camera image available
        print('⚠️ No camera image available for detection');
        return;
      }

      if (prediction != null && prediction.isHighConfidence) {
        setState(() {
          _currentPrediction = prediction!.letter;
          _currentConfidence = prediction.confidence;

          // Add to history
          _detectionHistory.add(prediction);

          // Update detected sentence (simple concatenation for now)
          if (_detectedSentence.isEmpty ||
              _detectedSentence[_detectedSentence.length - 1] !=
                  prediction.letter) {
            _detectedSentence += prediction.letter;
          }

          // Update translation text
          _translationText =
              "🎯 Current: ${prediction.letter}\n"
              "📈 Confidence: ${(prediction.confidence * 100).toStringAsFixed(1)}%\n"
              "📝 Sentence: $_detectedSentence\n"
              "🕒 Last detected: ${prediction.timestamp.toString().substring(11, 19)}";
        });
      }
    } catch (e) {
      print('Error processing gesture: $e');
    }
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _captureTimer?.cancel();
    _controller?.dispose();
    _aslService.dispose();
    super.dispose();
  }

  void _startCapture() {
    if (!_isCameraInitialized) return;

    setState(() {
      _isCapturing = true;
    });

    // Start camera image stream if not already running (detection might not be active)
    if (!_isDetecting && _controller != null) {
      _controller!.startImageStream((CameraImage image) {
        _currentCameraImage = image;
      });
    }

    // Capture landmarks every 200ms while capturing
    _captureTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (timer) => _captureLandmarks(),
    );
  }

  void _stopCapture() {
    setState(() {
      _isCapturing = false;
    });

    _captureTimer?.cancel();
    _captureTimer = null;

    // Stop camera image stream if detection is not running
    if (!_isDetecting && _controller != null) {
      _controller!.stopImageStream();
      _currentCameraImage = null;
    }
  }

  Future<void> _captureLandmarks() async {
    if (!_isCapturing || _currentCameraImage == null) return;

    try {
      final landmarks = await _aslService.getLandmarkVector(
        cameraImage: _currentCameraImage,
      );

      if (landmarks != null && landmarks.isNotEmpty) {
        // Send landmarks to capture widget
        final widgetState = _captureWidgetKey.currentState;
        if (widgetState != null) {
          (widgetState as dynamic).processLandmarks(landmarks);
        }
      }
    } catch (e) {
      print('Error capturing landmarks: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // UI-only changes: more polished header, glass card, floating controls, and animated translation area.
    return Scaffold(

      extendBody: true, // Extend body behind bottom navigation
      extendBodyBehindAppBar: true, // Extend body behind app bar
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.white, Color(0xFFF8F9FA)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: _buildContent(),
          ),
          // Header Section
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(
                top: 30,
                left: 20,
                right: 20,
                bottom: 10,
              ),

              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFEFF7FF), Color(0xFFF7FBFF)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),

                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '📷 ASL Camera',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black26,
                                    offset: Offset(0, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _isDetecting
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isDetecting
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _isDetecting
                                        ? 'Detection Active'
                                        : 'Ready to Detect',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isDetecting
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isDetecting ? 'ON' : 'OFF',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],

                        ),
                        child: const Icon(Icons.info_outline, color: Colors.black54, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),


  Widget _buildContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final cameraHeight =
            height * 0.50; // Reduced to fit content without scrolling

        return ConstrainedBox(
          constraints: BoxConstraints(minHeight: height),
          child: Column(
            children: [
              SizedBox(
                height: cameraHeight,
                child: Container(
                  margin: const EdgeInsets.only(
                    top: 130,
                    left: 16,
                    right: 16,
                    bottom: 16,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      color: Colors.black,
                      child: _isPermissionGranted
                          ? (_isCameraInitialized && _controller != null
                                ? Stack(
                                    children: [
                                      CameraPreview(_controller!),
                                      // Camera overlay with detection frame
                                      if (_isDetecting)
                                        Container(
                                          margin: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.green.withOpacity(
                                                0.9,
                                              ),
                                              width: 4,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.green.withOpacity(
                                                  0.3,
                                                ),
                                                blurRadius: 8,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                        ),
                                      // Camera switch button
                                      Positioned(
                                        top: 20,
                                        right: 20,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(
                                              0.7,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(
                                                0.4,
                                              ),
                                              width: 1.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.3,
                                                ),
                                                blurRadius: 8,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.flip_camera_android,
                                              color: Colors.white,
                                              size: 22,
                                            ),
                                            onPressed:
                                                (cameras != null &&
                                                    cameras!.length > 1)
                                                ? _switchCamera
                                                : null,
                                            padding: const EdgeInsets.all(10),
                                            tooltip: 'Switch Camera',
                                          ),
                                        ),
                                      ),
                                      // Detection status overlay
                                      if (_isDetecting)
                                        Positioned(
                                          bottom: 20,
                                          left: 20,
                                          right: 20,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(
                                                0.8,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: Colors.green.withOpacity(
                                                  0.5,
                                                ),
                                                width: 1,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.3),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Container(
                                                  width: 10,
                                                  height: 10,
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: Colors.green,
                                                        shape: BoxShape.circle,
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.green,
                                                            blurRadius: 6,
                                                            spreadRadius: 1,
                                                          ),
                                                        ],
                                                      ),
                                                ),
                                                const SizedBox(width: 10),
                                                const Text(
                                                  '🔍 Detecting Signs...',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  )
                                : Center(
                                    child: SingleChildScrollView(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 20,
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(
                                                  0.15,
                                                ),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white
                                                      .withOpacity(0.3),
                                                  width: 2,
                                                ),
                                              ),
                                              child:
                                                  const CircularProgressIndicator(
                                                    color: Colors.white,
                                                    strokeWidth: 3,
                                                  ),
                                            ),
                                            const SizedBox(height: 12),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 8,
                                                  ),
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 20,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(
                                                  0.6,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                _statusText,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ))
                          : Center(
                              child: SingleChildScrollView(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 20,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.15),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white.withOpacity(
                                              0.3,
                                            ),
                                            width: 2,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.camera_alt,
                                          color: Colors.white,
                                          size: 32,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.6),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          _statusText,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton.icon(
                                        onPressed: _requestPermissions,
                                        icon: const Icon(
                                          Icons.camera,
                                          size: 18,
                                        ),
                                        label: const Text(
                                          'Grant Camera Access',
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF4facfe,
                                          ),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 10,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          elevation: 4,
                                          shadowColor: const Color(
                                            0xFF4facfe,
                                          ).withOpacity(0.3),
                                          textStyle: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),

              // Control Panel
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4facfe).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFF4facfe).withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.translate,
                              color: Color(0xFF4facfe),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Text(
                            'Translation Results',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        height: 140,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.grey[200]!,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: SingleChildScrollView(
                          child: Text(
                            _translationText,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),

                      // Current prediction display
                      if (_currentPrediction.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(top: 20),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4facfe).withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '🤟 $_currentPrediction',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black26,
                                      offset: Offset(0, 2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _currentConfidence > 0.8
                                      ? Colors.white.withOpacity(0.25)
                                      : Colors.white.withOpacity(0.35),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.4),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '${(_currentConfidence * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 24),

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
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 6,
                                shadowColor: Colors.green.withOpacity(0.4),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isDetecting ? _stopDetection : null,
                              icon: const Icon(Icons.stop, size: 20),
                              label: const Text('Stop'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 6,
                                shadowColor: Colors.red.withOpacity(0.4),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Clear sentence button
                      // if (_detectedSentence.isNotEmpty)
                      //   Container(
                      //     margin: const EdgeInsets.only(top: 12),
                      //     child: ElevatedButton.icon(
                      //       onPressed: () {
                      //         setState(() {
                      //           _detectedSentence = "";
                      //           _detectionHistory.clear();
                      //           _currentPrediction = "";
                      //           _translationText = _isDetecting
                      //               ? "🔍 Detection active...\nShow your hand signs to the camera."
                      //               : "Sign language translation will appear here...";
                      //         });
                      //       },
                      //       icon: const Icon(Icons.clear),
                      //       label: const Text('Clear Sentence'),
                      //       style: ElevatedButton.styleFrom(
                      //         backgroundColor: Colors.grey,
                      //         foregroundColor: Colors.white,
                      //         padding: const EdgeInsets.symmetric(vertical: 12),
                      //         shape: RoundedRectangleBorder(
                      //           borderRadius: BorderRadius.circular(12),
                      //         ),
                      //         elevation: 2,
                      //       ),
                      //     ),
                      //   ),

                      // // Hand Capture Widget
                      // const SizedBox(height: 20),
                      // HandCaptureWidget(
                      //   key: _captureWidgetKey,
                      //   isCapturing: _isCapturing,
                      //   onStartCapture: _startCapture,
                      //   onStopCapture: _stopCapture,
                      // ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },

    );
  }
}
