import 'dart:async';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:http_parser/http_parser.dart';
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
    milliseconds: 1000,
  ); // 1 FPS (1000ms interval) - reduced frequency for better performance
  static const Duration minUploadInterval = Duration(
    milliseconds: 500,
  ); // 2 FPS max
  static const Duration maxUploadInterval = Duration(
    milliseconds: 3000,
  ); // 0.33 FPS min
  static const int targetImageSize = 200; // 200x200 as specified
  static const int retryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 2);
  static const Duration healthCheckInterval = Duration(seconds: 30);
  static const Duration healthCheckIntervalFast = Duration(seconds: 5);
  static const Duration healthCheckIntervalSlow = Duration(minutes: 2);
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

  // Health check state
  int _consecutiveHealthFailures = 0;
  DateTime? _lastHealthCheck;

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
      // DO NOT set a fixed multipart Content-Type header here; Dio will
      // add the proper header including the boundary when sending FormData.
      // Setting it manually (without a boundary) can corrupt multipart uploads.

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
      // Log image format for debugging
      print(
        '📸 Processing image: ${cameraImage.width}x${cameraImage.height}, '
        'format: ${cameraImage.format.group}, planes: ${cameraImage.planes.length}',
      );

      // Convert and resize image
      final jpegBytes = await _convertAndResizeImage(cameraImage);
      if (jpegBytes == null) {
        throw Exception('Failed to convert image');
      }

      print('📤 Uploading ${jpegBytes.length} bytes JPEG image to backend');

      // Prepare multipart request matching Flask backend expectations
      final formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(
          jpegBytes,
          filename: 'frame.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
        if (_sessionId != null) 'session_id': _sessionId,
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
      } else if (response.statusCode != null && response.statusCode! >= 500) {
        // 5xx errors - force immediate health check
        _forceHealthCheck();
        throw Exception(
          'Server Error HTTP ${response.statusCode}: ${response.statusMessage}',
        );
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
          '${EnvironmentConfig.aslBackendUrlSync}/predict-image',
          data: formData,
        );
        return response;
      } catch (e) {
        // Check if it's a 5xx error and trigger health check
        if (e is DioException &&
            e.response?.statusCode != null &&
            e.response!.statusCode! >= 500) {
          _forceHealthCheck();
        }

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
      img.Image? image;

      if (cameraImage.format.group == ImageFormatGroup.yuv420) {
        image = await _convertYuv420ToColor(cameraImage);
      } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
        image = await _convertBgraToRgb(cameraImage);
      } else if (cameraImage.format.group == ImageFormatGroup.jpeg) {
        // Direct JPEG format - decode it
        image = img.decodeImage(cameraImage.planes[0].bytes);
      } else {
        image = await _convertUnknownFormat(cameraImage);
      }

      if (image == null) {
        throw Exception('Failed to convert camera image format');
      }

      // Apply orientation correction - test if backend receives rotated images
      // If backend receives images rotated 90° clockwise, uncomment/change the next line
      image = img.copyRotate(
        image,
        angle: -90,
      ); // Rotate counter-clockwise by 90°

      // IMPORTANT: preserve aspect ratio to avoid squashing.
      // The previous behavior directly resized any rectangular image to a
      // square (targetImageSize x targetImageSize) which distorts the image.
      // Here we center-crop the longer side to a square first, then resize
      // to the target square. This keeps the content undistorted.
      final int srcWidth = image.width;
      final int srcHeight = image.height;
      final int squareSize = math.min(srcWidth, srcHeight);
      final int offsetX = ((srcWidth - squareSize) / 2).round();
      final int offsetY = ((srcHeight - squareSize) / 2).round();

      final cropped = img.copyCrop(
        image,
        x: offsetX,
        y: offsetY,
        width: squareSize,
        height: squareSize,
      );

      // Resize to target size with high quality interpolation
      final resized = img.copyResize(
        cropped,
        width: targetImageSize,
        height: targetImageSize,
        interpolation: img.Interpolation.cubic, // Higher quality interpolation
      );

      // Convert to JPEG with high quality for better ASL recognition (95% quality)
      final jpegBytes = img.encodeJpg(resized, quality: 95);

      return Uint8List.fromList(jpegBytes);
    } catch (e) {
      print('❌ Error converting image: $e');
      return null;
    }
  }

  /// Enhanced YUV420 to RGB conversion for full color processing
  Future<img.Image?> _convertYuv420ToColor(CameraImage cameraImage) async {
    try {
      final int width = cameraImage.width;
      final int height = cameraImage.height;

      final yPlane = cameraImage.planes[0];
      final uPlane = cameraImage.planes[1];
      final vPlane = cameraImage.planes[2];

      final yBytes = yPlane.bytes;
      final uBytes = uPlane.bytes;
      final vBytes = vPlane.bytes;

      final image = img.Image(width: width, height: height);

      // YUV420 to RGB conversion with proper color processing
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final yIndex = y * yPlane.bytesPerRow + x;
          final uvPixelStride = uPlane.bytesPerPixel ?? 1;
          final uvIndex =
              (y ~/ 2) * uPlane.bytesPerRow + (x ~/ 2) * uvPixelStride;

          if (yIndex < yBytes.length &&
              uvIndex < uBytes.length &&
              uvIndex < vBytes.length) {
            final yVal = yBytes[yIndex];
            final uVal = uBytes[uvIndex] - 128;
            final vVal = vBytes[uvIndex] - 128;

            // YUV to RGB conversion formulas
            final r = (yVal + 1.402 * vVal).clamp(0, 255).toInt();
            final g = (yVal - 0.344136 * uVal - 0.714136 * vVal)
                .clamp(0, 255)
                .toInt();
            final b = (yVal + 1.772 * uVal).clamp(0, 255).toInt();

            image.setPixelRgb(x, y, r, g, b);
          }
        }
      }

      print('✅ Converted YUV420 to full color RGB image (${width}x${height})');
      return image;
    } catch (e) {
      print('❌ Error converting YUV420 to color: $e');
      // Fallback to simple grayscale conversion
      return _convertYuv420Simple(cameraImage);
    }
  }

  /// Simple YUV420 to RGB conversion (fallback method)
  Future<img.Image?> _convertYuv420Simple(CameraImage cameraImage) async {
    try {
      final int width = cameraImage.width;
      final int height = cameraImage.height;

      final yPlane = cameraImage.planes[0];
      final yBytes = yPlane.bytes;
      final yRowStride = yPlane.bytesPerRow;

      final image = img.Image(width: width, height: height);

      // Use only the Y (luminance) channel for grayscale fallback
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final yIndex = y * yRowStride + x;

          if (yIndex < yBytes.length) {
            final luminance = yBytes[yIndex];
            image.setPixelRgb(x, y, luminance, luminance, luminance);
          }
        }
      }

      print('⚠️ Using YUV420 grayscale fallback conversion');
      return image;
    } catch (e) {
      print('❌ Error in YUV420 simple conversion: $e');
      return null;
    }
  }

  Future<img.Image?> _convertBgraToRgb(CameraImage cameraImage) async {
    try {
      final int width = cameraImage.width;
      final int height = cameraImage.height;
      final bytes = cameraImage.planes[0].bytes;
      final bytesPerRow = cameraImage.planes[0].bytesPerRow;

      final image = img.Image(width: width, height: height);

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final pixelIndex = y * bytesPerRow + x * 4;

          if (pixelIndex + 3 < bytes.length) {
            final b = bytes[pixelIndex];
            final g = bytes[pixelIndex + 1];
            final r = bytes[pixelIndex + 2];
            final a = bytes[pixelIndex + 3]; // Alpha channel

            // Use alpha channel for proper color blending if needed
            image.setPixelRgba(x, y, r, g, b, a);
          }
        }
      }

      print('✅ Converted BGRA to RGB image (${width}x${height})');
      return image;
    } catch (e) {
      print('❌ Error converting BGRA: $e');
      return null;
    }
  }

  /// Convert unknown format (fallback to grayscale)
  Future<img.Image?> _convertUnknownFormat(CameraImage cameraImage) async {
    try {
      final int width = cameraImage.width;
      final int height = cameraImage.height;
      final bytes = cameraImage.planes[0].bytes;

      final image = img.Image(width: width, height: height);

      // Treat as grayscale data
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final pixelIndex = y * width + x;

          if (pixelIndex < bytes.length) {
            final gray = bytes[pixelIndex];
            image.setPixelRgb(x, y, gray, gray, gray);
          }
        }
      }

      return image;
    } catch (e) {
      print('❌ Error converting unknown format: $e');
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

  /// Start adaptive health check with frequency based on backend status
  void _startHealthCheck() {
    _performHealthCheck(); // Initial check
    _scheduleNextHealthCheck();
  }

  /// Perform a single health check
  Future<void> _performHealthCheck() async {
    _lastHealthCheck = DateTime.now();

    try {
      final response = await _dio.get(
        '${EnvironmentConfig.aslBackendUrlSync}/health',
      );

      final wasHealthy = _isServerHealthy;
      _isServerHealthy = response.statusCode == 200;

      if (_isServerHealthy) {
        _consecutiveHealthFailures = 0;
        if (!wasHealthy) {
          print('✅ Backend is back online');
        }
      } else {
        _consecutiveHealthFailures++;
        print('⚠️ Backend health check failed: HTTP ${response.statusCode}');
      }
    } catch (e) {
      _isServerHealthy = false;
      _consecutiveHealthFailures++;
      print('⚠️ Server health check failed: $e');
    }

    _scheduleNextHealthCheck();
  }

  /// Schedule the next health check based on current backend status
  void _scheduleNextHealthCheck() {
    _healthCheckTimer?.cancel();

    Duration nextCheckInterval;

    if (_isServerHealthy && _consecutiveHealthFailures == 0) {
      // Backend is healthy - check less frequently
      nextCheckInterval = healthCheckIntervalSlow;
    } else if (_consecutiveHealthFailures > 0) {
      // Backend has issues - check more frequently
      nextCheckInterval = healthCheckIntervalFast;
    } else {
      // Default interval
      nextCheckInterval = healthCheckInterval;
    }

    _healthCheckTimer = Timer(nextCheckInterval, _performHealthCheck);
  }

  /// Force an immediate health check (called when 5xx errors occur)
  void _forceHealthCheck() {
    if (_lastHealthCheck == null ||
        DateTime.now().difference(_lastHealthCheck!) >
            const Duration(seconds: 5)) {
      print('🔄 Forcing immediate health check due to server error');
      _performHealthCheck();
    }
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
      'backendUrl': EnvironmentConfig.aslBackendUrlSync,
      'sessionId': _sessionId,
    };
  }

  /// Clear assembled text state locally and on the backend (/clear-session).
  ///
  /// Sends a JSON POST {"session_id": "..."} to the backend clear endpoint.
  /// Uses the same retry/backoff strategy as uploads. This method is safe to
  /// call without awaiting; failures are logged but won't throw.
  Future<void> clearAssembledText() async {
    _lastAssembledText = '';

    // Don't call backend in mock mode
    if (EnvironmentConfig.useLocalMock) {
      print('ℹ️ Mock mode enabled - skipping backend clear-session call');
      return;
    }

    if (_sessionId == null) {
      print('⚠️ No session ID available to clear backend session');
      return;
    }

    final uri = '${EnvironmentConfig.aslBackendUrlSync}/clear-session';
    final payload = {'session_id': _sessionId};

    for (int attempt = 1; attempt <= retryAttempts; attempt++) {
      try {
        final response = await _dio.post(
          uri,
          data: payload,
          options: Options(headers: {'Content-Type': 'application/json'}),
        );

        if (response.statusCode == 200) {
          print('✅ Cleared backend assembled text for session $_sessionId');
          return;
        } else {
          print(
            '⚠️ Clear-session HTTP ${response.statusCode}: ${response.statusMessage}',
          );
        }
      } catch (e) {
        // If Dio returned a non-2xx (e.g. 404), it may be surfaced here as a
        // DioException. Treat 404 (session not found) as a successful outcome
        // for our purposes (nothing to clear on the backend).
        if (e is DioException) {
          final status = e.response?.statusCode;
          if (status == 404) {
            print(
              'ℹ️ Backend responded 404 for clear-session: session not found (treated as cleared) for session $_sessionId',
            );
            return;
          }
        }

        if (attempt == retryAttempts) {
          print(
            '❌ Failed to clear backend session after $attempt attempts: $e',
          );
          return;
        }

        final delay = Duration(
          milliseconds: retryDelay.inMilliseconds * attempt,
        );
        print(
          '⚠️ Attempt $attempt to clear session failed, retrying in ${delay.inMilliseconds}ms...',
        );
        await Future.delayed(delay);
      }
    }
  }

  /// Test and save a captured image for quality verification (DEBUG ONLY)
  Future<void> testImageCapture(CameraImage cameraImage) async {
    try {
      final jpegBytes = await _convertAndResizeImage(cameraImage);
      if (jpegBytes != null) {
        print('🔍 Image test results:');
        print('   - Original: ${cameraImage.width}x${cameraImage.height}');
        print('   - Format: ${cameraImage.format.group}');
        print('   - Planes: ${cameraImage.planes.length}');
        print('   - JPEG size: ${jpegBytes.length} bytes');
        print('   - Target size: ${targetImageSize}x${targetImageSize}');

        // TODO: Uncomment to save test image to device storage
        // final directory = await getApplicationDocumentsDirectory();
        // final file = File('${directory.path}/test_capture_${DateTime.now().millisecondsSinceEpoch}.jpg');
        // await file.writeAsBytes(jpegBytes);
        // print('   - Saved to: ${file.path}');
      }
    } catch (e) {
      print('❌ Image test failed: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _uploadTimer?.cancel();
    _healthCheckTimer?.cancel();
    _dio.close();
  }
}
