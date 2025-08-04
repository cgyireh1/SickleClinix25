import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'screens/landing_screen.dart';
import 'models/patient.dart';
import 'models/user_profile.dart';
import 'services/prediction_service.dart';
import 'screens/privacy_consent_screen.dart';
import 'package:capstone/screens/home_screen.dart';
import 'package:capstone/screens/result_screen.dart';
import 'package:capstone/screens/history_screen.dart';
import 'package:capstone/screens/prediction_screen.dart';
import 'package:capstone/screens/patient_list_screen.dart';
import 'package:capstone/screens/patient_add_edit_screen.dart';
import 'package:capstone/screens/patient_profile_screen.dart';
import 'package:capstone/screens/notifications_screen.dart';
import 'package:capstone/screens/settings_screen.dart';
import 'package:capstone/screens/profile_screen.dart';
import 'package:capstone/screens/data_management_screen.dart';
import 'screens/helpsupport_Screen.dart';
import 'package:capstone/screens/auth/login_screen.dart';
import 'package:capstone/screens/auth/signup_screen.dart';
import 'package:capstone/screens/auth/terms_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:capstone/screens/auth/auth_manager.dart';
import 'package:capstone/services/config_service.dart';
import 'package:capstone/firebase_options_secure.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'screens/dashboard_screen.dart';
import 'services/firebase_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> syncOfflineData() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final firebaseService = FirebaseService();

    if (await firebaseService.isOnline) {
      // Sync offline feedback
      final offlineFeedback = prefs.getStringList('offline_feedback') ?? [];
      if (offlineFeedback.isNotEmpty) {
        for (String feedbackJson in offlineFeedback) {
          final feedbackData = jsonDecode(feedbackJson) as Map<String, dynamic>;
          final feedbackId = DateTime.now().millisecondsSinceEpoch.toString();
          await firebaseService.syncData('feedback', feedbackId, feedbackData);
          await Future.delayed(const Duration(milliseconds: 500));
        }
        await prefs.remove('offline_feedback');
        debugPrint(
          'Offline feedback synced successfully - emails will be sent',
        );
      }

      // Sync offline contact forms
      final offlineContact = prefs.getStringList('offline_contact') ?? [];
      if (offlineContact.isNotEmpty) {
        for (String contactJson in offlineContact) {
          final contactData = jsonDecode(contactJson) as Map<String, dynamic>;
          final contactId = DateTime.now().millisecondsSinceEpoch.toString();
          await firebaseService.syncData(
            'contact_requests',
            contactId,
            contactData,
          );
          await Future.delayed(const Duration(milliseconds: 500));
        }
        await prefs.remove('offline_contact');
        debugPrint(
          'Offline contact forms synced successfully - emails will be sent',
        );
      }
    }
  } catch (e) {
    debugPrint('Error syncing offline data: $e');
  }
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: SecureFirebaseOptions.currentPlatform);
  _showAndSaveNotification(message);
}

Future<void> _showAndSaveNotification(RemoteMessage message) async {
  final notification = message.notification;
  if (notification == null) return;

  // Show notification
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
        'default_channel',
        'General Notifications',
        channelDescription: 'General notifications for SickleClinix',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );
  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
  );
  await flutterLocalNotificationsPlugin.show(
    notification.hashCode,
    notification.title,
    notification.body,
    platformChannelSpecifics,
    payload: 'notifications',
  );

  final prefs = await SharedPreferences.getInstance();
  final savedNotifications = prefs.getStringList('notifications') ?? [];
  final now = DateTime.now().toIso8601String();
  final type = message.data['type'] ?? 'system';
  final newNotification =
      '${notification.title}|${notification.body}|$now|false|$type';
  savedNotifications.insert(0, newNotification);
  await prefs.setStringList('notifications', savedNotifications);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ConfigService.initialize();
  final connectivity = await Connectivity().checkConnectivity();
  final isOnline = connectivity != ConnectivityResult.none;

  if (isOnline) {
    try {
      await Firebase.initializeApp(
        options: SecureFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint(
        'Firebase initialization timeout - continuing in offline mode',
      );
    }
  } else {
    debugPrint('Offline detected - skipping Firebase initialization');
  }

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      if (response.payload == 'notifications') {
        navigatorKey.currentState?.pushNamed('/notifications');
      }
    },
  );
  if (isOnline) {
    try {
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission().timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint(
        'Firebase messaging setup timeout - continuing in offline mode',
      );
    }
  } else {
    debugPrint('Offline detected - skipping Firebase messaging setup');
  }

  // Foreground message handler
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    _showAndSaveNotification(message);
  });

  // Notification tap handler
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    navigatorKey.currentState?.pushNamed('/notifications');
  });

  // Initialize Hive
  await Hive.initFlutter();

  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(PatientAdapter());
  }

  const secureStorage = FlutterSecureStorage();
  final patientKey = await secureStorage.read(key: 'hive_patient_key');

  List<int> keyBytes;
  if (patientKey == null) {
    // Generate new key
    keyBytes = Hive.generateSecureKey();
    final keyString = base64Url.encode(keyBytes);
    await secureStorage.write(key: 'hive_patient_key', value: keyString);
  } else {
    if (patientKey.contains(',')) {
      try {
        keyBytes = patientKey
            .split(',')
            .map((e) => int.parse(e.trim()))
            .toList();
        final keyString = base64Url.encode(keyBytes);
        await secureStorage.write(key: 'hive_patient_key', value: keyString);
      } catch (e) {
        keyBytes = Hive.generateSecureKey();
        final keyString = base64Url.encode(keyBytes);
        await secureStorage.write(key: 'hive_patient_key', value: keyString);
      }
    } else {
      try {
        keyBytes = base64Url.decode(patientKey);
      } catch (e) {
        keyBytes = Hive.generateSecureKey();
        final keyString = base64Url.encode(keyBytes);
        await secureStorage.write(key: 'hive_patient_key', value: keyString);
      }
    }
  }

  await Hive.openBox<Patient>(
    'patients',
    encryptionCipher: HiveAesCipher(keyBytes),
  );

  await PredictionService().initialize();
  if (isOnline) {
    try {
      await syncOfflineData().timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('Offline data sync timeout - continuing');
    }
  } else {
    debugPrint('Offline detected - skipping data sync');
  }

  Connectivity().onConnectivityChanged.listen((
    List<ConnectivityResult> results,
  ) async {
    final result = results.first;
    if (result != ConnectivityResult.none) {
      try {
        final predictionService = PredictionService();
        await predictionService.syncToCloud();

        // Sync patients
        final patients = Hive.box<Patient>('patients').values.toList();
        for (final patient in patients) {
          await Patient.syncToCloud(patient);
        }

        print('Automatic sync completed');
      } catch (e) {
        print('Automatic sync failed: $e');
      }
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _storage = const FlutterSecureStorage();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _showOnboardingIfNeeded(),
    );
  }

  Future<void> _showOnboardingIfNeeded() async {
    final user = await AuthManager.getCurrentUser();
    if (user == null) return;
    final onboardingKey = 'onboarding_shown_${user.email}';
    final alreadyShown = await _storage.read(key: onboardingKey);
    if (alreadyShown == 'true') return;
    await _storage.write(key: onboardingKey, value: 'true');
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => AlertDialog(
          title: Text('Welcome to SickleClinix!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Here are some tips to get started:'),
              SizedBox(height: 12),
              Text('• Add patients and manage their records.'),
              Text('• Use the Prediction tool to analyze blood smears.'),
              Text('• View Grad-CAM for model explanations.'),
              Text('• Access Help & Support for guides and FAQs.'),
              SizedBox(height: 16),
              Text('You can always find help in the Help & Support section.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/helpsupport');
              },
              child: Text('Open Help & Support'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SickleClinix',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.red,
        primaryColor: const Color(0xFFB71C1C),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB71C1C)),
        useMaterial3: true,
      ),
      navigatorKey: navigatorKey,
      home: LandingScreen(onContinue: _handleLandingContinue),
      onGenerateRoute: _onGenerateRoute,
      routes: {'/dashboard': (context) => const DashboardScreen()},
    );
  }

  void _handleLandingContinue() async {
    final prefs = await SharedPreferences.getInstance();
    final consentGiven = prefs.getBool('privacy_consent_given') ?? false;
    if (!consentGiven) {
      navigatorKey.currentState?.pushReplacementNamed('/privacy-consent');
    } else {
      navigatorKey.currentState?.pushReplacementNamed('/login');
    }
  }

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    try {
      print('Navigating to: ${settings.name}');

      if (settings.arguments != null) {
        print('Route arguments: ${settings.arguments}');
      }

      switch (settings.name) {
        case '/':
          return MaterialPageRoute(builder: (_) => const LandingScreen());

        case '/home':
          return MaterialPageRoute(builder: (_) => const HomeScreen());

        case '/predict':
          return MaterialPageRoute(builder: (_) => const PredictionScreen());

        case '/patients':
          final args = settings.arguments as Map<String, dynamic>?;
          final isSelectionMode = args?['isSelectionMode'] ?? false;
          return MaterialPageRoute(
            builder: (_) => PatientListScreen(isSelectionMode: isSelectionMode),
          );

        case '/history':
          return MaterialPageRoute(builder: (_) => const HistoryScreen());

        case '/results':
          final args = settings.arguments as Map<String, dynamic>?;
          if (args == null) {
            return MaterialPageRoute(
              builder: (_) => const Scaffold(
                body: Center(child: Text('No results data provided.')),
              ),
            );
          }
          return MaterialPageRoute(
            builder: (_) => ResultScreen(
              imageFile: args['imageFile'],
              prediction: args['prediction'],
              confidence: args['confidence'],
              interpreter: args['interpreter'],
              predictionId: args['predictionId'],
              isOnline: args['isOnline'] ?? false,
              patientId: args['patientId'],
              healthworkerId: args['healthworkerId'],
              heatmapUrl: args['heatmapUrl'],
            ),
          );

        case '/add-edit-patient':
          return MaterialPageRoute(
            builder: (_) => const PatientAddEditScreen(),
          );

        case '/patient-profile':
          final args = settings.arguments as Map<String, dynamic>?;
          if (args == null || args['patientId'] == null) {
            return MaterialPageRoute(
              builder: (_) => const Scaffold(
                body: Center(child: Text('No patient selected.')),
              ),
            );
          }
          return MaterialPageRoute(
            builder: (_) => PatientProfileScreen(patientId: args['patientId']),
          );

        case '/notifications':
          return MaterialPageRoute(builder: (_) => const NotificationScreen());

        case '/settings':
          return MaterialPageRoute(builder: (_) => const SettingsScreen());

        case '/data-management':
          return MaterialPageRoute(
            builder: (_) => const DataManagementScreen(),
          );

        case '/profile':
          final args = settings.arguments as Map<String, dynamic>?;
          return MaterialPageRoute(
            builder: (context) => FutureBuilder<UserProfile?>(
              future: _ensureUserExists(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError || !snapshot.hasData) {
                  return Scaffold(
                    appBar: AppBar(
                      title: const Text('Profile'),
                      backgroundColor: const Color(0xFFB71C1C),
                      foregroundColor: Colors.white,
                    ),
                    body: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red,
                          ),
                          SizedBox(height: 16),
                          Text('Unable to load profile'),
                          SizedBox(height: 8),
                          Text('Please log in to access your profile'),
                        ],
                      ),
                    ),
                  );
                }

                return ProfileScreen(
                  initialProfile: snapshot.data!,
                  isOnline: true,
                  startInEditMode: args?['startInEditMode'] == true,
                );
              },
            ),
            settings: settings,
          );

        case '/help-support':
          return MaterialPageRoute(builder: (_) => const HelpSupportScreen());

        case '/login':
          return MaterialPageRoute(builder: (_) => const LoginScreen());

        case '/signup':
          return MaterialPageRoute(builder: (_) => const SignUpScreen());

        case '/terms':
          return MaterialPageRoute(builder: (_) => const TermsScreen());

        case '/privacy-consent':
          return MaterialPageRoute(
            builder: (_) =>
                PrivacyConsentScreen(onConsentGiven: _onConsentGiven),
          );

        default:
          return MaterialPageRoute(
            builder: (context) => Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text('Page not found: ${settings.name}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () =>
                          Navigator.of(context).pushReplacementNamed('/'),
                      child: const Text('Go Home'),
                    ),
                  ],
                ),
              ),
            ),
          );
      }
    } catch (e) {
      return MaterialPageRoute(
        builder: (context) => Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Navigation Error: ${e.toString()}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).pushReplacementNamed('/'),
                  child: const Text('Go Home'),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  Future<UserProfile?> _ensureUserExists() async {
    try {
      final currentUser = await AuthManager.getCurrentUser();
      if (currentUser != null) {
        return currentUser;
      }

      final defaultUser = UserProfile(
        email: 'user@example.com',
        passwordHash: '',
        fullName: 'User',
        facilityName: 'Healthcare Facility',
        phoneNumber: '+250 XXX XXX XXX',
        specialty: 'General Practitioner',
        createdAt: DateTime.now(),
        lastUpdated: DateTime.now(),
        isSynced: true,
      );

      final users = await _getLocalUsers();
      users[defaultUser.email] = defaultUser.toJson();
      await _saveLocalUsers(users);
      await _setCurrentUser(defaultUser);

      return defaultUser;
    } catch (e) {
      print('Error ensuring user exists: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> _getLocalUsers() async {
    try {
      final jsonString = await const FlutterSecureStorage().read(
        key: 'local_users',
      );
      return jsonString != null ? json.decode(jsonString) : {};
    } catch (e) {
      await const FlutterSecureStorage().delete(key: 'local_users');
      return {};
    }
  }

  Future<void> _saveLocalUsers(Map<String, dynamic> users) async {
    await const FlutterSecureStorage().write(
      key: 'local_users',
      value: json.encode(users),
    );
  }

  Future<void> _setCurrentUser(UserProfile? user) async {
    if (user == null) {
      await const FlutterSecureStorage().delete(key: 'current_user');
    } else {
      await const FlutterSecureStorage().write(
        key: 'current_user',
        value: json.encode(user.toJson()),
      );
    }
  }

  void _onConsentGiven() {
    navigatorKey.currentState?.pushReplacementNamed('/login');
  }
}
