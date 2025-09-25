import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';
import '../models/asl_prediction.dart';
import '../models/backend_response.dart';
import 'environment_config.dart';
import 'device_session_manager.dart';

/// Service for handling backend ASL prediction API calls
class BackendPredictionService {
  static BackendPredictionService? _instance;
  static BackendPredictionService get instance {
    _instance ??= BackendPredictionService._();
    return _instance!;
  }

  BackendPredictionService._();

  late Dio _dio;
  Timer? _uploadTimer;
  Timer? _healthCheckTimer;

  // Configuration
  static const Duration defaultUploadInterval = Duration(
    milliseconds: 2000,
  ); // 0.5 FPS (2000ms interval)
  static const Duration minUploadInterval = Duration(
    milliseconds: 200,
  ); // 5 FPS max
  static const Duration maxUploadInterval = Duration(
    milliseconds: 1000,
  ); // 1 FPS min
  static const int targetImageSize = 200; // 200x200 as specified
  static const int retryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  static const Duration healthCheckInterval = Duration(seconds: 30);
  static const double frameDifferenceThreshold =
      0.1; // 10% difference threshold

  // State
  bool _isInitialized = false;
  bool _isServerHealthy = true;
  Duration _currentUploadInterval = defaultUploadInterval;
  String? _sessionId;
  Uint8List? _lastFrameData;
  DateTime? _lastUploadTime;
  DateTime? _lastFrameChangeTime;
  String? _lastAssembledText = '';

  // Network performance tracking
  int _successfulUploads = 0;
  int _failedUploads = 0;
  double _averageLatency = 0.0;
  final List<int> _latencyHistory = [];

  // Smoothing buffer
  final List<String> _predictionBuffer = [];
  static const int smoothingBufferSize = 3;

  // Mock data for development
  static const List<Map<String, dynamic>> _mockResponses = [
    {
      "predictions": [
        {"label": "a", "score": 0.94},
        {"label": "space", "score": 0.03},
        {"label": "b", "score": 0.02},
      ],
      "top_prediction": {"label": "a", "score": 0.94},
      "predicted_label": "a",
      "assembled_text": "HELLO A",
    },
    {
      "predictions": [
        {"label": "hello", "score": 0.89},
        {"label": "hi", "score": 0.08},
        {"label": "hey", "score": 0.02},
      ],
      "top_prediction": {"label": "hello", "score": 0.89},
      "predicted_label": "hello",
      "assembled_text": "HELLO HELLO",
    },
    {
      "predictions": [
        {"label": "thank", "score": 0.92},
        {"label": "thanks", "score": 0.05},
        {"label": "you", "score": 0.02},
      ],
      "top_prediction": {"label": "thank", "score": 0.92},
      "predicted_label": "thank",
      "assembled_text": "HELLO HELLO THANK",
    },
  ];

  /// Initialize the backend service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _dio = Dio();
      _dio.options.connectTimeout = const Duration(seconds: 10);
      _dio.options.receiveTimeout = const Duration(seconds: 10);
      _dio.options.headers['Content-Type'] = 'multipart/form-data';

      // Initialize session ID
      _sessionId = await DeviceSessionManager.getSessionId();

      // Start health monitoring
      _startHealthCheck();

      _isInitialized = true;
      print('✅ Backend prediction service initialized');
      return true;
    } catch (e) {
      print('❌ Failed to initialize backend service: $e');
      return false;
    }
  }

  /// Start continuous frame upload at specified frequency
  Future<void> startPrediction({
    required Stream<CameraImage> cameraStream,
    Duration uploadInterval = defaultUploadInterval,
    Function(ASLPrediction)? onPrediction,
    Function(String)? onAssembledTextUpdate,
    Function(String)? onError,
    Function(double)? onLatencyUpdate,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    _currentUploadInterval = _clampDuration(
      uploadInterval,
      minUploadInterval,
      maxUploadInterval,
    );

    print(
      '🚀 Starting backend prediction at ${1000 ~/ _currentUploadInterval.inMilliseconds} FPS',
    );

    // Listen to camera stream
    cameraStream.listen(
      (cameraImage) async {
        final now = DateTime.now();

        // Rate limiting
        if (_lastUploadTime != null &&
            now.difference(_lastUploadTime!) < _currentUploadInterval) {
          return;
        }

        // Frame difference check for stability
        if (!await _shouldUploadFrame(cameraImage)) {
          return;
        }

        _lastUploadTime = now;

        try {
          final prediction = await _uploadFrameForPrediction(cameraImage);
          if (prediction != null) {
            final smoothedPrediction = _applySmoothingBuffer(prediction);
            if (smoothedPrediction != null) {
              onPrediction?.call(smoothedPrediction);
            }

            // Update assembled text if it changed
            if (prediction.assembledText != _lastAssembledText) {
              _lastAssembledText = prediction.assembledText;
              onAssembledTextUpdate?.call(prediction.assembledText ?? '');
            }
          }
        } catch (e) {
          onError?.call('Prediction failed: $e');
          _handleUploadFailure();
        }
      },
      onError: (error) {
        onError?.call('Camera stream error: $error');
      },
    );

    // Update latency callback periodically
    if (onLatencyUpdate != null) {
      Timer.periodic(const Duration(seconds: 2), (timer) {
        onLatencyUpdate(_averageLatency);
      });
    }
  }

  /// Stop the prediction service
  void stopPrediction() {
    _uploadTimer?.cancel();
    _uploadTimer = null;
    print('⏹️ Backend prediction stopped');
  }

  /// Upload a single frame for prediction
  Future<BackendResponse?> _uploadFrameForPrediction(
    CameraImage cameraImage,
  ) async {
    if (EnvironmentConfig.useLocalMock) {
      return getMockResponse();
    }

    final stopwatch = Stopwatch()..start();

    try {
      // Convert and resize image
      final jpegBytes = await _convertAndResizeImage(cameraImage);
      if (jpegBytes == null) {
        throw Exception('Failed to convert image');
      }

      // Prepare multipart request
      final formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(
          jpegBytes,
          filename: 'frame.jpg',
          contentType: DioMediaType('image', 'jpeg'),
        ),
        'session_id': _sessionId,
      });

      // Make API call with retry logic
      final response = await _makeRequestWithRetry(formData);

      stopwatch.stop();
      final latency = stopwatch.elapsedMilliseconds.toDouble();
      _updateLatencyMetrics(latency);

      if (response.statusCode == 200) {
        _successfulUploads++;
        final backendResponse = BackendResponse.fromJson(response.data);
        print(
          '✅ Prediction: ${backendResponse.predictedLabel} (${(backendResponse.topPrediction?.score ?? 0).toStringAsFixed(2)})',
        );
        return backendResponse;
      } else {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.statusMessage}',
        );
      }
    } catch (e) {
      stopwatch.stop();
      _failedUploads++;
      print('❌ Upload failed: $e');
      rethrow;
    }
  }

  /// Make HTTP request with retry and backoff
  Future<Response> _makeRequestWithRetry(FormData formData) async {
    for (int attempt = 1; attempt <= retryAttempts; attempt++) {
      try {
        final response = await _dio.post(
          '${EnvironmentConfig.aslBackendUrl}/predict-image',
          data: formData,
        );
        return response;
      } catch (e) {
        if (attempt == retryAttempts) {
          rethrow;
        }

        final delay = Duration(
          milliseconds: retryDelay.inMilliseconds * attempt,
        );
        print(
          '⚠️ Attempt $attempt failed, retrying in ${delay.inMilliseconds}ms...',
        );
        await Future.delayed(delay);
      }
    }

    throw Exception('All retry attempts failed');
  }

  /// Convert CameraImage to JPEG and resize to target size
  Future<Uint8List?> _convertAndResizeImage(CameraImage cameraImage) async {
    try {
      // Convert CameraImage to Image format
      img.Image? image;

      if (cameraImage.format.group == ImageFormatGroup.yuv420) {
        // YUV420 format
        final yBuffer = cameraImage.planes[0].bytes;
        final uBuffer = cameraImage.planes[1].bytes;
        final vBuffer = cameraImage.planes[2].bytes;

        image = img.Image(width: cameraImage.width, height: cameraImage.height);

        // Simple YUV to RGB conversion (this is a simplified approach)
        // For production, you might want a more accurate conversion
        for (int y = 0; y < cameraImage.height; y++) {
          for (int x = 0; x < cameraImage.width; x++) {
            final yIndex = y * cameraImage.width + x;
            final uvIndex = (y ~/ 2) * (cameraImage.width ~/ 2) + (x ~/ 2);

            if (yIndex < yBuffer.length &&
                uvIndex < uBuffer.length &&
                uvIndex < vBuffer.length) {
              final yValue = yBuffer[yIndex];
              final uValue = uBuffer[uvIndex];
              final vValue = vBuffer[uvIndex];

              // YUV to RGB conversion
              final r = (yValue + 1.402 * (vValue - 128)).clamp(0, 255).toInt();
              final g =
                  (yValue -
                          0.344136 * (uValue - 128) -
                          0.714136 * (vValue - 128))
                      .clamp(0, 255)
                      .toInt();
              final b = (yValue + 1.772 * (uValue - 128)).clamp(0, 255).toInt();

              image.setPixelRgb(x, y, r, g, b);
            }
          }
        }
      } else {
        // For other formats, use a simpler approach
        image = img.Image(width: cameraImage.width, height: cameraImage.height);

        // Copy bytes directly (this is a fallback)
        final bytes = cameraImage.planes[0].bytes;
        for (int i = 0; i < bytes.length && i < image.length * 4; i += 4) {
          if (i + 3 < bytes.length) {
            final pixelIndex = i ~/ 4;
            if (pixelIndex < image.length) {
              final pixel = image.getPixel(
                pixelIndex % image.width,
                pixelIndex ~/ image.width,
              );
              pixel.r = bytes[i];
              pixel.g = bytes[i + 1];
              pixel.b = bytes[i + 2];
            }
          }
        }
      }

      // Resize to target size
      final resized = img.copyResize(
        image,
        width: targetImageSize,
        height: targetImageSize,
        interpolation: img.Interpolation.linear,
      );

      // Convert to JPEG
      final jpegBytes = img.encodeJpg(resized, quality: 85);
      return Uint8List.fromList(jpegBytes);
    } catch (e) {
      print('❌ Error converting image: $e');
      return null;
    }
  }

  /// Check if frame should be uploaded based on difference from last frame
  Future<bool> _shouldUploadFrame(CameraImage cameraImage) async {
    final now = DateTime.now();

    // Always upload first frame
    if (_lastFrameData == null) {
      _lastFrameData = cameraImage.planes[0].bytes;
      _lastFrameChangeTime = now;
      return true;
    }

    // Calculate frame difference (simplified)
    final currentBytes = cameraImage.planes[0].bytes;
    final minLength = math.min(_lastFrameData!.length, currentBytes.length);
    int differenceCount = 0;

    // Sample every 10th pixel for performance
    for (int i = 0; i < minLength; i += 10) {
      if ((_lastFrameData![i] - currentBytes[i]).abs() > 30) {
        differenceCount++;
      }
    }

    final differenceRatio = differenceCount / (minLength / 10);

    // Upload if significant change or enough time has passed
    final shouldUpload =
        differenceRatio > frameDifferenceThreshold ||
        (_lastFrameChangeTime != null &&
            now.difference(_lastFrameChangeTime!) > const Duration(seconds: 2));

    if (shouldUpload) {
      _lastFrameData = Uint8List.fromList(currentBytes);
      _lastFrameChangeTime = now;
    }

    return shouldUpload;
  }

  /// Apply smoothing buffer to reduce prediction flicker
  ASLPrediction? _applySmoothingBuffer(BackendResponse response) {
    final label = response.predictedLabel ?? '';

    // Ignore transient "nothing" values
    if (label.toLowerCase() == 'nothing' || label.isEmpty) {
      return null;
    }

    _predictionBuffer.add(label);
    if (_predictionBuffer.length > smoothingBufferSize) {
      _predictionBuffer.removeAt(0);
    }

    // Wait for buffer to fill
    if (_predictionBuffer.length < smoothingBufferSize) {
      return null;
    }

    // Check if majority agrees
    final labelCounts = <String, int>{};
    for (final bufferLabel in _predictionBuffer) {
      labelCounts[bufferLabel] = (labelCounts[bufferLabel] ?? 0) + 1;
    }

    final majority = labelCounts.entries.reduce(
      (a, b) => a.value > b.value ? a : b,
    );

    // Confirm label change only if majority agrees
    if (majority.value >= (smoothingBufferSize / 2).ceil()) {
      return ASLPrediction(
        letter: majority.key,
        confidence: response.topPrediction?.score ?? 0.0,
        timestamp: DateTime.now(),
        assembledText: response.assembledText,
      );
    }

    return null;
  }

  /// Handle upload failure by adjusting frequency
  void _handleUploadFailure() {
    // Reduce frequency on continuous failures
    if (_failedUploads > 3 && _successfulUploads < 2) {
      final newInterval = Duration(
        milliseconds: (_currentUploadInterval.inMilliseconds * 1.5).round(),
      );
      _currentUploadInterval = _clampDuration(
        newInterval,
        minUploadInterval,
        maxUploadInterval,
      );
      print(
        '⚠️ Reduced upload frequency due to failures: ${1000 ~/ _currentUploadInterval.inMilliseconds} FPS',
      );
    }
  }

  /// Update network latency metrics
  void _updateLatencyMetrics(double latency) {
    _latencyHistory.add(latency.round());
    if (_latencyHistory.length > 10) {
      _latencyHistory.removeAt(0);
    }

    _averageLatency = _latencyHistory.isEmpty
        ? 0.0
        : _latencyHistory.reduce((a, b) => a + b) / _latencyHistory.length;
  }

  /// Start periodic health check
  void _startHealthCheck() {
    _healthCheckTimer = Timer.periodic(healthCheckInterval, (timer) async {
      try {
        final response = await _dio.get(
          '${EnvironmentConfig.aslBackendUrl}/health',
        );
        _isServerHealthy = response.statusCode == 200;
      } catch (e) {
        _isServerHealthy = false;
        print('⚠️ Server health check failed: $e');
      }
    });
  }

  /// Get mock response for development (public for testing)
  BackendResponse getMockResponse() {
    final random = math.Random();
    final mockData = _mockResponses[random.nextInt(_mockResponses.length)];
    return BackendResponse.fromJson(mockData);
  }

  /// Check if using mock mode
  bool get isUsingMockMode => EnvironmentConfig.useLocalMock;

  /// Configure upload frequency
  void setUploadFrequency(int fps) {
    final interval = Duration(milliseconds: (1000 / fps).round());
    _currentUploadInterval = _clampDuration(
      interval,
      minUploadInterval,
      maxUploadInterval,
    );
    print('🔧 Upload frequency set to $fps FPS');
  }

  /// Clamp duration between min and max values
  Duration _clampDuration(Duration value, Duration min, Duration max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  /// Public method for testing duration clamping
  Duration clampDurationForTesting(Duration value, Duration min, Duration max) {
    return _clampDuration(value, min, max);
  }

  /// Get current network statistics
  Map<String, dynamic> getNetworkStats() {
    final totalUploads = _successfulUploads + _failedUploads;
    return {
      'isServerHealthy': _isServerHealthy,
      'averageLatency': _averageLatency.round(),
      'successRate': totalUploads > 0
          ? (_successfulUploads / totalUploads * 100).round()
          : 0,
      'currentFPS': 1000 ~/ _currentUploadInterval.inMilliseconds,
      'totalUploads': totalUploads,
    };
  }

  /// Dispose resources
  void dispose() {
    _uploadTimer?.cancel();
    _healthCheckTimer?.cancel();
    _dio.close();
  }
}
