import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/patient.dart';
import '../screens/auth/auth_manager.dart';
import '../theme.dart';
import 'notifications_screen.dart';

class PatientAddEditScreen extends StatefulWidget {
  final Patient? patient;

  const PatientAddEditScreen({Key? key, this.patient}) : super(key: key);

  @override
  State<PatientAddEditScreen> createState() => _PatientAddEditScreenState();
}

class _PatientAddEditScreenState extends State<PatientAddEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _contactController = TextEditingController();
  String _selectedGender = 'Male';
  bool _isLoading = false;

  final List<String> _genderOptions = ['Male', 'Female'];

  @override
  void initState() {
    super.initState();
    if (widget.patient != null) {
      // Edit mode - populate fields
      _nameController.text = widget.patient!.name;
      _ageController.text = widget.patient!.age.toString();
      _contactController.text = widget.patient!.contact ?? '';
      _selectedGender = widget.patient!.gender;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<Box<Patient>> _getUserPatientBox() async {
    final user = await AuthManager.getCurrentUser();
    if (user != null) {
      final emailKey = user.email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      return await Hive.openBox<Patient>('patients_$emailKey');
    }
    return Hive.box<Patient>('patients');
  }

  Future<void> _savePatient() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String healthworkerId = '';
      final user = await AuthManager.getCurrentUser();
      if (user != null && user.firebaseUid != null) {
        healthworkerId = user.firebaseUid!;
      }

      final patient = Patient(
        id:
            widget.patient?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        age: int.parse(_ageController.text),
        gender: _selectedGender,
        contact: _contactController.text.trim().isEmpty
            ? null
            : _contactController.text.trim(),
        createdAt: widget.patient?.createdAt ?? DateTime.now(),
        lastUpdated: DateTime.now(),
        healthworkerId: healthworkerId,
        isSynced: widget.patient?.isSynced ?? false,
      );

      final box = await _getUserPatientBox();

      if (widget.patient != null) {
        await box.put(patient.id, patient);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Patient updated successfully')),
          );
        }
      } else {
        await box.put(patient.id, patient);
        await addAppNotification(
          title: 'New Patient Added',
          message: 'Patient ${patient.name} has been added to your records.',
          type: 'system',
          payload: patient.id,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Patient added successfully')),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context, patient);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
          widget.patient != null ? 'Edit Patient' : 'Add Patient',
          style: appBarTitleStyle,
        ),
        centerTitle: true,
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPrivacyNotice(),
                    const SizedBox(height: 20),
                    _buildNameField(),
                    const SizedBox(height: 16),
                    _buildAgeField(),
                    const SizedBox(height: 16),
                    _buildGenderField(),
                    const SizedBox(height: 16),
                    _buildContactField(),
                    const SizedBox(height: 32),
                    _buildSaveButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPrivacyNotice() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.privacy_tip, color: Colors.blue.shade600, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Patient data is stored securely. Only essential information is collected.',
              style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: const InputDecoration(
        labelText: 'Full Name *',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.person),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter patient name';
        }
        if (value.trim().length < 2) {
          return 'Name must be at least 2 characters';
        }
        return null;
      },
    );
  }

  Widget _buildAgeField() {
    return TextFormField(
      controller: _ageController,
      decoration: const InputDecoration(
        labelText: 'Age *',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.calendar_today),
      ),
      keyboardType: TextInputType.number,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter age';
        }
        final age = int.tryParse(value);
        if (age == null || age < 0 || age > 150) {
          return 'Please enter a valid age (0-150)';
        }
        return null;
      },
    );
  }

  Widget _buildGenderField() {
    return DropdownButtonFormField<String>(
      value: _selectedGender,
      decoration: const InputDecoration(
        labelText: 'Gender *',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.person_outline),
      ),
      items: _genderOptions.map((gender) {
        return DropdownMenuItem(value: gender, child: Text(gender));
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedGender = value!;
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select gender';
        }
        return null;
      },
    );
  }

  Widget _buildContactField() {
    return TextFormField(
      controller: _contactController,
      decoration: const InputDecoration(
        labelText: 'Contact (Optional)',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.phone),
        helperText: 'Phone number or email for emergency contact',
      ),
      keyboardType: TextInputType.phone,
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _savePatient,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: Text(
        widget.patient != null ? 'Update Patient' : 'Add Patient',
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
}
