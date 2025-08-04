import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:capstone/models/patient.dart';
import 'package:capstone/widgets/app_bottom_navbar.dart';
import '../../theme.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:capstone/services/validation_service.dart';

class PredictionScreen extends StatefulWidget {
  final Patient? testPatient;
  final VoidCallback? onPredict;
  final bool testMode;
  const PredictionScreen({
    Key? key,
    this.testPatient,
    this.onPredict,
    this.testMode = false,
  }) : super(key: key);

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen>
    with SingleTickerProviderStateMixin {
  File? _selectedImage;
  String? _predictionResult;
  double? _confidence;
  bool _isLoading = false;
  bool _modelLoaded = false;
  bool _isSaving = false;
  bool _isOnline = true;
  String? _errorMessage;
  String? _savedPredictionId;
  Patient? _selectedPatient;

  final picker = ImagePicker();
  late Interpreter _interpreter;
  final int _inputSize = 224;

  // Firebase instances
  FirebaseFirestore? _firestore;
  FirebaseStorage? _storage;
  FirebaseAuth? _auth;

  // Offline storage
  Database? _localDatabase;
  final Connectivity _connectivity = Connectivity();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    if (!widget.testMode) {
      _firestore = FirebaseFirestore.instance;
      _storage = FirebaseStorage.instance;
      _auth = FirebaseAuth.instance;
    }
    if (widget.testPatient != null) {
      _selectedPatient = widget.testPatient;
    }
    _loadModel();
    _initializeOfflineStorage();
    _checkConnectivity();
    _setupConnectivityListener();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(_animationController);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['selectedPatient'] != null) {
      setState(() {
        _selectedPatient = args['selectedPatient'] as Patient;
      });
    }
  }

  Future<void> _initializeOfflineStorage() async {
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final dbPath = path.join(
        documentsDirectory.path,
        'sickleclinix_offline.db',
      );

      _localDatabase = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE predictions (
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
              patientName TEXT
            )
          ''');

          await db.execute('''
            CREATE TABLE user_stats (
              userId TEXT PRIMARY KEY,
              totalPredictions INTEGER DEFAULT 0,
              sickleCellDetected INTEGER DEFAULT 0,
              normalResults INTEGER DEFAULT 0,
              lastUpdated TEXT,
              synced INTEGER DEFAULT 0
            )
          ''');
        },
      );

      if (kDebugMode) {
        print("Local database initialized");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Database initialization error: $e");
      }
    }
  }

  void _setupConnectivityListener() {
    _connectivity.onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final bool wasOnline = _isOnline;

      final bool nowOnline = results.any((r) => r != ConnectivityResult.none);
      setState(() {
        _isOnline = nowOnline;
      });

      if (!wasOnline && _isOnline) {
        _syncPendingData();
      }
    });
  }

  Future<void> _checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    setState(() {
      _isOnline = result != ConnectivityResult.none;
    });
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/sickleclinix_model.tflite',
        options: InterpreterOptions()..threads = 4,
      );
      setState(() => _modelLoaded = true);
      if (kDebugMode) {
        print("Model loaded successfully");
        print("Input details: ${_interpreter.getInputTensors()}");
        print("Output details: ${_interpreter.getOutputTensors()}");
      }
    } catch (e) {
      setState(() => _errorMessage = "Failed to load model: $e");
      if (kDebugMode) {
        print("Model loading error: $e");
      }
    }
  }

  void _showImagePickerDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Image Source'),
          content: const Text('Choose how you want to select an image'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.camera);
              },
              child: const Text('Camera'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _pickImage(ImageSource.gallery);
              },
              child: const Text('Gallery'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    if (!_modelLoaded) {
      _showError("Model not loaded yet. Please wait.");
      return;
    }

    try {
      if (source == ImageSource.camera) {
        final status = await Permission.camera.request();
        if (status != PermissionStatus.granted) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Camera Permission Required'),
                content: const Text(
                  'Camera access is needed to capture blood smear images for analysis. '
                  'This helps ensure image quality and accurate results. '
                  'Your privacy is important - images are only used for medical analysis and are stored securely.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      openAppSettings();
                    },
                    child: const Text('Open Settings'),
                  ),
                ],
              ),
            );
          }
          return;
        }
      }

      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _isLoading = true;
          _predictionResult = null;
          _errorMessage = null;
          _savedPredictionId = null;
        });
        await _runInference(_selectedImage!);
      }
    } catch (e) {
      _showError("Failed to pick image: ${e.toString()}");
    }
  }

  Future<void> _runInference(File imageFile) async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final validation = await ValidationService.validateBloodSmearImage(
        imageFile,
      );

      if (!validation['isValid']) {
        setState(() {
          _isLoading = false;
          _errorMessage = validation['error'];
        });

        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Image Validation Warning'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(validation['error']),
                  const SizedBox(height: 16),
                  if (validation['suggestions'].isNotEmpty) ...[
                    const Text(
                      'Suggestions:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...validation['suggestions'].map(
                      (suggestion) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $suggestion'),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedImage = null;
                      _errorMessage = null;
                    });
                  },
                  child: const Text('Choose Different Image'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _proceedWithInference(imageFile);
                  },
                  child: const Text('Proceed Anyway'),
                ),
              ],
            ),
          );
        }
        return;
      }

      await _proceedWithInference(imageFile);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Analysis failed: ${e.toString()}";
      });
      if (kDebugMode) {
        print("Inference error: $e");
      }
    }
  }

  Future<void> _proceedWithInference(File imageFile) async {
    try {
      // Load and decode image
      final rawBytes = await imageFile.readAsBytes();
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) throw Exception("Image decoding failed");

      // Preprocess image
      final resized = img.copyResize(
        decoded,
        width: _inputSize,
        height: _inputSize,
      );

      // Normalize to [0,1] and convert to Float32List
      final input = Float32List(_inputSize * _inputSize * 3);
      int pixelIndex = 0;
      for (int y = 0; y < _inputSize; y++) {
        for (int x = 0; x < _inputSize; x++) {
          final pixel = resized.getPixel(x, y);
          input[pixelIndex++] = pixel.r / 255.0;
          input[pixelIndex++] = pixel.g / 255.0;
          input[pixelIndex++] = pixel.b / 255.0;
        }
      }

      // Reshape for model input
      final inputTensor = input.reshape([1, _inputSize, _inputSize, 3]);
      final output = List.filled(1, 0.0).reshape([1, 1]);

      // Run inference
      _interpreter.run(inputTensor, output);

      // Process results
      final double predictionScore = output[0][0];
      final String result = predictionScore > 0.5
          ? "Sickle Cell Detected"
          : "Normal";
      final double confidence = (result == "Sickle Cell Detected")
          ? predictionScore * 100
          : (1 - predictionScore) * 100;

      setState(() {
        _isLoading = false;
        _predictionResult = result;
        _confidence = confidence;
      });

      // Save to local database
      await _saveLocally();

      if (_isOnline) {
        await _syncToCloud();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Analysis failed: ${e.toString()}";
      });
      if (kDebugMode) {
        print("Inference error: $e");
      }
    }
  }

  Future<void> _saveLocally() async {
    if (_localDatabase == null ||
        _selectedImage == null ||
        _predictionResult == null ||
        _confidence == null) {
      if (kDebugMode) {
        print(
          "Cannot save: database=${_localDatabase != null}, image=${_selectedImage != null}, result=${_predictionResult != null}, confidence=${_confidence != null}",
        );
      }
      return;
    }

    if (!_localDatabase!.isOpen) {
      if (kDebugMode) {
        print("Database is closed, cannot save prediction");
      }
      return;
    }

    try {
      final user = _auth?.currentUser;
      final predictionId = DateTime.now().millisecondsSinceEpoch.toString();

      final appDir = await getApplicationDocumentsDirectory();
      final fileName =
          'prediction_${predictionId}_${path.basename(_selectedImage!.path)}';
      final localImagePath = path.join(appDir.path, 'images', fileName);

      final imagesDir = Directory(path.dirname(localImagePath));
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      await _selectedImage!.copy(localImagePath);

      // Save prediction data to SQLite
      await _localDatabase!.insert('predictions', {
        'id': predictionId,
        'userId': user?.uid ?? 'anonymous',
        'userEmail': user?.email ?? '',
        'prediction': _predictionResult!,
        'confidence': _confidence!,
        'imagePath': localImagePath,
        'timestamp': DateTime.now().toIso8601String(),
        'modelVersion': '1.0',
        'deviceInfo': jsonEncode({
          'platform': Platform.operatingSystem,
          'isDebugMode': kDebugMode,
        }),
        'analysisMetadata': jsonEncode({
          'inputSize': _inputSize,
          'modelType': 'sickleclinix_model',
          'predictionScore': _predictionResult == "Sickle Cell Detected"
              ? _confidence! / 100
              : 1 - (_confidence! / 100),
        }),
        'synced': 0, // Not synced to cloud yet
        'patientId': _selectedPatient?.id,
        'patientName': _selectedPatient?.name,
      });

      await _updateLocalUserStats();

      setState(() => _savedPredictionId = predictionId);

      _showSuccess("Prediction saved locally");

      if (kDebugMode) {
        print("Prediction saved locally with ID: $predictionId");
      }
    } catch (e) {
      _showError("Failed to save locally: ${e.toString()}");
      if (kDebugMode) {
        print("Local save error: $e");
      }
    }
  }

  Future<void> _updateLocalUserStats() async {
    if (_localDatabase == null) return;

    if (!_localDatabase!.isOpen) {
      if (kDebugMode) {
        print("Database is closed, cannot update user stats");
      }
      return;
    }

    try {
      final user = _auth?.currentUser;
      final userId = user?.uid ?? 'anonymous';

      await _localDatabase!.rawUpdate(
        '''
        INSERT OR REPLACE INTO user_stats (
          userId, 
          totalPredictions, 
          sickleCellDetected, 
          normalResults, 
          lastUpdated,
          synced
        ) VALUES (
          ?, 
          COALESCE((SELECT totalPredictions FROM user_stats WHERE userId = ?), 0) + 1,
          COALESCE((SELECT sickleCellDetected FROM user_stats WHERE userId = ?), 0) + ?,
          COALESCE((SELECT normalResults FROM user_stats WHERE userId = ?), 0) + ?,
          ?,
          0
        )
      ''',
        [
          userId,
          userId,
          userId,
          _predictionResult == "Sickle Cell Detected" ? 1 : 0,
          userId,
          _predictionResult == "Normal" ? 1 : 0,
          DateTime.now().toIso8601String(),
        ],
      );
    } catch (e) {
      if (kDebugMode) {
        print("Local user stats update error: $e");
      }
    }
  }

  Future<void> _syncToCloud() async {
    if (!_isOnline || _localDatabase == null) return;

    if (!_localDatabase!.isOpen) {
      if (kDebugMode) {
        print("Database is closed, cannot sync to cloud");
      }
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = _auth?.currentUser;
      if (user == null) {
        setState(() => _isSaving = false);
        return;
      }

      final unsyncedPredictions = await _localDatabase!.query(
        'predictions',
        where: 'synced = ? AND userId = ?',
        whereArgs: [0, user.uid],
        orderBy: 'timestamp ASC',
      );

      for (final prediction in unsyncedPredictions) {
        try {
          // Upload image to Firebase Storage
          String? imageUrl;
          final imagePath = prediction['imagePath'] as String;
          if (File(imagePath).existsSync()) {
            imageUrl = await _uploadImageToStorage(File(imagePath));
          }

          // Prepare cloud data
          final cloudData = {
            'userId': prediction['userId'],
            'userEmail': prediction['userEmail'],
            'prediction': prediction['prediction'],
            'confidence': prediction['confidence'],
            'imageUrl': imageUrl,
            'timestamp': FieldValue.serverTimestamp(),
            'modelVersion': prediction['modelVersion'],
            'deviceInfo': jsonDecode(prediction['deviceInfo'] as String),
            'analysisMetadata': jsonDecode(
              prediction['analysisMetadata'] as String,
            ),
            'localId': prediction['id'], // Reference to local record
            'patientId': prediction['patientId'],
            'patientName': prediction['patientName'],
          };

          // Save to Firestore
          final docRef = await _firestore
              ?.collection('predictions')
              .add(cloudData);

          await _localDatabase!.update(
            'predictions',
            {'synced': 1, 'cloudId': docRef?.id},
            where: 'id = ?',
            whereArgs: [prediction['id']],
          );

          if (kDebugMode) {
            print(
              "Synced prediction ${prediction['id']} to cloud: ${docRef?.id}",
            );
          }
        } catch (e) {
          if (kDebugMode) {
            print("Failed to sync prediction ${prediction['id']}: $e");
          }
        }
      }

      // Sync user stats
      await _syncUserStatsToCloud();

      setState(() => _isSaving = false);
      _showSuccess("Data synced to cloud");
    } catch (e) {
      setState(() => _isSaving = false);
      if (kDebugMode) {
        print("Cloud sync error: $e");
      }
    }
  }

  Future<void> _syncUserStatsToCloud() async {
    if (_localDatabase == null) return;

    try {
      final user = _auth?.currentUser;
      if (user == null) return;

      final localStats = await _localDatabase!.query(
        'user_stats',
        where: 'userId = ?',
        whereArgs: [user.uid],
      );

      if (localStats.isNotEmpty) {
        final stats = localStats.first;

        await _firestore?.collection('userStats').doc(user.uid).set({
          'totalPredictions': stats['totalPredictions'],
          'sickleCellDetected': stats['sickleCellDetected'],
          'normalResults': stats['normalResults'],
          'lastPredictionDate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Mark as synced
        await _localDatabase!.update(
          'user_stats',
          {'synced': 1},
          where: 'userId = ?',
          whereArgs: [user.uid],
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print("User stats cloud sync error: $e");
      }
    }
  }

  Future<void> _syncPendingData() async {
    if (!_isOnline) return;

    try {
      await _syncToCloud();
    } catch (e) {
      if (kDebugMode) {
        print("Background sync error: $e");
      }
    }
  }

  Future<String?> _uploadImageToStorage(File imageFile) async {
    try {
      final user = _auth?.currentUser;
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
      final ref = _storage?.ref().child(fileName);

      debugPrint('Uploading prediction image: $fileName');

      final uploadTask = ref?.putFile(imageFile);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot?.ref.getDownloadURL();

      debugPrint('Successfully uploaded prediction image: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('Prediction image upload error: $e');

      // Check for App Check or security-related errors
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

  void _showError(String message) {
    setState(() => _errorMessage = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _retryAnalysis() async {
    if (_selectedImage != null) {
      setState(() {
        _isLoading = true;
        _predictionResult = null;
        _errorMessage = null;
        _savedPredictionId = null;
      });
      await _runInference(_selectedImage!);
    }
  }

  Future<void> _manualSync() async {
    if (_isOnline) {
      await _syncPendingData();
    } else {
      _showError("No internet connection. Will sync when online.");
    }
  }

  @override
  void dispose() {
    _interpreter.close();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasResult = _predictionResult != null && !_isLoading;
    final Color resultColor = _predictionResult == "Sickle Cell Detected"
        ? Colors.red.shade700
        : Colors.green.shade700;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed('/home');
            }
          },
        ),
        title: Text("Make Predictions", style: appBarTitleStyle),
        backgroundColor: const Color(0xFFB71C1C),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _selectedImage != null ? _retryAnalysis : null,
            tooltip: "Retry Analysis",
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Patient Selection Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.person,
                                color: Colors.blue.shade700,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Patient",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_selectedPatient != null) ...[
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.blue.shade100,
                                  child: Text(
                                    _selectedPatient!.name[0].toUpperCase(),
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedPatient!.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                      Text(
                                        "Age: ${_selectedPatient!.age}, Gender: ${_selectedPatient!.gender}",
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: Colors.red.shade600,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _selectedPatient = null;
                                    });
                                  },
                                  tooltip: "Clear patient selection",
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    "No patient selected",
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    final selectedPatient =
                                        await Navigator.pushNamed(
                                          context,
                                          '/patients',
                                          arguments: {'isSelectionMode': true},
                                        );
                                    if (selectedPatient != null) {
                                      setState(() {
                                        _selectedPatient =
                                            selectedPatient as Patient;
                                      });
                                    }
                                  },
                                  icon: const Icon(Icons.person_add, size: 16),
                                  label: const Text(
                                    "Select Patient",
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade600,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    final newPatient =
                                        await Navigator.pushNamed(
                                          context,
                                          '/add-edit-patient',
                                        );
                                    if (newPatient != null) {
                                      setState(() {
                                        _selectedPatient =
                                            newPatient as Patient;
                                      });
                                    }
                                  },
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text(
                                    "Add New",
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green.shade600,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                    GestureDetector(
                      onTap: () => _showImagePickerDialog(),
                      child: Container(
                        width: 260,
                        height: 260,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.grey.shade200,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                          image: _selectedImage != null
                              ? DecorationImage(
                                  image: FileImage(_selectedImage!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _selectedImage == null
                            ? const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.image_search,
                                      size: 60,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 10),
                                    Text(
                                      "Select blood smear image",
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                    SizedBox(height: 5),
                                  ],
                                ),
                              )
                            : Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 40,
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    // Status Indicators
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  setState(() => _errorMessage = null),
                              child: const Text("Dismiss"),
                            ),
                          ],
                        ),
                      ),
                    if (_isLoading) ...[
                      const SizedBox(height: 20),
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Color(0xFFB71C1C)),
                      ),
                      const SizedBox(height: 10),
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: const Text(
                          "Analyzing blood smear...",
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                    if (hasResult) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: resultColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: resultColor.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _predictionResult == "Sickle Cell Detected"
                                      ? Icons.warning
                                      : Icons.check_circle,
                                  color: resultColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _predictionResult!,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: resultColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            LinearProgressIndicator(
                              value: _confidence! / 100,
                              backgroundColor: Colors.grey.shade300,
                              valueColor: AlwaysStoppedAnimation(resultColor),
                              minHeight: 12,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "${_confidence!.toStringAsFixed(1)}% confidence",
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 25),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (_selectedImage == null ||
                                _predictionResult == null) {
                              _showError("Please complete analysis first");
                              return;
                            }

                            Navigator.pushNamed(
                              context,
                              '/results',
                              arguments: {
                                'imageFile': _selectedImage!,
                                'prediction': _predictionResult!,
                                'confidence': _confidence ?? 0.0,
                                'interpreter': _interpreter,
                                'predictionId': _savedPredictionId,
                                'isOnline': _isOnline,
                                'patientId': _selectedPatient?.id,
                                'healthworkerId': _auth?.currentUser?.uid,
                              },
                            );
                          },
                          icon: const Icon(Icons.analytics),
                          label: const Text("View Detailed Analysis"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                    if (!_modelLoaded)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          "Loading model...",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: widget.onPredict != null
                      ? ElevatedButton.icon(
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Predict'),
                          onPressed: widget.onPredict,
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 2,
                          ),
                        )
                      : ElevatedButton.icon(
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Predict'),
                          onPressed: () => _pickImage(ImageSource.camera),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.red.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 2,
                          ),
                        ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.photo_library),
                    label: const Text("Gallery"),
                    onPressed: _modelLoaded
                        ? () => _pickImage(ImageSource.gallery)
                        : null,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNavBar(currentRoute: '/predict'),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () => Navigator.pushNamed(context, '/terms'),
      //   backgroundColor: const Color(0xFFB71C1C),
      //   child: const Icon(Icons.info_outline, color: Colors.white),
      //   tooltip: "Terms & Conditions",
      // ),
    );
  }
}

Widget _buildFooterIconButton({
  required IconData icon,
  // required String label,
  required VoidCallback onPressed,
}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        icon: Icon(icon, size: 28),
        onPressed: onPressed,
        // tooltip: label,
        color: Colors.red.shade700,
      ),
      // Text(
      //   // label,
      //   style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      // ),
    ],
  );
}
