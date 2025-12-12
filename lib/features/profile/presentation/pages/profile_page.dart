import 'package:flutter/material.dart';

// --- Color Palette (matching home dashboard) ---
const Color _kBackgroundColor = Color(0xFF1E1E1E);
const Color _kCardColor = Color(0xFF333333);
const Color _kWhite = Colors.white;
const Color _kLightGray = Color(0xFFCCCCCC);

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackgroundColor,
      appBar: AppBar(
        backgroundColor: _kCardColor,
        title: const Text(
          'Profile',
          style: TextStyle(color: _kWhite),
        ),
        iconTheme: const IconThemeData(color: _kWhite),
      ),
      body: const Center(
        child: Text(
          'Profile content coming soon...',
          style: TextStyle(color: _kLightGray),
        ),
      ),
    );
  }
}
