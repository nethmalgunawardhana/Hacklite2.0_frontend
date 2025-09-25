/// Data model representing an ASL prediction result
class ASLPrediction {
  final String letter;
  final double confidence;
  final DateTime timestamp;
  final List<HandLandmark> landmarks;
  final String? assembledText;

  ASLPrediction({
    required this.letter,
    required this.confidence,
    required this.timestamp,
    this.landmarks = const [],
    this.assembledText,
  });

  /// Returns true if the prediction confidence is above threshold
  bool get isHighConfidence => confidence > 0.7;

  @override
  String toString() {
    return 'ASLPrediction(letter: $letter, confidence: ${confidence.toStringAsFixed(2)})';
  }
}

/// Data model for hand landmark points
class HandLandmark {
  final double x;
  final double y;
  final double z;

  HandLandmark({required this.x, required this.y, required this.z});

  @override
  String toString() {
    return 'HandLandmark(x: $x, y: $y, z: $z)';
  }
}
