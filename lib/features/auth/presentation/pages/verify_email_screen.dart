import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/routes.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

// --- Color Palette ---
const Color _kBackgroundColor = Color(0xFF1E1E1E);
const Color _kCardColor = Color(0xFF333333);
const Color _kAccentBlue = Color(0xFF00BFFF);
const Color _kWhite = Colors.white;
const Color _kLightGray = Color(0xFFCCCCCC);
const Color _kDarkGray = Color(0xFF888888);

class VerifyEmailView extends StatefulWidget {
  const VerifyEmailView({super.key});

  @override
  State<VerifyEmailView> createState() => _VerifyEmailViewState();
}

class _VerifyEmailViewState extends State<VerifyEmailView> {
  bool _isSending = false;
  int _countdown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    setState(() => _countdown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
      }
    });
  }

  void _onSendVerification() {
    setState(() => _isSending = true);
    context.read<AuthBloc>().add(const SendEmailVerificationEvent());
  }

  void _onCheckVerification() {
    context.read<AuthBloc>().add(const CheckEmailVerifiedEvent());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is Authenticated) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.mainNav,
            (routes) => false,
          );
        } else if (state is EmailVerificationSent) {
          setState(() => _isSending = false);
          _startCountdown();
          _showAlertDialog(
            context,
            'Verification Email Sent',
            'An email verification link has been sent to your email.',
          );
        } else if (state is AuthError) {
          setState(() => _isSending = false);
          _showAlertDialog(context, 'Error', state.message);
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          // Get user email from state
          String userEmail = '';
          if (state is EmailNotVerified) {
            userEmail = state.user.email;
          }

          return Scaffold(
            backgroundColor: _kBackgroundColor,
            body: SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 60),
                      // Title
                      const Text(
                        'Verify Email',
                        style: TextStyle(
                          fontSize: 32,
                          color: _kWhite,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // Email Icon
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: const BoxDecoration(
                            color: _kCardColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.mark_email_unread_outlined,
                            size: 80,
                            color: _kAccentBlue,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Description
                      const Text(
                        'A verification email has been sent to:',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: _kLightGray,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        userEmail,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: _kWhite,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Please check your inbox and spam folder, then click the verification link.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: _kDarkGray,
                        ),
                      ),
                      const SizedBox(height: 50),

                      // Continue Button
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _onCheckVerification,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kAccentBlue,
                            foregroundColor: _kWhite,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: const Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Resend Button
                      SizedBox(
                        height: 56,
                        child: OutlinedButton(
                          onPressed: (_isSending || _countdown > 0) ? null : _onSendVerification,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _kAccentBlue,
                            side: BorderSide(
                              color: (_isSending || _countdown > 0) ? _kDarkGray : _kAccentBlue,
                              width: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: _isSending
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: _kAccentBlue,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _countdown > 0
                                      ? 'Resend in ${_countdown}s'
                                      : 'Resend Verification Email',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: (_isSending || _countdown > 0) ? _kDarkGray : _kAccentBlue,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Help Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _kCardColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.info_outline, color: _kAccentBlue, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  "Didn't receive the email?",
                                  style: TextStyle(
                                    color: _kWhite,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '• Check your spam or junk folder\n• Make sure the email address is correct\n• Wait a few minutes and try resending',
                              style: TextStyle(
                                color: _kLightGray,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAlertDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _kCardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: _kWhite,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            content,
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
}
