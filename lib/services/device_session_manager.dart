import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Manages unique session IDs for device/user tracking
class DeviceSessionManager {
  static const String _sessionFileName = 'device_session.txt';
  static String? _cachedSessionId;

  /// Get or generate a session ID for this device/user
  static Future<String> getSessionId() async {
    if (_cachedSessionId != null) {
      return _cachedSessionId!;
    }

    try {
      final file = await _getSessionFile();

      // Try to read existing session ID
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          _cachedSessionId = content.trim();
          return _cachedSessionId!;
        }
      }

      // Generate new session ID
      final newSessionId = await _generateSessionId();
      await file.writeAsString(newSessionId);
      _cachedSessionId = newSessionId;

      print('📱 Generated new session ID: $newSessionId');
      return newSessionId;
    } catch (e) {
      print('❌ Error managing session ID: $e');
      // Return a fallback session ID
      return 'device-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Generate a new unique session ID
  static Future<String> _generateSessionId() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = timestamp.hashCode.abs().toString().substring(0, 6);
    return 'device-$random-$timestamp';
  }

  /// Get the session file reference
  static Future<File> _getSessionFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_sessionFileName');
  }

  /// Reset session ID (for testing or user logout)
  static Future<void> resetSessionId() async {
    try {
      final file = await _getSessionFile();
      if (await file.exists()) {
        await file.delete();
      }
      _cachedSessionId = null;
      print('🗑️ Session ID reset');
    } catch (e) {
      print('❌ Error resetting session ID: $e');
    }
  }

  /// Get current session ID without generating new one
  static String? getCurrentSessionId() {
    return _cachedSessionId;
  }
}
