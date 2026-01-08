import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/profile/presentation/pages/profile_page.dart';
import '../features/quiz/presentation/bloc/quiz_bloc.dart';
import '../features/quiz/presentation/pages/quiz_creation_page.dart';
import '../features/study_mode/presentation/pages/study_mode_page.dart';
import '../features/study_folders/presentation/pages/study_folder_detail_page.dart';
import '../features/subscription/presentation/pages/subscription_page.dart';
import '../features/summarization/presentation/pages/summary_page.dart';
import '../features/text_to_speech/presentation/pages/tts_page.dart';
import '../features/transcription/presentation/pages/transcription_page.dart';
import '../injection_container.dart';
import '../features/auth/presentation/pages/verify_email_screen.dart';
import '../features/auth/presentation/pages/login_screen.dart';
import '../features/auth/presentation/pages/signup_screen.dart';
import '../features/auth/presentation/pages/forgot_password_screen.dart';
import '../app/main_navigation.dart';

class AppRoutes {
  static const String transcription = '/transcription';
  static const String summarization = '/summarization';
  static const String quiz = '/quiz';
  static const String tts = '/tts';
  static const String studyMode = '/study-mode';
  static const String profile = '/profile';
  static const String studyFolderDetail = '/study-folder-detail';
  static const String subscription = '/subscription';
  static const String verifyEmailView = '/verify-email';
  static const String signupView = '/signup-view';
  static const String loginView = '/login-view';
  static const String mainNav = '/main-nav';
  static const String forgotPasswordView = '/forgot-password';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case transcription:
      case '/':
        return MaterialPageRoute(
          builder: (_) => const TranscriptionPage(),
          settings: settings,
        );
      case summarization:
        return MaterialPageRoute(
          builder: (_) => const SummaryPage(),
          settings: settings,
        );
      case quiz:
        // Wrap quiz flow with a single QuizBloc instance
        return MaterialPageRoute(
          builder: (_) => BlocProvider<QuizBloc>(
            create: (_) => getIt<QuizBloc>(),
            child: const QuizCreationPage(),
          ),
          settings: settings,
        );
      case tts:
        return MaterialPageRoute(
          builder: (_) => const TtsPage(),
          settings: settings,
        );
      case studyMode:
        return MaterialPageRoute(
          builder: (_) => const StudyModePage(),
          settings: settings,
        );
      case profile:
        return MaterialPageRoute(
          builder: (_) => const ProfilePage(),
          settings: settings,
        );
      case subscription:
        return MaterialPageRoute(
          builder: (_) => const SubscriptionPage(),
          settings: settings,
        );
        case verifyEmailView:
        return MaterialPageRoute(
          builder: (_) => const VerifyEmailView(),
          settings: settings,
        );
          case loginView:
        return MaterialPageRoute(
          builder: (_) => const LoginView(),
          settings: settings,
        );
       case signupView:
        return MaterialPageRoute(
          builder: (_) => const SignupView(),
          settings: settings,
        );
        case mainNav:
        return MaterialPageRoute(
          builder: (_) => const MainNavigation(),
          settings: settings,
        );
      case forgotPasswordView:
        return MaterialPageRoute(
          builder: (_) => const ForgotPasswordScreen(),
          settings: settings,
        );

      case studyFolderDetail:
        final args = settings.arguments as Map<String, dynamic>?;
        if (args == null ||
            args['folderId'] == null ||
            args['folderName'] == null) {
          return MaterialPageRoute(
            builder: (_) => const _UnknownRoutePage(),
            settings: settings,
          );
        }
        // Validate types before casting
        if (args['folderId'] is! String || args['folderName'] is! String) {
          return MaterialPageRoute(
            builder: (_) => const _UnknownRoutePage(),
            settings: settings,
          );
        }
        return MaterialPageRoute(
          builder: (_) => StudyFolderDetailPage(
            folderId: args['folderId'] as String,
            folderName: args['folderName'] as String,
          ),
          settings: settings,
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const _UnknownRoutePage(),
          settings: settings,
        );
    }
  }
}

class _UnknownRoutePage extends StatelessWidget {
  const _UnknownRoutePage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48),
            SizedBox(height: 12),
            Text('Route not found'),
          ],
        ),
      ),
    );
  }
}
