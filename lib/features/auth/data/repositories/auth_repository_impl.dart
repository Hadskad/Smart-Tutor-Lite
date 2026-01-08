import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';

@LazySingleton(as: AuthRepository)
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required AuthLocalDataSource localDataSource,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource;

  final AuthRemoteDataSource _remoteDataSource;
  final AuthLocalDataSource _localDataSource;

  @override
  Future<Either<Failure, AppUser>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final userData = await _remoteDataSource.signInWithEmail(
        email: email,
        password: password,
      );
      // Cache user data for offline access
      await _localDataSource.cacheUserData(userData);
      return Right(_mapToAppUser(userData));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message));
    } catch (e) {
      return Left(AuthFailure(message: 'Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, AppUser>> signUpWithEmail({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    try {
      final userData = await _remoteDataSource.signUpWithEmail(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );
      // Cache user data for offline access
      await _localDataSource.cacheUserData(userData);
      return Right(_mapToAppUser(userData));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message));
    } catch (e) {
      return Left(AuthFailure(message: 'Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, AppUser>> signInWithGoogle() async {
    try {
      final userData = await _remoteDataSource.signInWithGoogle();
      // Cache user data for offline access
      await _localDataSource.cacheUserData(userData);
      return Right(_mapToAppUser(userData));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message));
    } catch (e) {
      return Left(AuthFailure(message: 'Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Unit>> signOut() async {
    try {
      await _remoteDataSource.signOut();
      // Clear cached auth data on sign out
      await _localDataSource.clearAuthCache();
      return const Right(unit);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message));
    } catch (e) {
      return Left(AuthFailure(message: 'Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Unit>> sendPasswordResetEmail({
    required String email,
  }) async {
    try {
      await _remoteDataSource.sendPasswordResetEmail(email: email);
      return const Right(unit);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message));
    } catch (e) {
      return Left(AuthFailure(message: 'Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, AppUser?>> checkAuthStatus() async {
    try {
      // Try to get current user from Firebase
      final userData = await _remoteDataSource.getCurrentUser();

      if (userData == null) {
        // User not authenticated in Firebase, clear cache
        await _localDataSource.clearAuthCache();
        return const Right(null);
      }

      // Cache the fresh user data
      await _localDataSource.cacheUserData(userData);
      return Right(_mapToAppUser(userData));
    } on AuthException catch (e) {
      // If Firebase call fails, try to use cached data for offline access
      final cachedData = _localDataSource.getCachedUserData();
      if (cachedData != null) {
        return Right(_mapToAppUser(cachedData));
      }
      return Left(AuthFailure(message: e.message));
    } catch (e) {
      // On any error, try cached data for offline access
      final cachedData = _localDataSource.getCachedUserData();
      if (cachedData != null) {
        return Right(_mapToAppUser(cachedData));
      }
      return Left(AuthFailure(message: 'Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Unit>> sendEmailVerification() async {
    try {
      await _remoteDataSource.sendEmailVerification();
      return const Right(unit);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message));
    } catch (e) {
      return Left(AuthFailure(message: 'Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> checkEmailVerified() async {
    try {
      final isVerified = await _remoteDataSource.checkEmailVerified();
      // Update cached email verification status
      if (isVerified) {
        final cachedData = _localDataSource.getCachedUserData();
        if (cachedData != null) {
          cachedData['emailVerified'] = true;
          await _localDataSource.cacheUserData(cachedData);
        }
      }
      return Right(isVerified);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message));
    } catch (e) {
      return Left(AuthFailure(message: 'Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, AppUser>> updateProfilePhoto({
    required String imagePath,
  }) async {
    try {
      final userData = await _remoteDataSource.updateProfilePhoto(
        imagePath: imagePath,
      );
      // Update cached user data
      await _localDataSource.cacheUserData(userData);
      return Right(_mapToAppUser(userData));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message));
    } catch (e) {
      return Left(AuthFailure(message: 'Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, AppUser>> updateUsername({
    required String firstName,
    required String lastName,
  }) async {
    try {
      final userData = await _remoteDataSource.updateUsername(
        firstName: firstName,
        lastName: lastName,
      );
      // Update cached user data
      await _localDataSource.cacheUserData(userData);
      return Right(_mapToAppUser(userData));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message));
    } catch (e) {
      return Left(AuthFailure(message: 'Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteAccount() async {
    try {
      await _remoteDataSource.deleteAccount();
      // Clear cached auth data on account deletion
      await _localDataSource.clearAuthCache();
      return const Right(unit);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message));
    } catch (e) {
      return Left(AuthFailure(message: 'Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Stream<AppUser?> get authStateChanges {
    return _remoteDataSource.authStateChanges.asyncMap((userData) async {
      if (userData == null) {
        // User signed out via Firebase, clear cache
        await _localDataSource.clearAuthCache();
        return null;
      }
      // Update cache with fresh data from Firebase
      await _localDataSource.cacheUserData(userData);
      return _mapToAppUser(userData);
    });
  }

  AppUser _mapToAppUser(Map<String, dynamic> data) {
    DateTime createdAt;
    final createdAtValue = data['createdAt'];
    if (createdAtValue is Timestamp) {
      createdAt = createdAtValue.toDate();
    } else if (createdAtValue is DateTime) {
      createdAt = createdAtValue;
    } else if (createdAtValue is String) {
      // Handle ISO string from cached data
      createdAt = DateTime.tryParse(createdAtValue) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    return AppUser(
      uid: data['uid'] as String,
      email: data['email'] as String,
      firstName: data['firstName'] as String? ?? '',
      lastName: data['lastName'] as String? ?? '',
      emailVerified: data['emailVerified'] as bool? ?? false,
      photoUrl: data['photoUrl'] as String?,
      createdAt: createdAt,
    );
  }
}
