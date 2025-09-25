import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:camera/camera.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/hand_landmark_processor.dart';
import '../utils/camera_stream_processor.dart';
import '../utils/gesture_stabilizer.dart';
import '../utils/word_recognizer.dart';
import '../models/asl_prediction.dart';
import 'asl_backend_service.dart';

/// Detection modes for ASL service
enum ASLDetectionMode {
  localMLKit, // Use local ML Kit processing
  backendAPI, // Use backend API for predictions
  hybrid, // Try backend first, fallback to local
}

class ASLDetectionServiceV2 {
  static ASLDetectionServiceV2? _instance;
  static ASLDetectionServiceV2 get instance {
    _instance ??= ASLDetectionServiceV2._();
    return _instance!;
  }

  ASLDetectionServiceV2._();

  // Local ML Kit components
  PoseDetector? _poseDetector;
  HandLandmarkProcessor? _landmarkProcessor;
  CameraStreamProcessor? _streamProcessor;
  GestureStabilizer? _gestureStabilizer;
  WordRecognizer? _wordRecognizer;
  List<String> _labels = [];
  bool _isInitialized = false;
  bool _useStreamProcessing = false;

  // Backend service
  late ASLBackendService _backendService;
  bool _isBackendAvailable = false;
  ASLDetectionMode _detectionMode = ASLDetectionMode.hybrid;

  // Configuration
  static const String labelsPath = 'assets/models/labels.txt';
  static const double confidenceThreshold = 0.6;

  /// Initialize the enhanced ASL detection service
  Future<bool> initialize({
    bool useStreamProcessing = false,
    ASLDetectionMode mode = ASLDetectionMode.hybrid,
  }) async {
    if (_isInitialized) return true;

    try {
      _useStreamProcessing = useStreamProcessing;
      _detectionMode = mode;

      // Initialize backend service
      _backendService = ASLBackendService.instance;
      final backendUrl =
          dotenv.env['ASL_BACKEND_URL'] ??
          dotenv.env['BACKEND_URL'] ??
          'http://localhost:5000';
      _backendService.initialize(baseUrl: backendUrl);

      // Check backend availability
      _isBackendAvailable = await _backendService.checkHealth();
      print('🌐 Backend availability: $_isBackendAvailable');

      // Initialize local ML Kit if needed
      if (_detectionMode == ASLDetectionMode.localMLKit ||
          _detectionMode == ASLDetectionMode.hybrid ||
          !_isBackendAvailable) {
        await _initializeMLKit();
      }

      // Initialize Phase 3 components if enabled
      if (_useStreamProcessing) {
        _streamProcessor = CameraStreamProcessor();
        _gestureStabilizer = GestureStabilizer();
        _wordRecognizer = WordRecognizer();
        print('✅ Phase 3 components initialized');
      }

      _isInitialized = true;
      final modeStr = _detectionMode.toString().split('.').last;
      print('✅ Enhanced ASL Detection Service initialized (Mode: $modeStr)');
      return true;
    } catch (e) {
      print('❌ Error initializing Enhanced ASL Detection Service: $e');
      return false;
    }
  }

  /// Initialize local ML Kit components
  Future<void> _initializeMLKit() async {
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
    );
    _landmarkProcessor = HandLandmarkProcessor();
    print('✅ ML Kit pose detector initialized');

    // Try to load labels
    try {
      final labelsString = await rootBundle.loadString(labelsPath);
      _labels = labelsString
          .split('\n')
          .where((label) => label.isNotEmpty)
          .toList();
      print('✅ Labels loaded: ${_labels.length} classes');
    } catch (e) {
      _labels = ['A', 'B', 'C', 'D', 'L', 'V', 'Y'];
      print('⚠️ Using default labels: $e');
    }
  }

  /// Detect ASL gesture using the configured detection mode
  Future<ASLPrediction?> detectGesture({CameraImage? cameraImage}) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (cameraImage == null) {
      print('❌ No camera image provided for detection');
      return null;
    }

    try {
      ASLPrediction? prediction;

      switch (_detectionMode) {
        case ASLDetectionMode.backendAPI:
          prediction = await _detectUsingBackend(cameraImage);
          break;

        case ASLDetectionMode.localMLKit:
          prediction = await _detectUsingMLKit(cameraImage);
          break;

        case ASLDetectionMode.hybrid:
          // Try backend first, fallback to local
          if (_isBackendAvailable) {
            prediction = await _detectUsingBackend(cameraImage);
            if (prediction == null) {
              print(
                '⚠️ Backend detection failed, falling back to local ML Kit',
              );
              prediction = await _detectUsingMLKit(cameraImage);
            }
          } else {
            prediction = await _detectUsingMLKit(cameraImage);
          }
          break;
      }

      return prediction;
    } catch (e) {
      print('❌ Error in gesture detection: $e');
      return null;
    }
  }

  /// Detect using backend API
  Future<ASLPrediction?> _detectUsingBackend(CameraImage cameraImage) async {
    try {
      final prediction = await _backendService.predictFromCameraImage(
        cameraImage,
      );
      if (prediction != null) {
        print(
          '🌐 Backend prediction: ${prediction.letter} (${(prediction.confidence * 100).toStringAsFixed(1)}%)',
        );
      }
      return prediction;
    } catch (e) {
      print('❌ Backend detection error: $e');
      // Mark backend as unavailable for future requests
      _isBackendAvailable = false;
      return null;
    }
  }

  /// Detect using local ML Kit
  Future<ASLPrediction?> _detectUsingMLKit(CameraImage cameraImage) async {
    if (_poseDetector == null || _landmarkProcessor == null) {
      print('❌ ML Kit components not initialized');
      return null;
    }

    try {
      // Convert camera image to InputImage
      final inputImage = _convertCameraImageToInputImage(cameraImage);
      if (inputImage == null) {
        print('❌ Failed to convert camera image to InputImage');
        return null;
      }

      // Detect poses
      final poses = await _poseDetector!.processImage(inputImage);
      if (poses.isEmpty) return null;

      // Process the first detected pose
      final pose = poses.first;
      final landmarkVector = _landmarkProcessor!.extractHandLandmarkVector(
        pose,
      );

      if (landmarkVector.isEmpty) {
        return null;
      }

      // Use rule-based recognition for now
      final landmarks = _landmarkProcessor!.extractHandLandmarksFromPose(pose);

      if (landmarks.isEmpty) {
        return null;
      }

      // Recognize gesture using the landmarks
      final prediction = _landmarkProcessor!.recognizeGesture(landmarks);

      if (prediction != null && prediction.confidence > confidenceThreshold) {
        print(
          '🤖 Local ML Kit prediction: ${prediction.letter} (${(prediction.confidence * 100).toStringAsFixed(1)}%)',
        );
        return prediction;
      }

      return null;
    } catch (e) {
      print('❌ ML Kit detection error: $e');
      return null;
    }
  }

  /// Convert CameraImage to InputImage for ML Kit
  InputImage? _convertCameraImageToInputImage(CameraImage cameraImage) {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in cameraImage.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final imageSize = Size(
        cameraImage.width.toDouble(),
        cameraImage.height.toDouble(),
      );

      // Use a default rotation (this could be improved with actual device orientation)
      const inputImageRotation = InputImageRotation.rotation0deg;

      final inputImageFormat = InputImageFormatValue.fromRawValue(
        cameraImage.format.raw,
      );
      if (inputImageFormat == null) return null;

      final inputImageMetadata = InputImageMetadata(
        size: imageSize,
        rotation: inputImageRotation,
        format: inputImageFormat,
        bytesPerRow: cameraImage.planes.first.bytesPerRow,
      );

      return InputImage.fromBytes(bytes: bytes, metadata: inputImageMetadata);
    } catch (e) {
      print('Error converting camera image: $e');
      return null;
    }
  }

  /// Switch detection mode at runtime
  Future<void> switchDetectionMode(ASLDetectionMode newMode) async {
    if (newMode == _detectionMode) return;

    _detectionMode = newMode;
    print(
      '🔄 Switched to detection mode: ${newMode.toString().split('.').last}',
    );

    // Check backend availability if switching to backend mode
    if (newMode == ASLDetectionMode.backendAPI ||
        newMode == ASLDetectionMode.hybrid) {
      _isBackendAvailable = await _backendService.checkHealth();
      print('🌐 Backend availability check: $_isBackendAvailable');
    }
  }

  /// Get backend assembled text (for session-based text building)
  String get backendAssembledText => _backendService.assembledText;

  /// Clear backend session
  void clearBackendSession() {
    _backendService.clearSession();
  }

  /// Get service status
  Future<Map<String, dynamic>> getServiceStatus() async {
    final backendStatus = await _backendService.getStatus();

    return {
      'is_initialized': _isInitialized,
      'detection_mode': _detectionMode.toString().split('.').last,
      'ml_kit_available': _poseDetector != null,
      'backend_available': _isBackendAvailable,
      'backend_status': backendStatus,
      'use_stream_processing': _useStreamProcessing,
    };
  }

  /// Phase 3: Advanced ASL detection with stream processing and stabilization
  Future<ASLPrediction?> detectWithAdvancedProcessing(CameraImage image) async {
    if (!_isInitialized || !_useStreamProcessing) {
      throw Exception('Phase 3 components not initialized');
    }

    try {
      // Process with configured detection method
      final prediction = await detectGesture(cameraImage: image);
      if (prediction == null) return null;

      // Apply gesture stabilization to reduce jitter
      final stabilizedPrediction = _gestureStabilizer!.addPrediction(
        prediction,
      );
      if (stabilizedPrediction == null) {
        return null; // Prediction not stable enough yet
      }

      // Add letter to word recognizer for word detection
      _wordRecognizer!.addLetter(stabilizedPrediction.letter);

      return stabilizedPrediction;
    } catch (e) {
      print('❌ Error in advanced ASL detection: $e');
      return null;
    }
  }

  /// Get available gesture labels
  List<String> get availableGestures => List.from(_labels);

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Get current detection mode
  ASLDetectionMode get detectionMode => _detectionMode;

  /// Check if backend is available
  bool get isBackendAvailable => _isBackendAvailable;

  /// Start stream processing (Phase 3)
  Future<void> startStreamProcessing(CameraController controller) async {
    if (!_useStreamProcessing || _streamProcessor == null) {
      throw Exception(
        'Stream processing not enabled or components not initialized',
      );
    }

    await _streamProcessor!.initialize();
    await _streamProcessor!.startProcessing(controller);
    print('🎥 Phase 3 stream processing started');
  }

  /// Stop stream processing (Phase 3)
  Future<void> stopStreamProcessing(CameraController controller) async {
    if (_streamProcessor != null) {
      await _streamProcessor!.stopProcessing(controller);
      print('⏹️ Phase 3 stream processing stopped');
    }
  }

  /// Check if ML model is available
  bool get hasMLModel => _poseDetector != null;

  /// Dispose resources
  void dispose() {
    _poseDetector?.close();
    _isInitialized = false;
    print('🧹 Enhanced ASL Detection Service disposed');
  }
}
