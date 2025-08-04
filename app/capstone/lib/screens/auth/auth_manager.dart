import 'dart:convert';
import 'dart:async';
// import 'dart:developer';
import 'dart:io';
import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:capstone/models/user_profile.dart';
import 'package:flutter/foundation.dart';
import '../../screens/notifications_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:capstone/models/patient.dart';
// import 'package:capstone/screens/prediction_history.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class AuthManager {
  // Storage instances
  static final _storage = const FlutterSecureStorage();
  static final _auth = FirebaseAuth.instance;
  static final _firestore = FirebaseFirestore.instance;

  // Storage keys
  static const _usersKey = 'local_users';
  static const _syncQueueKey = 'sync_queue';
  static const _currentUserKey = 'current_user';
  static const _sessionKey = 'session_data';

  // Session configuration
  static const Duration _sessionTimeout = Duration(hours: 2);
  static const Duration _maxSessionDuration = Duration(days: 7);

  // Session management
  static Future<void> _saveSessionData(DateTime loginTime) async {
    final sessionData = {
      'loginTime': loginTime.toIso8601String(),
      'lastActivity': DateTime.now().toIso8601String(),
    };
    await _storage.write(key: _sessionKey, value: json.encode(sessionData));
  }

  static Future<Map<String, dynamic>?> _getSessionData() async {
    try {
      final sessionJson = await _storage.read(key: _sessionKey);
      return sessionJson != null ? json.decode(sessionJson) : null;
    } catch (e) {
      debugPrint('Error reading session data: $e');
      return null;
    }
  }

  static Future<void> _updateLastActivity() async {
    final sessionData = await _getSessionData();
    if (sessionData != null) {
      sessionData['lastActivity'] = DateTime.now().toIso8601String();
      await _storage.write(key: _sessionKey, value: json.encode(sessionData));
    }
  }

  static Future<bool> isSessionValid() async {
    try {
      final sessionData = await _getSessionData();
      if (sessionData == null) return false;

      final loginTime = DateTime.parse(sessionData['loginTime']);
      final lastActivity = DateTime.parse(sessionData['lastActivity']);
      final now = DateTime.now();

      if (now.difference(loginTime) > _maxSessionDuration) {
        debugPrint('Session expired: exceeded maximum duration');
        await _clearSession();
        return false;
      }

      if (now.difference(lastActivity) > _sessionTimeout) {
        debugPrint('Session expired: exceeded timeout duration');
        await _clearSession();
        return false;
      }

      await _updateLastActivity();
      return true;
    } catch (e) {
      debugPrint('Error checking session validity: $e');
      return false;
    }
  }

  static Future<void> _clearSession() async {
    await _storage.delete(key: _sessionKey);
    await _storage.delete(key: _currentUserKey);
    debugPrint('Session cleared');
  }

  static Future<void> clearCorruptedData() async {
    try {
      await Hive.close();
      final appDir = await getApplicationDocumentsDirectory();
      final hiveDir = Directory('${appDir.path}/hive');
      if (await hiveDir.exists()) {
        await hiveDir.delete(recursive: true);
        debugPrint('Hive data cleared');
      }

      // Reinitialize Hive
      await Hive.initFlutter();
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(PatientAdapter());
      }
    } catch (e) {
      debugPrint('Error clearing corrupted data: $e');
    }
  }

  static Future<Duration> getSessionRemainingTime() async {
    try {
      final sessionData = await _getSessionData();
      if (sessionData == null) return Duration.zero;

      final lastActivity = DateTime.parse(sessionData['lastActivity']);
      final now = DateTime.now();
      final timeSinceLastActivity = now.difference(lastActivity);
      final remainingTime = _sessionTimeout - timeSinceLastActivity;

      return remainingTime.isNegative ? Duration.zero : remainingTime;
    } catch (e) {
      debugPrint('Error getting session remaining time: $e');
      return Duration.zero;
    }
  }

  static Future<Duration> getMaxSessionRemainingTime() async {
    try {
      final sessionData = await _getSessionData();
      if (sessionData == null) return Duration.zero;

      final loginTime = DateTime.parse(sessionData['loginTime']);
      final now = DateTime.now();
      final timeSinceLogin = now.difference(loginTime);
      final remainingTime = _maxSessionDuration - timeSinceLogin;

      return remainingTime.isNegative ? Duration.zero : remainingTime;
    } catch (e) {
      debugPrint('Error getting max session remaining time: $e');
      return Duration.zero;
    }
  }

  static Duration getSessionTimeout() => _sessionTimeout;
  static Duration getMaxSessionDuration() => _maxSessionDuration;

  // Secure password hashing using bcrypt
  static String _hashPassword(String password) {
    return BCrypt.hashpw(password, BCrypt.gensalt());
  }

  static bool _verifyPassword(String password, String hash) {
    return BCrypt.checkpw(password, hash);
  }

  // Connectivity check
  static Future<bool> get isOnline async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) return false;

      //internet connectivity test
      try {
        final result = await InternetAddress.lookup('google.com');
        return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      } catch (e) {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // User management
  static Future<UserProfile?> getCurrentUser() async {
    try {
      final userJson = await _storage.read(key: _currentUserKey);
      return userJson != null
          ? UserProfile.fromJson(json.decode(userJson))
          : null;
    } catch (e) {
      await _storage.delete(key: _currentUserKey);
      return null;
    }
  }

  static Future<UserProfile?> getCurrentUserWithSessionCheck() async {
    try {
      // First check if session is valid
      final sessionValid = await isSessionValid();
      if (!sessionValid) {
        debugPrint('Session is not valid, user needs to login again');
        return null;
      }

      final user = await getCurrentUser();
      if (user != null) {
        await _updateLastActivity();
      }
      return user;
    } catch (e) {
      debugPrint('Error checking user with session: $e');
      return null;
    }
  }

  static Future<void> _setCurrentUser(UserProfile? user) async {
    if (user == null) {
      await _storage.delete(key: _currentUserKey);
    } else {
      await _storage.write(
        key: _currentUserKey,
        value: json.encode(user.toJson()),
      );
    }
  }

  // Authentication
  static Future<void> signUp({
    required String email,
    required String password,
    required String fullName,
    required String facilityName,
    String? phoneNumber,
    String? specialty,
  }) async {
    if (email.trim().isEmpty) {
      throw const FormatException('Email is required');
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email.trim())) {
      throw const FormatException('Invalid email format');
    }

    if (password.length < 8) {
      throw const FormatException('Password must be at least 8 characters');
    }

    if (password.length > 128) {
      throw const FormatException('Password is too long (max 128 characters)');
    }

    final weakPasswords = ['password', '123456', 'qwerty', 'admin', 'user'];
    if (weakPasswords.contains(password.toLowerCase())) {
      throw const FormatException(
        'Password is too weak. Please choose a stronger password',
      );
    }

    if (fullName.trim().isEmpty) {
      throw const FormatException('Full name is required');
    }

    if (facilityName.trim().isEmpty) {
      throw const FormatException('Facility name is required');
    }

    final users = await _getLocalUsers();
    if (users.containsKey(email)) {
      throw Exception('User already exists');
    }

    final userProfile = UserProfile(
      email: email,
      passwordHash: _hashPassword(password),
      fullName: fullName,
      facilityName: facilityName,
      phoneNumber: phoneNumber,
      specialty: specialty,
      firebaseUid: null,
      createdAt: DateTime.now(),
      lastUpdated: DateTime.now(),
      isSynced: false,
    );

    users[email] = userProfile.toJson();
    await _saveLocalUsers(users);
    await _setCurrentUser(userProfile);

    await _addToSyncQueue({
      'type': 'signup',
      'data': {
        'email': email,
        'password': password,
        'profile': userProfile.toJson(),
      },
    });

    if (await isOnline) {
      try {
        await _processSyncQueue();
        final currentUser = await getCurrentUser();
        if (currentUser?.firebaseUid != null) {
          try {
            debugPrint('Attempting to send email verification to: $email');
            final firebaseUser = _auth.currentUser;
            if (firebaseUser != null && firebaseUser.email == email) {
              await firebaseUser.sendEmailVerification();
              debugPrint('Email verification sent successfully to: $email');
            } else {
              debugPrint(
                'Firebase user not found or email mismatch, trying to sign in first',
              );
              final credential = await _auth.signInWithEmailAndPassword(
                email: email,
                password: password,
              );
              await credential.user?.sendEmailVerification();
              debugPrint('Email verification sent after sign in to: $email');
            }

            // Welcome email
            debugPrint('Attempting to send welcome email to: $email');
            await _sendWelcomeEmail(email, fullName);
            debugPrint('Welcome email sent successfully to: $email');
          } catch (e) {
            debugPrint('Failed to send emails: $e');
            debugPrint('Error details: ${e.toString()}');
            debugPrint('Stack trace: ${StackTrace.current}');
          }
        } else {
          debugPrint('Firebase UID not available, skipping email sending');
          debugPrint('Current user: ${currentUser?.email}');
          debugPrint('Firebase UID: ${currentUser?.firebaseUid}');
        }
      } catch (e) {
        debugPrint('Sync failed during signup: $e');
      }
    }
  }

  static Future<bool> login({
    required String email,
    required String password,
  }) async {
    try {
      // Input validation
      if (email.trim().isEmpty) {
        throw const FormatException('Email is required');
      }

      if (password.trim().isEmpty) {
        throw const FormatException('Password is required');
      }

      final users = await _getLocalUsers();
      if (!users.containsKey(email.trim())) {
        throw const FormatException('Invalid email or password');
      }

      final storedHash = users[email.trim()]['passwordHash'];
      if (!_verifyPassword(password, storedHash)) {
        throw const FormatException('Invalid email or password');
      }

      final userProfile = UserProfile.fromJson(users[email]);
      await _setCurrentUser(userProfile);

      // Save session data
      await _saveSessionData(DateTime.now());

      try {
        await _migrateUserData(userProfile.email);
      } catch (e) {
        debugPrint('Data migration failed: $e');
      }

      final welcomeKey = 'welcome_notification_shown_${userProfile.email}';
      final alreadyWelcomed = await _storage.read(key: welcomeKey);
      if (alreadyWelcomed != 'true') {
        await _storage.write(key: welcomeKey, value: 'true');
        final firstName = userProfile.fullName.split(' ').first;
        await addAppNotification(
          title: 'Welcome, $firstName!',
          message:
              'If you need help using the app, tap this notification or check the guides section in the Help & Support page.',
          type: 'system',
          payload: 'help',
        );
      }

      if (await isOnline) {
        try {
          final credential = await _auth.signInWithEmailAndPassword(
            email: email,
            password: password,
          );

          if (userProfile.firebaseUid != credential.user?.uid) {
            final updatedUser = userProfile.copyWith(
              firebaseUid: credential.user?.uid,
              isSynced: true,
              lastUpdated: DateTime.now(),
            );

            users[email] = updatedUser.toJson();
            await _saveLocalUsers(users);
            await _setCurrentUser(updatedUser);
            await _syncUserDataToFirestore(updatedUser);
          }
        } catch (e) {
          debugPrint('Firebase login failed: $e');
        }
      }
      return true;
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
    }
  }

  static Future<void> logout() async {
    await _clearSession();
    // Clear sensitive cached data for privacy
    // await Hive.box<Patient>('patients').clear();
    if (await isOnline) {
      try {
        await _auth.signOut();
      } catch (e) {
        debugPrint('Firebase logout error: $e');
      }
    }
  }

  // Data synchronization
  static Future<void> syncProfileData() async {
    if (!await isOnline) return;

    final currentUser = await getCurrentUser();
    if (currentUser == null || currentUser.firebaseUid == null) return;

    try {
      await _syncUserDataToFirestore(currentUser);
      final users = await _getLocalUsers();
      if (users.containsKey(currentUser.email)) {
        users[currentUser.email] = currentUser
            .copyWith(isSynced: true, lastUpdated: DateTime.now())
            .toJson();
        await _saveLocalUsers(users);
      }
      await _processSyncQueue();
    } catch (e) {
      debugPrint('Sync failed: $e');
    }
  }

  static Future<void> _syncUserDataToFirestore(UserProfile user) async {
    if (user.firebaseUid == null) return;

    try {
      String? finalImageUrl = user.profileImageUrl;
      if (user.profileImageUrl != null &&
          user.profileImageUrl!.startsWith('/') &&
          File(user.profileImageUrl!).existsSync()) {
        try {
          finalImageUrl = await _uploadImageToFirebase(
            File(user.profileImageUrl!),
            user.firebaseUid!,
          );
        } catch (e) {
          debugPrint(
            'Profile image will remain local (Firebase upload not available)',
          );
        }
      }

      await _firestore.collection('users').doc(user.firebaseUid).set({
        'email': user.email,
        'fullName': user.fullName,
        'facilityName': user.facilityName,
        'phoneNumber': user.phoneNumber,
        'specialty': user.specialty,
        'profileImageUrl': finalImageUrl,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (finalImageUrl != user.profileImageUrl) {
        final users = await _getLocalUsers();
        if (users.containsKey(user.email)) {
          users[user.email]['profileImageUrl'] = finalImageUrl;
          users[user.email]['isSynced'] = true;
          await _saveLocalUsers(users);

          final currentUser = await getCurrentUser();
          if (currentUser?.email == user.email) {
            await _setCurrentUser(UserProfile.fromJson(users[user.email]));
          }
        }
      }
    } catch (e) {
      debugPrint('Error syncing user data: $e');
      rethrow;
    }
  }

  static Future<String> _uploadImageToFirebase(
    File imageFile,
    String userId,
  ) async {
    try {
      if (!imageFile.existsSync()) {
        debugPrint('File does not exist:  [31m [1m [4m${imageFile.path} [0m');
        throw Exception('Profile image file does not exist: ${imageFile.path}');
      } else {
        debugPrint(
          'Uploading image for user: $userId, file: ${imageFile.path}',
        );
      }
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_images')
          .child('$userId.jpg');

      final uploadTask = await ref.putFile(imageFile);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Firebase Storage upload failed, using local path');
      return imageFile.path;
    }
  }

  // Helper methods
  static Future<Map<String, dynamic>> _getLocalUsers() async {
    try {
      final jsonString = await _storage.read(key: _usersKey);
      return jsonString != null ? json.decode(jsonString) : {};
    } catch (e) {
      await _storage.delete(key: _usersKey);
      return {};
    }
  }

  static Future<void> updateProfile(UserProfile updatedProfile) async {
    try {
      final users = await _getLocalUsers();
      final email = updatedProfile.email;

      if (!users.containsKey(email)) {
        throw Exception('User not found in local storage');
      }

      users[email] = updatedProfile.toJson();
      await _saveLocalUsers(users);
      await _setCurrentUser(updatedProfile);

      await _addToSyncQueue({
        'type': 'updateProfile',
        'timestamp': DateTime.now().toIso8601String(),
        'data': {'email': email, 'profile': updatedProfile.toJson()},
      });

      if (await isOnline) {
        await _processSyncQueue();
      }
    } catch (e) {
      debugPrint('Error updating profile: $e');
      rethrow;
    }
  }

  static Future<void> checkAndSync() async {
    if (!await isOnline) return;

    try {
      // Process any pending sync operations
      await _processSyncQueue();

      final currentUser = await getCurrentUser();
      if (currentUser != null && !currentUser.isSynced) {
        await syncProfileData();
      }
    } catch (e) {
      debugPrint('Error during checkAndSync: $e');
    }
  }

  static Future<void> sendPasswordResetEmail(String email) async {
    if (!await isOnline) {
      throw Exception('Password reset requires internet connection');
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      throw const FormatException('Invalid email format');
    }

    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint('Error sending password reset email: $e');
      rethrow;
    }
  }

  static Future<void> changePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async {
    // Input validation
    if (email.trim().isEmpty) {
      throw const FormatException('Email is required');
    }

    if (currentPassword.trim().isEmpty) {
      throw const FormatException('Current password is required');
    }

    if (newPassword.length < 8) {
      throw const FormatException('New password must be at least 8 characters');
    }

    if (newPassword.length > 128) {
      throw const FormatException(
        'New password is too long (max 128 characters)',
      );
    }

    final weakPasswords = ['password', '123456', 'qwerty', 'admin', 'user'];
    if (weakPasswords.contains(newPassword.toLowerCase())) {
      throw const FormatException(
        'New password is too weak. Please choose a stronger password',
      );
    }

    try {
      final users = await _getLocalUsers();
      if (!users.containsKey(email.trim())) {
        throw const FormatException('User not found');
      }
      final storedHash = users[email.trim()]['passwordHash'];
      if (!_verifyPassword(currentPassword, storedHash)) {
        throw const FormatException('Current password is incorrect');
      }

      final newHash = _hashPassword(newPassword);
      users[email.trim()]['passwordHash'] = newHash;
      users[email.trim()]['lastUpdated'] = DateTime.now().toIso8601String();
      users[email.trim()]['isSynced'] = false;

      await _saveLocalUsers(users);

      final currentUser = await getCurrentUser();
      if (currentUser?.email == email.trim()) {
        final updatedUser = currentUser!.copyWith(
          passwordHash: newHash,
          lastUpdated: DateTime.now(),
          isSynced: false,
        );
        await _setCurrentUser(updatedUser);
      }

      await _addToSyncQueue({
        'type': 'changePassword',
        'timestamp': DateTime.now().toIso8601String(),
        'data': {'email': email.trim(), 'newPassword': newPassword},
      });

      if (await isOnline) {
        await _processSyncQueue();
      }
    } catch (e) {
      debugPrint('Error changing password: $e');
      rethrow;
    }
  }

  static Future<void> deleteAccount(String email) async {
    try {
      debugPrint('Starting account deletion for: $email');

      final users = await _getLocalUsers();
      if (!users.containsKey(email.trim())) {
        throw const FormatException('User not found');
      }

      final userData = users[email.trim()];
      final firebaseUid = userData?['firebaseUid'];

      await _clearUserData(email.trim());

      users.remove(email.trim());
      await _saveLocalUsers(users);

      final currentUser = await getCurrentUser();
      if (currentUser?.email == email.trim()) {
        await _setCurrentUser(null);
        await _clearSession();
        debugPrint('Cleared current user session');
      }

      if (await isOnline) {
        try {
          if (firebaseUid != null) {
            try {
              await _firestore.collection('users').doc(firebaseUid).delete();
              debugPrint('User document deleted from Firestore for: $email');
              final patientsQuery = await _firestore
                  .collection('patients')
                  .where('userId', isEqualTo: firebaseUid)
                  .get();

              for (final doc in patientsQuery.docs) {
                await doc.reference.delete();
              }
              debugPrint(
                'Deleted ${patientsQuery.docs.length} patients from Firestore for: $email',
              );
              final predictionsQuery = await _firestore
                  .collection('predictions')
                  .where('userId', isEqualTo: firebaseUid)
                  .get();

              for (final doc in predictionsQuery.docs) {
                await doc.reference.delete();
              }
              debugPrint(
                'Deleted ${predictionsQuery.docs.length} predictions from Firestore for: $email',
              );

              final historyQuery = await _firestore
                  .collection('prediction_history')
                  .where('userId', isEqualTo: firebaseUid)
                  .get();

              for (final doc in historyQuery.docs) {
                await doc.reference.delete();
              }
              debugPrint(
                'Deleted ${historyQuery.docs.length} history records from Firestore for: $email',
              );
            } catch (e) {
              debugPrint('Error deleting Firestore data: $e');
            }
          }

          final currentFirebaseUser = _auth.currentUser;
          if (currentFirebaseUser != null &&
              currentFirebaseUser.email == email.trim()) {
            try {
              await currentFirebaseUser.delete();
              debugPrint('Firebase Auth user deleted for: $email');
            } catch (e) {
              debugPrint('Error deleting Firebase Auth user: $e');
              await _auth.signOut();
              debugPrint('Signed out user after deletion failure');
            }
          } else {
            debugPrint(
              'Cannot delete Firebase Auth user - not signed in as the target user',
            );
            debugPrint('Current Firebase user: ${currentFirebaseUser?.email}');
            debugPrint('Target user: $email');
          }
        } catch (e) {
          debugPrint('Error deleting from Firebase: $e');
        }
      }

      await _addToSyncQueue({
        'type': 'deleteAccount',
        'timestamp': DateTime.now().toIso8601String(),
        'data': {'email': email.trim()},
      });

      if (await isOnline) {
        await _processSyncQueue();
      }

      debugPrint('Account deletion completed for: $email');
    } catch (e) {
      debugPrint('Error deleting account: $e');
      rethrow;
    }
  }

  static Future<void> _clearUserData(String email) async {
    try {
      final emailKey = email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      try {
        final userPatientBox = await Hive.openBox<Patient>(
          'patients_$emailKey',
        );
        await userPatientBox.clear();
        await userPatientBox.close();
      } catch (e) {
        debugPrint('Error clearing patient data: $e');
      }

      try {
        final prefs = await SharedPreferences.getInstance();

        final notificationKey = 'notifications_$emailKey';
        await prefs.remove(notificationKey);
        final globalNotifications = prefs.getStringList('notifications') ?? [];
        final filteredNotifications = globalNotifications.where((notification) {
          return !notification.contains(email);
        }).toList();
        await prefs.setStringList('notifications', filteredNotifications);

        debugPrint('Cleared notifications for user: $email');
      } catch (e) {
        debugPrint('Error clearing notifications: $e');
      }
      try {
        final welcomeKey = 'welcome_notification_shown_$email';
        await _storage.delete(key: welcomeKey);
      } catch (e) {
        debugPrint('Error clearing welcome flag: $e');
      }

      try {
        final welcomeEmailKey = 'welcome_email_sent_$email';
        await _storage.delete(key: welcomeEmailKey);
      } catch (e) {
        debugPrint('Error clearing welcome email flag: $e');
      }

      try {
        final onboardingKey = 'onboarding_shown_$email';
        await _storage.delete(key: onboardingKey);
      } catch (e) {
        debugPrint('Error clearing onboarding flag: $e');
      }

      debugPrint('User data cleared for: $email');
    } catch (e) {
      debugPrint('Error clearing user data: $e');
    }
  }

  static Future<void> _saveLocalUsers(Map<String, dynamic> users) async {
    await _storage.write(key: _usersKey, value: json.encode(users));
  }

  static Future<void> _addToSyncQueue(Map<String, dynamic> operation) async {
    final queue = await _getSyncQueue();
    queue.add(operation);
    await _storage.write(key: _syncQueueKey, value: json.encode(queue));
  }

  static Future<List<dynamic>> _getSyncQueue() async {
    try {
      final jsonString = await _storage.read(key: _syncQueueKey);
      return jsonString != null ? json.decode(jsonString) : [];
    } catch (e) {
      await _storage.delete(key: _syncQueueKey);
      return [];
    }
  }

  static Future<void> _processSyncQueue() async {
    final queue = await _getSyncQueue();
    if (queue.isEmpty || !await isOnline) return;

    final failedOperations = [];
    final users = await _getLocalUsers();

    for (final operation in queue) {
      try {
        switch (operation['type']) {
          case 'signup':
            await _processSignupOperation(operation, users);
            break;
          case 'updateProfile':
            await _processProfileUpdate(operation, users);
            break;
          case 'deleteAccount':
            await _processAccountDeletion(operation);
            break;
        }
      } catch (e) {
        debugPrint('Sync failed: ${operation['type']} - $e');
        failedOperations.add(operation);
      }
    }

    await _storage.write(
      key: _syncQueueKey,
      value: json.encode(failedOperations),
    );
  }

  static Future<void> _processSignupOperation(
    Map<String, dynamic> operation,
    Map<String, dynamic> users,
  ) async {
    final email = operation['data']['email'];
    final password = operation['data']['password'];
    final profileData = operation['data']['profile'];

    try {
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      if (methods.isNotEmpty) {
        debugPrint(
          'User already exists in Firebase, attempting sign in: $email',
        );
        final credential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        final updatedProfile = UserProfile.fromJson({
          ...profileData,
          'firebaseUid': credential.user?.uid,
          'isSynced': true,
          'lastUpdated': DateTime.now(),
        });

        users[email] = updatedProfile.toJson();
        await _saveLocalUsers(users);

        final currentUser = await getCurrentUser();
        if (currentUser?.email == email) {
          await _setCurrentUser(updatedProfile);
        }

        await _syncUserDataToFirestore(updatedProfile);
      } else {
        // Create new user
        final credential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        final updatedProfile = UserProfile.fromJson({
          ...profileData,
          'firebaseUid': credential.user?.uid,
          'isSynced': true,
          'lastUpdated': DateTime.now(),
        });

        users[email] = updatedProfile.toJson();
        await _saveLocalUsers(users);

        final currentUser = await getCurrentUser();
        if (currentUser?.email == email) {
          await _setCurrentUser(updatedProfile);
        }

        await _syncUserDataToFirestore(updatedProfile);
      }
    } catch (e) {
      debugPrint('Error in signup operation: $e');
    }
  }

  static Future<void> _processProfileUpdate(
    Map<String, dynamic> operation,
    Map<String, dynamic> users,
  ) async {
    final email = operation['data']['email'];

    if (operation['data'].containsKey('profile')) {
      final profileData = operation['data']['profile'];

      // Handle image upload
      if (profileData['profileImageUrl'] != null &&
          profileData['profileImageUrl'].startsWith('/') &&
          File(profileData['profileImageUrl']).existsSync()) {
        try {
          final imageUrl = await _uploadImageToFirebase(
            File(profileData['profileImageUrl']),
            profileData['firebaseUid'],
          );
          profileData['profileImageUrl'] = imageUrl;
        } catch (e) {
          debugPrint('Failed to upload image during sync: $e');
        }
      }

      profileData['isSynced'] = true;
      profileData['lastUpdated'] = DateTime.now().toIso8601String();

      users[email] = profileData;
      await _saveLocalUsers(users);

      final currentUser = await getCurrentUser();
      if (currentUser?.email == email) {
        await _setCurrentUser(UserProfile.fromJson(profileData));
      }
      // Sync to Firestore
      if (profileData['firebaseUid'] != null) {
        await _firestore
            .collection('users')
            .doc(profileData['firebaseUid'])
            .set({
              'email': profileData['email'],
              'fullName': profileData['fullName'],
              'facilityName': profileData['facilityName'],
              'phoneNumber': profileData['phoneNumber'],
              'specialty': profileData['specialty'],
              'profileImageUrl': profileData['profileImageUrl'],
              'lastUpdated': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      }
    }
  }

  static Future<void> _processAccountDeletion(
    Map<String, dynamic> operation,
  ) async {
    final email = operation['data']['email'];

    try {
      debugPrint('Processing account deletion from sync queue for: $email');
      if (await isOnline) {
        try {
          // Get user data to find Firebase UID
          final users = await _getLocalUsers();
          final userData = users[email];
          final firebaseUid = userData?['firebaseUid'];

          if (firebaseUid != null) {
            try {
              await _firestore.collection('users').doc(firebaseUid).delete();
              debugPrint('Remaining user document deleted for: $email');
              final patientsQuery = await _firestore
                  .collection('patients')
                  .where('userId', isEqualTo: firebaseUid)
                  .get();

              for (final doc in patientsQuery.docs) {
                await doc.reference.delete();
              }
              debugPrint(
                'Deleted ${patientsQuery.docs.length} remaining patients for: $email',
              );

              final predictionsQuery = await _firestore
                  .collection('predictions')
                  .where('userId', isEqualTo: firebaseUid)
                  .get();

              for (final doc in predictionsQuery.docs) {
                await doc.reference.delete();
              }
              debugPrint(
                'Deleted ${predictionsQuery.docs.length} remaining predictions for: $email',
              );

              final historyQuery = await _firestore
                  .collection('prediction_history')
                  .where('userId', isEqualTo: firebaseUid)
                  .get();

              for (final doc in historyQuery.docs) {
                await doc.reference.delete();
              }
              debugPrint(
                'Deleted ${historyQuery.docs.length} remaining history records for: $email',
              );
            } catch (e) {
              debugPrint('Error deleting remaining Firestore data: $e');
            }
          }
        } catch (e) {
          debugPrint('Error processing remaining Firebase deletion: $e');
        }
      }

      debugPrint('Account deletion sync processing completed for: $email');
    } catch (e) {
      debugPrint('Error processing account deletion from sync queue: $e');
    }
  }

  static Future<void> _migrateUserData(String email) async {
    final emailKey = email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    // Patients
    final globalPatientBox = await Hive.openBox<Patient>('patients');
    final userPatientBox = await Hive.openBox<Patient>('patients_$emailKey');
    for (final patient in globalPatientBox.values) {
      if (!userPatientBox.containsKey(patient.id)) {
        await userPatientBox.put(patient.id, patient);
      }
    }
  }

  static Future<void> _sendWelcomeEmail(String email, String fullName) async {
    try {
      final welcomeKey = 'welcome_email_sent_$email';
      final alreadySent = await _storage.read(key: welcomeKey);
      if (alreadySent == 'true') {
        debugPrint('Welcome email already sent to: $email');
        return;
      }

      final welcomeMessage =
          '''
Welcome to SickleClinix, ${fullName.split(' ').first}!

🎉 Your account has been successfully created!

Here's what you can do with SickleClinix:

🔬 **Blood Smear Analysis**
• Upload blood smear images for AI-powered analysis
• Get instant predictions for sickle cell detection
• View detailed Grad-CAM visualizations

👥 **Patient Management**
• Add and manage patient records
• Track patient history and predictions
• Maintain organized healthcare data

📊 **History & Analytics**
• View all your predictions and results
• Track your analysis statistics
• Export data for reporting

🔒 **Security & Privacy**
• Your data is encrypted and secure
• HIPAA-compliant healthcare standards
• Offline functionality for remote areas

💡 **Getting Started**
1. Add your first patient from the Patients tab
2. Try a prediction with a blood smear image
3. Explore the Help & Support section for guides

Need help? Check the Help & Support section in the app or contact our team.

Best regards,
The SickleClinix Team
''';

      await addAppNotification(
        title: 'Welcome to SickleClinix!',
        message:
            'Your account has been created successfully. Tap to learn more about getting started.',
        type: 'welcome',
        payload: 'welcome_guide',
      );

      await _storage.write(key: welcomeKey, value: 'true');

      debugPrint('Welcome email content prepared for: $email');
    } catch (e) {
      debugPrint('Error preparing welcome email: $e');
    }
  }

  static Future<bool> wasWelcomeEmailSent(String email) async {
    try {
      final welcomeKey = 'welcome_email_sent_$email';
      final alreadySent = await _storage.read(key: welcomeKey);
      return alreadySent == 'true';
    } catch (e) {
      debugPrint('Error checking welcome email status: $e');
      return false;
    }
  }

  static Future<bool> isEmailVerified() async {
    try {
      final user = _auth.currentUser;
      return user?.emailVerified ?? false;
    } catch (e) {
      debugPrint('Error checking email verification: $e');
      return false;
    }
  }

  static Future<void> resendEmailVerification() async {
    try {
      debugPrint('Attempting to resend email verification...');
      final user = _auth.currentUser;
      if (user != null) {
        debugPrint('Current user found: ${user.email}');
        debugPrint('Email verified status: ${user.emailVerified}');

        if (!user.emailVerified) {
          debugPrint('Sending email verification to: ${user.email}');
          await user.sendEmailVerification();
          debugPrint('Email verification resent successfully');
        } else {
          debugPrint('Email is already verified');
        }
      } else {
        debugPrint('No current user found');
      }
    } catch (e) {
      debugPrint('Error resending email verification: $e');
      debugPrint('Error details: ${e.toString()}');
      debugPrint('Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> testFirebaseConnection() async {
    final results = <String, dynamic>{};

    try {
      debugPrint('Testing Firebase connection...');

      try {
        final app = Firebase.app();
        results['firebase_initialized'] = true;
        results['project_id'] = app.options.projectId;
        debugPrint('Firebase initialized: ${app.options.projectId}');
      } catch (e) {
        results['firebase_initialized'] = false;
        results['firebase_error'] = e.toString();
        debugPrint('Firebase not initialized: $e');
        return results;
      }
      final user = _auth.currentUser;
      if (user != null) {
        results['current_user'] = user.email;
        results['email_verified'] = user.emailVerified;
        results['user_id'] = user.uid;
        debugPrint(
          'Current user: ${user.email} (verified: ${user.emailVerified})',
        );
      } else {
        results['current_user'] = null;
        debugPrint('No current user');
      }

      if (user != null && !user.emailVerified) {
        try {
          await user.sendEmailVerification();
          results['email_verification_sent'] = true;
          debugPrint('Email verification sent successfully');
        } catch (e) {
          results['email_verification_sent'] = false;
          results['email_verification_error'] = e.toString();
          debugPrint('Failed to send email verification: $e');
        }
      } else if (user != null && user.emailVerified) {
        results['email_verification_sent'] = 'already_verified';
        debugPrint('ℹEmail already verified');
      } else {
        results['email_verification_sent'] = 'no_user';
        debugPrint('No user to verify');
      }

      final online = await isOnline;
      results['online'] = online;
      debugPrint('Online status: $online');
    } catch (e) {
      results['test_error'] = e.toString();
      debugPrint('Test failed: $e');
    }

    return results;
  }
}
