import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:capstone/screens/auth/auth_manager.dart';
import 'package:capstone/models/user_profile.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../theme.dart';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ProfileScreen extends StatefulWidget {
  final UserProfile initialProfile;
  final bool isOnline;
  final Function(UserProfile)? onProfileUpdated;
  final bool startInEditMode;

  const ProfileScreen({
    super.key,
    required this.initialProfile,
    this.isOnline = false,
    this.onProfileUpdated,
    this.startInEditMode = false,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _emailController;
  late TextEditingController _fullNameController;
  late TextEditingController _facilityNameController;
  late TextEditingController _phoneController;
  late TextEditingController _licenseController;

  File? _profileImageFile;
  bool _isEditing = false;
  bool _isLoading = false;
  bool _isSyncing = false;
  bool _isOnline = false;
  Timer? _connectivityTimer;
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _picker = ImagePicker();

  final List<String> _specialties = [
    'General Practitioner',
    'Internal Medicine',
    'Pediatrics',
    'Emergency Medicine',
    'Family Medicine',
    'Hematology',
    'Oncology',
    'Cardiology',
    'Neurology',
    'Other',
  ];

  late String _selectedSpecialty;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _selectedSpecialty =
        widget.initialProfile.specialty ?? 'General Practitioner';
    _checkConnectivity();
    _startConnectivityTimer();

    // Start in edit mode if requested
    if (widget.startInEditMode) {
      _isEditing = true;
    }

    if (widget.initialProfile.profileImageUrl != null &&
        widget.initialProfile.profileImageUrl!.isNotEmpty) {
      final imageUrl = widget.initialProfile.profileImageUrl!;
      if (imageUrl.startsWith('/') && File(imageUrl).existsSync()) {
        _profileImageFile = File(imageUrl);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  Future<void> _refreshEmailVerificationStatus() async {
    try {
      setState(() {
        _isLoading = true;
      });

      await AuthManager.isEmailVerified();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _connectivityTimer?.cancel();
    _emailController.dispose();
    _fullNameController.dispose();
    _facilityNameController.dispose();
    _phoneController.dispose();
    _licenseController.dispose();
    super.dispose();
  }

  void _startConnectivityTimer() {
    _connectivityTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        _checkConnectivity();
      }
    });
  }

  void _checkConnectivity() async {
    final online = await AuthManager.isOnline;
    if (mounted && online != _isOnline) {
      setState(() => _isOnline = online);
    }
  }

  void _initializeControllers() {
    _emailController = TextEditingController(text: widget.initialProfile.email);
    _fullNameController = TextEditingController(
      text: widget.initialProfile.fullName,
    );
    _facilityNameController = TextEditingController(
      text: widget.initialProfile.facilityName,
    );
    _phoneController = TextEditingController(
      text: widget.initialProfile.phoneNumber ?? "+250 ",
    );
    _licenseController = TextEditingController(text: "GP-2024-001");
  }

  Future<File> _copyImageToPersistentDir(File imageFile) async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(path.join(appDir.path, 'profile_images'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    final fileName =
        'profile_${DateTime.now().millisecondsSinceEpoch}_${path.basename(imageFile.path)}';
    final persistentPath = path.join(imagesDir.path, fileName);
    return await imageFile.copy(persistentPath);
  }

  Future<void> _pickImage() async {
    try {
      final result = await showModalBottomSheet<ImageSource>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                width: 50,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Select Profile Photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildImageOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    source: ImageSource.camera,
                  ),
                  _buildImageOption(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    source: ImageSource.gallery,
                  ),
                  if (widget.initialProfile.profileImageUrl != null ||
                      _profileImageFile != null)
                    _buildImageOption(
                      icon: Icons.delete,
                      label: 'Remove',
                      isDestructive: true,
                    ),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      );

      if (result == null) return;

      if (result == ImageSource.camera || result == ImageSource.gallery) {
        await _getImage(result);
      } else {
        _removeImage();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error selecting image: ${e.toString()}', isError: true);
      }
    }
  }

  Widget _buildImageOption({
    required IconData icon,
    required String label,
    ImageSource? source,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, isDestructive ? null : source),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isDestructive
                  ? Colors.red[50]
                  : const Color(0xFFB71C1C).withOpacity(0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              icon,
              color: isDestructive ? Colors.red : const Color(0xFFB71C1C),
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: isDestructive ? Colors.red : Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _getImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null && mounted) {
        final originalFile = File(image.path);
        final persistentFile = await _copyImageToPersistentDir(originalFile);
        setState(() {
          _profileImageFile = persistentFile;
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error selecting image: ${e.toString()}', isError: true);
      }
    }
  }

  void _removeImage() {
    if (mounted) {
      setState(() {
        _profileImageFile = null;
      });
    }
  }

  Future<void> _saveProfile() async {
    debugPrint('Save button pressed');
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String? newProfileImageUrl = widget.initialProfile.profileImageUrl;

      // Handle profile image upload/update
      if (_profileImageFile != null) {
        if (_isOnline) {
          try {
            newProfileImageUrl = await _uploadProfileImage(_profileImageFile!);
            debugPrint(
              'Uploaded image, got Firebase URL: ' +
                  (newProfileImageUrl ?? 'null'),
            );
          } catch (e) {
            debugPrint('Failed to upload image: $e');
            newProfileImageUrl = _profileImageFile!.path;
          }
        } else {
          newProfileImageUrl = _profileImageFile!.path;
        }
      } else if (_profileImageFile == null &&
          widget.initialProfile.profileImageUrl != null) {
        newProfileImageUrl = null;
      }

      // Create updated profile
      final updatedProfile = widget.initialProfile.copyWith(
        fullName: _fullNameController.text.trim(),
        facilityName: _facilityNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        specialty: _selectedSpecialty,
        profileImageUrl: newProfileImageUrl,
        lastUpdated: DateTime.now(),
        isSynced: !_isOnline,
      );

      await AuthManager.updateProfile(updatedProfile);

      if (_isOnline) {
        setState(() => _isSyncing = true);
        await AuthManager.syncProfileData();
        final refreshedProfile = await AuthManager.getCurrentUser();
        debugPrint(
          'Refreshed profileImageUrl after sync: ' +
              (refreshedProfile?.profileImageUrl ?? 'null'),
        );
        if (refreshedProfile != null && mounted) {
          setState(() {
            _profileImageFile = null;
            _isEditing = false;
            _isLoading = false;
            _isSyncing = false;
          });
          if (widget.onProfileUpdated != null) {
            widget.onProfileUpdated!(refreshedProfile);
          }
          _showSnackBar('Profile successfully updated');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ProfileScreen(
                initialProfile: refreshedProfile,
                isOnline: _isOnline,
                onProfileUpdated: widget.onProfileUpdated,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _isEditing = false;
            _isLoading = false;
            _isSyncing = false;
          });
          _showSnackBar('Profile successfully updated');
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to save profile: ${e.toString()}', isError: true);
        setState(() {
          _isLoading = false;
          _isSyncing = false;
        });
      }
    }
  }

  Future<String?> _uploadProfileImage(File imageFile) async {
    try {
      final user = await AuthManager.getCurrentUser();
      if (user?.firebaseUid == null) {
        debugPrint('No valid firebaseUid for user.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Not logged in. Please log in again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return null;
      }

      if (!imageFile.existsSync()) {
        debugPrint(
          'File does not exist: \u001b[31m\u001b[1m\u001b[4m${imageFile.path}\u001b[0m',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Profile image file does not exist: ${imageFile.path}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return null;
      }

      debugPrint(
        'Uploading image for user: ${user!.firebaseUid}, file: ${imageFile.path}',
      );

      String? downloadUrl;
      int retryCount = 0;
      const maxRetries = 3;

      while (retryCount < maxRetries) {
        try {
          final ref = FirebaseStorage.instance
              .ref()
              .child('profile_images')
              .child('${user.firebaseUid}.jpg');

          final uploadTask = await ref.putFile(imageFile);
          downloadUrl = await uploadTask.ref.getDownloadURL();

          if (downloadUrl.isNotEmpty) {
            debugPrint('Successfully uploaded image, got URL: $downloadUrl');
            break;
          }
        } catch (e) {
          retryCount++;
          debugPrint('Upload attempt $retryCount failed: $e');

          if (e.toString().contains('object-not-found') ||
              e.toString().contains('AppCheck') ||
              e.toString().contains('permission-denied') ||
              e.toString().contains('security')) {
            return imageFile.path;
          }

          if (retryCount >= maxRetries) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Failed to upload image after $maxRetries attempts. Using local storage.',
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            return imageFile.path;
          }

          await Future.delayed(Duration(seconds: retryCount));
        }
      }

      return downloadUrl;
    } catch (e, stack) {
      debugPrint('Error uploading image: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Image saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
      return imageFile.path;
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red[600] : Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildProfileImage() {
    return Center(
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(child: _buildImageWidget()),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFB71C1C),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageWidget() {
    if (_profileImageFile != null) {
      debugPrint('Displaying _profileImageFile: ' + _profileImageFile!.path);
      return Image.file(_profileImageFile!, fit: BoxFit.cover);
    }

    if (widget.initialProfile.profileImageUrl != null &&
        widget.initialProfile.profileImageUrl!.isNotEmpty) {
      final imageUrl = widget.initialProfile.profileImageUrl!;
      debugPrint('Displaying profileImageUrl: ' + imageUrl);
      if (imageUrl.startsWith('/') && File(imageUrl).existsSync()) {
        return Image.file(File(imageUrl), fit: BoxFit.cover);
      }
      if (imageUrl.startsWith('http')) {
        return Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                    : null,
                color: const Color(0xFFB71C1C),
              ),
            );
          },
        );
      }
    }
    return _buildDefaultAvatar();
  }

  Widget _buildDefaultAvatar() {
    return Image.asset(
      'assets/images/user.png',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          Icon(Icons.person, size: 60, color: Colors.grey[400]),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool readOnly = false,
    int? maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      readOnly: !_isEditing || readOnly,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFFB71C1C)),
        filled: true,
        fillColor: _isEditing ? Colors.white : Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: _isEditing ? Colors.grey.shade300 : Colors.grey.shade200,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFB71C1C), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildSpecialtyDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedSpecialty,
      decoration: InputDecoration(
        labelText: 'Medical Specialty',
        prefixIcon: const Icon(
          Icons.medical_services,
          color: Color(0xFFB71C1C),
        ),
        filled: true,
        fillColor: _isEditing ? Colors.white : Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: _isEditing ? Colors.grey.shade300 : Colors.grey.shade200,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFB71C1C), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      items: _specialties
          .map(
            (specialty) =>
                DropdownMenuItem(value: specialty, child: Text(specialty)),
          )
          .toList(),
      onChanged: _isEditing
          ? (value) {
              if (value != null) {
                setState(() => _selectedSpecialty = value);
              }
            }
          : null,
      validator: (val) => val == null ? 'Please select your specialty' : null,
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
      alignment: Alignment.topRight,
      padding: const EdgeInsets.only(top: 6, right: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _isOnline ? Colors.green : Colors.orange,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 2,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 12,
              color: _isOnline ? Colors.green[700] : Colors.orange[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    if (!_isEditing) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isLoading
                  ? null
                  : () => setState(() {
                      _isEditing = false;
                      _profileImageFile = null;
                    }),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.grey),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB71C1C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Save Changes',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfo() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: [
        ],
      ),
    );
  }

  Widget _buildMemberSinceInfo() {
    final createdAt = widget.initialProfile.createdAt;
    final memberSinceText = createdAt != null
        ? 'Joined on ${_formatDate(createdAt)}'
        : 'Joined on ${_formatDate(DateTime.now())}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today, color: Colors.grey[600], size: 18),
          const SizedBox(width: 8),
          Text(
            memberSinceText,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      decoration: const InputDecoration(
        labelText: 'Email',
        prefixIcon: Icon(Icons.email),
        border: OutlineInputBorder(),
      ),
      enabled: false,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Email is required';
        }
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }

  Future<void> _resendVerificationEmail() async {
    try {
      await AuthManager.resendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent! Please check your inbox.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send verification email: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF3F4),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pushReplacementNamed('/home');
          },
        ),
        title: const Text('Profile', style: appBarTitleStyle),
        centerTitle: true,
        backgroundColor: const Color(0xFFB71C1C),
        foregroundColor: Colors.white,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _isEditing = true),
              tooltip: 'Edit Profile',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildConnectionStatus(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    _buildProfileImage(),
                    const SizedBox(height: 32),
                    _buildTextField(
                      controller: _fullNameController,
                      label: 'Full Name',
                      icon: Icons.person,
                      validator: (value) => value?.isEmpty == true
                          ? 'Full name is required'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    _buildEmailField(),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      icon: Icons.phone,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _licenseController,
                      label: 'License Number',
                      icon: Icons.badge,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _facilityNameController,
                      label: 'Facility Name',
                      icon: Icons.business,
                    ),
                    _buildActionButtons(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            _buildMemberSinceInfo(),
          ],
        ),
      ),
    );
  }
}
