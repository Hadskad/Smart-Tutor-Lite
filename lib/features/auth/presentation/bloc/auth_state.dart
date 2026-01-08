import 'package:equatable/equatable.dart';

import '../../domain/entities/app_user.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Initial state before authentication status is checked.
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Loading state during authentication operations.
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// User is authenticated and email is verified.
class Authenticated extends AuthState {
  const Authenticated({required this.user});

  final AppUser user;

  @override
  List<Object?> get props => [user];
}

/// No user is signed in.
class Unauthenticated extends AuthState {
  const Unauthenticated();
}

/// Account was successfully deleted - navigate to signup screen.
class AccountDeleted extends AuthState {
  const AccountDeleted();
}

/// User is signed in but email is not verified.
class EmailNotVerified extends AuthState {
  const EmailNotVerified({required this.user});

  final AppUser user;

  @override
  List<Object?> get props => [user];
}

/// An error occurred during authentication.
class AuthError extends AuthState {
  const AuthError({required this.message});

  final String message;

  @override
  List<Object?> get props => [message];
}

/// Password reset email was sent successfully.
class PasswordResetEmailSent extends AuthState {
  const PasswordResetEmailSent({required this.email});

  final String email;

  @override
  List<Object?> get props => [email];
}

/// Email verification was sent successfully.
class EmailVerificationSent extends AuthState {
  const EmailVerificationSent();
}

/// Profile photo is being updated.
class ProfilePhotoUpdating extends AuthState {
  const ProfilePhotoUpdating({required this.user});

  final AppUser user;

  @override
  List<Object?> get props => [user];
}

/// Username is being updated.
class ProfileNameUpdating extends AuthState {
  const ProfileNameUpdating({required this.user});

  final AppUser user;

  @override
  List<Object?> get props => [user];
}
