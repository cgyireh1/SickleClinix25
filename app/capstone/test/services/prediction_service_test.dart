import 'package:flutter_test/flutter_test.dart';
import 'package:capstone/services/prediction_service.dart';
import 'package:capstone/services/firebase_service.dart';

class MockFirebaseService extends Fake implements FirebaseService {}

void main() {
  group('PredictionService (mocked)', () {
    late PredictionService predictionService;

    setUp(() {
      predictionService = PredictionService(
        firebaseService: MockFirebaseService(),
      );
    });

    test('can be instantiated with a mock', () {
      expect(predictionService, isNotNull);
    });

    test('getHistory returns empty list if no local database', () async {
      final service = PredictionService(firebaseService: MockFirebaseService());
      expect(await service.getHistory(), isEmpty);
    });

    test('PredictionResult serializes and deserializes', () {
      final now = DateTime.now();
      final result = PredictionResult(
        id: 'pred1',
        prediction: 'Normal',
        confidence: 98.5,
        imagePath: '/tmp/image.png',
        timestamp: now,
        rawScore: 0.98,
        isSickleCell: false,
        patientId: '2',
        patientName: 'Caroline Gyireh',
        healthworkerId: 'hw1',
        heatmapUrl: null,
      );
      final map = result.toMap();
      final fromMap = PredictionResult.fromMap({
        ...map,
        'id': 'pred1',
        'timestamp': now.toIso8601String(),
        'confidence': 98.5,
        'synced': 0,
      });
      expect(fromMap.prediction, 'Normal');
      expect(fromMap.patientName, 'Caroline Gyireh');
    });
  });
}
