import 'package:flutter/material.dart';

// --- Color Palette (matching home dashboard) ---
const Color _kBackgroundColor = Color(0xFF1E1E1E);
const Color _kCardColor = Color(0xFF333333);
const Color _kAccentPurple = Color(0xFF9C27B0); // Purple for upgrade button
const Color _kAccentCoral = Color(0xFFFF7043); // Soft Coral/Orange for logout
const Color _kWhite = Colors.white;
const Color _kLightGray = Color(0xFFCCCCCC);
const Color _kDarkGray = Color(0xFF888888);

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackgroundColor,
      appBar: AppBar(
        backgroundColor: _kBackgroundColor,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(
            color: _kWhite,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: _kWhite),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // User Profile Card
                _UserProfileCard(
                  name: 'Hadid Musbau',
                  email: 'hadidmusbau@gmail.com',
                  onTap: () {
                    // Navigate to profile details
                  },
                ),

                const SizedBox(height: 20),

                // Upgrade to Unlimited Button
                _UpgradeButton(
                  onTap: () {
                    // Navigate to subscription page
                  },
                ),

                const SizedBox(height: 30),

                // ACCOUNT Section
                _SectionHeader(title: 'APP'),
                const SizedBox(height: 12),
                _SettingsCard(
                  children: [
                 
                    _SettingsTile(
                      icon: Icons.palette_outlined,
                      title: 'Theme',
                      trailing: 'System',
                      onTap: () {
                        // Navigate to theme settings
                      },
                    ),
                 
                  ],
                ),

                const SizedBox(height: 30),

                // SUBSCRIPTION Section
                _SectionHeader(title: 'SUBSCRIPTION'),
                const SizedBox(height: 12),
                _SettingsCard(
                  children: [
                    _SettingsTile(
                      icon: Icons.card_membership_outlined,
                      title: 'Manage Subscription',
                      trailing: 'Free Plan',
                      onTap: () {
                        // Navigate to subscription management
                      },
                    ),
                    
                  
                  ],
                ),

                const SizedBox(height: 30),

                // SUPPORT Section
                _SectionHeader(title: 'SUPPORT'),
                const SizedBox(height: 12),
                _SettingsCard(
                  children: [
                    _SettingsTile(
                      icon: Icons.headset_mic_outlined,
                      title: 'Contact Support',
                      onTap: () {
                        // Navigate to contact support
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // Logout Button
                _LogoutButton(
                  onTap: () {
                    // Handle logout
                  },
                ),

                const SizedBox(height: 15),

                // Delete Account Text
                _DeleteAccountButton(
                  onTap: (){
                    //Handle account deletion
                  }
                  ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- User Profile Card ---
class _UserProfileCard extends StatelessWidget {
  const _UserProfileCard({
    required this.name,
    required this.email,
    required this.onTap,
  });

  final String name;
  final String email;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kCardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Profile Avatar
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kBackgroundColor,
              ),
              child: const Icon(
                Icons.person,
                color: _kWhite,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            // User Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: _kWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: const TextStyle(
                      color: _kLightGray,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // Arrow Icon
            const Icon(
              Icons.chevron_right,
              color: _kLightGray,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}

// --- Upgrade Button ---
class _UpgradeButton extends StatelessWidget {
  const _UpgradeButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF9C27B0), Color(0xFFBA68C8)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.auto_awesome,
              color: _kWhite,
              size: 24,
            ),
            const SizedBox(width: 12),
            const Text(
              'Upgrade to Unlimited',
              style: TextStyle(
                color: _kWhite,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Section Header ---
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: _kDarkGray,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }
}

// --- Settings Card Container ---
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

// --- Settings Tile ---
class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: _kWhite,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: _kWhite,
                  fontSize: 16,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: const TextStyle(
                  color: _kDarkGray,
                  fontSize: 14,
                ),
              ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: _kLightGray,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

// --- Logout Button Widget ---
class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.red.shade300,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            'Log Out',
            style: TextStyle(
              color: _kWhite,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}


// --- Delete account button ---
class _DeleteAccountButton extends StatelessWidget {
  const _DeleteAccountButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            'Delete Account',
            style: TextStyle(
              color: _kWhite,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
