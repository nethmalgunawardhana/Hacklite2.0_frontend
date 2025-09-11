import 'dart:math';
import 'landmark_storage.dart';

/// A simple k-NN classifier for hand landmark recognition
class KnnClassifier {
  final int k;
  final double rejectionThreshold;
  final List<LandmarkExample> _examples = [];
  bool _isLoaded = false;

  KnnClassifier({this.k = 3, this.rejectionThreshold = 0.6});

  /// Load examples from storage
  Future<void> loadExamples(LandmarkStorage storage) async {
    try {
      _examples.clear();
      _examples.addAll(await storage.loadExamples());
      _isLoaded = true;
      print('✅ Loaded ${_examples.length} examples for k-NN classifier');
    } catch (e) {
      print('❌ Error loading examples: $e');
      _isLoaded = false;
    }
  }

  /// Predict label for given landmarks
  PredictionResult? predict(List<double> landmarks) {
    if (!_isLoaded || _examples.isEmpty) {
      return null;
    }

    try {
      final normalizedInput = _normalizeLandmarks(landmarks);
      if (normalizedInput == null) return null;

      // Compute distances to all examples
      final distances = <_Distance>[];
      for (int i = 0; i < _examples.length; i++) {
        final example = _examples[i];
        final normalizedExample = _normalizeLandmarks(example.landmarks);
        if (normalizedExample == null) continue;

        final distance = _euclideanDistance(normalizedInput, normalizedExample);
        distances.add(
          _Distance(index: i, distance: distance, label: example.label),
        );
      }

      if (distances.isEmpty) return null;

      // Sort by distance and take k nearest
      distances.sort((a, b) => a.distance.compareTo(b.distance));
      final nearestK = distances.take(k).toList();

      // Weighted voting (inverse distance)
      final votes = <String, double>{};
      double totalWeight = 0.0;

      for (final neighbor in nearestK) {
        final weight =
            1.0 /
            (neighbor.distance + 1e-6); // Add epsilon to avoid division by zero
        votes[neighbor.label] = (votes[neighbor.label] ?? 0.0) + weight;
        totalWeight += weight;
      }

      if (votes.isEmpty) return null;

      // Find the best prediction
      final bestEntry = votes.entries.reduce(
        (a, b) => a.value > b.value ? a : b,
      );
      final confidence = bestEntry.value / totalWeight;

      // Apply rejection threshold
      if (confidence < rejectionThreshold) {
        return PredictionResult(
          label: 'unknown',
          confidence: confidence,
          nearestDistance: nearestK.first.distance,
        );
      }

      return PredictionResult(
        label: bestEntry.key,
        confidence: confidence,
        nearestDistance: nearestK.first.distance,
      );
    } catch (e) {
      print('❌ Error in k-NN prediction: $e');
      return null;
    }
  }

  /// Normalize landmarks to be scale and position invariant
  List<double>? _normalizeLandmarks(List<double> landmarks) {
    if (landmarks.length < 63) return null; // Need 21 landmarks * 3 coordinates

    try {
      // Extract coordinates
      final points = <Point3D>[];
      for (int i = 0; i < 21; i++) {
        points.add(
          Point3D(landmarks[i * 3], landmarks[i * 3 + 1], landmarks[i * 3 + 2]),
        );
      }

      // Use wrist (point 0) as reference
      final wrist = points[0];

      // Calculate scale using distance between wrist and middle finger MCP (point 9)
      final middleMcp = points[9];
      final scale = _distance3D(wrist, middleMcp);

      if (scale < 1e-6) return null; // Invalid hand pose

      // Normalize: center on wrist and scale
      final normalized = <double>[];
      for (final point in points) {
        normalized.add((point.x - wrist.x) / scale);
        normalized.add((point.y - wrist.y) / scale);
        normalized.add((point.z - wrist.z) / scale);
      }

      return normalized;
    } catch (e) {
      print('❌ Error normalizing landmarks: $e');
      return null;
    }
  }

  /// Calculate Euclidean distance between two feature vectors
  double _euclideanDistance(List<double> a, List<double> b) {
    if (a.length != b.length) return double.infinity;

    double sum = 0.0;
    for (int i = 0; i < a.length; i++) {
      final diff = a[i] - b[i];
      sum += diff * diff;
    }
    return sqrt(sum);
  }

  /// Calculate 3D distance between two points
  double _distance3D(Point3D a, Point3D b) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;
    final dz = a.z - b.z;
    return sqrt(dx * dx + dy * dy + dz * dz);
  }

  /// Get classifier statistics
  Map<String, dynamic> getStats() {
    final labelCounts = <String, int>{};
    for (final example in _examples) {
      labelCounts[example.label] = (labelCounts[example.label] ?? 0) + 1;
    }

    return {
      'isLoaded': _isLoaded,
      'totalExamples': _examples.length,
      'uniqueLabels': labelCounts.length,
      'labelCounts': labelCounts,
      'k': k,
      'rejectionThreshold': rejectionThreshold,
    };
  }

  /// Check if classifier is ready
  bool get isReady => _isLoaded && _examples.isNotEmpty;

  /// Get available labels
  Set<String> get availableLabels => _examples.map((e) => e.label).toSet();
}

/// Temporal smoothing for predictions
class PredictionSmoother {
  final int windowSize;
  final double stabilityThreshold;
  final List<PredictionResult> _history = [];

  PredictionSmoother({this.windowSize = 5, this.stabilityThreshold = 0.6});

  /// Add a new prediction and get smoothed result
  PredictionResult? addPrediction(PredictionResult prediction) {
    _history.add(prediction);

    // Keep only recent predictions
    if (_history.length > windowSize) {
      _history.removeAt(0);
    }

    // Need minimum history for smoothing
    if (_history.length < 3) return null;

    // Count occurrences of each label
    final labelCounts = <String, int>{};
    double totalConfidence = 0.0;

    for (final pred in _history) {
      labelCounts[pred.label] = (labelCounts[pred.label] ?? 0) + 1;
      totalConfidence += pred.confidence;
    }

    final avgConfidence = totalConfidence / _history.length;

    // Find most frequent label
    final mostFrequent = labelCounts.entries.reduce(
      (a, b) => a.value > b.value ? a : b,
    );

    final stability = mostFrequent.value / _history.length;

    // Only return if stable enough
    if (stability >= stabilityThreshold) {
      return PredictionResult(
        label: mostFrequent.key,
        confidence: avgConfidence,
        nearestDistance: _history.last.nearestDistance,
      );
    }

    return null;
  }

  /// Clear prediction history
  void clear() {
    _history.clear();
  }

  /// Get current stability metrics
  Map<String, dynamic> getMetrics() {
    if (_history.isEmpty) {
      return {'stability': 0.0, 'historySize': 0};
    }

    final labelCounts = <String, int>{};
    for (final pred in _history) {
      labelCounts[pred.label] = (labelCounts[pred.label] ?? 0) + 1;
    }

    final maxCount = labelCounts.values.isEmpty
        ? 0
        : labelCounts.values.reduce((a, b) => a > b ? a : b);

    return {
      'stability': maxCount / _history.length,
      'historySize': _history.length,
      'labelCounts': labelCounts,
    };
  }
}

/// Data classes
class Point3D {
  final double x, y, z;
  Point3D(this.x, this.y, this.z);
}

class _Distance {
  final int index;
  final double distance;
  final String label;

  _Distance({required this.index, required this.distance, required this.label});
}

class PredictionResult {
  final String label;
  final double confidence;
  final double nearestDistance;

  PredictionResult({
    required this.label,
    required this.confidence,
    required this.nearestDistance,
  });

  @override
  String toString() {
    return 'PredictionResult(label: $label, confidence: ${confidence.toStringAsFixed(3)})';
  }
}
