import 'package:capstone/screens/prediction_history.dart';
import 'package:capstone/services/prediction_service.dart';
import 'package:flutter/foundation.dart';

class HistoryService {
  static final PredictionService _predictionService = PredictionService();

  static Future<List<PredictionHistory>> loadHistory({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final results = await _predictionService.getHistory(
        page: page,
        limit: limit,
      );

      return results
          .map(
            (result) => PredictionHistory(
              id: result.id,
              imagePath: result.imagePath,
              prediction: result.prediction,
              confidence: result.confidence,
              timestamp: result.timestamp,
              isSynced: result.isSynced,
              patientId: result.patientId,
              patientName: result.patientName,
              healthworkerId: result.healthworkerId ?? '',
              heatmapUrl: result.heatmapUrl,
            ),
          )
          .toList()
          .cast<PredictionHistory>();
    } catch (e) {
      debugPrint('Error loading history: $e');
      return [];
    }
  }

  static Future<void> saveHistory(PredictionHistory record) async {}

  static Future<void> clearHistory() async {
    try {
      await _predictionService.clearHistory();
    } catch (e) {
      debugPrint('Error clearing history: $e');
      rethrow;
    }
  }

  static Future<void> deleteHistoryItem(String itemId) async {
    try {
      await _predictionService.deleteHistoryItem(itemId);
    } catch (e) {
      debugPrint('Error deleting history item: $e');
      rethrow;
    }
  }

  static Future<void> updatePredictionPatient(
    String predictionId,
    dynamic patient,
  ) async {
    await _predictionService.updatePredictionPatient(predictionId, patient);
  }
}
