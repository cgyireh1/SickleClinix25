import 'package:flutter/material.dart';
import '/screens/auth/auth_manager.dart';
import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _facilityController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  // State variables
  bool _agreeToTerms = false;
  bool _hasViewedTerms = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isOnline = false;
  // bool _isSyncing = false;
  String _selectedSpecialty = 'General Practitioner';

  // Predefined specialties
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

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _phoneController.text = '+250 ';
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _facilityController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _checkConnectivity() async {
    final online = await AuthManager.isOnline;
    setState(() => _isOnline = online);
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  String? _validatePassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }
    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Password must contain at least one special character';
    }
    return null;
  }

  Widget _buildCreateAccountButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitForm,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFB71C1C),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
              )
            : const Text("Create Account"),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Already have an account?",
          style: TextStyle(color: Colors.grey[700], fontSize: 15),
        ),
        TextButton(
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          ),
          child: const Text(
            "LOG IN",
            style: TextStyle(
              color: Color(0xFFB80000),
              fontWeight: FontWeight.bold,
              fontSize: 15,
              // decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTermsSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Checkbox(
          value: _agreeToTerms,
          onChanged: (value) async {
            if (!_hasViewedTerms) {
              await _showTermsDialog();
            }
            setState(() {
              _agreeToTerms = value ?? false;
            });
          },
          activeColor: const Color(0xFFB71C1C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          visualDensity: VisualDensity.compact,
        ),
        Expanded(
          child: GestureDetector(
            onTap: () async {
              await _showTermsDialog();
              setState(() {
                _agreeToTerms = true;
              });
            },
            child: RichText(
              text: TextSpan(
                text: 'I agree to the ',
                style: TextStyle(color: Colors.grey[800], fontSize: 14),
                children: [
                  TextSpan(
                    text: 'Terms & Conditions',
                    style: const TextStyle(
                      color: Color(0xFFB71C1C),
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_agreeToTerms && _hasViewedTerms)
          const Padding(
            padding: EdgeInsets.only(left: 4.0),
            child: Icon(Icons.check_circle, color: Colors.green, size: 20),
          ),
      ],
    );
  }

  Future<void> _showTermsDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFB71C1C).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.description, color: Color(0xFFB71C1C)),
            ),
            const SizedBox(width: 12),
            const Text("Terms & Conditions"),
          ],
        ),
        content: SizedBox(
          height: 400,
          child: SingleChildScrollView(
            child: const Text(
              "SICKLE CLINIX TERMS & CONDITIONS\n\n"
              "1. ACCEPTANCE OF TERMS\n"
              "By creating an account and using SickleClinix, you agree to these Terms & Conditions and our Privacy Policy.\n\n"
              "2. MEDICAL DISCLAIMER\n"
              "SickleClinix is a diagnostic assistance tool. It does NOT replace professional medical judgment. All AI predictions should be verified by qualified healthcare professionals.\n\n"
              "3. DATA PRIVACY & SECURITY\n"
              "• Patient data is encrypted and stored securely\n"
              "• We comply with healthcare data protection regulations\n"
              "• Data is never shared without explicit consent\n"
              "• Local storage with secure cloud synchronization\n\n"
              "4. USER RESPONSIBILITIES\n"
              "• Provide accurate facility and professional information\n"
              "• Use the app responsibly for patient care\n"
              "• Maintain confidentiality of patient information\n"
              "• Report any technical issues promptly\n\n"
              "5. OFFLINE FUNCTIONALITY\n"
              "• App works offline with limited features\n"
              "• Data syncs automatically when online\n"
              "• Critical features available without internet\n\n"
              "6. PROFESSIONAL LIABILITY\n"
              "Healthcare professionals remain fully responsible for patient care decisions. SickleClinix provides assistance only.\n\n"
              "7. UPDATES & MODIFICATIONS\n"
              "We may update these terms. Continued use implies acceptance of changes.\n\n"
              "8. SUPPORT & CONTACT\n"
              "For technical support or questions, contact: support@sickleclinix.com\n\n"
              "Last updated: June 2025",
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("Cancel", style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _hasViewedTerms = true);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB71C1C),
              foregroundColor: Colors.white,
            ),
            child: const Text("I Understand"),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      _showErrorSnackBar('Please fill all required fields correctly.');
      return;
    }
    if (!_agreeToTerms) {
      _showErrorSnackBar('You must agree to the Terms & Conditions.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await AuthManager.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        fullName: _fullNameController.text.trim(),
        facilityName: _facilityController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        specialty: _selectedSpecialty,
      );
      if (!mounted) return;

      _showSuccessSnackBar();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Sign up failed. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Account created successfully! Please check your email for verification.',
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _getErrorMessage(String error) {
    if (error.contains('User already exists')) {
      return 'An account with this email already exists';
    } else if (error.contains('weak-password')) {
      return 'Password is too weak (min 8 chars)';
    } else if (error.contains('email-already-in-use')) {
      return 'Email is already registered';
    } else if (error.contains('invalid-email')) {
      return 'Please enter a valid email address';
    } else if (error.contains('network-request-failed')) {
      return 'Network error. Please check your connection';
    } else {
      return 'Sign-up failed: ${error.split(':').last.trim()}';
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red[600] : Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: Duration(seconds: isError ? 4 : 3),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
      alignment: Alignment.topRight,
      padding: const EdgeInsets.only(top: 6, right: 12),
      child: Container(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF3F4),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            _buildConnectionStatus(),
            Expanded(
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            const SizedBox(height: 8),
                            Image.asset('assets/images/login.png', height: 130),
                            const SizedBox(height: 12),
                            Text(
                              "Join SickleClinix",
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFB71C1C),
                                  ),
                            ),
                            const SizedBox(height: 28),
                            ..._buildFormFields(),
                            _buildTermsSection(),
                            const SizedBox(height: 24),
                            _buildCreateAccountButton(),
                            const SizedBox(height: 20),
                            _buildLoginLink(),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFormFields() {
    return [
      TextFormField(
        controller: _fullNameController,
        decoration: InputDecoration(
          labelText: "Full Name",
          prefixIcon: Icon(
            Icons.person_rounded,
            color: const Color(0xFFB71C1C),
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFB71C1C), width: 2),
          ),
        ),
        textCapitalization: TextCapitalization.words,
        autofillHints: [AutofillHints.name],
        validator: (val) {
          if (val == null || val.trim().isEmpty) {
            return 'Full name is required';
          }
          if (val.trim().length < 2) {
            return 'Name must be at least 2 characters';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _facilityController,
        decoration: InputDecoration(
          labelText: "Healthcare Facility",
          prefixIcon: Icon(
            Icons.local_hospital_rounded,
            color: const Color(0xFFB71C1C),
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFB71C1C), width: 2),
          ),
        ),
        textCapitalization: TextCapitalization.words,
        validator: (val) {
          if (val == null || val.trim().isEmpty) {
            return 'Facility name is required';
          }
          if (val.trim().length < 2) {
            return 'Facility name must be at least 2 characters';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _emailController,
        decoration: InputDecoration(
          labelText: "Email Address",
          prefixIcon: Icon(Icons.email_rounded, color: const Color(0xFFB71C1C)),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFB71C1C), width: 2),
          ),
        ),
        keyboardType: TextInputType.emailAddress,
        autofillHints: [AutofillHints.email],
        validator: (val) {
          if (val == null || val.trim().isEmpty) {
            return 'Email is required';
          }
          if (!_isValidEmail(val.trim())) {
            return 'Enter a valid email address';
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _phoneController,
        decoration: InputDecoration(
          labelText: "Phone Number",
          prefixIcon: Icon(Icons.phone_rounded, color: const Color(0xFFB71C1C)),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFB71C1C), width: 2),
          ),
        ),
        keyboardType: TextInputType.phone,
        autofillHints: [AutofillHints.telephoneNumber],
        validator: (val) {
          if (val != null && val.trim().isNotEmpty) {
            String cleanPhone = val.replaceAll('+250 ', '').trim();
            if (cleanPhone.isNotEmpty && cleanPhone.length < 9) {
              return 'Enter a valid phone number';
            }
          }
          return null;
        },
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        value: _selectedSpecialty,
        decoration: InputDecoration(
          labelText: "Specialty",
          prefixIcon: Icon(
            Icons.medical_services_rounded,
            color: const Color(0xFFB71C1C),
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFB71C1C), width: 2),
          ),
        ),
        items: _specialties.map((specialty) {
          return DropdownMenuItem<String>(
            value: specialty,
            child: Text(specialty),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _selectedSpecialty = value;
            });
          }
        },
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _passwordController,
        decoration: InputDecoration(
          labelText: "Password",
          prefixIcon: Icon(Icons.lock_rounded, color: const Color(0xFFB71C1C)),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFB71C1C), width: 2),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        obscureText: _obscurePassword,
        autofillHints: [AutofillHints.newPassword],
        validator: _validatePassword,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _confirmPasswordController,
        decoration: InputDecoration(
          labelText: "Confirm Password",
          prefixIcon: Icon(
            Icons.lock_outline_rounded,
            color: const Color(0xFFB71C1C),
          ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFB71C1C), width: 2),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
            ),
            onPressed: () => setState(
              () => _obscureConfirmPassword = !_obscureConfirmPassword,
            ),
          ),
        ),
        obscureText: _obscureConfirmPassword,
        autofillHints: [AutofillHints.newPassword],
        validator: (val) {
          if (val == null || val.isEmpty) {
            return 'Please confirm your password';
          }
          if (val != _passwordController.text) {
            return 'Passwords do not match';
          }
          return null;
        },
      ),
    ];
  }
}
