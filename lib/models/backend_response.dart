/// Response model from backend ASL prediction API
class BackendResponse {
  final List<PredictionItem> predictions;
  final PredictionItem? topPrediction;
  final String? predictedLabel;
  final String? assembledText;

  BackendResponse({
    required this.predictions,
    this.topPrediction,
    this.predictedLabel,
    this.assembledText,
  });

  factory BackendResponse.fromJson(Map<String, dynamic> json) {
    final predictionsList = json['predictions'] as List<dynamic>? ?? [];
    final predictions = predictionsList
        .map((item) => PredictionItem.fromJson(item as Map<String, dynamic>))
        .toList();

    PredictionItem? topPrediction;
    if (json['top_prediction'] != null) {
      topPrediction = PredictionItem.fromJson(
        json['top_prediction'] as Map<String, dynamic>,
      );
    }

    return BackendResponse(
      predictions: predictions,
      topPrediction: topPrediction,
      predictedLabel: json['predicted_label'] as String?,
      assembledText: json['assembled_text'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'predictions': predictions.map((p) => p.toJson()).toList(),
      'top_prediction': topPrediction?.toJson(),
      'predicted_label': predictedLabel,
      'assembled_text': assembledText,
    };
  }
}

/// Individual prediction item with label and confidence score
class PredictionItem {
  final String label;
  final double score;

  PredictionItem({required this.label, required this.score});

  factory PredictionItem.fromJson(Map<String, dynamic> json) {
    return PredictionItem(
      label: json['label'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'label': label, 'score': score};
  }

  @override
  String toString() {
    return 'PredictionItem(label: $label, score: ${score.toStringAsFixed(3)})';
  }
}
