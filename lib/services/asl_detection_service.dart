import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:camera/camera.dart';
import '../utils/hand_landmark_processor.dart';
import '../utils/camera_stream_processor.dart';
import '../utils/gesture_stabilizer.dart';
import '../utils/word_recognizer.dart';
import '../models/asl_prediction.dart';
import 'landmark_storage.dart';
import 'knn_classifier.dart';

class ASLDetectionService {
  static ASLDetectionService? _instance;
  static ASLDetectionService get instance {
    _instance ??= ASLDetectionService._();
    return _instance!;
  }

  ASLDetectionService._();

  PoseDetector? _poseDetector;
  HandLandmarkProcessor? _landmarkProcessor;
  CameraStreamProcessor? _streamProcessor;
  GestureStabilizer? _gestureStabilizer;
  WordRecognizer? _wordRecognizer;
  List<String> _labels = [];
  bool _isInitialized = false;
  bool _useStreamProcessing = false; // Flag for Phase 3 stream processing

  // Configuration
  static const String labelsPath = 'assets/models/labels.txt';
  static const double confidenceThreshold = 0.6;

  /// Initialize the ASL detection service with ML Kit only
  Future<bool> initialize({bool useStreamProcessing = false}) async {
    if (_isInitialized) return true;

    try {
      _useStreamProcessing = useStreamProcessing;

      // Always initialize ML Kit pose detector (no mock mode)
      _poseDetector = PoseDetector(
        options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
      );
      _landmarkProcessor = HandLandmarkProcessor();
      print('✅ ML Kit pose detector initialized');

      // Initialize Phase 3 components if enabled
      if (_useStreamProcessing) {
        _streamProcessor = CameraStreamProcessor();
        _gestureStabilizer = GestureStabilizer();
        _wordRecognizer = WordRecognizer();
        print('✅ Phase 3 components initialized');
      }

      // Try to load labels (optional for now)
      try {
        final labelsString = await rootBundle.loadString(labelsPath);
        _labels = labelsString
            .split('\n')
            .where((label) => label.isNotEmpty)
            .toList();
        print('✅ Labels loaded: ${_labels.length} classes');
      } catch (e) {
        // Use default labels for rule-based detection
        _labels = ['A', 'B', 'C', 'D', 'L', 'V', 'Y'];
        print('⚠️ Labels file not found, using default labels: $e');
      }

      _isInitialized = true;
      final phase = _useStreamProcessing ? ' (Phase 3)' : '';
      print(
        '✅ ASL Detection Service initialized successfully (ML Kit mode$phase)',
      );
      return true;
    } catch (e) {
      print('❌ Error initializing ASL Detection Service: $e');
      return false;
    }
  }

  /// Detect ASL gesture from camera stream
  Future<ASLPrediction?> detectGestureFromCamera({
    CameraImage? cameraImage,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      if (cameraImage == null) {
        print('❌ No camera image provided for detection');
        return null;
      }

      // Use real ML Kit detection only
      return await _detectFromCameraImage(cameraImage);
    } catch (e) {
      print('❌ Error detecting gesture from camera: $e');
      return null;
    }
  }

  /// Detect from camera image using ML Kit
  Future<ASLPrediction?> _detectFromCameraImage(CameraImage cameraImage) async {
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
      final handLandmarks = _landmarkProcessor!.extractHandLandmarksFromPose(
        pose,
      );

      if (handLandmarks.isEmpty) return null;

      // Recognize gesture from landmarks
      return _landmarkProcessor!.recognizeGesture(handLandmarks);
    } catch (e) {
      print('❌ Error in ML Kit detection: $e');
      return null;
    }
  }

  /// Convert CameraImage to InputImage for ML Kit
  InputImage? _convertCameraImageToInputImage(CameraImage cameraImage) {
    try {
      // Simplified conversion - create InputImage from camera image
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in cameraImage.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize = Size(
        cameraImage.width.toDouble(),
        cameraImage.height.toDouble(),
      );

      // Determine rotation and format more carefully. Rotation is left as
      // rotation0deg here (device rotation should be handled by caller if
      // needed). The important fix is mapping the camera ImageFormatGroup to
      // the ML Kit InputImageFormat so ML Kit doesn't fail with
      // "ImageFormat is not supported".
      const InputImageRotation imageRotation = InputImageRotation.rotation0deg;

      InputImageFormat inputImageFormat;
      switch (cameraImage.format.group) {
        case ImageFormatGroup.yuv420:
          inputImageFormat = InputImageFormat.nv21;
          break;
        case ImageFormatGroup.bgra8888:
          inputImageFormat = InputImageFormat.bgra8888;
          break;
        default:
          inputImageFormat = InputImageFormat.nv21;
      }

      final inputImageMetadata = InputImageMetadata(
        size: imageSize,
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: cameraImage.planes.first.bytesPerRow,
      );

      return InputImage.fromBytes(bytes: bytes, metadata: inputImageMetadata);
    } catch (e) {
      print('Error converting camera image: $e');
      return null;
    }
  }

  /// Get hand landmarks as coordinate vector for k-NN training/inference
  Future<List<double>?> getLandmarkVector({CameraImage? cameraImage}) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      if (cameraImage == null) {
        print('❌ No camera image provided for landmark extraction');
        return null;
      }

      // Convert camera image to InputImage
      final inputImage = _convertCameraImageToInputImage(cameraImage);
      if (inputImage == null) {
        print('❌ Failed to convert camera image to InputImage');
        return null;
      }

      // Detect poses
      final poses = await _poseDetector!.processImage(inputImage);

      if (poses.isEmpty) return null;

      // Extract landmarks from the first detected pose
      final pose = poses.first;
      final landmarkVector = _landmarkProcessor!.extractHandLandmarkVector(
        pose,
      );

      return landmarkVector.isNotEmpty ? landmarkVector : null;
    } catch (e) {
      print('❌ Error extracting landmark vector: $e');
      return null;
    }
  }

  /// Process InputImage and detect hand landmarks (disabled)
  // Future<ASLPrediction?> _processImage(InputImage inputImage) async {
  //   // Temporarily disabled - ML Kit functionality
  //   return null;
  // }

  /// Extract hand landmarks from pose detection (disabled)
  // List<HandLandmark> _extractHandLandmarksFromPose(Pose pose) {
  //   // Temporarily disabled - ML Kit functionality
  //   return [];
  // }

  /// Get available gesture labels
  List<String> get availableGestures => List.from(_labels);

  /// Phase 3: Advanced ASL detection with stream processing and stabilization
  Future<ASLPrediction?> detectWithAdvancedProcessing(CameraImage image) async {
    if (!_isInitialized || !_useStreamProcessing) {
      throw Exception('Phase 3 components not initialized');
    }

    try {
      // Skip frame-based throttling logic for now (handled by stream processor separately)

      // Process with normal detection
      final prediction = await detectGestureFromCamera();
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

      // Create enhanced prediction with additional Phase 3 information
      return stabilizedPrediction;
    } catch (e) {
      print('❌ Error in advanced ASL detection: $e');
      return null;
    }
  }

  /// Get current word recognition progress
  String getCurrentWordProgress() {
    return _wordRecognizer?.currentWord ?? '';
  }

  /// Get current sequence being typed
  String getCurrentSequence() {
    return _wordRecognizer?.currentSequence ?? '';
  }

  /// Get recognized words
  List<String> getRecognizedWords() {
    return _wordRecognizer?.recognizedWords ?? [];
  }

  /// Reset word recognition state
  void resetWordRecognizer() {
    _wordRecognizer?.reset();
  }

  /// Get gesture stabilization metrics
  Map<String, dynamic> getStabilizationMetrics() {
    if (_gestureStabilizer == null) return {};
    return {
      'stabilityRate': _gestureStabilizer!.stabilityRate,
      'averageConfidence': _gestureStabilizer!.averageConfidence,
      'predictionHistory': _gestureStabilizer!.history.length,
      'isStable': _gestureStabilizer!.isStable,
    };
  }

  /// Check if stream processing is enabled
  bool get isStreamProcessingEnabled => _useStreamProcessing;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

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
    print('🧹 ASL Detection Service disposed');
  }
}
