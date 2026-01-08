import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/utils/logger.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/usecases/check_auth_status.dart';
import '../../domain/usecases/check_email_verified.dart';
import '../../domain/usecases/send_email_verification.dart';
import '../../domain/usecases/send_password_reset_email.dart';
import '../../domain/usecases/sign_in_with_email.dart';
import '../../domain/usecases/sign_in_with_google.dart';
import '../../domain/usecases/delete_account.dart';
import '../../domain/usecases/sign_out.dart';
import '../../domain/usecases/sign_up_with_email.dart';
import '../../domain/usecases/update_profile_photo.dart';
import '../../domain/usecases/update_username.dart';
import 'auth_event.dart';
import 'auth_state.dart';

@injectable
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(
    this._checkAuthStatus,
    this._signInWithEmail,
    this._signUpWithEmail,
    this._signInWithGoogle,
    this._signOut,
    this._sendPasswordResetEmail,
    this._sendEmailVerification,
    this._checkEmailVerified,
    this._updateProfilePhoto,
    this._updateUsername,
    this._deleteAccount,
    this._logger,
  ) : super(const AuthInitial()) {
    on<CheckAuthStatusEvent>(_onCheckAuthStatus);
    on<SignInWithEmailEvent>(_onSignInWithEmail);
    on<SignUpWithEmailEvent>(_onSignUpWithEmail);
    on<SignInWithGoogleEvent>(_onSignInWithGoogle);
    on<SignOutEvent>(_onSignOut);
    on<SendPasswordResetEmailEvent>(_onSendPasswordResetEmail);
    on<SendEmailVerificationEvent>(_onSendEmailVerification);
    on<CheckEmailVerifiedEvent>(_onCheckEmailVerified);
    on<UpdateProfilePhotoEvent>(_onUpdateProfilePhoto);
    on<UpdateUsernameEvent>(_onUpdateUsername);
    on<DeleteAccountEvent>(_onDeleteAccount);
  }

  final CheckAuthStatus _checkAuthStatus;
  final SignInWithEmail _signInWithEmail;
  final SignUpWithEmail _signUpWithEmail;
  final SignInWithGoogle _signInWithGoogle;
  final SignOut _signOut;
  final SendPasswordResetEmail _sendPasswordResetEmail;
  final SendEmailVerification _sendEmailVerification;
  final CheckEmailVerified _checkEmailVerified;
  final UpdateProfilePhoto _updateProfilePhoto;
  final UpdateUsername _updateUsername;
  final DeleteAccount _deleteAccount;
  final AppLogger _logger;

  Future<void> _onCheckAuthStatus(
    CheckAuthStatusEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final result = await _checkAuthStatus();

    result.fold(
      (failure) {
        _logger.error('Check auth status failed', {'error': failure.message});
        emit(const Unauthenticated());
      },
      (user) {
        if (user == null) {
          emit(const Unauthenticated());
        } else {
          _emitAuthenticatedState(emit, user);
        }
      },
    );
  }

  Future<void> _onSignInWithEmail(
    SignInWithEmailEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final result = await _signInWithEmail(
      email: event.email,
      password: event.password,
    );

    result.fold(
      (failure) {
        _logger.error('Sign in with email failed', {'error': failure.message});
        emit(AuthError(message: failure.message ?? 'Sign in failed.'));
      },
      (user) => _emitAuthenticatedState(emit, user),
    );
  }

  Future<void> _onSignUpWithEmail(
    SignUpWithEmailEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final result = await _signUpWithEmail(
      email: event.email,
      password: event.password,
      firstName: event.firstName,
      lastName: event.lastName,
    );

    result.fold(
      (failure) {
        _logger.error('Sign up with email failed', {'error': failure.message});
        emit(AuthError(message: failure.message ?? 'Sign up failed.'));
      },
      (user) {
        // Email/password sign-up always requires email verification
        emit(EmailNotVerified(user: user));
      },
    );
  }

  Future<void> _onSignInWithGoogle(
    SignInWithGoogleEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final result = await _signInWithGoogle();

    result.fold(
      (failure) {
        final message = failure.message ?? 'Google Sign-In failed.';
        // Don't show error if user cancelled
        if (message.contains('cancelled')) {
          emit(const Unauthenticated());
        } else {
          _logger.error('Sign in with Google failed', {'error': message});
          emit(AuthError(message: message));
        }
      },
      (user) {
        // Google users are always verified (Google verifies their email)
        emit(Authenticated(user: user));
      },
    );
  }

  Future<void> _onSignOut(
    SignOutEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final result = await _signOut();

    result.fold(
      (failure) {
        _logger.error('Sign out failed', {'error': failure.message});
        emit(AuthError(message: failure.message ?? 'Sign out failed.'));
      },
      (_) => emit(const Unauthenticated()),
    );
  }

  Future<void> _onSendPasswordResetEmail(
    SendPasswordResetEmailEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final result = await _sendPasswordResetEmail(email: event.email);

    result.fold(
      (failure) {
        _logger.error('Send password reset email failed', {'error': failure.message});
        emit(AuthError(message: failure.message ?? 'Failed to send reset email.'));
      },
      (_) => emit(PasswordResetEmailSent(email: event.email)),
    );
  }

  Future<void> _onSendEmailVerification(
    SendEmailVerificationEvent event,
    Emitter<AuthState> emit,
  ) async {
    // Keep current state while sending
    final currentState = state;

    final result = await _sendEmailVerification();

    result.fold(
      (failure) {
        _logger.error('Send email verification failed', {'error': failure.message});
        emit(AuthError(message: failure.message ?? 'Failed to send verification email.'));
      },
      (_) {
        emit(const EmailVerificationSent());
        // Restore the previous state after a brief moment
        // so the UI can show the success message
        if (currentState is EmailNotVerified) {
          emit(currentState);
        }
      },
    );
  }

  Future<void> _onCheckEmailVerified(
    CheckEmailVerifiedEvent event,
    Emitter<AuthState> emit,
  ) async {
    final currentState = state;

    final result = await _checkEmailVerified();

    result.fold(
      (failure) {
        _logger.error('Check email verified failed', {'error': failure.message});
        emit(AuthError(message: failure.message ?? 'Failed to check verification status.'));
      },
      (isVerified) {
        if (isVerified) {
          // User is now verified, get user data and emit authenticated
          if (currentState is EmailNotVerified) {
            emit(Authenticated(user: currentState.user));
          } else {
            // Re-check auth status to get fresh user data
            add(const CheckAuthStatusEvent());
          }
        } else {
          // Still not verified, keep current state or emit error
          if (currentState is EmailNotVerified) {
            emit(AuthError(message: 'Email not yet verified. Please check your inbox.'));
            emit(currentState);
          }
        }
      },
    );
  }

  Future<void> _onUpdateProfilePhoto(
    UpdateProfilePhotoEvent event,
    Emitter<AuthState> emit,
  ) async {
    final currentState = state;
    AppUser? currentUser;

    if (currentState is Authenticated) {
      currentUser = currentState.user;
    } else if (currentState is EmailNotVerified) {
      currentUser = currentState.user;
    }

    if (currentUser == null) {
      emit(const AuthError(message: 'No user is currently signed in.'));
      return;
    }

    // Emit updating state
    emit(ProfilePhotoUpdating(user: currentUser));

    final result = await _updateProfilePhoto(imagePath: event.imagePath);

    result.fold(
      (failure) {
        _logger.error('Update profile photo failed', {'error': failure.message});
        emit(AuthError(message: failure.message ?? 'Failed to update profile photo.'));
        // Restore previous state
        _emitAuthenticatedState(emit, currentUser!);
      },
      (updatedUser) {
        _emitAuthenticatedState(emit, updatedUser);
      },
    );
  }

  Future<void> _onUpdateUsername(
    UpdateUsernameEvent event,
    Emitter<AuthState> emit,
  ) async {
    final currentState = state;
    AppUser? currentUser;

    if (currentState is Authenticated) {
      currentUser = currentState.user;
    } else if (currentState is EmailNotVerified) {
      currentUser = currentState.user;
    }

    if (currentUser == null) {
      emit(const AuthError(message: 'No user is currently signed in.'));
      return;
    }

    // Emit updating state
    emit(ProfileNameUpdating(user: currentUser));

    final result = await _updateUsername(
      firstName: event.firstName,
      lastName: event.lastName,
    );

    result.fold(
      (failure) {
        _logger.error('Update username failed', {'error': failure.message});
        emit(AuthError(message: failure.message ?? 'Failed to update username.'));
        // Restore previous state
        _emitAuthenticatedState(emit, currentUser!);
      },
      (updatedUser) {
        _emitAuthenticatedState(emit, updatedUser);
      },
    );
  }

  Future<void> _onDeleteAccount(
    DeleteAccountEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());

    final result = await _deleteAccount();

    result.fold(
      (failure) {
        _logger.error('Delete account failed', {'error': failure.message});
        emit(AuthError(message: failure.message ?? 'Failed to delete account.'));
      },
      (_) => emit(const AccountDeleted()),
    );
  }

  /// Emits the appropriate authenticated state based on email verification.
  void _emitAuthenticatedState(Emitter<AuthState> emit, AppUser user) {
    if (user.emailVerified) {
      emit(Authenticated(user: user));
    } else {
      emit(EmailNotVerified(user: user));
    }
  }
}
