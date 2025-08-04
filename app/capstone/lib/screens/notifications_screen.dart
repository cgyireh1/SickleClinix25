import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/auth/auth_manager.dart';
import '../screens/patient_profile_screen.dart';
import '../theme.dart';

Future<void> addAppNotification({
  required String title,
  required String message,
  required String type,
  String? payload,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final now = DateTime.now();
  final user = await AuthManager.getCurrentUser();
  final email = user?.email ?? 'anonymous';
  final emailKey = email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
  final key = 'notifications_$emailKey';
  final notification =
      '$title|$message|${now.toIso8601String()}|false|$type|${payload ?? ''}';
  final notifications = prefs.getStringList(key) ?? [];
  notifications.insert(0, notification);
  await prefs.setStringList(key, notifications);
}

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _allNotifications = [];
  bool _isLoading = false;
  String? _userEmailKey;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initUserKeyAndLoadNotifications();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initUserKeyAndLoadNotifications();
  }

  Future<void> _initUserKeyAndLoadNotifications() async {
    final user = await AuthManager.getCurrentUser();
    if (user != null) {
      final newEmailKey = user.email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

      if (_userEmailKey != newEmailKey) {
        _userEmailKey = newEmailKey;
        await _loadNotifications();
        setState(() {});
      }
    } else {
      _userEmailKey = null;
      _allNotifications = [];
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'notifications_${_userEmailKey ?? 'anonymous'}';
      final savedNotifications = prefs.getStringList(key) ?? [];

      if (savedNotifications.isNotEmpty) {
        _allNotifications = savedNotifications.map((json) {
          final parts = json.split('|');
          return {
            'title': parts[0],
            'message': parts[1],
            'time': DateTime.parse(parts[2]),
            'isRead': parts[3] == 'true',
            'type': parts[4],
            'payload': parts.length > 5 ? parts[5] : null,
          };
        }).toList();
      } else {
        _allNotifications = [];
      }
    } catch (e) {
      _allNotifications = [];
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'notifications_${_userEmailKey ?? 'anonymous'}';
      final notificationsJson = _allNotifications
          .map(
            (notification) =>
                '${notification['title']}|${notification['message']}|${notification['time'].toIso8601String()}|${notification['isRead']}|${notification['type']}|${notification['payload'] ?? ''}',
          )
          .toList();
      await prefs.setStringList(key, notificationsJson);
    } catch (e) {
      debugPrint('Error saving notifications: $e');
    }
  }

  void _markAllAsRead() async {
    setState(() {
      for (var notification in _allNotifications) {
        notification['isRead'] = true;
      }
    });
    await _saveNotifications();
    await _loadNotifications();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _markAsRead(int index) async {
    setState(() {
      _allNotifications[index]['isRead'] = true;
    });
    await _saveNotifications();
  }

  void _deleteNotification(int index) async {
    setState(() {
      _allNotifications.removeAt(index);
    });
    await _saveNotifications();
    await _loadNotifications();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notification deleted'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _addNotification(Map<String, dynamic> notification) async {
    setState(() {
      _allNotifications.insert(0, notification);
    });
    await _saveNotifications();
  }

  Future<void> _clearAllNotifications() async {
    setState(() {
      _allNotifications.clear();
    });
    await _saveNotifications();
    await _loadNotifications();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications cleared'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> clearAllNotificationsForCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'notifications_${_userEmailKey ?? 'anonymous'}';
      await prefs.remove(key);

      setState(() {
        _allNotifications.clear();
      });

      debugPrint('Cleared all notifications for user: ${_userEmailKey}');
    } catch (e) {
      debugPrint('Error clearing notifications: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final readNotifications = _allNotifications
        .where((n) => n['isRead'])
        .toList();
    final unreadNotifications = _allNotifications
        .where((n) => !n['isRead'])
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications', style: appBarTitleStyle),
        centerTitle: true,
        backgroundColor: const Color(0xFFB71C1C),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('All'),
                  if (_allNotifications.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_allNotifications.length}',
                        style: const TextStyle(
                          color: Color(0xFFB71C1C),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Unread'),
                  if (unreadNotifications.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${unreadNotifications.length}',
                        style: const TextStyle(
                          color: Color(0xFFB71C1C),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Tab(text: 'Read'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'clear_all':
                  _showClearAllDialog();
                  break;
                case 'refresh':
                  _loadNotifications();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(
                  children: [
                    Icon(Icons.refresh),
                    SizedBox(width: 8),
                    Text('Refresh'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.clear_all, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Clear All', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildNotificationList(_allNotifications),
                _buildNotificationList(unreadNotifications),
                _buildNotificationList(readNotifications),
              ],
            ),
    );
  }

  Widget _buildNotificationList(List<Map<String, dynamic>> notifications) {
    if (notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No notifications',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'re all caught up!',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: notifications.length,
      itemBuilder: (context, index) {
        final notification = notifications[index];
        final originalIndex = _allNotifications.indexOf(notification);
        return _buildNotificationCard(context, notification, originalIndex);
      },
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    Map<String, dynamic> notification,
    int index,
  ) {
    final isRead = notification['isRead'] as bool;
    final time = notification['time'] as DateTime;
    final type = notification['type'] as String;

    return Dismissible(
      key: Key('$index-${notification['time']}'),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      secondaryBackground: Container(
        color: Colors.green,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.check, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Delete
          return await _showDeleteDialog(index);
        } else {
          // Mark as read
          _markAsRead(index);
          return false;
        }
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          _deleteNotification(index);
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        elevation: isRead ? 1 : 3,
        color: isRead ? Colors.white : Colors.blue[50],
        child: InkWell(
          onTap: () {
            _markAsRead(index);
            _handleNotificationTap(context, notification);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _getNotificationIcon(type),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification['title'],
                              style: TextStyle(
                                fontWeight: isRead
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification['message'],
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getTimeAgo(time),
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                          const Spacer(),
                          _getNotificationBadge(type),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _getNotificationIcon(String type) {
    final iconSize = 40.0;
    switch (type) {
      case 'results':
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.assignment, color: Colors.green, size: iconSize),
        );
      case 'welcome':
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.celebration, color: Colors.purple, size: iconSize),
        );
      case 'reminder':
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.notifications_active,
            color: Colors.orange,
            size: iconSize,
          ),
        );
      case 'system':
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.system_update, color: Colors.blue, size: iconSize),
        );
      case 'alert':
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.warning, color: Colors.red, size: iconSize),
        );
      default:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.notifications, color: Colors.grey, size: iconSize),
        );
    }
  }

  Widget _getNotificationBadge(String type) {
    switch (type) {
      case 'results':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Results',
            style: TextStyle(color: Colors.white, fontSize: 10),
          ),
        );
      case 'welcome':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.purple,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Welcome',
            style: TextStyle(color: Colors.white, fontSize: 10),
          ),
        );
      case 'reminder':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Reminder',
            style: TextStyle(color: Colors.white, fontSize: 10),
          ),
        );
      case 'system':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'System',
            style: TextStyle(color: Colors.white, fontSize: 10),
          ),
        );
      case 'alert':
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Alert',
            style: TextStyle(color: Colors.white, fontSize: 10),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  String _getTimeAgo(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<bool> _showDeleteDialog(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notification?'),
        content: const Text('This notification will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  Future<void> _showClearAllDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Notifications?'),
        content: const Text('All notifications will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _clearAllNotifications();
    }
  }

  void _handleNotificationTap(
    BuildContext context,
    Map<String, dynamic> notification,
  ) {
    final payload = notification['payload'];
    switch (notification['type']) {
      case 'results':
        if (payload != null && payload.isNotEmpty) {
          Navigator.pushNamed(
            context,
            '/history',
            arguments: {'predictionId': payload},
          );
        } else {
          Navigator.pushNamed(context, '/history');
        }
        break;
      case 'welcome':
        if (payload == 'welcome_guide') {
          _showWelcomeGuide();
        }
        break;
      case 'system':
        if (payload != null && payload.isNotEmpty) {
          if (payload == 'help') {
            Navigator.pushNamed(context, '/help-support');
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PatientProfileScreen(patientId: payload),
              ),
            );
          }
        }
        break;
      case 'reminder':
        Navigator.pushNamed(context, '/reminders');
        break;
      case 'alert':
        if (payload != null && payload.isNotEmpty) {
          Navigator.pushNamed(
            context,
            '/history',
            arguments: {'predictionId': payload},
          );
        } else {
          Navigator.pushNamed(context, '/history');
        }
        break;
      default:
        break;
    }
  }

  void _showWelcomeGuide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Welcome to SickleClinix!'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '🎉 Your account has been successfully created!',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              // const SizedBox(height: 16),
              // const Text(
              //   'Here\'s what you can do with SickleClinix:',
              //   style: TextStyle(fontWeight: FontWeight.bold),
              // ),
              // const SizedBox(height: 8),
              // const Text('**Blood Smear Analysis**\n• Upload blood smear images for AI-powered analysis\n• Get instant predictions for sickle cell detection\n• View detailed Grad-CAM visualizations'),
              // const SizedBox(height: 8),
              // const Text('**Patient Management**\n• Add and manage patient records\n• Track patient history and predictions\n• Maintain organized healthcare data'),
              // const SizedBox(height: 8),
              // const Text('**History & Analytics**\n• View all your predictions and results\n• Track your analysis statistics\n• Export data for reporting'),
              // const SizedBox(height: 8),
              // const Text('**Security & Privacy**\n• Your data is encrypted and secure\n• HIPAA-compliant healthcare standards\n• Offline functionality for remote areas'),
              // const SizedBox(height: 16),
              const Text(
                '💡 Getting Started',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                '1. Add your first patient from the Patients tab\n2. Try a prediction with a blood smear image\n3. Explore the Help & Support section for guides',
              ),
              const SizedBox(height: 16),
              const Text(
                'Need help? Check the Help & Support section in the app or contact our team.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/help-support');
            },
            child: const Text('Open Help & Support'),
          ),
        ],
      ),
    );
  }
}
