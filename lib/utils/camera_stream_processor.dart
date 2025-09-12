import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../models/asl_prediction.dart';
import '../utils/hand_landmark_processor.dart';

/// Advanced real-time camera stream processor for Phase 3
class CameraStreamProcessor {
  // Stream processing state
  bool _isProcessing = false;
  bool _isActive = false;
  StreamSubscription<CameraImage>? _streamSubscription;

  // ML Kit components
  PoseDetector? _poseDetector;
  HandLandmarkProcessor? _landmarkProcessor;

  // Performance tracking
  int _frameCount = 0;
  DateTime? _lastFrameTime;
  double _averageFps = 0.0;

  // Detection settings
  static const int targetFps = 10; // Process 10 frames per second
  static const Duration minFrameInterval = Duration(milliseconds: 100);
  DateTime? _lastProcessTime;

  // Callbacks
  Function(ASLPrediction)? onPrediction;
  Function(String)? onError;
  Function(double)? onFpsUpdate;

  /// Initialize the stream processor
  Future<bool> initialize() async {
    try {
      _poseDetector = PoseDetector(
        options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
      );
      _landmarkProcessor = HandLandmarkProcessor();
      print('✅ Camera Stream Processor initialized');
      return true;
    } catch (e) {
      print('❌ Error initializing stream processor: $e');
      return false;
    }
  }

  /// Start processing camera stream
  Future<void> startProcessing(CameraController controller) async {
    if (_isActive || _poseDetector == null) return;

    _isActive = true;
    _frameCount = 0;
    _lastFrameTime = DateTime.now();

    try {
      await controller.startImageStream((CameraImage image) {
        _processFrame(image);
      });
      print('🎥 Camera stream processing started');
    } catch (e) {
      print('❌ Error starting camera stream: $e');
      onError?.call('Failed to start camera stream: $e');
    }
  }

  /// Stop processing camera stream
  Future<void> stopProcessing(CameraController controller) async {
    if (!_isActive) return;

    _isActive = false;

    try {
      await controller.stopImageStream();
      await _streamSubscription?.cancel();
      _streamSubscription = null;
      print('⏹️ Camera stream processing stopped');
    } catch (e) {
      print('❌ Error stopping camera stream: $e');
    }
  }

  /// Process individual camera frame
  void _processFrame(CameraImage image) {
    // Skip if already processing or not active
    if (_isProcessing || !_isActive) return;

    // Throttle frame processing to target FPS
    final now = DateTime.now();
    if (_lastProcessTime != null &&
        now.difference(_lastProcessTime!) < minFrameInterval) {
      return;
    }
    _lastProcessTime = now;

    _isProcessing = true;

    // Update FPS tracking
    _updateFpsTracking();

    // Process frame asynchronously
    _processFrameAsync(image)
        .catchError((error) {
          print('Error processing frame: $error');
          onError?.call('Frame processing error: $error');
        })
        .whenComplete(() {
          _isProcessing = false;
        });
  }

  /// Asynchronously process camera frame
  Future<void> _processFrameAsync(CameraImage image) async {
    try {
      // Convert camera image to InputImage
      final inputImage = _convertCameraImageToInputImage(image);
      if (inputImage == null) return;

      // Detect poses using ML Kit
      final poses = await _poseDetector!.processImage(inputImage);

      if (poses.isNotEmpty) {
        // Process the first detected pose
        final pose = poses.first;
        final handLandmarks = _landmarkProcessor!.extractHandLandmarksFromPose(
          pose,
        );

        if (handLandmarks.isNotEmpty) {
          // Recognize gesture from landmarks
          final prediction = _landmarkProcessor!.recognizeGesture(
            handLandmarks,
          );

          if (prediction != null && prediction.isHighConfidence) {
            onPrediction?.call(prediction);
          }
        }
      }
    } catch (e) {
      print('Error in frame processing: $e');
    }
  }

  /// Convert CameraImage to InputImage for ML Kit
  InputImage? _convertCameraImageToInputImage(CameraImage image) {
    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize = Size(
        image.width.toDouble(),
        image.height.toDouble(),
      );

      // Determine image rotation based on device orientation
      const InputImageRotation rotation = InputImageRotation.rotation0deg;

      // Determine image format
      InputImageFormat format;
      switch (image.format.group) {
        case ImageFormatGroup.yuv420:
          format = InputImageFormat.nv21;
          break;
        case ImageFormatGroup.bgra8888:
          format = InputImageFormat.bgra8888;
          break;
        default:
          format = InputImageFormat.nv21;
      }

      final inputImageMetadata = InputImageMetadata(
        size: imageSize,
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      );

      return InputImage.fromBytes(bytes: bytes, metadata: inputImageMetadata);
    } catch (e) {
      print('Error converting camera image: $e');
      return null;
    }
  }

  /// Update FPS tracking
  void _updateFpsTracking() {
    _frameCount++;
    final now = DateTime.now();

    if (_lastFrameTime != null) {
      final timeDiff = now.difference(_lastFrameTime!);
      if (timeDiff.inMilliseconds > 1000) {
        // Calculate FPS over the last second
        _averageFps = _frameCount / (timeDiff.inMilliseconds / 1000);
        onFpsUpdate?.call(_averageFps);

        _frameCount = 0;
        _lastFrameTime = now;
      }
    } else {
      _lastFrameTime = now;
    }
  }

  /// Get current FPS
  double get currentFps => _averageFps;

  /// Check if currently processing
  bool get isProcessing => _isProcessing;

  /// Check if stream is active
  bool get isActive => _isActive;

  /// Dispose resources
  void dispose() {
    _isActive = false;
    _isProcessing = false;
    _streamSubscription?.cancel();
    _poseDetector?.close();
    print('🧹 Camera Stream Processor disposed');
  }
}
