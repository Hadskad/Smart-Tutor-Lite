import 'package:flutter/material.dart';

import '../features/home/presentation/pages/home_dashboard_page.dart';
import '../features/timetable/presentation/pages/timetable_page.dart';
import '../features/settings/presentation/pages/settings_page.dart';
import '../features/profile/presentation/pages/profile_page.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomeDashboardPage(),
    TimetablePage(),
    SettingsPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: _CustomCircularNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

class _CustomCircularNavBar extends StatelessWidget {
  const _CustomCircularNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    // Teal/cyan color for active state (matching image)
    const activeColor =
        Color.fromARGB(255, 6, 28, 36); // Using tertiary from theme
    const inactiveColor = Color.fromARGB(255, 28, 29, 31); // Light grey

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            color: const Color.fromARGB(255, 73, 51, 51),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NavIconButton(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home,
                isSelected: currentIndex == 0,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: () => onTap(0),
              ),
              _NavIconButton(
                icon: Icons.schedule_outlined,
                selectedIcon: Icons.schedule,
                isSelected: currentIndex == 1,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: () => onTap(1),
              ),
              _NavIconButton(
                icon: Icons.settings_outlined,
                selectedIcon: Icons.settings,
                isSelected: currentIndex == 2,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: () => onTap(2),
              ),
              _NavIconButton(
                icon: Icons.person_outline,
                selectedIcon: Icons.person,
                isSelected: currentIndex == 3,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavIconButton extends StatelessWidget {
  const _NavIconButton({
    required this.icon,
    required this.selectedIcon,
    required this.isSelected,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final bool isSelected;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final circleColor = isSelected ? activeColor : inactiveColor;
    final iconData = isSelected ? selectedIcon : icon;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: circleColor,
          shape: BoxShape.circle,
        ),
        child: Icon(
          iconData,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}
