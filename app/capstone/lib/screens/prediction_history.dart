import 'dart:io';

class PredictionHistory {
  final String id;
  final String prediction;
  final double confidence;
  final String imagePath;
  final DateTime timestamp;
  final bool isSynced;
  final String? patientName;
  final String? patientId;
  final String healthworkerId;
  final String? heatmapUrl;

  PredictionHistory({
    required this.id,
    required this.prediction,
    required this.confidence,
    required this.imagePath,
    required this.timestamp,
    required this.isSynced,
    this.patientName,
    this.patientId,
    this.healthworkerId = '',
    this.heatmapUrl,
  });

  File get imageFile => File(imagePath);

  factory PredictionHistory.fromMap(Map<String, dynamic> map) {
    return PredictionHistory(
      id: map['id'] as String,
      prediction: map['prediction'] as String,
      confidence: (map['confidence'] as num).toDouble(),
      imagePath: map['imagePath'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      isSynced: (map['synced'] as int) == 1,
      patientName: map['patientName'] as String?,
      patientId: map['patientId'] as String?,
      healthworkerId: map['healthworkerId'] as String? ?? '',
      heatmapUrl: map['heatmapUrl'] as String?,
    );
  }
}
