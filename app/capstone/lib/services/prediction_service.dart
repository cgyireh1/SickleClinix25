import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_service.dart';
import 'package:firebase_storage/firebase_storage.dart';

class PredictionResult {
  final String id;
  final String prediction;
  final double confidence;
  final String imagePath;
  final DateTime timestamp;
  final bool isSynced;
  final double rawScore;
  final bool isSickleCell;
  final String? patientId;
  final String? patientName;
  final String? healthworkerId;
  final String? heatmapUrl;

  PredictionResult({
    required this.id,
    required this.prediction,
    required this.confidence,
    required this.imagePath,
    required this.timestamp,
    this.isSynced = false,
    required this.rawScore,
    required this.isSickleCell,
    this.patientId,
    this.patientName,
    this.healthworkerId,
    this.heatmapUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'prediction': prediction,
      'confidence': confidence,
      'imagePath': imagePath,
      'timestamp': timestamp.toIso8601String(),
      'isSynced': isSynced,
      'rawScore': rawScore,
      'isSickleCell': isSickleCell,
      'patientId': patientId,
      'patientName': patientName,
      'healthworkerId': healthworkerId,
      'heatmapUrl': heatmapUrl,
    };
  }

  factory PredictionResult.fromMap(Map<String, dynamic> map) {
    return PredictionResult(
      id: map['id'] as String,
      imagePath: map['imagePath'] as String,
      prediction: map['prediction'] as String,
      confidence: map['confidence'] as double,
      timestamp: DateTime.parse(map['timestamp'] as String),
      isSynced: (map['synced'] as int) == 1,
      rawScore: (map['rawScore'] as num?)?.toDouble() ?? 0.0,
      isSickleCell: map['isSickleCell'] as bool? ?? false,
      patientId: map['patientId'] as String?,
      patientName: map['patientName'] as String?,
      healthworkerId: map['healthworkerId'] as String?,
      heatmapUrl: map['heatmapUrl'] as String?,
    );
  }
}

class PredictionService {
  static final PredictionService _instance = PredictionService._internal();
  factory PredictionService({FirebaseService? firebaseService}) {
    _instance._firebaseService = firebaseService ?? FirebaseService();
    return _instance;
  }
  PredictionService._internal();

  late FirebaseService _firebaseService;

  Database? _localDatabase;
  Interpreter? _interpreter;
  Interpreter? _gradCamInterpreter;
  final int _inputSize = 224;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  Database? get localDatabase => _localDatabase;
  Interpreter? get interpreter => _interpreter;
  Database? get database => _localDatabase;

  Future<void> initialize({bool forceRecreate = false}) async {
    try {
      if (forceRecreate) {
        await _forceDatabaseRecreation();
      } else {
        await _initializeDatabase();
      }
      await _loadModel();
      await _firebaseService.initialize();
      print('PredictionService initialized successfully');
      await _migrateIsSickleCellFlag();
    } catch (e) {
      print('Error initializing PredictionService: $e');
      rethrow;
    }
  }

  Future<void> _migrateIsSickleCellFlag() async {
    if (_localDatabase == null) return;
    final results = await _localDatabase!.query('predictions');
    for (final row in results) {
      String prediction = row['prediction'] as String? ?? '';
      String analysisMetadataRaw = row['analysisMetadata'] as String? ?? '{}';
      Map<String, dynamic> metadata = {};
      try {
        metadata = jsonDecode(analysisMetadataRaw);
      } catch (_) {}
      if (metadata['isSickleCell'] == null) {
        final isSickle = prediction.toLowerCase().contains('sickle');
        metadata['isSickleCell'] = isSickle;
        await _localDatabase!.update(
          'predictions',
          {'analysisMetadata': jsonEncode(metadata)},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    }
    print('Migration: isSickleCell flag ensured for all predictions');
  }

  Future<void> _forceDatabaseRecreation() async {
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final dbPath = path.join(
        documentsDirectory.path,
        'sickleclinix_offline.db',
      );

      print('Force recreating database at: $dbPath');
      await _localDatabase?.close();

      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        await dbFile.delete();
        print('Deleted existing database file');
      }

      // Recreate database with new schema
      _localDatabase = await openDatabase(
        dbPath,
        version: 2,
        onCreate: (db, version) async {
          print('Creating database with version: $version');
          await db.execute('''
          CREATE TABLE IF NOT EXISTS predictions (
            id TEXT PRIMARY KEY,
            userId TEXT,
            userEmail TEXT,
            prediction TEXT,
            confidence REAL,
            imagePath TEXT,
            timestamp TEXT,
            modelVersion TEXT,
            deviceInfo TEXT,
            analysisMetadata TEXT,
            synced INTEGER DEFAULT 0,
              cloudId TEXT,
              patientId TEXT,
              patientName TEXT,
            healthworkerId TEXT,
            heatmapUrl TEXT
            )
          ''');
          print('Created predictions table with patient columns');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS user_stats (
              userId TEXT PRIMARY KEY,
              totalPredictions INTEGER DEFAULT 0,
              sickleCellDetected INTEGER DEFAULT 0,
              normalResults INTEGER DEFAULT 0,
              lastUpdated TEXT,
              synced INTEGER DEFAULT 0
          )
        ''');
          print('Created user_stats table');
        },
        onOpen: (db) async {
          print('Database opened successfully');
          // Verify tables exist
          final tables = await db.query(
            'sqlite_master',
            where: 'type = ?',
            whereArgs: ['table'],
          );
          print('Available tables: ${tables.map((t) => t['name']).toList()}');
        },
      );
      print('Database recreation completed successfully');
    } catch (e) {
      print('Error in _forceDatabaseRecreation: $e');
      rethrow;
    }
  }

  Future<void> _initializeDatabase() async {
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final dbPath = path.join(
        documentsDirectory.path,
        'sickleclinix_offline.db',
      );

      print('Initializing database at: $dbPath');

      _localDatabase = await openDatabase(
        dbPath,
        version: 2,
        onCreate: (db, version) async {
          print('Creating database with version: $version');
          await db.execute('''
          CREATE TABLE IF NOT EXISTS predictions (
            id TEXT PRIMARY KEY,
            userId TEXT,
            userEmail TEXT,
            prediction TEXT,
            confidence REAL,
            imagePath TEXT,
            imageUrl TEXT,
            timestamp TEXT,
            modelVersion TEXT,
            deviceInfo TEXT,
            analysisMetadata TEXT,
            synced INTEGER DEFAULT 0,
            cloudId TEXT,
            patientId TEXT,
            patientName TEXT,
            healthworkerId TEXT,
            heatmapUrl TEXT
          )
          ''');
          print('Created predictions table with patient columns');

          await db.execute('''
            CREATE TABLE IF NOT EXISTS user_stats (
              userId TEXT PRIMARY KEY,
              totalPredictions INTEGER DEFAULT 0,
              sickleCellDetected INTEGER DEFAULT 0,
              normalResults INTEGER DEFAULT 0,
              lastUpdated TEXT,
              synced INTEGER DEFAULT 0
          )
        ''');
          print('Created user_stats table');
        },
        onOpen: (db) async {
          print('Database opened successfully');
          // Verify tables exist
          final tables = await db.query(
            'sqlite_master',
            where: 'type = ?',
            whereArgs: ['table'],
          );
          print('Available tables: ${tables.map((t) => t['name']).toList()}');
        },
      );
      print('Database initialization completed successfully');
    } catch (e) {
      print('Error in _initializeDatabase: $e');
      rethrow;
    }
  }

  Future<void> _loadModel() async {
    try {
      // Load main model
      _interpreter = await Interpreter.fromAsset(
        'assets/models/sickleclinix_model.tflite',
        options: InterpreterOptions()..threads = 4,
      );

      // Load Grad-CAM model
      _gradCamInterpreter = await Interpreter.fromAsset(
        'assets/models/sickleclinix_model.tflite',
        options: InterpreterOptions()..threads = 4,
      );

      _isLoaded = true;

      if (kDebugMode) {
        print('Model loaded successfully');
        _printModelDetails();
      }
    } catch (e) {
      throw Exception('Failed to load model: $e');
    }
  }

  void _printModelDetails() {
    if (_interpreter != null) {
      print('Input shape: ${_interpreter!.getInputTensor(0).shape}');
      print('Output shape: ${_interpreter!.getOutputTensor(0).shape}');
    }
  }

  List<List<List<double>>> _preprocessImage(img.Image image) {
    // Resize image to 224x224
    final resizedImage = img.copyResize(
      image,
      width: _inputSize,
      height: _inputSize,
    );

    // Convert to grayscale and normalize
    final inputArray = List.generate(
      1,
      (batch) => List.generate(
        _inputSize,
        (y) => List.generate(_inputSize, (x) {
          final pixel = resizedImage.getPixel(x, y);
          final gray = (pixel.r + pixel.g + pixel.b) / 3.0;
          return gray / 255.0; // Normalize to [0, 1]
        }),
      ),
    );

    return inputArray;
  }

  Future<List<PredictionResult>> getHistory({
    int page = 1,
    int limit = 20,
  }) async {
    if (_localDatabase == null) return [];

    try {
      final user = _firebaseService.currentUser;
      final offset = (page - 1) * limit;

      final results = await _localDatabase!.query(
        'predictions',
        where: 'userId = ?',
        whereArgs: [user?.uid ?? 'anonymous'],
        orderBy: 'timestamp DESC',
        limit: limit,
        offset: offset,
      );

      return results.map((row) {
        Map<String, dynamic> metadata = {};
        try {
          metadata = jsonDecode(row['analysisMetadata'] as String? ?? '{}');
        } catch (e) {
          print('Error parsing metadata: $e');
        }

        return PredictionResult(
          id: row['id'] as String,
          prediction: row['prediction'] as String,
          confidence: (row['confidence'] as num).toDouble(),
          imagePath: row['imagePath'] as String,
          timestamp: DateTime.parse(row['timestamp'] as String),
          isSynced: (row['synced'] as int) == 1,
          rawScore: (metadata['rawScore'] as num?)?.toDouble() ?? 0.0,
          isSickleCell: metadata['isSickleCell'] as bool? ?? false,
          patientId: row['patientId'] as String?,
          patientName: row['patientName'] as String?,
          healthworkerId: row['healthworkerId'] as String?,
          heatmapUrl: row['heatmapUrl'] as String?,
        );
      }).toList();
    } catch (e) {
      print('Error getting history: $e');
      return [];
    }
  }

  Future<void> savePrediction(
    PredictionResult result,
    String userId,
    String userEmail,
  ) async {
    if (_localDatabase == null) return;

    try {
      final predictionData = {
        'id': result.id,
        'userId': userId,
        'userEmail': userEmail,
        'prediction': result.prediction,
        'confidence': result.confidence,
        'imagePath': result.imagePath,
        'imageUrl': null,
        'timestamp': result.timestamp.toIso8601String(),
        'modelVersion': '1.0',
        'deviceInfo': 'Flutter/Android',
        'analysisMetadata': jsonEncode({
          'rawScore': result.rawScore,
          'isSickleCell': result.isSickleCell,
        }),
        'synced': result.isSynced ? 1 : 0,
        'patientId': result.patientId,
        'patientName': result.patientName,
        'healthworkerId': result.healthworkerId,
        'heatmapUrl': result.heatmapUrl,
      };

      await _localDatabase!.insert('predictions', predictionData);
      await _updateUserStats(result, userId);
    } catch (e) {
      print('Error saving prediction: $e');
      rethrow;
    }
  }

  Future<void> _updateUserStats(PredictionResult result, String userId) async {
    if (_localDatabase == null) return;

    try {
      final existingStats = await _localDatabase!.query(
        'user_stats',
        where: 'userId = ?',
        whereArgs: [userId],
      );

      if (existingStats.isEmpty) {
        await _localDatabase!.insert('user_stats', {
          'userId': userId,
          'totalPredictions': 1,
          'sickleCellDetected': result.isSickleCell ? 1 : 0,
          'normalResults': result.isSickleCell ? 0 : 1,
          'lastUpdated': DateTime.now().toIso8601String(),
          'synced': 0,
        });
      } else {
        final stats = existingStats.first;
        final totalPredictions = (stats['totalPredictions'] as int) + 1;
        final sickleCellDetected =
            (stats['sickleCellDetected'] as int) +
            (result.isSickleCell ? 1 : 0);
        final normalResults =
            (stats['normalResults'] as int) + (result.isSickleCell ? 0 : 1);

        await _localDatabase!.update(
          'user_stats',
          {
            'totalPredictions': totalPredictions,
            'sickleCellDetected': sickleCellDetected,
            'normalResults': normalResults,
            'lastUpdated': DateTime.now().toIso8601String(),
            'synced': 0,
          },
          where: 'userId = ?',
          whereArgs: [userId],
        );
      }
    } catch (e) {
      print('Error updating user stats: $e');
    }
  }

  Future<void> clearHistory() async {
    if (_localDatabase == null) return;

    try {
      final user = _firebaseService.currentUser;
      await _localDatabase!.delete(
        'predictions',
        where: 'userId = ?',
        whereArgs: [user?.uid ?? 'anonymous'],
      );
      print('History cleared successfully');
    } catch (e) {
      print('Error clearing history: $e');
      rethrow;
    }
  }

  Future<void> deleteHistoryItem(String itemId) async {
    if (_localDatabase == null) return;

    try {
      await _localDatabase!.delete(
        'predictions',
        where: 'id = ?',
        whereArgs: [itemId],
      );
      print('History item deleted successfully');
    } catch (e) {
      print('Error deleting history item: $e');
      rethrow;
    }
  }

  Future<void> syncToCloud() async {
    if (_localDatabase == null) return;

    final user = _firebaseService.currentUser;
    if (user == null) return;

    try {
      final unsyncedPredictions = await _localDatabase!.query(
        'predictions',
        where: 'synced = ? AND userId = ?',
        whereArgs: [0, user.uid],
        orderBy: 'timestamp ASC',
      );

      print(
        'Found  [32m${unsyncedPredictions.length} [0m unsynced predictions',
      );

      for (final prediction in unsyncedPredictions) {
        try {
          String? imageUrl;
          final imagePath = prediction['imagePath'] as String;
          if (File(imagePath).existsSync()) {
            final imageBytes = await File(imagePath).readAsBytes();
            final fileName =
                'predictions/${user.uid}/${prediction['id'] as String}${path.extension(imagePath)}';
            imageUrl = await _firebaseService.uploadFile(fileName, imageBytes);
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
            'modelVersion': prediction['modelVersion'],
            'deviceInfo': prediction['deviceInfo'],
            'heatmapUrl': prediction['heatmapUrl'],
          };

          await _firebaseService.syncData(
            'predictions',
            prediction['id'] as String,
            cloudData,
          );

          await _localDatabase!.update(
            'predictions',
            {
              'synced': 1,
              'cloudId': prediction['id'] as String,
              'imageUrl': imageUrl,
            },
            where: 'id = ?',
            whereArgs: [prediction['id'] as String],
          );

          print('Synced prediction: ${prediction['id']}');
        } catch (e) {
          print('Failed to sync prediction ${prediction['id']}: $e');
        }
      }
      await _syncGradCamImagesToCloud();
    } catch (e) {
      print('Error syncing to cloud: $e');
    }
  }

  Future<void> _syncGradCamImagesToCloud() async {
    if (_localDatabase == null) return;
    final user = _firebaseService.currentUser;
    if (user == null) return;
    final results = await _localDatabase!.query(
      'predictions',
      where: 'userId = ?',
      whereArgs: [user.uid],
    );
    for (final row in results) {
      final heatmapUrl = row['heatmapUrl'] as String?;
      if (heatmapUrl != null &&
          !heatmapUrl.startsWith('http') &&
          File(heatmapUrl).existsSync()) {
        try {
          final file = File(heatmapUrl);
          final fileName =
              'gradcam_results/${user.uid}_${row['id']}${path.extension(heatmapUrl)}';
          debugPrint('Uploading Grad-CAM to Firebase: $fileName');

          final storageRef = FirebaseStorage.instance.ref().child(fileName);
          final uploadTask = storageRef.putFile(file);
          final snapshot = await uploadTask;
          final downloadUrl = await snapshot.ref.getDownloadURL();

          debugPrint(
            'Successfully uploaded Grad-CAM to Firebase: $downloadUrl',
          );

          await _localDatabase!.update(
            'predictions',
            {'heatmapUrl': downloadUrl},
            where: 'id = ?',
            whereArgs: [row['id']],
          );
          print('Synced Grad-CAM for prediction ${row['id']} to cloud');
        } catch (e) {
          debugPrint('Failed to sync Grad-CAM for prediction ${row['id']}: $e');

          if (e.toString().contains('object-not-found') ||
              e.toString().contains('AppCheck') ||
              e.toString().contains('permission-denied') ||
              e.toString().contains('security')) {
            debugPrint(
              'Grad-CAM sync blocked by security settings. Keeping local storage only.',
            );
            continue;
          }
        }
      }
    }
  }

  Future<void> updatePredictionPatient(
    String predictionId,
    dynamic patient,
  ) async {
    if (_localDatabase == null) return;
    await _localDatabase!.update(
      'predictions',
      {'patientId': patient.id, 'patientName': patient.name},
      where: 'id = ?',
      whereArgs: [predictionId],
    );
  }

  Future<void> updateGradCamUrl(String predictionId, String gradcamUrl) async {
    if (_localDatabase == null) return;
    await _localDatabase!.update(
      'predictions',
      {'heatmapUrl': gradcamUrl},
      where: 'id = ?',
      whereArgs: [predictionId],
    );
  }

  Future<PredictionResult> predictImage(File imageFile) async {
    throw UnimplementedError('Image prediction not implemented yet');
  }

  Future<String?> generateGradCam(File imageFile) async {
    throw UnimplementedError('Grad-CAM generation not implemented yet');
  }
}
