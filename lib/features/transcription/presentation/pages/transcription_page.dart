import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../injection_container.dart';
import '../../../study_mode/presentation/bloc/study_mode_bloc.dart';
import '../../../study_mode/presentation/bloc/study_mode_event.dart';
import '../../domain/entities/transcription.dart';
import '../bloc/transcription_bloc.dart';
import '../bloc/transcription_event.dart';
import '../bloc/transcription_state.dart';
import '../widgets/audio_recorder_widget.dart';

class TranscriptionPage extends StatefulWidget {
  const TranscriptionPage({super.key});

  @override
  State<TranscriptionPage> createState() => _TranscriptionPageState();
}

class _TranscriptionPageState extends State<TranscriptionPage> {
  late final TranscriptionBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = getIt<TranscriptionBloc>();
    _bloc.add(const LoadTranscriptions());
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
      child: BlocConsumer<TranscriptionBloc, TranscriptionState>(
        listener: (context, state) {
          if (state is TranscriptionError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          } else if (state is TranscriptionSuccess) {
            final metrics = state.metrics;
            final message = metrics == null
                ? 'Transcription completed'
                : 'Transcribed in ${metrics.durationMs}ms';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message)),
            );
          }
        },
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Transcription'),
            ),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const AudioRecorderWidget(),
                  const SizedBox(height: 24),
                  _buildStatus(state),
                  const SizedBox(height: 16),
                  Expanded(child: _buildHistory(state.history)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatus(TranscriptionState state) {
    if (state is TranscriptionRecording) {
      return _StatusChip(
        icon: Icons.mic,
        color: Colors.redAccent,
        label: 'Recording…',
      );
    }
    if (state is TranscriptionProcessing) {
      return const _StatusChip(
        icon: Icons.cloud_upload,
        color: Colors.orange,
        label: 'Processing audio…',
      );
    }
    if (state is TranscriptionSuccess) {
      return _StatusChip(
        icon: Icons.check_circle,
        color: Colors.green,
        label: 'Latest transcription ready',
      );
    }
    if (state is TranscriptionError) {
      return _StatusChip(
        icon: Icons.error_outline,
        color: Colors.red,
        label: state.message,
      );
    }
    return const SizedBox.shrink();
  }

  void _generateFlashcards(String sourceId, String sourceType) {
    final studyModeBloc = getIt<StudyModeBloc>();
    studyModeBloc.add(GenerateFlashcardsEvent(
      sourceId: sourceId,
      sourceType: sourceType,
      numFlashcards: 10,
    ));

    // Show dialog to navigate to study mode
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Flashcards Generating'),
        content: const Text(
          'Your flashcards are being generated. Go to Study Mode to view them when ready.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/study-mode');
            },
            child: const Text('Go to Study Mode'),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory(List<Transcription> history) {
    if (history.isEmpty) {
      return const Center(
        child: Text('No transcriptions yet. Record something to get started!'),
      );
    }
    return ListView.separated(
      itemCount: history.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final transcription = history[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.graphic_eq),
                title: Text(
                  transcription.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${transcription.timestamp} • ${(transcription.confidence * 100).toStringAsFixed(1)}% confidence',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.play_arrow),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Audio playback coming soon.'),
                      ),
                    );
                  },
                ),
              ),
              ButtonBar(
                alignment: MainAxisAlignment.start,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.style, size: 18),
                    label: const Text('Generate Flashcards'),
                    onPressed: () {
                      _generateFlashcards(transcription.id, 'transcription');
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
