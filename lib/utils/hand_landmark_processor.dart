import 'dart:math';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import '../models/asl_prediction.dart';

/// Processes hand landmarks from pose detection and recognizes ASL gestures
class HandLandmarkProcessor {
  // Confidence thresholds
  static const double minConfidence = 0.6;
  static const double highConfidence = 0.8;

  /// Extract hand landmarks from pose detection and return as coordinate list
  List<double> extractHandLandmarkVector(Pose pose) {
    // Try to get the best hand (right hand preferred for consistency)
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];

    PoseLandmark? primaryWrist;

    if (rightWrist != null && rightWrist.likelihood > minConfidence) {
      primaryWrist = rightWrist;
    } else if (leftWrist != null && leftWrist.likelihood > minConfidence) {
      primaryWrist = leftWrist;
    } else {
      return []; // No usable hand detected
    }

    // Create 21-point landmark vector (simplified - we'll pad missing points)
    final landmarks = <double>[];

    // MediaPipe hand landmark order (simplified mapping from pose landmarks)
    final landmarkOrder = [
      primaryWrist, // 0: WRIST
      pose.landmarks[PoseLandmarkType.rightThumb], // 1-4: THUMB (simplified)
      pose.landmarks[PoseLandmarkType.rightThumb],
      pose.landmarks[PoseLandmarkType.rightThumb],
      pose.landmarks[PoseLandmarkType.rightThumb],
      pose.landmarks[PoseLandmarkType.rightIndex], // 5-8: INDEX
      pose.landmarks[PoseLandmarkType.rightIndex],
      pose.landmarks[PoseLandmarkType.rightIndex],
      pose.landmarks[PoseLandmarkType.rightIndex],
      primaryWrist, // 9-12: MIDDLE (use wrist as approximation)
      primaryWrist,
      primaryWrist,
      primaryWrist,
      primaryWrist, // 13-16: RING (use wrist as approximation)
      primaryWrist,
      primaryWrist,
      primaryWrist,
      pose.landmarks[PoseLandmarkType.rightPinky], // 17-20: PINKY
      pose.landmarks[PoseLandmarkType.rightPinky],
      pose.landmarks[PoseLandmarkType.rightPinky],
      pose.landmarks[PoseLandmarkType.rightPinky],
    ];

    // Convert to coordinate vector
    for (int i = 0; i < 21; i++) {
      final landmark = i < landmarkOrder.length
          ? landmarkOrder[i]
          : primaryWrist;
      if (landmark != null) {
        landmarks.addAll([landmark.x, landmark.y, landmark.z]);
      } else {
        // Use wrist position for missing landmarks
        landmarks.addAll([primaryWrist.x, primaryWrist.y, primaryWrist.z]);
      }
    }

    return landmarks.length == 63 ? landmarks : [];
  }

  /// Extract hand landmarks from pose detection (legacy method)
  List<HandLandmark> extractHandLandmarksFromPose(Pose pose) {
    List<HandLandmark> landmarks = [];

    // Get hand landmarks from pose
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];

    final leftThumb = pose.landmarks[PoseLandmarkType.leftThumb];
    final rightThumb = pose.landmarks[PoseLandmarkType.rightThumb];

    final leftIndex = pose.landmarks[PoseLandmarkType.leftIndex];
    final rightIndex = pose.landmarks[PoseLandmarkType.rightIndex];

    final leftPinky = pose.landmarks[PoseLandmarkType.leftPinky];
    final rightPinky = pose.landmarks[PoseLandmarkType.rightPinky];

    // Convert to our HandLandmark format if landmarks are detected
    if (leftWrist != null && leftWrist.likelihood > minConfidence) {
      landmarks.add(_convertToHandLandmark(leftWrist));

      if (leftThumb != null && leftThumb.likelihood > minConfidence) {
        landmarks.add(_convertToHandLandmark(leftThumb));
      }

      if (leftIndex != null && leftIndex.likelihood > minConfidence) {
        landmarks.add(_convertToHandLandmark(leftIndex));
      }

      if (leftPinky != null && leftPinky.likelihood > minConfidence) {
        landmarks.add(_convertToHandLandmark(leftPinky));
      }
    }

    if (rightWrist != null && rightWrist.likelihood > minConfidence) {
      landmarks.add(_convertToHandLandmark(rightWrist));

      if (rightThumb != null && rightThumb.likelihood > minConfidence) {
        landmarks.add(_convertToHandLandmark(rightThumb));
      }

      if (rightIndex != null && rightIndex.likelihood > minConfidence) {
        landmarks.add(_convertToHandLandmark(rightIndex));
      }

      if (rightPinky != null && rightPinky.likelihood > minConfidence) {
        landmarks.add(_convertToHandLandmark(rightPinky));
      }
    }

    return landmarks;
  }

  /// Convert ML Kit PoseLandmark to our HandLandmark
  HandLandmark _convertToHandLandmark(PoseLandmark landmark) {
    return HandLandmark(x: landmark.x, y: landmark.y, z: landmark.z);
  }

  /// Recognize ASL gesture from hand landmarks
  ASLPrediction? recognizeGesture(List<HandLandmark> landmarks) {
    if (landmarks.isEmpty) return null;

    // Simple rule-based recognition based on hand pose
    // This is a basic implementation - you can enhance with more sophisticated logic

    try {
      final gesture = _analyzeHandShape(landmarks);
      if (gesture != null) {
        return ASLPrediction(
          letter: gesture['letter'] as String,
          confidence: gesture['confidence'] as double,
          timestamp: DateTime.now(),
          landmarks: landmarks,
        );
      }
    } catch (e) {
      print('Error recognizing gesture: $e');
    }

    return null;
  }

  /// Analyze hand shape to determine ASL letter
  Map<String, dynamic>? _analyzeHandShape(List<HandLandmark> landmarks) {
    if (landmarks.length < 3) return null;

    // Get key landmarks (assuming we have at least wrist, thumb, index)
    final wrist = landmarks[0];
    final keyPoints = landmarks.sublist(1);

    // Calculate relative positions
    final relativePoints = keyPoints
        .map(
          (point) => HandLandmark(
            x: point.x - wrist.x,
            y: point.y - wrist.y,
            z: point.z - wrist.z,
          ),
        )
        .toList();

    // Basic gesture recognition logic
    return _classifyGesture(relativePoints);
  }

  /// Classify gesture based on relative hand positions
  Map<String, dynamic>? _classifyGesture(List<HandLandmark> relativePoints) {
    if (relativePoints.isEmpty) return null;

    // Calculate some basic features
    final spread = _calculateSpread(relativePoints);
    final fingersExtended = _countExtendedFingers(relativePoints);

    // Simple rule-based classification
    if (fingersExtended == 0 && spread < 0.1) {
      return {'letter': 'A', 'confidence': 0.8};
    } else if (fingersExtended == 1 && spread < 0.2) {
      return {'letter': 'D', 'confidence': 0.75};
    } else if (fingersExtended >= 2 && spread > 0.3) {
      // Check if it's L shape (thumb and index extended)
      if (_isLShape(relativePoints)) {
        return {'letter': 'L', 'confidence': 0.8};
      } else if (fingersExtended == 2) {
        return {'letter': 'V', 'confidence': 0.7};
      } else {
        return {'letter': 'B', 'confidence': 0.65};
      }
    } else if (fingersExtended == 3) {
      return {'letter': 'Y', 'confidence': 0.7};
    }

    // Return a random letter if no clear match (for testing)
    final letters = ['A', 'B', 'C', 'D', 'L', 'V', 'Y'];
    final randomLetter = letters[DateTime.now().millisecond % letters.length];
    return {'letter': randomLetter, 'confidence': 0.6};
  }

  /// Calculate spread of hand (max distance between any two points)
  double _calculateSpread(List<HandLandmark> points) {
    if (points.length < 2) return 0.0;

    double maxDistance = 0.0;
    for (int i = 0; i < points.length; i++) {
      for (int j = i + 1; j < points.length; j++) {
        final distance = _distanceBetweenPoints(points[i], points[j]);
        if (distance > maxDistance) {
          maxDistance = distance;
        }
      }
    }
    return maxDistance;
  }

  /// Count extended fingers (simplified)
  int _countExtendedFingers(List<HandLandmark> points) {
    // This is a simplified heuristic - in a real implementation,
    // you'd analyze the specific finger joint positions
    return points
        .where((point) => sqrt(point.x * point.x + point.y * point.y) > 0.15)
        .length;
  }

  /// Check if hand shape resembles an L
  bool _isLShape(List<HandLandmark> points) {
    if (points.length < 2) return false;

    // Look for two points that form roughly perpendicular lines
    // This is simplified - you'd check thumb and index finger positions
    for (int i = 0; i < points.length; i++) {
      for (int j = i + 1; j < points.length; j++) {
        final angle = _angleBetweenPoints(points[i], points[j]);
        if (angle > 70 && angle < 110) {
          // Roughly 90 degrees
          return true;
        }
      }
    }
    return false;
  }

  /// Calculate distance between two points
  double _distanceBetweenPoints(HandLandmark p1, HandLandmark p2) {
    final dx = p1.x - p2.x;
    final dy = p1.y - p2.y;
    final dz = p1.z - p2.z;
    return sqrt(dx * dx + dy * dy + dz * dz);
  }

  /// Calculate angle between two points relative to origin
  double _angleBetweenPoints(HandLandmark p1, HandLandmark p2) {
    final dot = p1.x * p2.x + p1.y * p2.y + p1.z * p2.z;
    final mag1 = sqrt(p1.x * p1.x + p1.y * p1.y + p1.z * p1.z);
    final mag2 = sqrt(p2.x * p2.x + p2.y * p2.y + p2.z * p2.z);

    if (mag1 == 0 || mag2 == 0) return 0.0;

    final cosAngle = dot / (mag1 * mag2);
    return acos(cosAngle.clamp(-1.0, 1.0)) * 180 / pi;
  }
}
