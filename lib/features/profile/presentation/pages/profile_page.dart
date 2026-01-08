import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../dialog/dialogs.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';

// --- Color Palette (matching home dashboard) ---
const Color _kBackgroundColor = Color(0xFF1E1E1E);
const Color _kCardColor = Color(0xFF333333);
const Color _kAccentBlue = Color(0xFF00BFFF); // Vibrant Electric Blue
const Color _kWhite = Colors.white;
const Color _kLightGray = Color(0xFFCCCCCC);
const Color _kDarkGray = Color(0xFF888888);

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        // Get user data from auth state
        String userName = 'User';
        String userEmail = '';
        String memberSince = '';
        String? photoUrl;
        bool isUpdatingPhoto = false;
        bool isUpdatingName = false;

        if (state is Authenticated) {
          userName = state.user.fullName.isNotEmpty
              ? state.user.fullName
              : 'User';
          userEmail = state.user.email;
          memberSince = _formatDate(state.user.createdAt);
          photoUrl = state.user.photoUrl;
        } else if (state is EmailNotVerified) {
          userName = state.user.fullName.isNotEmpty
              ? state.user.fullName
              : 'User';
          userEmail = state.user.email;
          memberSince = _formatDate(state.user.createdAt);
          photoUrl = state.user.photoUrl;
        } else if (state is ProfilePhotoUpdating) {
          userName = state.user.fullName.isNotEmpty
              ? state.user.fullName
              : 'User';
          userEmail = state.user.email;
          memberSince = _formatDate(state.user.createdAt);
          photoUrl = state.user.photoUrl;
          isUpdatingPhoto = true;
        } else if (state is ProfileNameUpdating) {
          userName = state.user.fullName.isNotEmpty
              ? state.user.fullName
              : 'User';
          userEmail = state.user.email;
          memberSince = _formatDate(state.user.createdAt);
          photoUrl = state.user.photoUrl;
          isUpdatingName = true;
        }

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

                    // Profile Avatar with Edit Icon
                    _ProfileAvatar(
                      photoUrl: photoUrl,
                      isUpdating: isUpdatingPhoto,
                      onEditTap: () => _pickAndUploadImage(context),
                    ),

                    const SizedBox(height: 20),

                    // User Name with Edit Icon
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isUpdatingName)
                          const Padding(
                            padding: EdgeInsets.only(right: 8.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(_kAccentBlue),
                              ),
                            ),
                          ),
                        Text(
                          userName,
                          style: const TextStyle(
                            color: _kWhite,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: isUpdatingName
                              ? null
                              : () => _showEditUsernameDialog(context, userName),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.edit,
                              color: isUpdatingName ? _kDarkGray : _kAccentBlue,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
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
                    _AccountDetailsCard(
                      email: userEmail,
                      memberSince: memberSince,
                    ),

                    const SizedBox(height: 40),

                    // Logout Button
                    _LogoutButton(
                      onTap: () {
                        logoutDialog(context);
                      },
                    ),

                    const SizedBox(height: 15),

                    _DeleteAccountButton(
                      onTap: () {
                        deleteAccountDialog(context);
                      },
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMMM d, yyyy').format(date);
  }

  Future<void> _pickAndUploadImage(BuildContext context) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (pickedFile != null && context.mounted) {
      context.read<AuthBloc>().add(
            UpdateProfilePhotoEvent(imagePath: pickedFile.path),
          );
    }
  }

  void _showEditUsernameDialog(BuildContext context, String currentFullName) {
    // Split current full name into first and last name
    final nameParts = currentFullName.split(' ');
    final currentFirstName = nameParts.isNotEmpty ? nameParts.first : '';
    final currentLastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    final firstNameController = TextEditingController(text: currentFirstName);
    final lastNameController = TextEditingController(text: currentLastName);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _kCardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Edit Username',
          style: TextStyle(
            color: _kWhite,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: firstNameController,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                labelText: 'First Name',
                labelStyle: const TextStyle(color: Colors.black),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: _kDarkGray),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: _kAccentBlue),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: lastNameController,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                labelText: 'Last Name',
                labelStyle: const TextStyle(color: Colors.black),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: _kDarkGray),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: _kAccentBlue),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: _kLightGray),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final firstName = firstNameController.text.trim();
              final lastName = lastNameController.text.trim();

              if (firstName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('First name cannot be empty'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.of(dialogContext).pop();
              context.read<AuthBloc>().add(
                    UpdateUsernameEvent(
                      firstName: firstName,
                      lastName: lastName,
                    ),
                  );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAccentBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Save',
              style: TextStyle(color: _kWhite),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Profile Avatar Widget with Edit Icon ---
class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    this.photoUrl,
    this.isUpdating = false,
    this.onEditTap,
  });

  final String? photoUrl;
  final bool isUpdating;
  final VoidCallback? onEditTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: _kWhite,
          ),
          child: ClipOval(
            child: isUpdating
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(_kAccentBlue),
                    ),
                  )
                : photoUrl != null && photoUrl!.isNotEmpty
                    ? Image.network(
                        photoUrl!,
                        fit: BoxFit.cover,
                        width: 120,
                        height: 120,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.person,
                            size: 80,
                            color: _kBackgroundColor,
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(_kAccentBlue),
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                      )
                    : const Icon(
                        Icons.person,
                        size: 80,
                        color: _kBackgroundColor,
                      ),
          ),
        ),
        // Edit icon overlay
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: isUpdating ? null : onEditTap,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _kAccentBlue,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _kBackgroundColor,
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.camera_alt,
                color: _kWhite,
                size: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// --- Account Details Card ---
class _AccountDetailsCard extends StatelessWidget {
  const _AccountDetailsCard({
    required this.email,
    required this.memberSince,
  });

  final String email;
  final String memberSince;

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
            value: email.isNotEmpty ? email : 'Not set',
          ),
          Divider(color: _kDarkGray.withValues(alpha: 0.3), height: 1),
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
          Divider(color: _kDarkGray.withValues(alpha: 0.3), height: 1),
          _DetailTile(
            icon: Icons.calendar_today_outlined,
            label: 'Member Since',
            value: memberSince.isNotEmpty ? memberSince : 'Unknown',
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
