import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:injectable/injectable.dart';

/// Exception thrown when authentication operations fail.
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Remote data source for authentication operations.
/// Handles Firebase Auth, Google Sign-In, and Firestore user document operations.
@lazySingleton
class AuthRemoteDataSource {
  AuthRemoteDataSource({
    required FirebaseAuth firebaseAuth,
    required GoogleSignIn googleSignIn,
    required FirebaseFirestore firestore,
    required FirebaseStorage firebaseStorage,
  })  : _firebaseAuth = firebaseAuth,
        _googleSignIn = googleSignIn,
        _firestore = firestore,
        _firebaseStorage = firebaseStorage;

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _firebaseStorage;

  /// Signs in with email and password.
  Future<Map<String, dynamic>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _firebaseAuth
          .signInWithEmailAndPassword(
            email: email,
            password: password,
          )
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              throw const AuthException(
                'Connection timeout. Please check your internet connection and try again.',
              );
            },
          );

      final user = userCredential.user;
      if (user == null) {
        throw const AuthException('Sign in failed. Please try again.');
      }

      return _getUserData(user);
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseException(e);
    } on SocketException {
      throw const AuthException(
        'No internet connection. Please check your network and try again.',
      );
    } on TimeoutException {
      throw const AuthException(
        'Connection timeout. Please check your internet connection and try again.',
      );
    } catch (e) {
      if (e is AuthException) rethrow;
      // Check if error message contains network-related keywords
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('network') ||
          errorMsg.contains('connection') ||
          errorMsg.contains('timeout')) {
        throw const AuthException(
          'Network error. Please check your internet connection and try again.',
        );
      }
      throw AuthException('Sign in failed: ${e.toString()}');
    }
  }

  /// Signs up with email and password and creates user document.
  Future<Map<String, dynamic>> signUpWithEmail({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    try {
      final userCredential = await _firebaseAuth
          .createUserWithEmailAndPassword(
            email: email,
            password: password,
          )
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              throw const AuthException(
                'Connection timeout. Please check your internet connection and try again.',
              );
            },
          );

      final user = userCredential.user;
      if (user == null) {
        throw const AuthException('Sign up failed. Please try again.');
      }

      // Create user document in Firestore (with timeout)
      await _createUserDocument(
        uid: user.uid,
        email: email,
        firstName: firstName,
        lastName: lastName,
      ).timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          throw const AuthException(
            'Connection timeout while saving user data. Please check your internet connection.',
          );
        },
      );

      // Send email verification (with timeout)
      await user.sendEmailVerification().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw const AuthException(
            'Connection timeout while sending verification email. Please check your internet connection.',
          );
        },
      );

      return _getUserData(user);
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseException(e);
    } on SocketException {
      throw const AuthException(
        'No internet connection. Please check your network and try again.',
      );
    } on TimeoutException {
      throw const AuthException(
        'Connection timeout. Please check your internet connection and try again.',
      );
    } catch (e) {
      if (e is AuthException) rethrow;
      // Check if error message contains network-related keywords
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('network') ||
          errorMsg.contains('connection') ||
          errorMsg.contains('timeout')) {
        throw const AuthException(
          'Network error. Please check your internet connection and try again.',
        );
      }
      throw AuthException('Sign up failed: ${e.toString()}');
    }
  }

  /// Signs in with Google.
  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      // Trigger Google Sign-In flow (with timeout)
      final googleUser = await _googleSignIn.signIn().timeout(
        const Duration(seconds: 90),
        onTimeout: () {
          throw const AuthException(
            'Google Sign-In timeout. Please check your internet connection and try again.',
          );
        },
      );

      if (googleUser == null) {
        throw const AuthException('Google Sign-In was cancelled.');
      }

      // Get authentication details (with timeout)
      final googleAuth = await googleUser.authentication.timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          throw const AuthException(
            'Connection timeout during Google authentication. Please check your internet connection.',
          );
        },
      );

      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase (with timeout)
      final userCredential = await _firebaseAuth
          .signInWithCredential(credential)
          .timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw const AuthException(
            'Connection timeout. Please check your internet connection and try again.',
          );
        },
      );

      final user = userCredential.user;
      if (user == null) {
        throw const AuthException('Google Sign-In failed. Please try again.');
      }

      // Check if user document exists (with timeout)
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw const AuthException(
            'Connection timeout while fetching user data. Please check your internet connection.',
          );
        },
      );

      if (!userDoc.exists) {
        // Split displayName into first and last name
        final nameParts = (user.displayName ?? '').split(' ');
        final firstName = nameParts.isNotEmpty ? nameParts.first : '';
        final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

        // Create user document (with timeout)
        await _createUserDocument(
          uid: user.uid,
          email: user.email ?? '',
          firstName: firstName,
          lastName: lastName,
          photoUrl: user.photoURL,
        ).timeout(
          const Duration(seconds: 45),
          onTimeout: () {
            throw const AuthException(
              'Connection timeout while saving user data. Please check your internet connection.',
            );
          },
        );
      }

      return _getUserData(user);
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseException(e);
    } on SocketException {
      throw const AuthException(
        'No internet connection. Please check your network and try again.',
      );
    } on TimeoutException {
      throw const AuthException(
        'Connection timeout. Please check your internet connection and try again.',
      );
    } catch (e) {
      if (e is AuthException) rethrow;
      // Check if error message contains network-related keywords
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('network') ||
          errorMsg.contains('connection') ||
          errorMsg.contains('timeout')) {
        throw const AuthException(
          'Network error. Please check your internet connection and try again.',
        );
      }
      throw AuthException('Google Sign-In failed: ${e.toString()}');
    }
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    try {
      // Sign out from Google if signed in with Google
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
      await _firebaseAuth.signOut();
    } catch (e) {
      throw AuthException('Sign out failed: ${e.toString()}');
    }
  }

  /// Sends password reset email.
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseException(e);
    } catch (e) {
      throw AuthException('Failed to send reset email: ${e.toString()}');
    }
  }

  /// Gets the current authenticated user.
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) return null;
      return _getUserData(user);
    } catch (e) {
      throw AuthException('Failed to get current user: ${e.toString()}');
    }
  }

  /// Sends email verification to the current user.
  Future<void> sendEmailVerification() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw const AuthException('No user is currently signed in.');
      }
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseException(e);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Failed to send verification email: ${e.toString()}');
    }
  }

  /// Checks if the current user's email is verified.
  Future<bool> checkEmailVerified() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw const AuthException('No user is currently signed in.');
      }

      // Reload user to get fresh data
      await user.reload();

      // Get updated user
      final updatedUser = _firebaseAuth.currentUser;
      return updatedUser?.emailVerified ?? false;
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Failed to check email verification: ${e.toString()}');
    }
  }

  /// Stream of authentication state changes.
  Stream<Map<String, dynamic>?> get authStateChanges {
    return _firebaseAuth.authStateChanges().asyncMap((user) async {
      if (user == null) return null;
      return _getUserData(user);
    });
  }

  /// Updates the user's profile photo.
  /// Uploads the image to Firebase Storage and updates Firestore.
  Future<Map<String, dynamic>> updateProfilePhoto({
    required String imagePath,
  }) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw const AuthException('No user is currently signed in.');
      }

      // Create a reference to the profile photo in Storage
      final storageRef = _firebaseStorage
          .ref()
          .child('profile_photos')
          .child('${user.uid}.jpg');

      // Upload the file
      final file = File(imagePath);
      await storageRef.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // Get the download URL
      final downloadUrl = await storageRef.getDownloadURL();

      // Update Firestore user document
      await _firestore.collection('users').doc(user.uid).update({
        'Photo URL': downloadUrl,
      });

      // Return updated user data
      return _getUserData(user);
    } on FirebaseException catch (e) {
      throw AuthException('Failed to upload photo: ${e.message}');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Failed to update profile photo: ${e.toString()}');
    }
  }

  /// Updates the user's username (first name and last name).
  /// Updates Firestore user document with new name values.
  Future<Map<String, dynamic>> updateUsername({
    required String firstName,
    required String lastName,
  }) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw const AuthException('No user is currently signed in.');
      }

      // Update Firestore user document
      await _firestore.collection('users').doc(user.uid).update({
        'First name': firstName,
        'Last name': lastName,
      });

      // Return updated user data
      return _getUserData(user);
    } on FirebaseException catch (e) {
      throw AuthException('Failed to update username: ${e.message}');
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Failed to update username: ${e.toString()}');
    }
  }

  /// Deletes the current user's account.
  /// Deletes user data from Firestore, profile photo from Storage, and Firebase Auth account.
  Future<void> deleteAccount() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw const AuthException('No user is currently signed in.');
      }

      final uid = user.uid;

      // Delete user document from Firestore
      try {
        await _firestore.collection('users').doc(uid).delete();
      } catch (e) {
        // Continue even if Firestore deletion fails
      }

      // Delete profile photo from Storage if it exists
      try {
        final storageRef = _firebaseStorage
            .ref()
            .child('profile_photos')
            .child('$uid.jpg');
        await storageRef.delete();
      } catch (e) {
        // Continue even if Storage deletion fails (photo might not exist)
      }

      // Sign out from Google if signed in with Google
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }

      // Delete the Firebase Auth account
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw const AuthException(
          'For security reasons, please log out and log back in before deleting your account.',
        );
      }
      throw _mapFirebaseException(e);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Failed to delete account: ${e.toString()}');
    }
  }

  /// Gets user data combining Firebase Auth and Firestore data.
  Future<Map<String, dynamic>> _getUserData(User user) async {
    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final firestoreData = userDoc.data() ?? {};

      return {
        'uid': user.uid,
        'email': user.email ?? '',
        'firstName': firestoreData['First name'] ?? '',
        'lastName': firestoreData['Last name'] ?? '',
        'emailVerified': user.emailVerified,
        'photoUrl': firestoreData['Photo URL'] ?? user.photoURL,
        'createdAt': firestoreData['Created At'] ?? Timestamp.now(),
      };
    } catch (e) {
      // If Firestore fetch fails, return basic user data
      return {
        'uid': user.uid,
        'email': user.email ?? '',
        'firstName': '',
        'lastName': '',
        'emailVerified': user.emailVerified,
        'photoUrl': user.photoURL,
        'createdAt': Timestamp.now(),
      };
    }
  }

  /// Creates a user document in Firestore.
  Future<void> _createUserDocument({
    required String uid,
    required String email,
    required String firstName,
    required String lastName,
    String? photoUrl,
  }) async {
    final userData = {
      'First name': firstName,
      'Last name': lastName,
      'Email': email,
      'Created At': FieldValue.serverTimestamp(),
    };

    if (photoUrl != null) {
      userData['Photo URL'] = photoUrl;
    }

    await _firestore.collection('users').doc(uid).set(userData);
  }

  /// Maps Firebase auth exceptions to user-friendly messages.
  AuthException _mapFirebaseException(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return const AuthException(
          'Incorrect email or password. Please try again.',
        );
      case 'email-already-in-use':
        return const AuthException(
          'This email is already registered. Please login instead.',
        );
      case 'weak-password':
        return const AuthException(
          'Password is too weak. Please use a stronger password.',
        );
      case 'user-disabled':
        return const AuthException(
          'This account has been disabled. Please contact support.',
        );
      case 'too-many-requests':
        return const AuthException(
          'Too many failed attempts. Please try again later.',
        );
      case 'network-request-failed':
        return const AuthException(
          'Network error. Please check your internet connection and try again.',
        );
      case 'internal-error':
        // Internal errors often occur due to network issues
        return const AuthException(
          'Connection error. Please check your internet connection and try again.',
        );
      case 'unavailable':
        return const AuthException(
          'Service temporarily unavailable. Please check your internet connection and try again.',
        );
      case 'deadline-exceeded':
        return const AuthException(
          'Connection timeout. Please check your internet connection and try again.',
        );
      case 'invalid-email':
        return const AuthException('Invalid email address format.');
      case 'account-exists-with-different-credential':
        return const AuthException(
          'This email is already registered with a different sign-in method.',
        );
      case 'operation-not-allowed':
        return const AuthException(
          'This sign-in method is not enabled. Please contact support.',
        );
      default:
        // Check if the error message contains network-related keywords
        final errorMsg = (e.message ?? '').toLowerCase();
        if (errorMsg.contains('network') ||
            errorMsg.contains('connection') ||
            errorMsg.contains('timeout') ||
            errorMsg.contains('unavailable')) {
          return const AuthException(
            'Network error. Please check your internet connection and try again.',
          );
        }
        return AuthException(e.message ?? 'Authentication failed. Please try again.');
    }
  }
}
