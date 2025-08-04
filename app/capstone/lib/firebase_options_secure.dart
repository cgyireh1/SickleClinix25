// Secure Firebase Options
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'services/config_service.dart';

class SecureFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'SecureFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'SecureFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static FirebaseOptions get android {
    final config = ConfigService.getAndroidConfig();
    return FirebaseOptions(
      apiKey: config['apiKey']!,
      appId: config['appId']!,
      messagingSenderId: config['messagingSenderId']!,
      projectId: config['projectId']!,
      storageBucket: config['storageBucket']!,
    );
  }

  static FirebaseOptions get ios {
    final config = ConfigService.getIosConfig();
    return FirebaseOptions(
      apiKey: config['apiKey']!,
      appId: config['appId']!,
      messagingSenderId: config['messagingSenderId']!,
      projectId: config['projectId']!,
      storageBucket: config['storageBucket']!,
      iosClientId: config['iosClientId']!,
      iosBundleId: config['iosBundleId']!,
    );
  }
}
