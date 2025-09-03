import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:runners_saga/core/constants/app_theme.dart';

/// Unified bottom navigation widget used consistently across the app
/// Provides navigation between: Home, Workouts, Stats, Settings
class BottomNavigationWidget extends StatelessWidget {
  final int currentIndex;
  
  const BottomNavigationWidget({
    super.key,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: kSurfaceBase,
      selectedItemColor: kElectricAqua,
      unselectedItemColor: Colors.white70,
      type: BottomNavigationBarType.fixed,
      currentIndex: currentIndex,
      onTap: (index) => _handleNavigation(context, index),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history),
          label: 'Workouts',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.analytics),
          label: 'Stats',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: 'Settings',
        ),
      ],
    );
  }

  void _handleNavigation(BuildContext context, int index) {
    switch (index) {
      case 0: // Home
        context.go('/home');
        break;
      case 1: // Workouts
        context.go('/run/history');
        break;
      case 2: // Stats
        context.go('/stats');
        break;
      case 3: // Settings
        context.go('/settings');
        break;
    }
  }
}

/// Enum for bottom navigation indices
enum BottomNavIndex {
  home(0),
  workouts(1),
  stats(2),
  settings(3);

  const BottomNavIndex(this.value);
  final int value;
}
