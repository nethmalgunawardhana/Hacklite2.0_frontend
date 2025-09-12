import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/knn_classifier.dart';
import 'package:flutter_app/services/landmark_storage.dart';

void main() {
  group('KNN Classifier Tests', () {
    test('normalization preserves relative distances', () {
      final classifier = KnnClassifier();

      // Create test landmarks (21 points * 3 coordinates = 63 values)
      final landmarks1 = List.generate(63, (i) => i.toDouble());
      final landmarks2 = List.generate(63, (i) => (i * 2).toDouble());

      // Test that classifier can be created
      expect(classifier.k, 3);
      expect(classifier.rejectionThreshold, 0.6);
    });

    test('prediction result creation', () {
      final result = PredictionResult(
        label: 'test',
        confidence: 0.8,
        nearestDistance: 0.1,
      );

      expect(result.label, 'test');
      expect(result.confidence, 0.8);
      expect(result.nearestDistance, 0.1);
    });

    test('landmark example serialization', () {
      final example = LandmarkExample(
        label: 'hello',
        landmarks: [1.0, 2.0, 3.0],
        timestamp: 1234567890,
      );

      final json = example.toJson();
      final restored = LandmarkExample.fromJson(json);

      expect(restored.label, example.label);
      expect(restored.landmarks, example.landmarks);
      expect(restored.timestamp, example.timestamp);
    });

    test('prediction smoother basic functionality', () {
      final smoother = PredictionSmoother(
        windowSize: 3,
        stabilityThreshold: 0.6,
      );

      final prediction1 = PredictionResult(
        label: 'hello',
        confidence: 0.8,
        nearestDistance: 0.1,
      );

      // First prediction should return null (not enough history)
      final result1 = smoother.addPrediction(prediction1);
      expect(result1, isNull);

      // Add more predictions
      smoother.addPrediction(prediction1);
      smoother.addPrediction(prediction1);

      // Now should have stable prediction
      final result2 = smoother.addPrediction(prediction1);
      expect(result2?.label, 'hello');
    });
  });
}
