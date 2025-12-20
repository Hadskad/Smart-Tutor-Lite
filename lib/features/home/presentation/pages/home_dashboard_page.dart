import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:smart_tutor_lite/app/routes.dart';
import 'package:smart_tutor_lite/injection_container.dart';
import '../../../../features/study_folders/presentation/bloc/study_folders_bloc.dart';
import '../../../../features/study_folders/presentation/bloc/study_folders_event.dart';
import '../../../../features/study_folders/presentation/bloc/study_folders_state.dart';
import '../widgets/create_folder_dialog.dart';
import '../widgets/study_folders_section.dart';

// --- Local Color Palette for Home Dashboard ---

const Color _kBackgroundColor = Color(0xFF1E1E1E);
const Color _kCardColor = Color(0xFF333333);
const Color _kAccentBlue = Color(0xFF00BFFF); // Vibrant Electric Blue
const Color _kAccentCoral = Color(0xFFFF7043); // Soft Coral/Orange
const Color _kWhite = Colors.white;
const Color _kLightGray = Color(0xFFCCCCCC);
const Color _kDarkGray = Color(0xFF888888);

class HomeDashboardPage extends StatefulWidget {
  const HomeDashboardPage({super.key});

  @override
  State<HomeDashboardPage> createState() => _HomeDashboardPageState();
}

class _HomeDashboardPageState extends State<HomeDashboardPage> {
  late final StudyFoldersBloc _studyFoldersBloc;

  @override
  void initState() {
    super.initState();
    _studyFoldersBloc = getIt<StudyFoldersBloc>();
    // Load folders on page initialization
    _studyFoldersBloc.add(const LoadFoldersEvent());
  }

  @override
  void dispose() {
    _studyFoldersBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _studyFoldersBloc,
      child: BlocListener<StudyFoldersBloc, StudyFoldersState>(
        listener: (context, state) {
          if (state is StudyFoldersError) {
            // Show error message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: Scaffold(
          backgroundColor: _kBackgroundColor,
          appBar: AppBar(
            backgroundColor: _kBackgroundColor,
            elevation: 0,
            centerTitle: false,
            title: _HeaderTitle(),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: _ProfileIconButton(
                  onTap: () {
                    Navigator.pushNamed(context, AppRoutes.profile);
                  },
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5.0),
                child: Column(
                  children: [
                    const SizedBox(height: 16.0),
                    const _SearchBarWidget(),
                    const SizedBox(height: 32.0),
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5,
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
                    const SizedBox(height: 16.0),
                    SizedBox(
                      width: double.infinity,
                      height: 70,
                      child: _FeatureCard(
                        title: 'Study Mode',
                        subtitle: 'Flashcards',
                        icon: Icons.quiz_outlined,
                        iconColor: _kAccentBlue,
                        isLarge: false,
                        isHorizontal: true,
                        cardColor: _kCardColor,
                        onTap: () {
                          Navigator.pushNamed(context, AppRoutes.studyMode);
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text('My Courses:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _kLightGray,
                                fontSize: 22)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Study Folders Grid Section
                    StudyFoldersSection(
                      onCreateFolderTap: () {
                        showDialog(
                          context: context,
                          builder: (dialogContext) => BlocProvider.value(
                            value: _studyFoldersBloc,
                            child: const CreateFolderDialog(),
                          ),
                        );
                      },
                      onFolderTap: (folderId, folderName) {
                        Navigator.pushNamed(
                          context,
                          AppRoutes.studyFolderDetail,
                          arguments: {
                            'folderId': folderId,
                            'folderName': folderName,
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- 1. Header Title Widget (for AppBar) ---

class _HeaderTitle extends StatelessWidget {
  const _HeaderTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Hi, Learner!',
          style: TextStyle(
            color: _kWhite,
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 1),
        Text(
          'Master your flow.',
          style: TextStyle(
            color: _kAccentBlue,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// --- 2. Profile Icon Button (for AppBar) ---

class _ProfileIconButton extends StatelessWidget {
  const _ProfileIconButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
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
    );
  }
}

// --- 3. Search Bar Widget ---

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
          flex: 3,
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
        const SizedBox(width: 2),
        // Stacked smaller cards
        Expanded(
          flex: 2,
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

// --- 5. Feature Card Template ---

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    this.isLarge = false,
    this.isHorizontal = false,
    required this.cardColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final bool isLarge;
  final bool isHorizontal;
  final Color cardColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20.0),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isLarge
            ? 0
            : isHorizontal
                ? 2
                : 6),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: isHorizontal
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 48,
                    color: iconColor,
                  ),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: _kWhite,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: _kLightGray,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: isLarge ? 70 : 38,
                    color: iconColor,
                  ),
                  isLarge ? SizedBox(height: 40) : SizedBox(height: 5),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Padding(
                        padding: isLarge
                            ? EdgeInsets.all(0)
                            : EdgeInsets.symmetric(horizontal: 3),
                        child: Text(
                          title,
                          style: TextStyle(
                            color: _kWhite,
                            fontSize: isLarge ? 24 : 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      isLarge ? SizedBox(height: 4) : SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: _kLightGray,
                          fontSize: isLarge ? 16 : 14,
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
