import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_tutor_lite/app/routes.dart';

import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../features/auth/presentation/bloc/auth_event.dart';
import '../features/auth/presentation/bloc/auth_state.dart';

// --- Color Palette ---
const Color _kCardColor = Color(0xFF333333);
const Color _kAccentBlue = Color(0xFF00BFFF);
const Color _kWhite = Colors.white;
const Color _kLightGray = Color(0xFFCCCCCC);

Future<void> errorDialog(BuildContext context, String error) {
  return showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        backgroundColor: _kCardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'An error occurred',
          style: TextStyle(
            color: _kWhite,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          error,
          style: const TextStyle(color: _kLightGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(foregroundColor: _kAccentBlue),
            child: const Text(
              'OK',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      );
    },
  );
}

Future logoutDialog(BuildContext context) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is Unauthenticated) {
            
            Navigator.of(dialogContext).pushNamedAndRemoveUntil(AppRoutes.loginView, (routes)=> false);
          } else if (state is AuthError) {
            // Close dialog and show error
            Navigator.of(dialogContext).pop();
            errorDialog(context, state.message);
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return AlertDialog(
            backgroundColor: _kCardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Center(
              child: Text(
                'Logout',
                style: TextStyle(
                  color: _kWhite,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            content: isLoading
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(_kAccentBlue),
                        ),
                      ),
                      SizedBox(width: 16),
                      Text(
                        'Logging out...',
                        style: TextStyle(
                          color: _kLightGray,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  )
                : const Text(
                    'Are you sure you want to logout?',
                    style: TextStyle(
                      color: _kLightGray,
                      fontSize: 16,
                    ),
                  ),
            actions: isLoading
                ? null
                : [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: _kLightGray),
                      ),
                    ),
                    const SizedBox(width: 16),
                    TextButton(
                      onPressed: () {
                        context.read<AuthBloc>().add(const SignOutEvent());
                      },
                      style: TextButton.styleFrom(foregroundColor: _kAccentBlue),
                      child: const Text(
                        'Logout',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
          );
        },
      );
    },
  );
}

Future deleteAccountDialog(BuildContext context) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AccountDeleted) {
            Navigator.of(dialogContext).pushNamedAndRemoveUntil(AppRoutes.signupView, (routes)=> false);
          } else if (state is AuthError) {
            // Close dialog and show error
            Navigator.of(dialogContext).pop();
            errorDialog(context, state.message);
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return AlertDialog(
            backgroundColor: _kCardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Center(
              child: Text(
                'Delete Account',
                style: TextStyle(
                  color: _kWhite,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            content: isLoading
                ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                        ),
                      ),
                      SizedBox(width: 16),
                      Text(
                        'Deleting account...',
                        style: TextStyle(
                          color: _kLightGray,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  )
                : const Text(
                    'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently deleted.',
                    style: TextStyle(
                      color: _kLightGray,
                      fontSize: 16,
                    ),
                  ),
            actions: isLoading
                ? null
                : [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: _kLightGray),
                      ),
                    ),
                    const SizedBox(width: 16),
                    TextButton(
                      onPressed: () {
                        context.read<AuthBloc>().add(const DeleteAccountEvent());
                      },
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text(
                        'Delete',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
          );
        },
      );
    },
  );
}
