import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  bool get isAuthenticated => _auth.currentUser != null;

  /// Get current user
  User? get currentUser => _auth.currentUser;

  Future<bool> get isOnline async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        if (kDebugMode) {
          print('No network connectivity detected');
        }
        return false;
      }

      try {
        await _auth.authStateChanges().first.timeout(
          const Duration(seconds: 2),
          onTimeout: () => throw Exception('Connection timeout'),
        );
        return true;
      } catch (e) {
        if (kDebugMode) {
          print('Firebase connection check failed: $e');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Connectivity check failed: $e');
      }
      return false;
    }
  }

  /// Initialize Firebase service
  Future<void> initialize() async {
    try {
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      if (kDebugMode) {
        print('Firebase service initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing Firebase service: $e');
      }
      rethrow;
    }
  }

  /// Sync data to Firestore
  Future<void> syncData(
    String collection,
    String documentId,
    Map<String, dynamic> data,
  ) async {
    try {
      if (!await isOnline) {
        if (kDebugMode) {
          print('Offline - data will be synced when online');
        }
        return;
      }

      await _firestore
          .collection(collection)
          .doc(documentId)
          .set(data, SetOptions(merge: true));

      if (kDebugMode) {
        print('Data synced to $collection/$documentId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error syncing data: $e');
      }
      rethrow;
    }
  }

  /// Get data from Firestore
  Future<Map<String, dynamic>?> getData(
    String collection,
    String documentId,
  ) async {
    try {
      if (!await isOnline) {
        if (kDebugMode) {
          print('Offline - cannot fetch data');
        }
        return null;
      }

      final doc = await _firestore.collection(collection).doc(documentId).get();

      return doc.data();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting data: $e');
      }
      return null;
    }
  }

  /// Upload file to Firebase Storage
  Future<String?> uploadFile(String path, dynamic fileBytes) async {
    try {
      if (!await isOnline) {
        if (kDebugMode) {
          print('Offline - file will be uploaded when online');
        }
        return null;
      }

      // Convert List<int> to Uint8List
      Uint8List bytes;
      if (fileBytes is List<int>) {
        bytes = Uint8List.fromList(fileBytes);
      } else if (fileBytes is Uint8List) {
        bytes = fileBytes;
      } else {
        throw ArgumentError('fileBytes must be List<int> or Uint8List');
      }

      final ref = _storage.ref().child(path);
      final uploadTask = ref.putData(bytes);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      if (kDebugMode) {
        print('File uploaded to $path');
      }

      return downloadUrl;
    } catch (e) {
      if (kDebugMode) {
        print('Error uploading file: $e');
      }
      return null;
    }
  }

  Future<void> deleteFile(String path) async {
    try {
      if (!await isOnline) {
        if (kDebugMode) {
          print('Offline - file will be deleted when online');
        }
        return;
      }

      final ref = _storage.ref().child(path);
      await ref.delete();

      if (kDebugMode) {
        print('File deleted from $path');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting file: $e');
      }
      rethrow;
    }
  }

  /// Query Firestore collection
  Future<List<Map<String, dynamic>>> queryCollection(
    String collection, {
    String? field,
    dynamic value,
    int? limit,
  }) async {
    try {
      if (!await isOnline) {
        if (kDebugMode) {
          print('Offline - cannot query collection');
        }
        return [];
      }

      Query query = _firestore.collection(collection);

      if (field != null && value != null) {
        query = query.where(field, isEqualTo: value);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error querying collection: $e');
      }
      return [];
    }
  }

  Future<void> deleteDocument(String collection, String documentId) async {
    try {
      if (!await isOnline) {
        if (kDebugMode) {
          print('Offline - document will be deleted when online');
        }
        return;
      }

      await _firestore.collection(collection).doc(documentId).delete();

      if (kDebugMode) {
        print('Document deleted from $collection/$documentId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting document: $e');
      }
      rethrow;
    }
  }

  /// Get user-specific data
  Future<List<Map<String, dynamic>>> getUserData(String collection) async {
    try {
      final user = currentUser;
      if (user == null) return [];

      return await queryCollection(
        collection,
        field: 'healthworkerId',
        value: user.uid,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user data: $e');
      }
      return [];
    }
  }

  Future<void> batchWrite(List<Map<String, dynamic>> operations) async {
    try {
      if (!await isOnline) {
        if (kDebugMode) {
          print('Offline - batch operations will be performed when online');
        }
        return;
      }

      final batch = _firestore.batch();

      for (final operation in operations) {
        final collection = operation['collection'] as String;
        final documentId = operation['documentId'] as String;
        final data = operation['data'] as Map<String, dynamic>;
        final type = operation['type'] as String;

        final docRef = _firestore.collection(collection).doc(documentId);

        switch (type) {
          case 'set':
            batch.set(docRef, data, SetOptions(merge: true));
            break;
          case 'update':
            batch.update(docRef, data);
            break;
          case 'delete':
            batch.delete(docRef);
            break;
        }
      }

      await batch.commit();

      if (kDebugMode) {
        print('Batch write completed: ${operations.length} operations');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in batch write: $e');
      }
      rethrow;
    }
  }
}
