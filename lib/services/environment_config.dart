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

  static String get aslBackendUrl {
    // First try to get from environment variables
    final envUrl = const String.fromEnvironment('ASL_BACKEND_URL');
    if (envUrl.isNotEmpty) {
      return envUrl;
    }

    // Fall back to .env file
    return dotenv.env['ASL_BACKEND_URL'] ?? 'http://localhost:5000';
  }

  // Development flags
  static bool get useLocalMock {
    final envMock = const String.fromEnvironment('USE_LOCAL_MOCK');
    if (envMock.isNotEmpty) {
      return envMock.toLowerCase() == 'true';
    }
    return dotenv.env['USE_LOCAL_MOCK']?.toLowerCase() == 'true';
  }

  static Future<void> initialize() async {
    // Load .env file for both web and mobile platforms
    await dotenv.load(fileName: ".env");
  }
}
