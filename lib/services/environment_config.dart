import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvironmentConfig {
  static String get geminiApiKey {
    // First try to get from environment variables (for web builds with --dart-define)
    final envKey = const String.fromEnvironment('GEMINI_API_KEY');
    if (envKey.isNotEmpty) {
      return envKey;
    }

    // Fall back to .env file for both web and mobile
    return dotenv.env['GEMINI_API_KEY'] ?? '';
  }

  static Future<void> initialize() async {
    // Load .env file for both web and mobile platforms
    await dotenv.load(fileName: ".env");
  }
}
