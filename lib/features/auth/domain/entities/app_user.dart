import 'package:equatable/equatable.dart';

/// Represents an authenticated user in the application.
class AppUser extends Equatable {
  const AppUser({
    required this.uid,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.emailVerified,
    required this.createdAt,
    this.photoUrl,
  });

  final String uid;
  final String email;
  final String firstName;
  final String lastName;
  final bool emailVerified;
  final DateTime createdAt;
  final String? photoUrl;

  /// Returns the full name of the user.
  String get fullName => '$firstName $lastName'.trim();

  /// Returns true if the user signed in with Google.
  bool get isGoogleUser => photoUrl != null;

  @override
  List<Object?> get props => [
        uid,
        email,
        firstName,
        lastName,
        emailVerified,
        createdAt,
        photoUrl,
      ];
}
