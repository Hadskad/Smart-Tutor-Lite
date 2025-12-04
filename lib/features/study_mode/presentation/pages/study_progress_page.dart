import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../injection_container.dart';
import '../../domain/repositories/study_mode_repository.dart';
import '../bloc/study_mode_bloc.dart';
import '../bloc/study_mode_event.dart';
import '../bloc/study_mode_state.dart';

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
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Study Progress'),
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
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(state.message),
                  ],
                ),
              );
            }

            return const Center(child: CircularProgressIndicator());
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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overview',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.style,
                        label: 'Total Cards',
                        value: '${progress.totalFlashcards}',
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.check_circle,
                        label: 'Known',
                        value: '${progress.totalKnown}',
                        color: Colors.green,
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
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.repeat,
                        label: 'Reviewed',
                        value: '${progress.totalReviewed}',
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Retention rate
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mastery',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),
                LinearProgressIndicator(
                  value: progress.retentionRate / 100,
                  minHeight: 24,
                  borderRadius: BorderRadius.circular(12),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    '${progress.retentionRate.toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _getMasteryColor(progress.retentionRate),
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Study sessions
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Study Sessions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 24),
                _StatRow(
                  icon: Icons.book,
                  label: 'Total Sessions',
                  value: '${progress.totalSessions}',
                ),
                const Divider(),
                _StatRow(
                  icon: Icons.timer,
                  label: 'Avg. Duration',
                  value: _formatDuration(progress.averageSessionDuration),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _getMasteryColor(double percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.orange;
    return Colors.red;
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
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
          Icon(icon, color: Colors.grey),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}

