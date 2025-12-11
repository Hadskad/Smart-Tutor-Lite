import 'package:flutter/material.dart';

import 'package:smart_tutor_lite/app/routes.dart';

// --- Local Color Palette for Home Dashboard ---

const Color _kBackgroundColor = Color(0xFF1E1E1E);
const Color _kCardColor = Color(0xFF333333);
const Color _kAccentBlue = Color(0xFF00BFFF); // Vibrant Electric Blue
const Color _kAccentCoral = Color(0xFFFF7043); // Soft Coral/Orange
const Color _kWhite = Colors.white;
const Color _kLightGray = Color(0xFFCCCCCC);
const Color _kDarkGray = Color(0xFF888888);

class HomeDashboardPage extends StatelessWidget {
  const HomeDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _HeaderWidget(),
            const SizedBox(height: 32.0),
            const _SearchBarWidget(),
            const SizedBox(height: 32.0),
             SizedBox(
              height: MediaQuery.of(context).size.height *0.5,
              width: double.infinity,
              child: _FeatureCardsGrid(
                onNoteTakerTap: () {
                  Navigator.pushNamed(context, AppRoutes.transcription);
                },
                onSummaryTap: () {
                  Navigator.pushNamed(context, AppRoutes.summarization);
                },
                onPracticeTap: () {
                  Navigator.pushNamed(context, AppRoutes.quiz);
                },
                onAudioNotesTap: () {
                  Navigator.pushNamed(context, AppRoutes.tts);
                },
              ),
            ),
          ],
        ),
      ),
    
    );
  }
}

// --- 1. Header Widget ---

class _HeaderWidget extends StatelessWidget {
  const _HeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Hi, Learner!',
              style: TextStyle(
                color: _kWhite,
                fontSize: 32,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Master your flow.',
              style: TextStyle(
                color: _kAccentBlue,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(4.0),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _kAccentBlue,
              width: 2.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _kAccentBlue.withOpacity(0.5),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const CircleAvatar(
            radius: 20,
            backgroundColor: _kCardColor,
            child: Icon(
              Icons.person_outlined,
              color: _kWhite,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }
}

// --- 2. Search Bar Widget ---

class _SearchBarWidget extends StatelessWidget {
  const _SearchBarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: _kCardColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(color: _kCardColor, width: 1.0),
      ),
      child: Row(
        children: const [
          Icon(Icons.search, color: _kAccentBlue),
          SizedBox(width: 12.0),
          Expanded(
            child: Text(
              'What are you mastering today?',
              style: TextStyle(
                color: _kLightGray,
                fontSize: 16,
              ),
            ),
          ),
          Icon(Icons.mic_none, color: _kAccentBlue),
        ],
      ),
    );
  }
}

// --- 3. Feature Cards Grid ---

class _FeatureCardsGrid extends StatelessWidget {
  const _FeatureCardsGrid({
    super.key,
    required this.onNoteTakerTap,
    required this.onSummaryTap,
    required this.onPracticeTap,
    required this.onAudioNotesTap,
  });

  final VoidCallback onNoteTakerTap;
  final VoidCallback onSummaryTap;
  final VoidCallback onPracticeTap;
  final VoidCallback onAudioNotesTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Large dominant card: Note Taker
        Expanded(
          flex: 2,
          child: _FeatureCard(
            title: 'Note Taker',
            subtitle: 'Lectures → notes',
            icon: Icons.auto_stories,
            iconColor: _kAccentBlue,
            isLarge: true,
            cardColor: _kCardColor,
            onTap: onNoteTakerTap,
          ),
        ),
        const SizedBox(width: 16.0),
        // Stacked smaller cards
        Expanded(
          flex: 1,
          child: Column(
            children: [
              Expanded(
                child: _FeatureCard(
                  title: 'Summary Bot',
                  subtitle: 'Summarize notes',
                  icon: Icons.hexagon_outlined,
                  iconColor: _kAccentBlue,
                  cardColor: _kCardColor,
                  onTap: onSummaryTap,
                ),
              ),
              const SizedBox(height: 16.0),
              Expanded(
                child: _FeatureCard(
                  title: 'Practice mode',
                  subtitle: 'Quizzes & drills',
                  icon: Icons.lightbulb_outline,
                  iconColor: _kAccentCoral,
                  cardColor: _kCardColor,
                  onTap: onPracticeTap,
                ),
              ),
              const SizedBox(height: 16.0),
              Expanded(
                child: _FeatureCard(
                  title: 'Audio Notes',
                  subtitle: 'Listen on the go',
                  icon: Icons.headphones_outlined,
                  iconColor: _kWhite,
                  cardColor: _kCardColor,
                  onTap: onAudioNotesTap,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- Feature Card Template ---

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    this.isLarge = false,
    required this.cardColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final bool isLarge;
  final Color cardColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20.0),
      onTap: onTap,
      child: Container(
        
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: isLarge ? 70 : 36,
              color: iconColor,
            ),
            isLarge? SizedBox(height: 40): SizedBox(height: 5),
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: _kWhite,
                    fontSize: isLarge ? 24 : 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
               isLarge? SizedBox(height: 4): SizedBox(height: 1),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: _kLightGray,
                    fontSize: isLarge ? 16 : 12,
                  ),
                ),
              ],
            ),
            
            
          ],
        ),
      ),
    );
  }
}

