import 'package:flutter/material.dart';
import '../../theme.dart';
import '../home_screen.dart';

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Initialize scroll controller if needed for other functionality
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 360;

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
        title: const Text("SickleClinix", style: appBarTitleStyle),
        backgroundColor: const Color(0xFFB71C1C),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16),
          child: Column(
            children: [
              // Header with icon
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.privacy_tip,
                      color: const Color(0xFFB71C1C),
                      size: isSmallScreen ? 28 : 32,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      "Terms & Conditions",
                      style: TextStyle(
                        fontSize: isSmallScreen ? 20 : 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFB71C1C),
                      ),
                    ),
                  ],
                ),
              ),

              // Terms content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSection(
                        title: "1. ACCEPTANCE OF TERMS",
                        content:
                            "By creating an account and using SickleClinix, you agree to these Terms & Conditions and our Privacy Policy.",
                      ),

                      _buildSection(
                        title: "2. MEDICAL DISCLAIMER",
                        content:
                            "SickleClinix is a diagnostic assistance tool. It does NOT replace professional medical judgment. All AI predictions should be verified by qualified healthcare professionals.",
                      ),

                      _buildSection(
                        title: "3. DATA PRIVACY & SECURITY",
                        content:
                            "• Patient data is encrypted and stored securely\n• We comply with healthcare data protection regulations\n• Data is never shared without explicit consent\n• Local storage with secure cloud synchronization",
                      ),

                      _buildSection(
                        title: "USER RESPONSIBILITIES",
                        content:
                            "• Provide accurate facility and professional information\n• Use the app responsibly for patient care\n• Maintain confidentiality of patient information\n• Report any technical issues promptly",
                      ),

                      _buildSection(
                        title: "5. OFFLINE FUNCTIONALITY",
                        content:
                            "• App works offline with limited features\n• Data syncs automatically when online\n• Critical features available without internet",
                      ),

                      _buildSection(
                        title: "6. PROFESSIONAL LIABILITY",
                        content:
                            "Healthcare professionals remain fully responsible for patient care decisions. SickleClinix provides assistance only.",
                      ),

                      _buildSection(
                        title: "7. UPDATES & MODIFICATIONS",
                        content:
                            "We may update these terms. Continued use implies acceptance of changes. Youu will also be given option to delete account if you don't agree.",
                      ),

                      _buildSection(
                        title: "8. SUPPORT & CONTACT",
                        content:
                            "For technical support or questions, contact: support@sickleclinix.com",
                        isList: true,
                      ),

                      const SizedBox(height: 24),
                      Center(
                        child: Text(
                          "Last Updated: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => HomeScreen()),
                        (route) => false,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Thank you for reading our Terms of Service',
                          ),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB71C1C),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                    ),
                    child: Text(
                      "I ACKNOWLEDGE",
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String content,
    bool isList = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFFB71C1C),
            ),
          ),
          const SizedBox(height: 6),
          isList
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: content.split('\n').map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• '),
                          Expanded(
                            child: Text(
                              item,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                )
              : Text(
                  content,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                ),
          const Divider(height: 24, thickness: 0.5),
        ],
      ),
    );
  }
}
