import 'package:flutter/material.dart';

import '../features/home/presentation/pages/home_dashboard_page.dart';
import '../features/timetable/presentation/pages/timetable_page.dart';
import '../features/settings/presentation/pages/settings_page.dart';

// --- Color Palette (matching home dashboard) ---
const Color _kBackgroundColor = Color(0xFF1E1E1E);
const Color _kCardColor = Color(0xFF333333);
const Color _kAccentBlue = Color(0xFF00BFFF);
const Color _kWhite = Colors.white;

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
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackgroundColor,
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            color: _kCardColor,
            boxShadow: [
              BoxShadow(
                color: _kAccentBlue.withOpacity(0.1),
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
                onTap: () => onTap(0),
              ),
              _NavIconButton(
                icon: Icons.schedule_outlined,
                selectedIcon: Icons.schedule,
                isSelected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavIconButton(
                icon: Icons.settings_outlined,
                selectedIcon: Icons.settings,
                isSelected: currentIndex == 2,
                onTap: () => onTap(2),
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
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final circleColor =
        isSelected ? _kAccentBlue : _kCardColor.withOpacity(0.5);
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
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _kAccentBlue.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Icon(
          iconData,
          color: _kWhite,
          size: 24,
        ),
      ),
    );
  }
}
