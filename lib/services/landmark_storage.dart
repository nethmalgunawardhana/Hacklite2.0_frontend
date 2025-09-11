import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

/// Service for storing and loading hand landmark data for training
class LandmarkStorage {
  static const String _fileName = 'hand_landmarks.jsonl';

  /// Get the file path for storing landmarks
  Future<String> get _filePath async {
    final directory = await getApplicationDocumentsDirectory();
    final landmarkDir = Directory('${directory.path}/hand_data');
    if (!await landmarkDir.exists()) {
      await landmarkDir.create(recursive: true);
    }
    return '${landmarkDir.path}/$_fileName';
  }

  /// Save a landmark example to storage
  Future<void> saveExample({
    required String label,
    required List<double> landmarks,
  }) async {
    try {
      final file = File(await _filePath);
      final example = {
        'label': label,
        'landmarks': landmarks,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      // Append as JSONL (one JSON object per line)
      await file.writeAsString(
        '${json.encode(example)}\n',
        mode: FileMode.append,
      );

      print('✅ Saved landmark example: $label');
    } catch (e) {
      print('❌ Error saving landmark example: $e');
      rethrow;
    }
  }

  /// Load all examples from storage
  Future<List<LandmarkExample>> loadExamples() async {
    try {
      final file = File(await _filePath);
      if (!await file.exists()) {
        return [];
      }

      final lines = await file.readAsLines();
      final examples = <LandmarkExample>[];

      for (final line in lines) {
        if (line.trim().isEmpty) continue;

        try {
          final data = json.decode(line) as Map<String, dynamic>;
          examples.add(LandmarkExample.fromJson(data));
        } catch (e) {
          print('⚠️ Skipping invalid line: $line');
        }
      }

      print('✅ Loaded ${examples.length} landmark examples');
      return examples;
    } catch (e) {
      print('❌ Error loading landmark examples: $e');
      return [];
    }
  }

  /// Get count of examples per label
  Future<Map<String, int>> getExampleCounts() async {
    final examples = await loadExamples();
    final counts = <String, int>{};

    for (final example in examples) {
      counts[example.label] = (counts[example.label] ?? 0) + 1;
    }

    return counts;
  }

  /// Export data as JSON for external use
  Future<String> exportData() async {
    final examples = await loadExamples();
    return json.encode(examples.map((e) => e.toJson()).toList());
  }

  /// Clear all stored data
  Future<void> clearData() async {
    try {
      final file = File(await _filePath);
      if (await file.exists()) {
        await file.delete();
      }
      print('✅ Cleared all landmark data');
    } catch (e) {
      print('❌ Error clearing data: $e');
      rethrow;
    }
  }

  /// Import data from JSON string
  Future<void> importData(String jsonData) async {
    try {
      final data = json.decode(jsonData) as List<dynamic>;
      final file = File(await _filePath);

      // Clear existing data
      if (await file.exists()) {
        await file.delete();
      }

      // Write imported data
      for (final item in data) {
        await file.writeAsString(
          '${json.encode(item)}\n',
          mode: FileMode.append,
        );
      }

      print('✅ Imported ${data.length} landmark examples');
    } catch (e) {
      print('❌ Error importing data: $e');
      rethrow;
    }
  }

  /// Get file size and path for debugging
  Future<Map<String, dynamic>> getStorageInfo() async {
    try {
      final file = File(await _filePath);
      final exists = await file.exists();
      final size = exists ? await file.length() : 0;
      final examples = await loadExamples();

      return {
        'path': await _filePath,
        'exists': exists,
        'sizeBytes': size,
        'exampleCount': examples.length,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}

/// Data class for landmark examples
class LandmarkExample {
  final String label;
  final List<double> landmarks;
  final int timestamp;

  LandmarkExample({
    required this.label,
    required this.landmarks,
    required this.timestamp,
  });

  factory LandmarkExample.fromJson(Map<String, dynamic> json) {
    return LandmarkExample(
      label: json['label'] as String,
      landmarks: (json['landmarks'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
      timestamp: json['timestamp'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {'label': label, 'landmarks': landmarks, 'timestamp': timestamp};
  }

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);
}
