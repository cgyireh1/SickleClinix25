import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/firebase_service.dart';
import '../theme.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  String _selectedCategory = 'General';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      _showSnackBar('Could not launch phone app', isError: true);
    }
  }

  void _clearForm() {
    _nameController.clear();
    _emailController.clear();
    _subjectController.clear();
    _messageController.clear();
    setState(() {
      _selectedCategory = 'General';
    });
  }

  Future<void> _submitContactForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final contactData = {
        'name': _nameController.text,
        'email': _emailController.text,
        'category': _selectedCategory,
        'subject': _subjectController.text,
        'message': _messageController.text,
        'timestamp': DateTime.now().toIso8601String(),
        'type': 'contact_form',
      };

      // Store in local storage
      final prefs = await SharedPreferences.getInstance();
      final offlineContact = prefs.getStringList('offline_contact') ?? [];
      offlineContact.add(jsonEncode(contactData));
      await prefs.setStringList('offline_contact', offlineContact);

      try {
        final firebaseService = FirebaseService();
        if (await firebaseService.isOnline) {
          final contactId = DateTime.now().millisecondsSinceEpoch.toString();
          await firebaseService
              .syncData('contact_requests', contactId, contactData)
              .timeout(const Duration(seconds: 3));
          debugPrint('Contact form synced to Firebase');
        } else {
          debugPrint('Offline - contact form stored locally only');
        }
      } catch (e) {
        debugPrint('Firebase sync failed, but contact form saved locally: $e');
      }

      if (mounted) {
        final firebaseService = FirebaseService();
        final isOnline = await firebaseService.isOnline;

        if (isOnline) {
          _showSnackBar('Thank you! Your message has been sent successfully.');
        } else {
          _showSnackBar(
            'Thank you! Your message has been saved and will be sent when you\'re back online.',
          );
        }
        _clearForm();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          'Failed to save request. Please try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
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
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed('/home');
            }
          },
        ),
        title: const Text('Help & Support', style: appBarTitleStyle),
        centerTitle: true,
        backgroundColor: const Color(0xFFB71C1C),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 14),
          tabs: const [
            Tab(text: 'About'),
            Tab(text: 'FAQ'),
            Tab(text: 'Guides'),
            Tab(text: 'Contact'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAboutTab(),
          _buildFAQTab(),
          _buildGuidesTab(),
          _buildContactTab(),
        ],
      ),
    );
  }

  Widget _buildAboutTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/images/just-sickle.png',
                      width: 100,
                      height: 100,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'SickleClinix',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB71C1C),
                  ),
                ),
                const Text(
                  'Version 1.0.0',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoSection(
            'About SickleClinix',
            'SickleClinix is a diagnostic tool designed to assist healthcare professionals in the early detection and management of sickle cell disease. Our mission is to improve patient outcomes through advanced technology.',
          ),
          _buildInfoSection(
            'Our Mission',
            'To revolutionize sickle cell disease management by providing healthcare professionals with accurate, accessible, and actionable diagnostic tools that improve patient care and outcomes worldwide.',
          ),
          _buildInfoSection(
            'Key Features',
            '• Sickle cell prediction\n• Offline functionality for remote areas                                      \n• Comprehensive patient history tracking\n• Secure data management\n• Real-time notifications',
          ),
          _buildInfoSection(
            'Legal Information',
            'SickleClinix is a medical device software intended for use by qualified healthcare professionals only. This software is not intended to replace clinical judgment or medical expertise.',
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              '© 2025 SickleClinix. All rights reserved.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFFB71C1C),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFAQItem(
            'How do I make a prediction?',
            'Go to the Home screen and tap "Make Prediction" or use the camera icon. Select or add a patient, then take a photo or choose from gallery.',
          ),
          _buildFAQItem(
            'What if the app crashes?',
            'First, try restarting the app. If the problem persists, check for updates or contact our support team with details about when the crash occurred.',
          ),
          _buildFAQItem(
            'How do I provide feedback?',
            'Go to the "Help & Support" and navigate to the "Contact" section. Scroll to the bottom, you will find the "Send us a message" form.',
          ),
          _buildFAQItem(
            'Is my data secure?',
            'Yes, all patient data is stored locally on your device and optionally synced to secure cloud storage. We follow strict privacy guidelines.',
          ),
          _buildFAQItem(
            'Can I use the app offline?',
            'Yes! SickleClinix works completely offline. All core features are available without internet connection.',
          ),
          _buildFAQItem(
            'How accurate are the predictions?',
            'Our AI model has been trained on extensive datasets, but predictions should always be used as a screening tool alongside clinical judgment.',
          ),
        ],
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFFB71C1C),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              answer,
              style: TextStyle(color: Colors.grey[700], height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildContactCard(
            'Emergency Support',
            'For urgent technical issues affecting patient care',
            [
              _buildContactMethod(
                Icons.phone,
                '+250 791 704 001',
                'Available 24/7',
                () => _makePhoneCall('+250791704001'),
              ),
            ],
            Colors.red[50]!,
            Colors.red[600]!,
          ),
          const SizedBox(height: 16),
          _buildContactCard(
            'General Support',
            'For general questions and non-urgent issues',
            [
              _buildContactMethod(
                Icons.phone,
                '+250 987 654 321',
                'Mon-Fri, 8 AM - 6 PM',
                () => _makePhoneCall('+250987654321'),
              ),
            ],
            Colors.blue[50]!,
            Colors.blue[600]!,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.green[600]!.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.message, color: Colors.green[600]),
                    const SizedBox(width: 8),
                    Text(
                      'Send us a Message',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'For all other inquiries, bug reports, feature requests, and feedback, please use the contact form below.',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildContactForm(),
        ],
      ),
    );
  }

  Widget _buildContactCard(
    String title,
    String description,
    List<Widget> methods,
    Color backgroundColor,
    Color accentColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.support_agent, color: accentColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(description, style: TextStyle(color: Colors.grey[700])),
          const SizedBox(height: 12),
          ...methods,
        ],
      ),
    );
  }

  Widget _buildContactMethod(
    IconData icon,
    String text,
    String subtitle,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFB71C1C)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildContactForm() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.feedback,
                    color: const Color(0xFFB71C1C),
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Send us a message',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Name field
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Your Name',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFB71C1C)),
                  ),
                ),
                validator: (value) =>
                    value?.isEmpty == true ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),

              // Email field
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFB71C1C)),
                  ),
                ),
                validator: (value) {
                  if (value?.isEmpty == true) return 'Email is required';
                  if (!RegExp(
                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                  ).hasMatch(value!)) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category dropdown
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Category',
                  prefixIcon: const Icon(Icons.category),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFB71C1C)),
                  ),
                ),
                items:
                    const [
                      'General',
                      'Technical Issue',
                      'Bug Report',
                      'Feature Request',
                      'Account Issue',
                      'Privacy Concern',
                      'Other',
                    ].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    _selectedCategory = newValue!;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Subject field
              TextFormField(
                controller: _subjectController,
                decoration: InputDecoration(
                  labelText: 'Subject',
                  prefixIcon: const Icon(Icons.subject),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFB71C1C)),
                  ),
                ),
                validator: (value) =>
                    value?.isEmpty == true ? 'Subject is required' : null,
              ),
              const SizedBox(height: 16),

              // Message field
              TextFormField(
                controller: _messageController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Message',
                  prefixIcon: const Icon(Icons.message),
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFB71C1C)),
                  ),
                ),
                validator: (value) {
                  if (value?.isEmpty == true) return 'Message is required';
                  if (value!.length < 10)
                    return 'Message must be at least 10 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitContactForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB71C1C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Send Message',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuidesTab() {
    const guides = [
      {
        'title': 'How to Make a Prediction',
        'steps': [
          'Go to the Home screen and tap "Make Prediction" or use the camera icon.',
          'Select or add a patient (optional, but recommended for tracking).',
          'Take a photo of the blood smear or select from your gallery.',
          'Wait for the AI analysis to complete.',
          'Review the prediction results and confidence score.',
          'Save the prediction to patient history if desired.',
        ],
      },
      {
        'title': 'Managing Patients',
        'steps': [
          'Navigate to the Patients tab from the bottom navigation.',
          'Tap the + button to add a new patient.',
          'Fill in patient details (name, age, gender, contact).',
          'View patient profile by tapping on a patient card.',
          'Edit patient information using the edit button.',
          'Delete patients by long-pressing on patient cards.',
        ],
      },
      {
        'title': 'Understanding Results',
        'steps': [
          'Prediction results show the likelihood of sickle cell presence.',
          'Confidence scores indicate the reliability of the prediction.',
          'Grad-CAM visualizations highlight areas the AI focused on.',
          'Results are automatically saved to patient history.',
          'You can export results or share them with colleagues.',
          'Always use results as a screening tool, not final diagnosis.',
        ],
      },
      {
        'title': 'Offline Usage',
        'steps': [
          'The app works completely offline for all core features.',
          'Patient data is stored locally on your device.',
          'Predictions are made using on-device AI models.',
          'Data syncs to cloud when internet is available.',
          'No internet required for daily use.',
          'Backup your data regularly for safety.',
        ],
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: guides.map((guide) => _buildGuideCard(guide)).toList(),
      ),
    );
  }

  Widget _buildGuideCard(Map<String, dynamic> guide) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ExpansionTile(
        title: Text(
          guide['title'],
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFFB71C1C),
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: (guide['steps'] as List<String>).asMap().entries.map((
                entry,
              ) {
                final index = entry.key;
                final step = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: const Color(0xFFB71C1C),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          step,
                          style: TextStyle(
                            color: Colors.grey[700],
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
