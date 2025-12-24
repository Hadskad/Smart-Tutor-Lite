import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../injection_container.dart';
import '../../domain/repositories/study_mode_repository.dart';
import '../bloc/study_mode_bloc.dart';
import '../bloc/study_mode_event.dart';
import '../bloc/study_mode_state.dart';

// Color Palette matching Home Dashboard
const Color _kBackgroundColor = Color(0xFF1E1E1E);
const Color _kCardColor = Color(0xFF333333);
const Color _kAccentBlue = Color(0xFF00BFFF);
const Color _kAccentCoral = Color(0xFFFF7043);
const Color _kWhite = Colors.white;
const Color _kLightGray = Color(0xFFCCCCCC);
const Color _kDarkGray = Color(0xFF888888);

class StudyProgressPage extends StatefulWidget {
  const StudyProgressPage({super.key});

  @override
  State<StudyProgressPage> createState() => _StudyProgressPageState();
}

class _StudyProgressPageState extends State<StudyProgressPage> {
  late final StudyModeBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = getIt<StudyModeBloc>();
    _bloc.add(const LoadProgressEvent());
  }

  @override
  void dispose() {
    // Don't close the bloc - it's a singleton shared across the app
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: _kBackgroundColor,
        appBar: AppBar(
          backgroundColor: _kBackgroundColor,
          elevation: 0,
          title: const Text(
            'Study Progress',
            style: TextStyle(
              color: _kWhite,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconTheme: const IconThemeData(color: _kWhite),
        ),
        body: BlocBuilder<StudyModeBloc, StudyModeState>(
          builder: (context, state) {
            if (state is StudyModeProgressLoaded) {
              return _ProgressView(progress: state.progress);
            }

            if (state is StudyModeError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: _kAccentCoral),
                    const SizedBox(height: 16),
                    Text(
                      state.message,
                      style: const TextStyle(color: _kWhite, fontSize: 16),
                    ),
                  ],
                ),
              );
            }

            return const Center(
              child: CircularProgressIndicator(color: _kAccentBlue),
            );
          },
        ),
      ),
    );
  }
}

class _ProgressView extends StatelessWidget {
  const _ProgressView({required this.progress});

  final StudyProgress progress;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Overview card
        Container(
          decoration: BoxDecoration(
            color: _kCardColor,
            borderRadius: BorderRadius.circular(20.0),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Overview',
                style: TextStyle(
                  color: _kWhite,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.style,
                      label: 'Total Cards',
                      value: '${progress.totalFlashcards}',
                      color: _kAccentBlue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.check_circle,
                      label: 'Known',
                      value: '${progress.totalKnown}',
                      color: _kAccentBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.help_outline,
                      label: 'Unknown',
                      value: '${progress.totalUnknown}',
                      color: _kAccentCoral,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.repeat,
                      label: 'Reviewed',
                      value: '${progress.totalReviewed}',
                      color: _kAccentBlue,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Study sessions
        Container(
          decoration: BoxDecoration(
            color: _kCardColor,
            borderRadius: BorderRadius.circular(20.0),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Study Sessions',
                style: TextStyle(
                  color: _kWhite,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              _StatRow(
                icon: Icons.book,
                label: 'Total Sessions',
                value: '${progress.totalSessions}',
              ),
              const Divider(color: _kDarkGray),
              _StatRow(
                icon: Icons.timer,
                label: 'Avg. Duration',
                value: _formatDuration(progress.averageSessionDuration),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '$seconds seconds';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes < 60) {
      return remainingSeconds > 0
          ? '$minutes m $remainingSeconds s'
          : '$minutes minutes';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '$hours h $remainingMinutes m';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: _kLightGray,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: _kDarkGray),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _kLightGray,
                fontSize: 16,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: _kWhite,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
