import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Check the current authentication status.
class CheckAuthStatusEvent extends AuthEvent {
  const CheckAuthStatusEvent();
}

/// Sign in with email and password.
class SignInWithEmailEvent extends AuthEvent {
  const SignInWithEmailEvent({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

/// Sign up with email and password.
class SignUpWithEmailEvent extends AuthEvent {
  const SignUpWithEmailEvent({
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
  });

  final String email;
  final String password;
  final String firstName;
  final String lastName;

  @override
  List<Object?> get props => [email, password, firstName, lastName];
}

/// Sign in with Google.
class SignInWithGoogleEvent extends AuthEvent {
  const SignInWithGoogleEvent();
}

/// Sign out the current user.
class SignOutEvent extends AuthEvent {
  const SignOutEvent();
}

/// Send email verification to the current user.
class SendEmailVerificationEvent extends AuthEvent {
  const SendEmailVerificationEvent();
}

/// Check if the current user's email is verified.
class CheckEmailVerifiedEvent extends AuthEvent {
  const CheckEmailVerifiedEvent();
}

/// Send password reset email.
class SendPasswordResetEmailEvent extends AuthEvent {
  const SendPasswordResetEmailEvent({required this.email});

  final String email;

  @override
  List<Object?> get props => [email];
}

/// Update the user's profile photo.
class UpdateProfilePhotoEvent extends AuthEvent {
  const UpdateProfilePhotoEvent({required this.imagePath});

  final String imagePath;

  @override
  List<Object?> get props => [imagePath];
}

/// Update the user's username.
class UpdateUsernameEvent extends AuthEvent {
  const UpdateUsernameEvent({
    required this.firstName,
    required this.lastName,
  });

  final String firstName;
  final String lastName;

  @override
  List<Object?> get props => [firstName, lastName];
}

/// Delete the current user's account.
class DeleteAccountEvent extends AuthEvent {
  const DeleteAccountEvent();
}
