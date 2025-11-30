import 'package:flutter/material.dart';

import '../features/quiz/presentation/pages/quiz_creation_page.dart';
import '../features/study_mode/presentation/pages/study_mode_page.dart';
import '../features/summarization/presentation/pages/summary_page.dart';
import '../features/text_to_speech/presentation/pages/tts_page.dart';
import '../features/transcription/presentation/pages/transcription_page.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const TranscriptionPage(),
    const SummaryPage(),
    const QuizCreationPage(),
    const StudyModePage(),
    const TtsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.mic_none),
              selectedIcon: Icon(Icons.mic),
              label: 'Record',
            ),
            NavigationDestination(
              icon: Icon(Icons.summarize_outlined),
              selectedIcon: Icon(Icons.summarize),
              label: 'Summarize',
            ),
            NavigationDestination(
              icon: Icon(Icons.quiz_outlined),
              selectedIcon: Icon(Icons.quiz),
              label: 'Quiz',
            ),
            NavigationDestination(
              icon: Icon(Icons.style_outlined),
              selectedIcon: Icon(Icons.style),
              label: 'Study',
            ),
            NavigationDestination(
              icon: Icon(Icons.volume_up_outlined),
              selectedIcon: Icon(Icons.volume_up),
              label: 'TTS',
            ),
          ],
        ),
      ),
    );
  }
}
