import '../models/asl_prediction.dart';

/// Simple utility class for basic hand gesture recognition
class SimpleGestureProcessor {
  /// Recognizes basic ASL letters using simple rules
  /// This is a placeholder implementation for demonstration
  static String recognizeGesture(Map<String, dynamic> gestureData) {
    // This is where we would implement simple gesture recognition
    // For now, return a random letter for demonstration
    final letters = ['A', 'B', 'C', 'D', 'L', 'V', 'Y'];
    final now = DateTime.now();
    final index = now.second % letters.length;
    return letters[index];
  }

  /// Creates a mock ASL prediction for testing
  static ASLPrediction createMockPrediction() {
    final letters = ['A', 'B', 'C', 'D', 'L', 'V', 'Y'];
    final now = DateTime.now();
    final index = now.second % letters.length;
    final confidence =
        0.6 + (now.millisecond % 400) / 1000; // Random confidence 0.6-1.0

    return ASLPrediction(
      letter: letters[index],
      confidence: confidence,
      timestamp: now,
    );
  }

  /// Validates if a gesture is clear enough for recognition
  static bool isValidGesture(Map<String, dynamic> gestureData) {
    // Simple validation - in a real implementation this would check hand landmarks
    return gestureData.isNotEmpty;
  }
}
