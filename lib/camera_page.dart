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
    _controller!.startImageStream((CameraImage image) {
      _currentCameraImage = image;
    });

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

    // Stop camera image stream
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
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxHeight;
            final cameraHeight = height * 0.6; // 60% for camera preview

            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: height),
                child: Column(
                  children: [
                    SizedBox(
                      height: cameraHeight,
                      child: Container(
                        color: Colors.black,
                        child: _isPermissionGranted
                            ? (_isCameraInitialized && _controller != null
                                  ? Stack(
                                      children: [
                                        CameraPreview(_controller!),
                                        // Camera switch button
                                        Positioned(
                                          top: 40,
                                          right: 16,
                                          child: FloatingActionButton(
                                            mini: true,
                                            onPressed:
                                                (cameras != null &&
                                                    cameras!.length > 1)
                                                ? _switchCamera
                                                : null,
                                            backgroundColor: Colors.black54,
                                            child: const Icon(
                                              Icons.flip_camera_android,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const CircularProgressIndicator(
                                            color: Colors.white,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            _statusText,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ))
                            : Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                      size: 64,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _statusText,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton(
                                      onPressed: _requestPermissions,
                                      child: const Text('Grant Permissions'),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),

                    Container(
                      padding: const EdgeInsets.all(16.0),
                      color: Colors.white,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Sign Language Translation',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 160,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: SingleChildScrollView(
                                child: Text(
                                  _translationText,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const SizedBox(height: 16),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton.icon(
                                onPressed: _isCameraInitialized && !_isDetecting
                                    ? _startDetection
                                    : null,
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Start Detection'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: _isDetecting ? _stopDetection : null,
                                icon: const Icon(Icons.stop),
                                label: const Text('Stop Detection'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Detection status indicator
                          if (_isDetecting)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Detecting...',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),

                          // Current prediction display
                          if (_currentPrediction.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '🤟 $_currentPrediction',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _currentConfidence > 0.8
                                          ? Colors.green
                                          : Colors.orange,
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

                          // Clear sentence button
                          if (_detectedSentence.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _detectedSentence = "";
                                    _detectionHistory.clear();
                                    _currentPrediction = "";
                                    _translationText = _isDetecting
                                        ? "🔍 Detection active...\nShow your hand signs to the camera."
                                        : "Sign language translation will appear here...";
                                  });
                                },
                                icon: const Icon(Icons.clear),
                                label: const Text('Clear Sentence'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),

                          // Hand Capture Widget
                          HandCaptureWidget(
                            key: _captureWidgetKey,
                            isCapturing: _isCapturing,
                            onStartCapture: _startCapture,
                            onStopCapture: _stopCapture,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

