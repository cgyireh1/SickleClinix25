import 'package:flutter/material.dart';
import 'package:capstone/screens/auth/auth_manager.dart';
import 'package:capstone/models/user_profile.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:capstone/widgets/app_bottom_navbar.dart';
import '../theme.dart';
import 'package:capstone/screens/landing_screen.dart';

class _ServiceCardData {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  _ServiceCardData({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class HomeScreen extends StatefulWidget {
  final String? username;
  final String? email;
  final String? fullName;
  final String? facilityName;
  final String? profileImageUrl;
  final bool isOffline;
  final UserProfile? testUserProfile;

  const HomeScreen({
    super.key,
    this.username,
    this.email,
    this.fullName,
    this.facilityName,
    this.profileImageUrl,
    this.isOffline = false,
    this.testUserProfile,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserProfile? _currentUser;
  bool _isLoading = true;
  int _unreadNotificationCount = 0;
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    if (widget.testUserProfile != null) {
      _currentUser = widget.testUserProfile;
      _isLoading = false;
    } else {
      _loadCurrentUser();
    }
    _loadUnreadNotificationCount();
    _checkConnectivity();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await AuthManager.getCurrentUser();
      if (mounted) {
        setState(() {
          _currentUser = user;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      print('Error loading current user: $e');
    }
  }

  Future<void> _loadUnreadNotificationCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final user = await AuthManager.getCurrentUser();
      final email = user?.email ?? 'anonymous';
      final emailKey = email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final savedNotifications =
          prefs.getStringList('notifications_$emailKey') ?? [];
      int count = 0;
      for (final json in savedNotifications) {
        final parts = json.split('|');
        if (parts.length >= 4 && parts[3] == 'false') {
          count++;
        }
      }
      if (mounted) {
        setState(() {
          _unreadNotificationCount = count;
        });
      }
    } catch (e) {
      // ignore error, just show 0
    }
  }

  Future<void> _checkConnectivity() async {
    final online = await AuthManager.isOnline;
    if (mounted) {
      setState(() => _isOnline = online);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 600;

    if (_isLoading) {
      return Scaffold(
        appBar: _buildAppBar(context),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFFB71C1C)),
        ),
      );
    }

    if (_currentUser == null) {
      return Scaffold(
        appBar: _buildAppBar(context),
        body: const Center(child: Text('No user data available')),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(context),
      drawer: _buildDrawer(context),
      body: _buildBody(context, isLargeScreen),
      bottomNavigationBar: const AppBottomNavBar(currentRoute: '/home'),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: const Color(0xFFB71C1C),
      elevation: 0,
      centerTitle: true,
      foregroundColor: Colors.white,
      title: const Text("SickleClinix", style: appBarTitleStyle),
      actions: [
        Stack(
          children: [
            _buildNotificationButton(context),
            Positioned(top: -8, right: 0, child: _buildConnectionStatus()),
          ],
        ),
        // _buildSettingsButton(context),
      ],
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.only(right: 4, top: 8),
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
    );
  }

  Widget _buildNotificationButton(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications),
          onPressed: () async {
            await Navigator.pushNamed(context, '/notifications');
            _loadUnreadNotificationCount();
          },
        ),
        if (_unreadNotificationCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(6),
              ),
              constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
              child: Text(
                '$_unreadNotificationCount',
                style: const TextStyle(color: Colors.white, fontSize: 8),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  // Widget _buildSettingsButton(BuildContext context) {
  //   return IconButton(
  //     icon: const Icon(Icons.settings),
  //     onPressed: () => Navigator.pushNamed(context, '/settings'),
  //   );
  // }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          _buildDrawerHeader(context),
          Expanded(child: _buildDrawerMenu(context)),
          _buildAppVersionFooter(),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 40, bottom: 20, left: 20, right: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFB71C1C), Color(0xFFD32F2F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileAvatar(context),
          const SizedBox(height: 16),
          _buildUserInfo(),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar(BuildContext context) {
    final imageUrl = _currentUser?.profileImageUrl;
    Widget avatarChild;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      if (imageUrl.startsWith('http')) {
        avatarChild = ClipOval(
          child: Image.network(
            imageUrl,
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
          ),
        );
      } else if (imageUrl.startsWith('/') && File(imageUrl).existsSync()) {
        avatarChild = ClipOval(
          child: Image.file(
            File(imageUrl),
            width: 80,
            height: 80,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
          ),
        );
      } else {
        avatarChild = _buildDefaultAvatar();
      }
    } else {
      avatarChild = _buildDefaultAvatar();
    }
    return CircleAvatar(
      radius: 40,
      backgroundColor: Colors.white.withOpacity(0.2),
      child: avatarChild,
    );
  }

  Widget _buildDefaultAvatar() {
    return const Icon(Icons.person, size: 40, color: Colors.white);
  }

  Widget _buildUserInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _currentUser?.fullName ?? 'User',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _currentUser?.email ?? 'user@example.com',
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
        ),
        if (_currentUser?.facilityName != null) ...[
          const SizedBox(height: 4),
          Text(
            _currentUser!.facilityName,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDrawerMenu(BuildContext context) {
    return ListView(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16),
      children: [
        _buildDrawerMenuItem(
          context,
          Icons.home,
          'Home',
          '/home',
          isSelected: true,
        ),
        _buildDrawerMenuItem(
          context,
          Icons.dashboard,
          'Dashboard',
          '/dashboard',
        ),
        _buildDrawerMenuItem(context, Icons.analytics, 'Predict', '/predict'),
        _buildDrawerMenuItem(context, Icons.people, 'Patients', '/patients'),
        _buildDrawerMenuItem(context, Icons.history, 'History', '/history'),
        const Divider(),
        _buildDrawerMenuItem(context, Icons.settings, 'Settings', '/settings'),
        _buildDrawerMenuItem(
          context,
          Icons.person,
          'Profile',
          '/profile',
          startInEditMode: true,
        ),
        _buildDrawerMenuItem(context, Icons.access_time, 'Terms', '/terms'),
        _buildDrawerMenuItem(
          context,
          Icons.data_usage,
          'Manage Data',
          '/data-management',
        ),
        _buildDrawerMenuItem(
          context,
          Icons.help,
          'Help & Support',
          '/help-support',
        ),
        const Divider(),
        ListTile(
          leading: Icon(Icons.logout, color: Colors.red[700]),
          title: Text(
            'Logout',
            style: TextStyle(
              color: Colors.red[700],
              fontWeight: FontWeight.bold,
            ),
          ),
          onTap: () async {
            Navigator.pop(context); // Close drawer
            await AuthManager.logout();
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => LandingScreen()),
              (route) => false,
            );
          },
        ),
      ],
    );
  }

  Widget _buildDrawerMenuItem(
    BuildContext context,
    IconData icon,
    String title,
    String route, {
    bool isSelected = false,
    bool startInEditMode = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? const Color(0xFFB71C1C) : Colors.grey[600],
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? const Color(0xFFB71C1C) : Colors.grey[800],
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: () {
        Navigator.pop(context); // Close drawer
        if (startInEditMode) {
          Navigator.pushReplacementNamed(
            context,
            route,
            arguments: {'startInEditMode': true},
          );
        } else {
          Navigator.pushReplacementNamed(context, route);
        }
      },
    );
  }

  Widget _buildAppVersionFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: const Text(
        'SickleClinix v1.0.0',
        style: TextStyle(color: Colors.grey, fontSize: 12),
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool isLargeScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderImageWithFade(),
        _buildWelcomeSection(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: _buildServiceGrid(),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeSection() {
    return Padding(
      padding: const EdgeInsets.only(left: 30, right: 8, top: 10, bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome, ${_currentUser?.fullName ?? 'User'}!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'These are the core features of SickleClinix',
            style: TextStyle(fontSize: 16, color: Colors.black87),
          ),
          SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildHeaderImageWithFade() {
    return Stack(
      children: [
        SizedBox(
          width: double.infinity,
          height: 220,
          child: Image.asset('assets/images/cells.png', fit: BoxFit.cover),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            height: 100,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.white],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServiceGrid() {
    final List<_ServiceCardData> services = [
      _ServiceCardData(
        label: 'Prediction',
        icon: Icons.analytics,
        color: const Color(0xFF43BFA0),
        onTap: () => Navigator.pushNamed(context, '/predict'),
      ),
      _ServiceCardData(
        label: 'History',
        icon: Icons.history,
        color: const Color(0xFF6C63FF),
        onTap: () => Navigator.pushNamed(context, '/history'),
      ),
      _ServiceCardData(
        label: 'Dashboard',
        icon: Icons.dashboard,
        color: const Color(0xFFFD7E50),
        onTap: () => Navigator.pushNamed(context, '/dashboard'),
      ),
      _ServiceCardData(
        label: 'Patients',
        icon: Icons.people,
        color: const Color(0xFFFFC542),
        onTap: () => Navigator.pushNamed(context, '/patients'),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 25,
      crossAxisSpacing: 25,
      childAspectRatio: 1,
      physics: const NeverScrollableScrollPhysics(),
      children: services.map((service) => _buildServiceCard(service)).toList(),
    );
  }

  Widget _buildServiceCard(_ServiceCardData data) {
    return Material(
      color: data.color,
      borderRadius: BorderRadius.circular(22),
      elevation: 6,
      shadowColor: data.color.withOpacity(0.25),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: data.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(data.icon, size: 35, color: Colors.white),
              const SizedBox(height: 14),
              Text(
                data.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 2,
                      color: Colors.black26,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavBar(BuildContext context) {
    return BottomAppBar(
      color: const Color(0xFFFDF3F4),
      elevation: 10,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home, 'Home', '/home', true, Color(0xFFB71C1C)),
            _buildNavItem(
              Icons.history,
              'History',
              '/history',
              false,
              Color(0xFFB71C1C),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label,
    String route,
    bool isSelected,
    Color iconColor,
  ) {
    return GestureDetector(
      onTap: () => Navigator.pushReplacementNamed(context, route),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: iconColor,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
