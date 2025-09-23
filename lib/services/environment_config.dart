import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvironmentConfig {
  static String get geminiApiKey {
    if (kIsWeb) {
      // For web, API key must be provided at build time using --dart-define
      const apiKey = String.fromEnvironment('GEMINI_API_KEY');
      if (apiKey.isEmpty) {
        print(
          'ERROR: GEMINI_API_KEY not provided for web build. Use: flutter run --dart-define=GEMINI_API_KEY=your_key_here',
        );
        return '';
      }
      return apiKey;
    } else {
      // For mobile, load from .env file
      return dotenv.env['GEMINI_API_KEY'] ?? '';
    }
  }

  static Future<void> initialize() async {
    if (!kIsWeb) {
      // Only load .env on mobile platforms
      await dotenv.load(fileName: ".env");
    }
    // For web, environment variables are set at build time
  }
}
