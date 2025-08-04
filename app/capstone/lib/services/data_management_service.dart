import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:archive/archive.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/patient.dart';
import '../models/user_profile.dart';
import '../screens/auth/auth_manager.dart';
import 'prediction_service.dart';

enum ExportFormat { json, csv, pdf, zip }

enum DataType { patients, predictions, userProfile, settings, analytics, all }

enum ExportStatus { preparing, processing, completed, failed }

enum BackupStatus { local, cloud, both, none }

class DataManagementService {
  static final DataManagementService _instance =
      DataManagementService._internal();
  factory DataManagementService() => _instance;
  DataManagementService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final PredictionService _predictionService = PredictionService();

  Future<void> initialize() async {
    await _predictionService.initialize();
    await _ensureBackupDirectory();
  }

  Future<void> _ensureBackupDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(path.join(appDir.path, 'backups'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }
  }

  Future<Map<String, dynamic>> exportAllData({
    ExportFormat format = ExportFormat.json,
    bool includeImages = true,
    bool includeMetadata = true,
  }) async {
    try {
      final user = await AuthManager.getCurrentUser();
      if (user == null) throw Exception('User not authenticated');

      final exportData = <String, dynamic>{
        'exportInfo': {
          'timestamp': DateTime.now().toIso8601String(),
          'format': format.name,
          'version': '1.0.0',
          'userEmail': user.email,
          'includeImages': includeImages,
          'includeMetadata': includeMetadata,
        },
        'userProfile': await _exportUserProfile(),
        'patients': await _exportPatients(),
        'predictions': await _exportPredictions(includeImages, includeMetadata),
        'analytics': await _exportAnalytics(),
        'settings': await _exportSettings(),
      };

      return exportData;
    } catch (e) {
      debugPrint('Error exporting data: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _exportUserProfile() async {
    final user = await AuthManager.getCurrentUser();
    if (user == null) return {};

    return {
      'profile': user.toJson(),
      'exportedAt': DateTime.now().toIso8601String(),
    };
  }

  /// Export patients data
  Future<List<Map<String, dynamic>>> _exportPatients() async {
    try {
      final box = Hive.box<Patient>('patients');
      final patients = box.values.toList();

      return patients
          .map(
            (patient) => {
              'patient': patient.toJson(),
              'exportedAt': DateTime.now().toIso8601String(),
            },
          )
          .toList();
    } catch (e) {
      debugPrint('Error exporting patients: $e');
      return [];
    }
  }

  /// Export predictions data
  Future<List<Map<String, dynamic>>> _exportPredictions(
    bool includeImages,
    bool includeMetadata,
  ) async {
    try {
      final predictions = await _predictionService.getHistory();

      return await Future.wait(
        predictions.map((prediction) async {
          final exportData = <String, dynamic>{
            'prediction': prediction.toMap(),
            'exportedAt': DateTime.now().toIso8601String(),
          };

          if (includeImages && File(prediction.imagePath).existsSync()) {
            final imageFile = File(prediction.imagePath);
            final imageBytes = await imageFile.readAsBytes();
            exportData['image'] = base64Encode(imageBytes);
            exportData['imageFormat'] = path
                .extension(prediction.imagePath)
                .toLowerCase();
          }

          if (includeMetadata) {
            exportData['metadata'] = {
              'fileSize': File(prediction.imagePath).lengthSync(),
              'imageDimensions': await _getImageDimensions(
                prediction.imagePath,
              ),
              'deviceInfo': await _getDeviceInfo(),
            };
          }

          return exportData;
        }),
      );
    } catch (e) {
      debugPrint('Error exporting predictions: $e');
      return [];
    }
  }

  /// Export analytics data
  Future<Map<String, dynamic>> _exportAnalytics() async {
    try {
      final predictions = await _predictionService.getHistory();
      final patients = Hive.box<Patient>('patients').values.toList();

      final analytics = {
        'summary': {
          'totalPredictions': predictions.length,
          'totalPatients': patients.length,
          'sickleCellDetected': predictions.where((p) => p.isSickleCell).length,
          'normalResults': predictions.where((p) => !p.isSickleCell).length,
          'averageConfidence': predictions.isEmpty
              ? 0.0
              : predictions.map((p) => p.confidence).reduce((a, b) => a + b) /
                    predictions.length,
        },
        'timeline': {
          'firstPrediction': predictions.isEmpty
              ? null
              : predictions
                    .map((p) => p.timestamp)
                    .reduce((a, b) => a.isBefore(b) ? a : b)
                    .toIso8601String(),
          'lastPrediction': predictions.isEmpty
              ? null
              : predictions
                    .map((p) => p.timestamp)
                    .reduce((a, b) => a.isAfter(b) ? a : b)
                    .toIso8601String(),
        },
        'exportedAt': DateTime.now().toIso8601String(),
      };

      return analytics;
    } catch (e) {
      debugPrint('Error exporting analytics: $e');
      return {};
    }
  }

  /// Export settings data
  Future<Map<String, dynamic>> _exportSettings() async {
    try {
      return {
        'settings': {
          'notificationsEnabled': true,
          'autoSyncEnabled': true,
          'highQualityImages': true,
        },
        'exportedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error exporting settings: $e');
      return {};
    }
  }

  Future<String> createBackup({
    BackupStatus backupType = BackupStatus.both,
    bool includeImages = true,
  }) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupId = 'backup_$timestamp';

      // Export data
      final exportData = await exportAllData(
        includeImages: includeImages,
        includeMetadata: true,
      );

      final backupFile = await _createBackupFile(backupId, exportData);
      if (backupType == BackupStatus.cloud || backupType == BackupStatus.both) {
        await _uploadBackupToCloud(backupFile, backupId);
      }

      return backupFile.path;
    } catch (e) {
      debugPrint('Error creating backup: $e');
      rethrow;
    }
  }

  /// Create backup file
  Future<File> _createBackupFile(
    String backupId,
    Map<String, dynamic> data,
  ) async {
    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(path.join(appDir.path, 'backups'));
    final backupPath = path.join(backupDir.path, '$backupId.zip');
    final jsonData = jsonEncode(data);
    final jsonBytes = utf8.encode(jsonData);

    final archive = Archive();
    final archiveFile = ArchiveFile('data.json', jsonData.length, jsonBytes);
    archive.addFile(archiveFile);

    final predictions = await _predictionService.getHistory();
    for (final prediction in predictions) {
      final imageFile = File(prediction.imagePath);
      if (await imageFile.exists()) {
        final imageBytes = await imageFile.readAsBytes();
        final imageArchiveFile = ArchiveFile(
          'images/${prediction.id}${path.extension(prediction.imagePath)}',
          imageBytes.length,
          imageBytes,
        );
        archive.addFile(imageArchiveFile);
      }
    }

    final zipData = ZipEncoder().encode(archive);

    final backupFile = File(backupPath);
    await backupFile.writeAsBytes(zipData);

    return backupFile;
  }

  Future<void> _uploadBackupToCloud(File backupFile, String backupId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final ref = _storage
          .ref()
          .child('backups')
          .child(user.uid)
          .child('$backupId.zip');

      await ref.putFile(backupFile);

      await _firestore
          .collection('backups')
          .doc(user.uid)
          .collection('backup_history')
          .doc(backupId)
          .set({
            'backupId': backupId,
            'timestamp': FieldValue.serverTimestamp(),
            'fileSize': await backupFile.length(),
            'status': 'completed',
          });
    } catch (e) {
      debugPrint('Error uploading backup to cloud: $e');
      rethrow;
    }
  }

  Future<void> restoreFromBackup(String backupPath) async {
    try {
      final backupFile = File(backupPath);
      if (!await backupFile.exists()) {
        throw Exception('Backup file not found');
      }

      final zipBytes = await backupFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(zipBytes);

      final dataFile = archive.findFile('data.json');
      if (dataFile == null)
        throw Exception('Invalid backup file: data.json not found');

      final jsonString = utf8.decode(dataFile.content as List<int>);
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      await _validateBackup(data);
      await _restoreData(data);
      await _restoreImages(archive);
    } catch (e) {
      debugPrint('Error restoring from backup: $e');
      rethrow;
    }
  }

  /// Validate backup data
  Future<void> _validateBackup(Map<String, dynamic> data) async {
    if (!data.containsKey('exportInfo')) {
      throw Exception('Invalid backup: missing export info');
    }

    final exportInfo = data['exportInfo'] as Map<String, dynamic>;
    if (!exportInfo.containsKey('timestamp')) {
      throw Exception('Invalid backup: missing timestamp');
    }

    final backupDate = DateTime.parse(exportInfo['timestamp']);
    final daysSinceBackup = DateTime.now().difference(backupDate).inDays;
    if (daysSinceBackup > 365) {
      throw Exception('Backup is too old (${daysSinceBackup} days)');
    }
  }

  /// Restore data from backup
  Future<void> _restoreData(Map<String, dynamic> data) async {
    try {
      // Restore user profile
      if (data.containsKey('userProfile')) {
        await _restoreUserProfile(data['userProfile']);
      }

      if (data.containsKey('patients')) {
        await _restorePatients(data['patients']);
      }

      if (data.containsKey('predictions')) {
        await _restorePredictions(data['predictions']);
      }

      if (data.containsKey('settings')) {
        await _restoreSettings(data['settings']);
      }
    } catch (e) {
      debugPrint('Error restoring data: $e');
      rethrow;
    }
  }

  /// Restore user profile
  Future<void> _restoreUserProfile(Map<String, dynamic> userData) async {
    if (userData.containsKey('profile')) {
      final profile = UserProfile.fromJson(userData['profile']);
      await AuthManager.updateProfile(profile);
    }
  }

  /// Restore patients
  Future<void> _restorePatients(List<dynamic> patientsData) async {
    final box = Hive.box<Patient>('patients');

    for (final patientData in patientsData) {
      if (patientData.containsKey('patient')) {
        final patient = Patient.fromJson(patientData['patient']);
        await box.put(patient.id, patient);
      }
    }
  }

  /// Restore predictions
  Future<void> _restorePredictions(List<dynamic> predictionsData) async {
    debugPrint('Prediction restoration not implemented yet');
  }

  /// Restore settings
  Future<void> _restoreSettings(Map<String, dynamic> settingsData) async {
    debugPrint('Settings restoration not implemented yet');
  }

  /// Restore images from backup
  Future<void> _restoreImages(Archive archive) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(path.join(appDir.path, 'images'));
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      for (final file in archive.files) {
        if (file.name.startsWith('images/')) {
          final imagePath = path.join(imagesDir.path, path.basename(file.name));
          final imageFile = File(imagePath);
          await imageFile.writeAsBytes(file.content as List<int>);
        }
      }
    } catch (e) {
      debugPrint('Error restoring images: $e');
      rethrow;
    }
  }

  /// Get backup list
  Future<List<Map<String, dynamic>>> getBackupList() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final snapshot = await _firestore
          .collection('backups')
          .doc(user.uid)
          .collection('backup_history')
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'timestamp': data['timestamp']?.toDate()?.toIso8601String(),
          'fileSize': data['fileSize'],
          'status': data['status'],
        };
      }).toList();
    } catch (e) {
      debugPrint('Error getting backup list: $e');
      return [];
    }
  }

  /// Delete backup
  Future<void> deleteBackup(String backupId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');
      await _firestore
          .collection('backups')
          .doc(user.uid)
          .collection('backup_history')
          .doc(backupId)
          .delete();
      final ref = _storage
          .ref()
          .child('backups')
          .child(user.uid)
          .child('$backupId.zip');

      await ref.delete();
    } catch (e) {
      debugPrint('Error deleting backup: $e');
      rethrow;
    }
  }

  Future<File> exportToFile({
    ExportFormat format = ExportFormat.json,
    DataType dataType = DataType.all,
    bool includeImages = false,
  }) async {
    try {
      final data = await exportAllData(
        format: format,
        includeImages: includeImages,
        includeMetadata: true,
      );

      final appDir = await getApplicationDocumentsDirectory();
      final exportDir = Directory(path.join(appDir.path, 'exports'));
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'export_${dataType.name}_$timestamp.${format.name}';
      final filePath = path.join(exportDir.path, fileName);

      File exportFile;
      switch (format) {
        case ExportFormat.json:
          final jsonString = jsonEncode(data);
          exportFile = File(filePath);
          await exportFile.writeAsString(jsonString);
          break;
        case ExportFormat.csv:
          final csvString = _convertToCSV(data);
          exportFile = File(filePath);
          await exportFile.writeAsString(csvString);
          break;
        case ExportFormat.zip:
          exportFile = await _createBackupFile('export_$timestamp', data);
          break;
        default:
          throw Exception('Unsupported export format');
      }

      return exportFile;
    } catch (e) {
      debugPrint('Error exporting to file: $e');
      rethrow;
    }
  }

  String _convertToCSV(Map<String, dynamic> data) {
    final buffer = StringBuffer();
    buffer.writeln('Data Type,Field,Value');
    _addToCSV(buffer, data, '');

    return buffer.toString();
  }

  void _addToCSV(StringBuffer buffer, dynamic data, String prefix) {
    if (data is Map) {
      for (final entry in data.entries) {
        final key = entry.key;
        final value = entry.value;
        final fullKey = prefix.isEmpty ? key : '$prefix.$key';

        if (value is Map || value is List) {
          _addToCSV(buffer, value, fullKey);
        } else {
          buffer.writeln('$fullKey,$value');
        }
      }
    } else if (data is List) {
      for (int i = 0; i < data.length; i++) {
        final item = data[i];
        final fullKey = '$prefix[$i]';
        _addToCSV(buffer, item, fullKey);
      }
    } else {
      buffer.writeln('$prefix,$data');
    }
  }

  /// Get data statistics
  Future<Map<String, dynamic>> getDataStatistics() async {
    try {
      final predictions = await _predictionService.getHistory();
      final patients = Hive.box<Patient>('patients').values.toList();
      final user = await AuthManager.getCurrentUser();

      return {
        'user': {
          'email': user?.email ?? 'Unknown',
          'name': user?.fullName ?? 'Unknown',
          'facility': user?.facilityName ?? 'Unknown',
        },
        'data': {
          'totalPredictions': predictions.length,
          'totalPatients': patients.length,
          'sickleCellDetected': predictions.where((p) => p.isSickleCell).length,
          'normalResults': predictions.where((p) => !p.isSickleCell).length,
          'averageConfidence': predictions.isEmpty
              ? 0.0
              : predictions.map((p) => p.confidence).reduce((a, b) => a + b) /
                    predictions.length,
        },
        'storage': {
          'localDatabaseSize': await _getDatabaseSize(),
          'imageStorageSize': await _getImageStorageSize(),
          'totalStorageSize': await _getTotalStorageSize(),
        },
        'sync': {
          'syncedPredictions': predictions.where((p) => p.isSynced).length,
          'unsyncedPredictions': predictions.where((p) => !p.isSynced).length,
          'lastSync': await _getLastSyncTime(),
        },
        'generatedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error getting data statistics: $e');
      return {};
    }
  }

  /// Get database size
  Future<int> _getDatabaseSize() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final dbPath = path.join(appDir.path, 'sickleclinix_offline.db');
      final dbFile = File(dbPath);
      return await dbFile.exists() ? await dbFile.length() : 0;
    } catch (e) {
      return 0;
    }
  }

  /// Get image storage size
  Future<int> _getImageStorageSize() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(path.join(appDir.path, 'images'));
      if (!await imagesDir.exists()) return 0;

      int totalSize = 0;
      await for (final file in imagesDir.list(recursive: true)) {
        if (file is File) {
          totalSize += await file.length();
        }
      }
      return totalSize;
    } catch (e) {
      return 0;
    }
  }

  /// Get total storage size
  Future<int> _getTotalStorageSize() async {
    final dbSize = await _getDatabaseSize();
    final imageSize = await _getImageStorageSize();
    return dbSize + imageSize;
  }

  /// Get last sync time
  Future<String?> _getLastSyncTime() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore.collection('users').doc(user.uid).get();

      final data = doc.data();
      return data?['lastUpdated']?.toDate()?.toIso8601String();
    } catch (e) {
      return null;
    }
  }

  /// Get image dimensions
  Future<Map<String, int>?> _getImageDimensions(String imagePath) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) return null;
      return {'width': 0, 'height': 0};
    } catch (e) {
      return null;
    }
  }

  /// Get device info
  Future<Map<String, String>> _getDeviceInfo() async {
    return {
      'platform': Platform.operatingSystem,
      'version': Platform.operatingSystemVersion,
      'locale': Platform.localeName,
    };
  }

  /// Clean up old data
  Future<void> cleanupOldData({
    int daysToKeep = 365,
    bool includeImages = true,
  }) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));

      // Clean up old predictions
      final predictions = await _predictionService.getHistory();
      final oldPredictions = predictions.where(
        (p) => p.timestamp.isBefore(cutoffDate),
      );

      for (final prediction in oldPredictions) {
        await _predictionService.deleteHistoryItem(prediction.id);

        if (includeImages) {
          final imageFile = File(prediction.imagePath);
          if (await imageFile.exists()) {
            await imageFile.delete();
          }
        }
      }

      await _cleanupOldBackups(5);
    } catch (e) {
      debugPrint('Error cleaning up old data: $e');
      rethrow;
    }
  }

  /// Clean up old backups
  Future<void> _cleanupOldBackups(int keepCount) async {
    try {
      final backups = await getBackupList();
      if (backups.length <= keepCount) return;

      final backupsToDelete = backups.skip(keepCount);
      for (final backup in backupsToDelete) {
        await deleteBackup(backup['id']);
      }
    } catch (e) {
      debugPrint('Error cleaning up old backups: $e');
    }
  }

  Future<bool> requestStoragePermissions() async {
    try {
      final status = await Permission.storage.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('Error requesting storage permissions: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> checkDataIntegrity() async {
    try {
      final issues = <String, List<String>>{};

      // Check predictions
      final predictions = await _predictionService.getHistory();
      final missingImages = <String>[];

      for (final prediction in predictions) {
        final imageFile = File(prediction.imagePath);
        if (!await imageFile.exists()) {
          missingImages.add(prediction.id);
        }
      }

      if (missingImages.isNotEmpty) {
        issues['missing_images'] = missingImages;
      }

      // Check patients
      final patients = Hive.box<Patient>('patients').values.toList();
      final invalidPatients = <String>[];

      for (final patient in patients) {
        if (patient.name.isEmpty || patient.age <= 0) {
          invalidPatients.add(patient.id);
        }
      }

      if (invalidPatients.isNotEmpty) {
        issues['invalid_patients'] = invalidPatients;
      }

      return {
        'hasIssues': issues.isNotEmpty,
        'issues': issues,
        'checkedAt': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      debugPrint('Error checking data integrity: $e');
      return {
        'hasIssues': true,
        'issues': {
          'error': [e.toString()],
        },
        'checkedAt': DateTime.now().toIso8601String(),
      };
    }
  }
}
