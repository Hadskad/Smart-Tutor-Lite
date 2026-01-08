import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../features/auth/presentation/bloc/auth_event.dart';
import '../features/auth/presentation/bloc/auth_state.dart';
import '../features/auth/presentation/pages/login_screen.dart';
import '../features/auth/presentation/pages/signup_screen.dart';
import '../features/auth/presentation/pages/verify_email_screen.dart';
import '../injection_container.dart';
import 'main_navigation.dart';
import 'routes.dart';

class SmartTutorLiteApp extends StatelessWidget {
  const SmartTutorLiteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>(
      create: (_) => getIt<AuthBloc>()..add(const CheckAuthStatusEvent()),
      child: MaterialApp(
        title: 'SmartTutor Lite',
        theme: AppTheme.light,
        home: const _AuthRouter(),
        onGenerateRoute: AppRoutes.onGenerateRoute,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

/// Routes to appropriate screens based on auth state.
/// Keeps screens mounted during loading/error states to preserve BlocListener functionality.
class _AuthRouter extends StatefulWidget {
  const _AuthRouter();

  @override
  State<_AuthRouter> createState() => _AuthRouterState();
}

class _AuthRouterState extends State<_AuthRouter> {
  // Track which screen type is currently shown to avoid unnecessary rebuilds
  _ScreenType _currentScreen = _ScreenType.loading;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        // Update screen type based on major auth state changes
        final newScreen = _getScreenType(state);
        if (newScreen != _currentScreen) {
          setState(() {
            _currentScreen = newScreen;
          });
        }
      },
      builder: (context, state) {
        // Show loading screen only during initial load
        if (state is AuthInitial) {
          return const _LoadingScreen();
        }

        // Return the appropriate screen based on current screen type
        switch (_currentScreen) {
          case _ScreenType.authenticated:
            return const MainNavigation();
          case _ScreenType.emailNotVerified:
            return const VerifyEmailView();
          case _ScreenType.unauthenticated:
            return const LoginView();
          case _ScreenType.accountDeleted:
            return const SignupView();
          case _ScreenType.loading:
            return const _LoadingScreen();
        }
      },
    );
  }

  _ScreenType _getScreenType(AuthState state) {
    if (state is Authenticated) {
      return _ScreenType.authenticated;
    } else if (state is EmailNotVerified) {
      return _ScreenType.emailNotVerified;
    } else if (state is AccountDeleted) {
      return _ScreenType.accountDeleted;
    } else if (state is Unauthenticated || state is AuthError) {
      return _ScreenType.unauthenticated;
    }
    // Keep current screen for AuthLoading, PasswordResetEmailSent, etc.
    return _currentScreen;
  }
}

enum _ScreenType {
  loading,
  authenticated,
  emailNotVerified,
  unauthenticated,
  accountDeleted,
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1E1E1E),
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00BFFF)),
        ),
      ),
    );
  }
}
