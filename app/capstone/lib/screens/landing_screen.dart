import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/screens/auth/login_screen.dart';
import '/screens/privacy_consent_screen.dart';
import '/screens/auth/auth_manager.dart';
import '/screens/home_screen.dart';
// import 'package:capstone/screens/home_screen.dart';

class LandingScreen extends StatefulWidget {
  final VoidCallback? onContinue;
  const LandingScreen({super.key, this.onContinue});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _floatController;
  late AnimationController _buttonController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _floatAnimation;
  late Animation<double> _buttonScaleAnimation;

  bool _isButtonPressed = false;
  bool _isCheckingSession = true;

  @override
  void initState() {
    super.initState();

    // Fade-in animation
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _floatAnimation = Tween<double>(begin: -10.0, end: 10.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _floatController.repeat(reverse: true);

    _checkSessionAndNavigate();
  }

  Future<void> _checkSessionAndNavigate() async {
    try {
      final currentUser = await AuthManager.getCurrentUserWithSessionCheck();

      if (mounted) {
        setState(() => _isCheckingSession = false);
      }

      if (currentUser != null) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomeScreen(
                isOffline: false,
                username: currentUser.email.split('@')[0],
                email: currentUser.email,
                fullName: currentUser.fullName,
                facilityName: currentUser.facilityName,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking session: $e');
      if (mounted) {
        setState(() => _isCheckingSession = false);
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _floatController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  void _onButtonPressed() async {
    setState(() => _isButtonPressed = true);
    await _buttonController.forward();

    if (widget.onContinue != null) {
      widget.onContinue!();
    } else {
      final prefs = await SharedPreferences.getInstance();
      final consentGiven = prefs.getBool('privacy_consent_given') ?? false;
      if (!consentGiven) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PrivacyConsentScreen(
              onConsentGiven: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    }

    await _buttonController.reverse();
    setState(() => _isButtonPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF6BA5C4),
      body: Stack(
        children: [
          // Animated background particles
          // ...List.generate(6, (index) => _buildFloatingParticle(size, index)),

          // Top wave
          // Positioned(
          //   top: 0,
          //   left: 0,
          //   right: 0,
          //   child: ClipPath(
          //     clipper: TopWaveClipper(),
          //     child: Container(
          //       height: size.height * 0.15,
          //       // decoration: BoxDecoration(
          //       //   gradient: LinearGradient(
          //       //     // colors: [const Color(0xFF8DC3D8), const Color(0xFF6BA5C4)],
          //       //     begin: Alignment.topCenter,
          //       //     end: Alignment.bottomCenter,
          //       //   ),
          //       // ),
          //     ),
          //   ),
          // ),

          // Bottom wave
          Positioned(
            top: size.height * 0.45,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: EnhancedBottomWaveClipper(),
              child: Container(
                height: size.height * 0.55,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFB80000), Color(0xFFFF8C8C)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),

          FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                const Spacer(flex: 2),

                if (_isCheckingSession) ...[
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Checking session...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 40),
                ],

                AnimatedBuilder(
                  animation: _floatAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _floatAnimation.value),
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFB80000).withOpacity(0.15),
                              blurRadius: 60,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/home-name.png',
                          height: 230,
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 20),

                // Tagline
                SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(0, 0.5),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: _fadeController,
                          curve: const Interval(
                            0.3,
                            1.0,
                            curve: Curves.easeOut,
                          ),
                        ),
                      ),
                  // child: FadeTransition(
                  //   opacity: CurvedAnimation(
                  //     parent: _fadeController,
                  //     curve: const Interval(0.3, 1.0),
                  //   ),
                  //   // child: const Padding(
                  //   //   padding: EdgeInsets.symmetric(horizontal: 40.0),
                  //   //   child: Text(
                  //   //     'Your journey begins here',
                  //   //     textAlign: TextAlign.center,
                  //   //     style: TextStyle(
                  //   //       fontSize: 18,
                  //   //       color: Colors.white,
                  //   //       fontWeight: FontWeight.w300,
                  //   //       letterSpacing: 1.0,
                  //   //       shadows: [
                  //   //         Shadow(
                  //   //           offset: Offset(0, 2),
                  //   //           blurRadius: 4,
                  //   //           color: Colors.black26,
                  //   //         ),
                  //   //       ],
                  //   //     ),
                  //   //   ),
                  //   // ),
                  // ),
                ),

                const Spacer(flex: 2),
                SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(0, 1),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: _fadeController,
                          curve: const Interval(
                            0.6,
                            1.0,
                            curve: Curves.elasticOut,
                          ),
                        ),
                      ),
                  child: FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _fadeController,
                      curve: const Interval(0.6, 1.0),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 50.0),
                      child: ScaleTransition(
                        scale: _buttonScaleAnimation,
                        child: Container(
                          width: double.infinity,
                          height: 55,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                              BoxShadow(
                                color: Colors.white.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, -2),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFFB80000),
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            onPressed: _onButtonPressed,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Get Started',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                AnimatedRotation(
                                  turns: _isButtonPressed ? 0.25 : 0,
                                  duration: const Duration(milliseconds: 200),
                                  child: const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const Spacer(flex: 3),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget _buildFloatingParticle(Size size, int index) {
  //   final random = (index * 37) % 100;
  //   final left = (random / 100) * size.width;
  //   final animationDelay = (index * 200) % 1000;

  //   return Positioned(
  //     left: left,
  //     top: size.height * 0.2 + (random % 200),
  //     child: TweenAnimationBuilder<double>(
  //       tween: Tween(begin: 0, end: 1),
  //       duration: Duration(milliseconds: 2000 + animationDelay),
  //       builder: (context, value, child) {
  //         return Transform.translate(
  //           offset: Offset(10 * value * (index.isEven ? 1 : -1), -20 * value),
  //           child: Opacity(
  //             opacity: (1 - value) * 0.6,
  //             child: Container(
  //               width: 4 + (random % 8),
  //               height: 4 + (random % 8),
  //               decoration: BoxDecoration(
  //                 color: Colors.white.withOpacity(0.4),
  //                 shape: BoxShape.circle,
  //                 boxShadow: [
  //                   BoxShadow(
  //                     color: Colors.white.withOpacity(0.3),
  //                     blurRadius: 8,
  //                     spreadRadius: 2,
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           ),
  //         );
  //       },
  //       onEnd: () {
  //         // Restart animation
  //         setState(() {});
  //       },
  //     ),
  //   );
  // }
}

class TopWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 30);
    path.quadraticBezierTo(
      size.width * 0.2,
      size.height,
      size.width * 0.4,
      size.height - 20,
    );
    path.quadraticBezierTo(
      size.width * 0.6,
      size.height - 40,
      size.width * 0.8,
      size.height - 10,
    );
    path.quadraticBezierTo(
      size.width * 0.9,
      size.height,
      size.width,
      size.height - 25,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class EnhancedBottomWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, 80);

    path.quadraticBezierTo(size.width * 0.15, 20, size.width * 0.3, 60);
    path.quadraticBezierTo(size.width * 0.45, 100, size.width * 0.6, 40);
    path.quadraticBezierTo(size.width * 0.75, -10, size.width * 0.9, 50);
    path.quadraticBezierTo(size.width * 0.95, 80, size.width, 30);

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
