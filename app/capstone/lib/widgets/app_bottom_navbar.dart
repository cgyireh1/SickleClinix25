import 'package:flutter/material.dart';

class AppBottomNavBar extends StatelessWidget {
  final String currentRoute;
  const AppBottomNavBar({Key? key, required this.currentRoute})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: const Color(0xFFFDF3F4),
      elevation: 10,
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(context, Icons.home_rounded, 'Home', '/home'),
            _buildNavItem(context, Icons.dashboard, 'Dashboard', '/dashboard'),
            _buildNavItem(context, Icons.analytics, 'Predict', '/predict'),
            _buildNavItem(context, Icons.history, 'History', '/history'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    IconData icon,
    String label,
    String route,
  ) {
    final bool isSelected = currentRoute == route;
    final Color selectedColor = const Color(0xFFB71C1C);
    final Color unselectedColor = const Color(0xFFD32F2F);
    final Color iconColor = isSelected ? selectedColor : unselectedColor;
    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          Navigator.pushReplacementNamed(context, route);
        }
      },
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
