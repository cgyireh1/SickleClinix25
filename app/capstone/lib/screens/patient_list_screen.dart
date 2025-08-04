import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/patient.dart';
import 'patient_add_edit_screen.dart';
import 'patient_profile_screen.dart';
import '../screens/auth/auth_manager.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../theme.dart';

class PatientListScreen extends StatefulWidget {
  final bool isSelectionMode;

  const PatientListScreen({Key? key, this.isSelectionMode = false})
    : super(key: key);

  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen>
    with WidgetsBindingObserver {
  String _searchQuery = '';
  bool _isOnline = false;
  Box<Patient>? _userPatientBox;
  String? _userEmailKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkConnectivity();
    _setupConnectivityListener();
    _initUserBox();
  }

  Future<void> _initUserBox() async {
    try {
      final user = await AuthManager.getCurrentUser();
      if (user != null) {
        _userEmailKey = user.email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        _userPatientBox = await Hive.openBox<Patient>(
          'patients_${_userEmailKey}',
        );
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error initializing patient box: $e');
      try {
        await AuthManager.clearCorruptedData();
        final user = await AuthManager.getCurrentUser();
        if (user != null) {
          _userEmailKey = user.email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
          _userPatientBox = await Hive.openBox<Patient>(
            'patients_${_userEmailKey}',
          );
          setState(() {});
        }
      } catch (retryError) {
        debugPrint('Failed to recover from Hive error: $retryError');
        try {
          final user = await AuthManager.getCurrentUser();
          if (user != null) {
            _userEmailKey = user.email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
            await Hive.deleteBoxFromDisk('patients_${_userEmailKey}');
            _userPatientBox = await Hive.openBox<Patient>(
              'patients_${_userEmailKey}',
            );
            setState(() {});
          }
        } catch (finalError) {
          debugPrint('Final attempt to fix Hive failed: $finalError');
        }
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reloadPatients();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reloadPatients();
  }

  void _reloadPatients() {
    setState(() {});
  }

  Future<void> _checkConnectivity() async {
    final online = await AuthManager.isOnline;
    if (mounted) {
      setState(() => _isOnline = online);
    }
  }

  void _setupConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) async {
      final result = results.first;
      if (result != ConnectivityResult.none) {
        await _syncToCloud();
      }
      await _checkConnectivity();
    });
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text(
          widget.isSelectionMode ? 'Select Patient' : 'Patients',
          style: appBarTitleStyle,
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFB71C1C),
        foregroundColor: Colors.white,
        actions: [
          if (!widget.isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.sync),
              onPressed: _syncToCloud,
              tooltip: 'Sync to Cloud',
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PatientAddEditScreen(),
                  ),
                );
                if (result != null) {
                  if (_isOnline) {
                    await _syncToCloud();
                  }
                }
              },
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search by name',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim().toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: _userPatientBox == null
                ? const Center(child: CircularProgressIndicator())
                : ValueListenableBuilder(
                    valueListenable: _userPatientBox!.listenable(),
                    builder: (context, Box<Patient> box, _) {
                      try {
                        final patients = box.values
                            .where(
                              (p) =>
                                  p.name.toLowerCase().contains(_searchQuery),
                            )
                            .toList();

                        if (patients.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _searchQuery.isEmpty
                                      ? 'No patients yet'
                                      : 'No patients found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                if (_searchQuery.isEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.isSelectionMode
                                        ? 'Add a patient first to select for prediction'
                                        : 'Tap the + button to add your first patient',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          itemCount: patients.length,
                          itemBuilder: (context, index) {
                            final patient = patients[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.red.shade100,
                                  child: Text(
                                    patient.name[0].toUpperCase(),
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  patient.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  'Age: ${patient.age}, Gender: ${patient.gender}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (patient.needsSync && !_isOnline)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: Colors.orange,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    widget.isSelectionMode
                                        ? Icon(
                                            Icons.check_circle_outline,
                                            color: Colors.grey.shade400,
                                          )
                                        : Icon(
                                            Icons.chevron_right,
                                            color: Colors.grey.shade400,
                                          ),
                                  ],
                                ),
                                onTap: () {
                                  if (widget.isSelectionMode) {
                                    Navigator.pop(context, patient);
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            PatientProfileScreen(
                                              patientId: patient.id,
                                            ),
                                      ),
                                    );
                                  }
                                },
                                onLongPress: widget.isSelectionMode
                                    ? null
                                    : () => _deletePatient(patient),
                              ),
                            );
                          },
                        );
                      } catch (e) {
                        debugPrint('Error reading patients from Hive: $e');
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Error loading patients',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Please restart the app',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _deletePatient(Patient patient) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Patient'),
        content: Text('Are you sure you want to delete ${patient.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                patient.delete();

                if (_isOnline && patient.needsSync) {
                  await Patient.deleteFromCloud(patient.id);
                }

                Navigator.pop(context);
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to delete patient: ${e.toString()}'),
                    backgroundColor: Colors.red[600],
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _syncToCloud() async {
    try {
      if (_userPatientBox == null) return;
      final patients = _userPatientBox!.values.toList();

      for (final patient in patients) {
        if (patient.needsSync) {
          try {
            await Patient.syncToCloud(patient);
          } catch (syncError) {
            debugPrint('Failed to sync patient ${patient.id}: $syncError');
          }
        }
      }

      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: ${e.toString()}'),
            backgroundColor: Colors.red[600],
          ),
        );
      }
    }
  }
}
