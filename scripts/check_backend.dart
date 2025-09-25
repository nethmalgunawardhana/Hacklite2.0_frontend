#!/usr/bin/env dart

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

/// Simple backend checker for the ASL prediction API.
///
/// Usage:
/// dart run scripts/check_backend.dart <BACKEND_URL> [image_path]
/// Example:
/// dart run scripts/check_backend.dart http://192.168.8.102:5000 assets/images/logo.png
void main(List<String> args) async {
  final defaultUrl =
      Platform.environment['ASL_BACKEND_URL'] ?? 'http://127.0.0.1:5000';
  final backend = args.isNotEmpty ? args[0] : defaultUrl;
  final imagePath = args.length > 1 ? args[1] : 'assets/images/logo.png';

  print('Checking backend: $backend');
  await checkHealth(backend);
  await sendPredictRequest(backend, imagePath);
}

Future<void> checkHealth(String baseUrl) async {
  final uri = Uri.parse(
    baseUrl.endsWith('/') ? baseUrl + 'health' : '$baseUrl/health',
  );
  stdout.write('GET ${uri.toString()} ... ');
  final sw = Stopwatch()..start();
  try {
    final resp = await http.get(uri).timeout(const Duration(seconds: 5));
    sw.stop();
    print('(${sw.elapsedMilliseconds} ms) status=${resp.statusCode}');
    print('body: ${resp.body}');
  } catch (e) {
    sw.stop();
    print('\nFailed to reach health endpoint: $e');
  }
}

Future<void> sendPredictRequest(String baseUrl, String imagePath) async {
  final uri = Uri.parse(
    baseUrl.endsWith('/')
        ? baseUrl + 'predict-image'
        : '$baseUrl/predict-image',
  );
  print('\nPOST ${uri.toString()} (multipart/form-data)');

  final file = File(imagePath);
  if (!await file.exists()) {
    print('Image file not found at "$imagePath". Skipping predict POST.');
    return;
  }

  final sessionId = const Uuid().v4();
  final request = http.MultipartRequest('POST', uri)
    ..fields['session_id'] = sessionId
    ..files.add(
      await http.MultipartFile.fromPath('image', imagePath, contentType: null),
    );

  final client = http.Client();
  final sw = Stopwatch()..start();
  try {
    final streamed = await client
        .send(request)
        .timeout(const Duration(seconds: 10));
    final resp = await http.Response.fromStream(streamed);
    sw.stop();
    print('Response status: ${resp.statusCode} (${sw.elapsedMilliseconds} ms)');
    if (resp.headers['content-type']?.contains('application/json') ?? false) {
      try {
        final jsonBody = json.decode(resp.body);
        print('Parsed JSON response:');
        print(const JsonEncoder.withIndent('  ').convert(jsonBody));
        if (jsonBody is Map && jsonBody.containsKey('predicted_label')) {
          print('\nTop prediction: ${jsonBody['predicted_label']}');
        }
      } catch (e) {
        print('Failed to parse JSON: $e');
        print('Raw body: ${resp.body}');
      }
    } else {
      print('Non-JSON response body: ${resp.body}');
    }
  } catch (e) {
    sw.stop();
    print('Failed to POST predict-image: $e');
  } finally {
    client.close();
  }
}
