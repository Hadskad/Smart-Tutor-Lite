import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/app_user.dart';

/// Repository interface for authentication operations.
abstract class AuthRepository {
  /// Signs in a user with email and password.
  Future<Either<Failure, AppUser>> signInWithEmail({
    required String email,
    required String password,
  });

  /// Signs up a new user with email and password.
  Future<Either<Failure, AppUser>> signUpWithEmail({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  });

  /// Signs in a user with Google.
  Future<Either<Failure, AppUser>> signInWithGoogle();

  /// Signs out the current user.
  Future<Either<Failure, Unit>> signOut();

  /// Sends a password reset email.
  Future<Either<Failure, Unit>> sendPasswordResetEmail({
    required String email,
  });

  /// Checks the current authentication status and returns the user if authenticated.
  Future<Either<Failure, AppUser?>> checkAuthStatus();

  /// Sends an email verification to the current user.
  Future<Either<Failure, Unit>> sendEmailVerification();

  /// Checks if the current user's email is verified.
  Future<Either<Failure, bool>> checkEmailVerified();

  /// Updates the user's profile photo.
  Future<Either<Failure, AppUser>> updateProfilePhoto({
    required String imagePath,
  });

  /// Updates the user's username (first name and last name).
  Future<Either<Failure, AppUser>> updateUsername({
    required String firstName,
    required String lastName,
  });

  /// Deletes the current user's account.
  Future<Either<Failure, Unit>> deleteAccount();

  /// Stream of authentication state changes.
  Stream<AppUser?> get authStateChanges;
}
