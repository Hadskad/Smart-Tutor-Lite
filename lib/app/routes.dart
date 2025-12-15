import 'package:flutter/material.dart';

import '../features/profile/presentation/pages/profile_page.dart';
import '../features/quiz/presentation/pages/quiz_creation_page.dart';
import '../features/study_mode/presentation/pages/study_mode_page.dart';
import '../features/summarization/presentation/pages/summary_page.dart';
import '../features/text_to_speech/presentation/pages/tts_page.dart';
import '../features/transcription/presentation/pages/transcription_page.dart';

class AppRoutes {
  static const String transcription = '/transcription';
  static const String summarization = '/summarization';
  static const String quiz = '/quiz';
  static const String tts = '/tts';
  static const String studyMode = '/study-mode';
  static const String profile = '/profile';

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
        return MaterialPageRoute(
          builder: (_) => const QuizCreationPage(),
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
