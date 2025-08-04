import 'dart:io';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/prediction_service.dart';

class PredictionRepository {
  Database? _database;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final PredictionService _predictionService = PredictionService();

  Future<void> initialize() async {
    await _predictionService.initialize();
    _database = _predictionService.localDatabase;
  }

  Future<String> saveLocally(
    PredictionResult result,
    File imageFile, {
    String? patientId,
    String? patientName,
    String? healthworkerId,
  }) async {
    if (_database == null) {
      print('Database not initialized, attempting to initialize...');
      await initialize();
      if (_database == null) {
        throw Exception('Failed to initialize database');
      }
    }

    final user = _auth.currentUser;
    final predictionId =
        '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecondsSinceEpoch}';

    print('Saving prediction with ID: $predictionId');

    try {
      // Save image locally
      final localImagePath = await _saveImageLocally(imageFile, predictionId);
      print('Image saved to: $localImagePath');

      // Save prediction data
      final predictionData = {
        'id': predictionId,
        'userId': user?.uid ?? 'anonymous',
        'userEmail': user?.email ?? 'anonymous@example.com',
        'prediction': result.prediction,
        'confidence': result.confidence,
        'imagePath': localImagePath,
        'timestamp': DateTime.now().toIso8601String(),
        'modelVersion': '1.0',
        'deviceInfo': 'Flutter/Web',
        'analysisMetadata': jsonEncode({
          'rawScore': result.rawScore,
          'isSickleCell': result.isSickleCell,
        }),
        'synced': 0,
        'patientId': patientId,
        'patientName': patientName,
        'healthworkerId': healthworkerId ?? user?.uid,
      };

      await _database!.insert('predictions', predictionData);
      print('Prediction data saved to database');

      await _updateUserStats(result);
      print('User stats updated');

      return predictionId;
    } catch (e) {
      print('Error in saveLocally: $e');
      rethrow;
    }
  }

  Future<String> _saveImageLocally(File imageFile, String predictionId) async {
    final appDir = await getApplicationDocumentsDirectory();
    final fileName =
        'prediction_${predictionId}_${path.basename(imageFile.path)}';
    final localImagePath = path.join(appDir.path, 'images', fileName);

    final imagesDir = Directory(path.dirname(localImagePath));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    await imageFile.copy(localImagePath);
    return localImagePath;
  }

  Future<void> _updateUserStats(PredictionResult result) async {
    final user = _auth.currentUser;
    final userId = user?.uid ?? 'anonymous';

    await _database!.rawUpdate(
      '''
      INSERT OR REPLACE INTO user_stats (
        userId, totalPredictions, sickleCellDetected, normalResults, lastUpdated, synced
      ) VALUES (
        ?, 
        COALESCE((SELECT totalPredictions FROM user_stats WHERE userId = ?), 0) + 1,
        COALESCE((SELECT sickleCellDetected FROM user_stats WHERE userId = ?), 0) + ?,
        COALESCE((SELECT normalResults FROM user_stats WHERE userId = ?), 0) + ?,
        ?, 0
      )
      ''',
      [
        userId,
        userId,
        userId,
        result.isSickleCell ? 1 : 0,
        userId,
        result.isSickleCell ? 0 : 1,
        DateTime.now().toIso8601String(),
      ],
    );
  }

  Future<void> syncToCloud() async {
    if (_database == null) return;

    final user = _auth.currentUser;
    if (user == null) return;

    final unsyncedPredictions = await _database!.query(
      'predictions',
      where: 'synced = ? AND userId = ?',
      whereArgs: [0, user.uid],
      orderBy: 'timestamp ASC',
    );

    for (final prediction in unsyncedPredictions) {
      try {
        // Upload image to storage
        String? imageUrl;
        final imagePath = prediction['imagePath'] as String;
        if (File(imagePath).existsSync()) {
          imageUrl = await _uploadImage(File(imagePath));
        }
        Map<String, dynamic> metadata = {};
        try {
          metadata = jsonDecode(prediction['analysisMetadata'] as String);
        } catch (e) {
          if (kDebugMode) print('Failed to parse metadata: $e');
        }

        // Save to Firestore
        final cloudData = {
          'userId': prediction['userId'],
          'userEmail': prediction['userEmail'],
          'prediction': prediction['prediction'],
          'confidence': prediction['confidence'],
          'imageUrl': imageUrl,
          'timestamp': FieldValue.serverTimestamp(),
          'metadata': metadata,
          'localId': prediction['id'],
          'patientId': prediction['patientId'],
          'patientName': prediction['patientName'],
          'healthworkerId': prediction['healthworkerId'],
        };

        final docRef = await _firestore
            .collection('predictions')
            .add(cloudData);

        // Mark as synced
        await _database!.update(
          'predictions',
          {'synced': 1, 'cloudId': docRef.id},
          where: 'id = ?',
          whereArgs: [prediction['id']],
        );
      } catch (e) {
        if (kDebugMode) print('Failed to sync prediction: $e');
      }
    }

    // Sync user stats
    await _syncUserStats();
  }

  Future<String?> _uploadImage(File imageFile) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('No authenticated user for image upload');
        return null;
      }

      if (!imageFile.existsSync()) {
        debugPrint('Image file does not exist: ${imageFile.path}');
        return null;
      }

      final fileName =
          'predictions/${user.uid}/${DateTime.now().millisecondsSinceEpoch}_${path.basename(imageFile.path)}';
      final ref = _storage.ref().child(fileName);

      debugPrint('Uploading prediction image: $fileName');

      final snapshot = await ref.putFile(imageFile);
      final downloadUrl = await snapshot.ref.getDownloadURL();

      debugPrint('Successfully uploaded prediction image: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('Failed to upload image: $e');
      if (e.toString().contains('object-not-found') ||
          e.toString().contains('AppCheck') ||
          e.toString().contains('permission-denied') ||
          e.toString().contains('security')) {
        debugPrint(
          'Upload blocked by security settings. Using local storage only.',
        );
        return imageFile.path;
      }

      return null;
    }
  }

  Future<void> _syncUserStats() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final localStats = await _database!.query(
        'user_stats',
        where: 'userId = ?',
        whereArgs: [user.uid],
      );

      if (localStats.isNotEmpty) {
        final stats = localStats.first;
        await _firestore.collection('userStats').doc(user.uid).set({
          'totalPredictions': stats['totalPredictions'],
          'sickleCellDetected': stats['sickleCellDetected'],
          'normalResults': stats['normalResults'],
          'lastPredictionDate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await _database!.update(
          'user_stats',
          {'synced': 1},
          where: 'userId = ?',
          whereArgs: [user.uid],
        );
      }
    } catch (e) {
      if (kDebugMode) print('Failed to sync user stats: $e');
    }
  }

  void dispose() {
    _database?.close();
  }
}
