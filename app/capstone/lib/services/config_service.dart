import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class ConfigService {
  static const String _envFileName = '.env';

  // Firebase Configuration Keys
  static const String _androidApiKey = 'FIREBASE_ANDROID_API_KEY';
  static const String _androidAppId = 'FIREBASE_ANDROID_APP_ID';
  static const String _messagingSenderId = 'FIREBASE_MESSAGING_SENDER_ID';
  static const String _projectId = 'FIREBASE_PROJECT_ID';
  static const String _storageBucket = 'FIREBASE_STORAGE_BUCKET';
  static const String _iosApiKey = 'FIREBASE_IOS_API_KEY';
  static const String _iosAppId = 'FIREBASE_IOS_APP_ID';
  static const String _iosClientId = 'FIREBASE_IOS_CLIENT_ID';
  static const String _iosBundleId = 'FIREBASE_IOS_BUNDLE_ID';

  static bool _isInitialized = false;

  /// Initialize configuration service
  static Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await dotenv.load(fileName: _envFileName);
      _isInitialized = true;
      if (kDebugMode) {
        print('Configuration service initialized successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print(
          'Warning: Could not load .env file. Using fallback configuration.',
        );
        print('Error: $e');
      }
      _isInitialized = true;
    }
  }

  static String _getEnvVar(String key, {String fallback = ''}) {
    if (!_isInitialized) {
      throw Exception(
        'ConfigService not initialized. Call initialize() first.',
      );
    }
    return dotenv.env[key] ?? fallback;
  }

  /// Firebase configuration for Android platform
  static Map<String, String> getAndroidConfig() {
    return {
      'apiKey': _getEnvVar(
        _androidApiKey,
        fallback: 'AIzaSyA8I7sAWuiY2fw60A4xcpFGQI8jDKdMHx8',
      ),
      'appId': _getEnvVar(
        _androidAppId,
        fallback: '1:508675732931:android:e5c74c49ae5c833911b976',
      ),
      'messagingSenderId': _getEnvVar(
        _messagingSenderId,
        fallback: '508675732931',
      ),
      'projectId': _getEnvVar(_projectId, fallback: 'sickleclinix'),
      'storageBucket': _getEnvVar(
        _storageBucket,
        fallback: 'sickleclinix.firebasestorage.app',
      ),
    };
  }

  /// Firebase configuration for iOS platform
  static Map<String, String> getIosConfig() {
    return {
      'apiKey': _getEnvVar(
        _iosApiKey,
        fallback: 'AIzaSyA8I7sAWuiY2fw60A4xcpFGQI8jDKdMHx8',
      ),
      'appId': _getEnvVar(
        _iosAppId,
        fallback: '1:508675732931:ios:622a3a56d7f9489511b976',
      ),
      'messagingSenderId': _getEnvVar(
        _messagingSenderId,
        fallback: '508675732931',
      ),
      'projectId': _getEnvVar(_projectId, fallback: 'sickleclinix'),
      'storageBucket': _getEnvVar(
        _storageBucket,
        fallback: 'sickleclinix.firebasestorage.app',
      ),
      'iosClientId': _getEnvVar(
        _iosClientId,
        fallback:
            '508675732931-b9bqon3iocf2bihnvc5usbebbe7puhi4.apps.googleusercontent.com',
      ),
      'iosBundleId': _getEnvVar(_iosBundleId, fallback: 'com.example.capstone'),
    };
  }
}
