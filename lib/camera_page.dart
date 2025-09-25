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
    // UI-only changes: more polished header, glass card, floating controls, and animated translation area.
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      extendBody: true,
      extendBodyBehindAppBar: true,
      body: SafeArea(
        child: Stack(
          children: [
            // Background gradient
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFEFF7FF), Color(0xFFF7FBFF)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),

            // Top header (glassmorphism)
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: const Icon(Icons.camera, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ASL Live Studio',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _statusText,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black.withOpacity(0.6),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        // purely visual; no logic change
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.info_outline, color: Colors.black54, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Main content
            Positioned.fill(
              top: 86,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                child: Column(
                  children: [
                    // Camera card
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.14),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                        border: Border.all(color: Colors.black.withOpacity(0.12)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Stack(
                            children: [
                              // Camera preview or placeholder
                              Positioned.fill(
                                child: _isPermissionGranted
                                    ? (_isCameraInitialized && _controller != null
                                        ? CameraPreview(_controller!)
                                        : Container(
                                            color: Colors.black,
                                            child: Center(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const CircularProgressIndicator(color: Colors.white),
                                                  const SizedBox(height: 12),
                                                  Text(_statusText, style: const TextStyle(color: Colors.white)),
                                                ],
                                              ),
                                            ),
                                          ))
                                    : Container(
                                        color: Colors.black,
                                        child: Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.camera_alt, color: Colors.white70, size: 48),
                                              const SizedBox(height: 12),
                                              Text(_statusText, style: const TextStyle(color: Colors.white70)),
                                              const SizedBox(height: 12),
                                              ElevatedButton.icon(
                                                onPressed: _requestPermissions,
                                                icon: const Icon(Icons.camera),
                                                label: const Text('Grant Camera Access'),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF4facfe),
                                                  foregroundColor: Colors.white,
                                                  elevation: 6,
                                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                              ),

                              // detection frame overlay
                              if (_isDetecting)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.greenAccent.withOpacity(0.9), width: 3),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                ),

                              // Top-right camera switch
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Material(
                                  color: Colors.black.withOpacity(0.36),
                                  borderRadius: BorderRadius.circular(12),
                                  child: IconButton(
                                    icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
                                    onPressed: (cameras != null && cameras!.length > 1) ? _switchCamera : null,
                                    tooltip: 'Switch Camera',
                                  ),
                                ),
                              ),

                              // bottom status banner on preview
                              if (_isDetecting)
                                Positioned(
                                  bottom: 12,
                                  left: 12,
                                  right: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                                        ),
                                        const SizedBox(width: 10),
                                        const Text('Live Detection', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                        const SizedBox(width: 12),
                                        if (_currentPrediction.isNotEmpty)
                                          Flexible(
                                            child: Text(
                                              ' • ${_currentPrediction} ${( _currentConfidence * 100).toStringAsFixed(0)}%',
                                              style: const TextStyle(color: Colors.white70),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Control pill (Start / Stop / Capture) floating style
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 6))
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _isCameraInitialized && !_isDetecting ? _startDetection : null,
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('Start'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _isDetecting ? _stopDetection : null,
                                  icon: const Icon(Icons.stop),
                                  label: const Text('Stop'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isCapturing ? _stopCapture : _startCapture,
                                  icon: Icon(_isCapturing ? Icons.pause : Icons.camera_alt),
                                  label: Text(_isCapturing ? 'Stop Capture' : 'Start Capture'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.history, size: 18, color: Colors.black54),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Detected: ${_detectedSentence.isEmpty ? "—" : _detectedSentence}',
                                      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                                    )
                                  ],
                                ),
                              )
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Translation & prediction card (animated)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFFFFFFF), Color(0xFFF7FBFF)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 14, offset: const Offset(0, 8))
                        ],
                        border: Border.all(color: Colors.grey.withOpacity(0.08)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4facfe).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.translate, color: Color(0xFF4facfe)),
                              ),
                              const SizedBox(width: 12),
                              const Text('Translation & Prediction', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                              const Spacer(),
                              if (_currentPrediction.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Text('$_currentPrediction', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                                      const SizedBox(width: 8),
                                      Text('${(_currentConfidence * 100).toStringAsFixed(0)}%', style: const TextStyle(color: Colors.black54)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.all(12),
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: SingleChildScrollView(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                child: Text(
                                  _translationText,
                                  key: ValueKey(_translationText),
                                  style: const TextStyle(fontSize: 15, height: 1.4, color: Colors.black87),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // HandCaptureWidget kept intact (UI only)
                          HandCaptureWidget(
                            key: _captureWidgetKey,
                            isCapturing: _isCapturing,
                            onStartCapture: _startCapture,
                            onStopCapture: _stopCapture,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
