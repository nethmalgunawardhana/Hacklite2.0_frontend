import 'dart:async';
import 'package:camera/camera.dart';
import '../models/asl_prediction.dart';
import '../services/backend_prediction_service.dart';
import '../services/environment_config.dart';

/// Enhanced ASL Detection Service that uses backend prediction API
class ASLDetectionServiceV2 {
  static ASLDetectionServiceV2? _instance;
  static ASLDetectionServiceV2 get instance {
    _instance ??= ASLDetectionServiceV2._();
    return _instance!;
  }

  ASLDetectionServiceV2._();

  BackendPredictionService? _backendService;
  StreamController<ASLPrediction>? _predictionStreamController;
  StreamController<String>? _assembledTextStreamController;
  StreamController<Map<String, dynamic>>? _networkStatsController;
  bool _isInitialized = false;
  bool _isDetecting = false;

  // Configuration
  String _currentAssembledText = '';
  String _lastError = '';

  /// Initialize the service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      _backendService = BackendPredictionService.instance;
      await _backendService!.initialize();

      _predictionStreamController = StreamController<ASLPrediction>.broadcast();
      _assembledTextStreamController = StreamController<String>.broadcast();
      _networkStatsController =
          StreamController<Map<String, dynamic>>.broadcast();

      _isInitialized = true;
      print('✅ ASL Detection Service V2 initialized with backend integration');
      return true;
    } catch (e) {
      print('❌ Failed to initialize ASL Detection Service V2: $e');
      return false;
    }
  }

  /// Start detection with camera stream
  Future<bool> startDetection({
    required Stream<CameraImage> cameraStream,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_isDetecting) {
      print('⚠️ Detection already running');
      return true;
    }

    try {
      _isDetecting = true;

      // Start backend prediction (use constant interval to force regular uploads)
      await _backendService!.startPrediction(
        cameraStream: cameraStream,
        uploadInterval: const Duration(milliseconds: 4000),
        useConstantInterval: true,
        onPrediction: (prediction) {
          _predictionStreamController?.add(prediction);
        },
        onAssembledTextUpdate: (assembledText) {
          _currentAssembledText = assembledText;
          _assembledTextStreamController?.add(assembledText);
        },
        onError: (error) {
          _lastError = error;
          print('❌ Backend prediction error: $error');
        },
        onLatencyUpdate: (latency) {
          // Update network stats periodically
          Timer.periodic(const Duration(seconds: 2), (timer) {
            if (!_isDetecting) {
              timer.cancel();
              return;
            }
            final stats = _backendService?.getNetworkStats() ?? {};
            _networkStatsController?.add(stats);
          });
        },
      );

      print('🚀 Backend detection started at fixed ${4000}ms interval');
      return true;
    } catch (e) {
      print('❌ Failed to start detection: $e');
      _isDetecting = false;
      return false;
    }
  }

  /// Stop detection
  void stopDetection() {
    if (!_isDetecting) return;

    _backendService?.stopPrediction();
    _isDetecting = false;
    print('⏹️ Backend detection stopped');
  }

  /// Get prediction stream
  Stream<ASLPrediction>? get predictionStream =>
      _predictionStreamController?.stream;

  /// Get assembled text stream
  Stream<String>? get assembledTextStream =>
      _assembledTextStreamController?.stream;

  /// Get network statistics stream
  Stream<Map<String, dynamic>>? get networkStatsStream =>
      _networkStatsController?.stream;

  /// Get current detection state
  bool get isDetecting => _isDetecting;

  /// Get current assembled text
  String get currentAssembledText => _currentAssembledText;

  /// Get current FPS setting
  int get currentFPS =>
      _backendService?.getNetworkStats()['currentFPS'] ?? (1000 ~/ 4000);

  /// Get last error message
  String get lastError => _lastError;

  /// Get current network statistics
  Map<String, dynamic> get networkStats =>
      _backendService?.getNetworkStats() ?? {};

  /// Check if using mock mode
  bool get isUsingMockMode => EnvironmentConfig.useLocalMock;

  /// Clear current assembled text
  void clearAssembledText() {
    _currentAssembledText = '';
    _backendService?.clearAssembledText();
    _assembledTextStreamController?.add('');
  }

  /// Legacy method for backward compatibility - single frame detection
  Future<ASLPrediction?> detectGestureFromCamera({
    CameraImage? cameraImage,
  }) async {
    // This is a legacy method - in the new architecture, use the stream-based approach
    print(
      '⚠️ detectGestureFromCamera is deprecated - use stream-based detection instead',
    );
    return null;
  }

  /// Dispose resources
  void dispose() {
    stopDetection();
    _backendService?.dispose();
    _predictionStreamController?.close();
    _assembledTextStreamController?.close();
    _networkStatsController?.close();
    _isInitialized = false;
  }
}
