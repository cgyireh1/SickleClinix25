import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrivacyConsentScreen extends StatefulWidget {
  final VoidCallback onConsentGiven;

  const PrivacyConsentScreen({super.key, required this.onConsentGiven});

  @override
  State<PrivacyConsentScreen> createState() => _PrivacyConsentScreenState();
}

class _PrivacyConsentScreenState extends State<PrivacyConsentScreen> {
  bool _hasReadPrivacyPolicy = false;
  bool _hasReadTermsOfService = false;
  bool _consentsToDataCollection = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFB71C1C),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.privacy_tip,
                        color: Colors.white,
                        size: 36,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Privacy & Data Consent',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: MediaQuery.of(context).size.height - 200,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Welcome to SickleClinix',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'This app helps healthcare workers detect sickle cell disease using AI analysis of blood smear images. Before you can use the app, we need your consent for data collection and processing.',
                            style: TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 20),

                          // Data Collection Section
                          _buildSection('What Data We Collect', [
                            '• Patient information (name, age, gender, contact)',
                            '• Blood smear images for AI analysis',
                            '• Analysis results and confidence scores',
                            '• Device information for app functionality',
                            '• Usage statistics for app improvement',
                          ], Icons.data_usage),

                          const SizedBox(height: 16),

                          // Data Usage Section
                          _buildSection('How We Use Your Data', [
                            '• AI analysis of blood smear images',
                            '• Patient record management',
                            '• Offline functionality with cloud backup',
                            '• App performance monitoring',
                            '• Healthcare worker authentication',
                          ], Icons.security),

                          const SizedBox(height: 16),

                          // Privacy Protection Section
                          _buildSection('Privacy Protection', [
                            '• All data is encrypted locally',
                            '• Cloud data is secured with Firebase',
                            '• Patient data is isolated per healthcare worker',
                            '• No data is shared with third parties',
                            '• You can delete data at any time',
                          ], Icons.lock),

                          const SizedBox(height: 20),

                          // Consent Checkboxes
                          CheckboxListTile(
                            value: _hasReadPrivacyPolicy,
                            onChanged: (value) {
                              setState(() {
                                _hasReadPrivacyPolicy = value ?? false;
                              });
                            },
                            title: const Text('I have read the Privacy Policy'),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                          ),

                          CheckboxListTile(
                            value: _hasReadTermsOfService,
                            onChanged: (value) {
                              setState(() {
                                _hasReadTermsOfService = value ?? false;
                              });
                            },
                            title: const Text(
                              'I have read the Terms of Service',
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                          ),

                          CheckboxListTile(
                            value: _consentsToDataCollection,
                            onChanged: (value) {
                              setState(() {
                                _consentsToDataCollection = value ?? false;
                              });
                            },
                            title: const Text(
                              'I consent to data collection and processing',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                          ),

                          const SizedBox(height: 20),

                          // Links
                          Row(
                            children: [
                              TextButton(
                                onPressed: () {
                                  _showPrivacyPolicy();
                                },
                                child: const Text('Privacy Policy'),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/terms');
                                },
                                child: const Text('Terms of Service'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        SystemNavigator.pop();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade600,
                      ),
                      child: const Text('Decline & Exit'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _canProceed() ? _acceptConsent : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB71C1C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Accept & Continue'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<String> items, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFB71C1C), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(item, style: const TextStyle(fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  bool _canProceed() {
    return _hasReadPrivacyPolicy &&
        _hasReadTermsOfService &&
        _consentsToDataCollection;
  }

  Future<void> _acceptConsent() async {
    print('Accepting consent...');

    // Save consent status
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_consent_given', true);
    await prefs.setString('consent_date', DateTime.now().toIso8601String());

    print('Consent saved successfully');
    print('Calling onConsentGiven callback...');
    widget.onConsentGiven();
    print('Callback completed');
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SickleClinix Privacy Policy',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 16),
              Text(
                'Data Collection: We collect only essential patient data for sickle cell detection.',
              ),
              SizedBox(height: 8),
              Text(
                'Data Storage: All data is encrypted and stored locally on your device.',
              ),
              SizedBox(height: 8),
              Text(
                'Data Sharing: Patient data is never shared without explicit consent.',
              ),
              SizedBox(height: 8),
              Text(
                'Security: We use industry-standard encryption to protect your data.',
              ),
              SizedBox(height: 8),
              Text(
                'Compliance: We follow HIPAA and local healthcare regulations.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
