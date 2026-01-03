import 'package:flutter/material.dart';

// --- Color Palette (matching home dashboard) ---
const Color _kBackgroundColor = Color(0xFF1E1E1E);
const Color _kCardColor = Color(0xFF333333);
const Color _kAccentBlue = Color(0xFF00BFFF); // Vibrant Electric Blue
const Color _kAccentCoral = Color(0xFFFF7043); // Soft Coral/Orange for logout
const Color _kWhite = Colors.white;
const Color _kLightGray = Color(0xFFCCCCCC);
const Color _kDarkGray = Color(0xFF888888);

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackgroundColor,
      appBar: AppBar(
        backgroundColor: _kBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _kWhite),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),

                // Profile Avatar
                _ProfileAvatar(),

                const SizedBox(height: 20),

                // User Name
                const Text(
                  'Hadid Musbau',
                  style: TextStyle(
                    color: _kWhite,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 40),

                // Account Details Section
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Account Details',
                    style: TextStyle(
                      color: _kWhite,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Account Details Card
                _AccountDetailsCard(),

                const SizedBox(height: 40),

                // Logout Button
                _LogoutButton(
                  onTap: () {
                    // Handle logout
                  },
                ),

                const SizedBox(height: 24),

                _DeleteAccountButton(
                  onTap: (){

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

// --- Profile Avatar Widget ---
class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _kWhite,
      ),
      child: Center(
        child: Icon(
          Icons.person,
          size: 80,
          color: _kBackgroundColor,
        ),
      ),
    );
  }
}

// --- Account Details Card ---
class _AccountDetailsCard extends StatelessWidget {
  const _AccountDetailsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _DetailTile(
            icon: Icons.email_outlined,
            label: 'Email',
            value: 'hadidmusbau@gmail.com',
          ),
          Divider(color: _kDarkGray.withOpacity(0.3), height: 1),
          _DetailTile(
            icon: Icons.diamond_outlined,
            label: 'Subscription',
            value: 'Free',
            valueWidget: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _kWhite,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Free',
                style: TextStyle(
                  color: _kBackgroundColor,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Divider(color: _kDarkGray.withOpacity(0.3), height: 1),
          _DetailTile(
            icon: Icons.calendar_today_outlined,
            label: 'Member Since',
            value: 'November 16, 2025',
          ),
        ],
      ),
    );
  }
}

// --- Detail Tile Widget ---
class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueWidget,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          // Icon
          Icon(
            icon,
            color: _kAccentBlue,
            size: 28,
          ),
          const SizedBox(width: 16),
          // Label and Value
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _kWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                valueWidget ??
                    Text(
                      value,
                      style: const TextStyle(
                        color: _kLightGray,
                        fontSize: 14,
                      ),
                    ),
              ],
            ),
          ),
        ],
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
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: _kAccentCoral,
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
        height: 10,
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
