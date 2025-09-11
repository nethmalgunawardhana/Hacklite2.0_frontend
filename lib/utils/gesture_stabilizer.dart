import 'dart:collection';
import '../models/asl_prediction.dart';

/// Gesture stabilizer to prevent jitter and improve detection accuracy
class GestureStabilizer {
  // Configuration
  static const int historySize = 5; // Number of recent predictions to analyze
  static const double stabilityThreshold =
      0.6; // Minimum confidence for stability
  static const int consistencyRequirement = 3; // Consecutive detections needed

  // Detection history
  final Queue<ASLPrediction> _history = Queue<ASLPrediction>();
  ASLPrediction? _lastStablePrediction;
  String? _lastStableLetter;
  DateTime? _lastStableTime;

  // Statistics
  int _totalPredictions = 0;
  int _stablePredictions = 0;
  double _averageConfidence = 0.0;

  /// Add a new prediction to the stabilizer
  ASLPrediction? addPrediction(ASLPrediction prediction) {
    _totalPredictions++;

    // Add to history
    _history.add(prediction);
    if (_history.length > historySize) {
      _history.removeFirst();
    }

    // Update average confidence
    _updateAverageConfidence();

    // Check for stable gesture
    final stablePrediction = _analyzeStability();

    if (stablePrediction != null) {
      _stablePredictions++;
      _lastStablePrediction = stablePrediction;
      _lastStableLetter = stablePrediction.letter;
      _lastStableTime = DateTime.now();

      return stablePrediction;
    }

    return null;
  }

  /// Analyze prediction history for stability
  ASLPrediction? _analyzeStability() {
    if (_history.length < consistencyRequirement) return null;

    // Get recent predictions
    final recentPredictions = _history
        .toList()
        .reversed
        .take(consistencyRequirement)
        .toList();

    // Check for letter consistency
    final String? consistentLetter = _findConsistentLetter(recentPredictions);
    if (consistentLetter == null) return null;

    // Check for confidence stability
    final double averageConfidence = _calculateAverageConfidence(
      recentPredictions,
    );
    if (averageConfidence < stabilityThreshold) return null;

    // Check if this is a new stable detection (different from last)
    if (_lastStableLetter == consistentLetter) {
      // Same letter as last stable detection - check time gap
      if (_lastStableTime != null &&
          DateTime.now().difference(_lastStableTime!).inMilliseconds < 2000) {
        return null; // Too soon for same letter
      }
    }

    // Create stabilized prediction
    return ASLPrediction(
      letter: consistentLetter,
      confidence: averageConfidence,
      timestamp: DateTime.now(),
      landmarks: recentPredictions.last.landmarks,
    );
  }

  /// Find consistent letter across recent predictions
  String? _findConsistentLetter(List<ASLPrediction> predictions) {
    if (predictions.isEmpty) return null;

    // Count occurrences of each letter
    final Map<String, int> letterCounts = {};
    for (final prediction in predictions) {
      letterCounts[prediction.letter] =
          (letterCounts[prediction.letter] ?? 0) + 1;
    }

    // Find the most common letter
    String? mostCommonLetter;
    int maxCount = 0;

    letterCounts.forEach((letter, count) {
      if (count > maxCount) {
        maxCount = count;
        mostCommonLetter = letter;
      }
    });

    // Check if it appears in enough predictions
    if (maxCount >= consistencyRequirement) {
      return mostCommonLetter;
    }

    return null;
  }

  /// Calculate average confidence for given predictions
  double _calculateAverageConfidence(List<ASLPrediction> predictions) {
    if (predictions.isEmpty) return 0.0;

    double totalConfidence = 0.0;
    for (final prediction in predictions) {
      totalConfidence += prediction.confidence;
    }

    return totalConfidence / predictions.length;
  }

  /// Update overall average confidence
  void _updateAverageConfidence() {
    if (_history.isEmpty) return;

    double totalConfidence = 0.0;
    for (final prediction in _history) {
      totalConfidence += prediction.confidence;
    }

    _averageConfidence = totalConfidence / _history.length;
  }

  /// Get stability statistics
  Map<String, dynamic> getStatistics() {
    return {
      'totalPredictions': _totalPredictions,
      'stablePredictions': _stablePredictions,
      'stabilityRate': _totalPredictions > 0
          ? _stablePredictions / _totalPredictions
          : 0.0,
      'averageConfidence': _averageConfidence,
      'historySize': _history.length,
      'lastStableLetter': _lastStableLetter,
      'lastStableTime': _lastStableTime?.toIso8601String(),
    };
  }

  /// Get current prediction history
  List<ASLPrediction> get history => _history.toList();

  /// Get last stable prediction
  ASLPrediction? get lastStablePrediction => _lastStablePrediction;

  /// Get stability rate (percentage of stable predictions)
  double get stabilityRate =>
      _totalPredictions > 0 ? _stablePredictions / _totalPredictions : 0.0;

  /// Get average confidence
  double get averageConfidence => _averageConfidence;

  /// Clear history and reset statistics
  void reset() {
    _history.clear();
    _lastStablePrediction = null;
    _lastStableLetter = null;
    _lastStableTime = null;
    _totalPredictions = 0;
    _stablePredictions = 0;
    _averageConfidence = 0.0;
  }

  /// Check if currently in a stable state
  bool get isStable =>
      _history.length >= consistencyRequirement &&
      _lastStablePrediction != null &&
      _lastStableTime != null &&
      DateTime.now().difference(_lastStableTime!).inMilliseconds < 3000;
}
