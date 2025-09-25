import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/asl_prediction.dart';

/// Service for communicating with the ASL recognition backend
class ASLBackendService {
  static ASLBackendService? _instance;
  static ASLBackendService get instance {
    _instance ??= ASLBackendService._();
    return _instance!;
  }

  ASLBackendService._();

  // Backend configuration
  static String get defaultBaseUrl =>
      dotenv.env['ASL_BACKEND_URL'] ??
      dotenv.env['BACKEND_URL'] ??
      'http://localhost:5000';
  // Increased timeout to handle slower model inference on the backend
  static const Duration timeoutDuration = Duration(seconds: 15);

  String _baseUrl = '';
  String? _currentSessionId;

  // Session management for text assembly
  String _assembledText = '';

  /// Initialize the backend service with custom URL
  void initialize({String? baseUrl}) {
    _baseUrl = baseUrl ?? defaultBaseUrl;
    _currentSessionId = _generateSessionId();
    print('🌐 ASL Backend Service initialized with URL: $_baseUrl');
    print('📱 Session ID: $_currentSessionId');
  }

  /// Generate a unique session ID
  String _generateSessionId() {
    return 'session_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }

  /// Health check endpoint
  Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(
            Uri.parse('$_baseUrl/health'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'ok';
      }
      return false;
    } catch (e) {
      print('❌ Backend health check failed: $e');
      return false;
    }
  }

  /// Predict ASL from camera image using multipart form data (recommended)
  Future<ASLPrediction?> predictFromCameraImage(CameraImage cameraImage) async {
    try {
      if (_currentSessionId == null) {
        _currentSessionId = _generateSessionId();
      }

      // Convert CameraImage to JPEG bytes
      final imageBytes = await _convertCameraImageToJpeg(cameraImage);
      if (imageBytes == null) {
        print('❌ Failed to convert camera image');
        return null;
      }

      return await _sendMultipartRequest(imageBytes);
    } catch (e) {
      print('❌ Error predicting from camera image: $e');
      return null;
    }
  }

  /// Predict ASL from file image
  Future<ASLPrediction?> predictFromFile(File imageFile) async {
    try {
      if (_currentSessionId == null) {
        _currentSessionId = _generateSessionId();
      }

      final imageBytes = await imageFile.readAsBytes();
      return await _sendMultipartRequest(imageBytes);
    } catch (e) {
      print('❌ Error predicting from file: $e');
      return null;
    }
  }

  /// Predict ASL from image bytes using Base64 JSON
  Future<ASLPrediction?> predictFromBytes(Uint8List imageBytes) async {
    try {
      if (_currentSessionId == null) {
        _currentSessionId = _generateSessionId();
      }

      return await _sendBase64Request(imageBytes);
    } catch (e) {
      print('❌ Error predicting from bytes: $e');
      return null;
    }
  }

  /// Send multipart form data request (Option 1 - Recommended)
  Future<ASLPrediction?> _sendMultipartRequest(Uint8List imageBytes) async {
    try {
      final uri = Uri.parse('$_baseUrl/predict-image');
      final request = http.MultipartRequest('POST', uri);

      // Add session ID
      request.fields['session_id'] = _currentSessionId!;

      // Add image file
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: 'image.jpg',
        ),
      );

      final response = await request.send().timeout(timeoutDuration);
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        return _parseResponse(responseBody);
      } else {
        print(
          '❌ Backend error (multipart) ${response.statusCode} -> ${uri.toString()}\n$responseBody',
        );
        return null;
      }
    } catch (e) {
      print('❌ Multipart request failed: $e');
      return null;
    }
  }

  /// Send Base64 JSON request (Option 2)
  Future<ASLPrediction?> _sendBase64Request(Uint8List imageBytes) async {
    try {
      final base64Image = base64Encode(imageBytes);

      final requestBody = {
        'image_data': base64Image,
        'session_id': _currentSessionId,
        'format': 'base64',
      };

      final response = await http
          .post(
            Uri.parse('$_baseUrl/predict-image'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(requestBody),
          )
          .timeout(timeoutDuration);

      if (response.statusCode == 200) {
        return _parseResponse(response.body);
      } else {
        print(
          '❌ Backend error (base64) ${response.statusCode} -> ${Uri.parse('$_baseUrl/predict-image').toString()}\n${response.body}',
        );
        return null;
      }
    } catch (e) {
      print('❌ Base64 request failed: $e');
      return null;
    }
  }

  /// Parse the backend response
  ASLPrediction? _parseResponse(String responseBody) {
    try {
      final data = json.decode(responseBody);

      // Some backends return a structured response with `success` and
      // `prediction:{letter,confidence}` while others (the recent format)
      // return `top_prediction`/`predicted_label` and `assembled_text`.
      // Accept both shapes for robustness.

      // If assembled_text is present update internal state regardless of shape
      if (data.containsKey('assembled_text') &&
          data['assembled_text'] != null) {
        try {
          _assembledText = data['assembled_text'] as String;
        } catch (_) {
          // ignore malformed assembled_text
        }
      }

      String? letter;
      double confidence = 0.0;

      // Old style: { success: true, prediction: { letter, confidence } }
      if (data.containsKey('success') &&
          data['success'] == true &&
          data.containsKey('prediction')) {
        final prediction = data['prediction'];
        letter = prediction['letter'] as String?;
        confidence = ((prediction['confidence'] as num?) ?? 0).toDouble();
      }

      // New style: { top_prediction: { label, score } } or { predicted_label, predictions }
      if (letter == null) {
        if (data.containsKey('top_prediction')) {
          final top = data['top_prediction'];
          letter = (top['label'] as String?) ?? (top['letter'] as String?);
          confidence = ((top['score'] as num?) ?? 0).toDouble();
        } else if (data.containsKey('predicted_label')) {
          letter = data['predicted_label'] as String?;
          // try to infer confidence from predictions array if present
          if (data.containsKey('predictions') &&
              data['predictions'] is List &&
              (data['predictions'] as List).isNotEmpty) {
            final first = (data['predictions'] as List).firstWhere(
              (e) =>
                  (e['label'] == letter) ||
                  (e['label'] == letter?.toLowerCase()),
              orElse: () => (data['predictions'] as List).first,
            );
            confidence = ((first['score'] as num?) ?? 0).toDouble();
          }
        }
      }

      if (letter != null) {
        // Create ASL prediction
        final aslPrediction = ASLPrediction(
          letter: letter,
          confidence: confidence,
          timestamp: DateTime.now(),
          landmarks: [], // Backend doesn't return landmarks
        );

        print(
          '✅ Backend prediction: $letter (${(confidence * 100).toStringAsFixed(1)}%)',
        );

        return aslPrediction;
      }

      // If we reach here, backend didn't return a recognizable prediction
      final error =
          data['error'] ??
          data['details'] ??
          data['message'] ??
          'Unknown error';
      print('❌ Backend prediction failed: $error');
      try {
        print('🔍 Backend response payload: ${json.encode(data)}');
      } catch (_) {}
      return null;
    } catch (e) {
      print('❌ Error parsing response: $e');
      return null;
    }
  }

  /// Convert CameraImage to JPEG bytes
  Future<Uint8List?> _convertCameraImageToJpeg(CameraImage cameraImage) async {
    try {
      // Handle different image formats
      if (cameraImage.format.group == ImageFormatGroup.yuv420) {
        return _convertYUV420ToJpeg(cameraImage);
      } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
        return _convertBGRA8888ToJpeg(cameraImage);
      } else {
        print('❌ Unsupported image format: ${cameraImage.format.group}');
        return null;
      }
    } catch (e) {
      print('❌ Error converting camera image: $e');
      return null;
    }
  }

  /// Convert YUV420 format to JPEG
  Uint8List _convertYUV420ToJpeg(CameraImage cameraImage) {
    // Simple YUV420 to RGB conversion (basic implementation)
    final int width = cameraImage.width;
    final int height = cameraImage.height;

    final Uint8List yPlane = cameraImage.planes[0].bytes;
    final Uint8List uPlane = cameraImage.planes[1].bytes;
    final Uint8List vPlane = cameraImage.planes[2].bytes;

    final int ySize = yPlane.length;
    final int uvSize = uPlane.length;

    final Uint8List rgbBytes = Uint8List(width * height * 3);

    // Basic YUV to RGB conversion (may not be perfect for all devices)
    int rgbIndex = 0;
    for (int i = 0; i < ySize && rgbIndex < rgbBytes.length - 2; i++) {
      final int y = yPlane[i] & 0xFF;
      final int uvIndex = (i ~/ 2) % uvSize;
      final int u = (uPlane[uvIndex] & 0xFF) - 128;
      final int v = (vPlane[uvIndex] & 0xFF) - 128;

      // YUV to RGB conversion
      final int r = (y + 1.13983 * v).round().clamp(0, 255);
      final int g = (y - 0.39465 * u - 0.58060 * v).round().clamp(0, 255);
      final int b = (y + 2.03211 * u).round().clamp(0, 255);

      rgbBytes[rgbIndex++] = r;
      rgbBytes[rgbIndex++] = g;
      rgbBytes[rgbIndex++] = b;
    }

    // Use the `image` package to construct an Image and encode as JPEG
    try {
      final img.Image image = img.Image.fromBytes(
        width: width,
        height: height,
        bytes: rgbBytes.buffer,
      );
      final jpg = img.encodeJpg(image, quality: 85);
      return Uint8List.fromList(jpg);
    } catch (e) {
      // Fallback: return raw RGB bytes if JPEG encoding fails
      print('\u26a0\ufe0f JPEG encoding failed: $e');
      return rgbBytes;
    }
  }

  /// Convert BGRA8888 format to JPEG
  Uint8List _convertBGRA8888ToJpeg(CameraImage cameraImage) {
    final Uint8List bytes = cameraImage.planes[0].bytes;
    final int width = cameraImage.width;
    final int height = cameraImage.height;

    // Convert BGRA to RGB
    final Uint8List rgbBytes = Uint8List(width * height * 3);
    int rgbIndex = 0;

    for (int i = 0; i < bytes.length; i += 4) {
      if (rgbIndex < rgbBytes.length - 2) {
        rgbBytes[rgbIndex++] = bytes[i + 2]; // R
        rgbBytes[rgbIndex++] = bytes[i + 1]; // G
        rgbBytes[rgbIndex++] = bytes[i]; // B
        // Skip A (alpha) channel
      }
    }

    try {
      final img.Image image = img.Image.fromBytes(
        width: width,
        height: height,
        bytes: rgbBytes.buffer,
      );
      final jpg = img.encodeJpg(image, quality: 85);
      return Uint8List.fromList(jpg);
    } catch (e) {
      print('\u26a0\ufe0f JPEG encoding failed: $e');
      return rgbBytes;
    }
  }

  /// Get current assembled text from session
  String get assembledText => _assembledText;

  /// Clear the current session and start fresh
  void clearSession() {
    _currentSessionId = _generateSessionId();
    _assembledText = '';
    print('🔄 Started new session: $_currentSessionId');
  }

  /// Get current session ID
  String? get sessionId => _currentSessionId;

  /// Update base URL for backend
  void updateBaseUrl(String newBaseUrl) {
    _baseUrl = newBaseUrl;
    print('🔄 Updated backend URL to: $_baseUrl');
  }

  /// Get current backend status
  Future<Map<String, dynamic>> getStatus() async {
    final isHealthy = await checkHealth();
    return {
      'base_url': _baseUrl,
      'session_id': _currentSessionId,
      'is_healthy': isHealthy,
      'assembled_text': _assembledText,
    };
  }
}
