import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../injection_container.dart';
import '../../../study_mode/presentation/bloc/study_mode_bloc.dart';
import '../../../study_mode/presentation/bloc/study_mode_event.dart';
import '../../domain/entities/transcription.dart';
import '../../domain/entities/transcription_job.dart';
import '../bloc/transcription_bloc.dart';
import '../bloc/transcription_event.dart';
import '../bloc/transcription_state.dart';
import '../widgets/audio_recorder_widget.dart';
import 'transcription_detail_page.dart';

class TranscriptionPage extends StatefulWidget {
  const TranscriptionPage({super.key});

  @override
  State<TranscriptionPage> createState() => _TranscriptionPageState();
}

class _TranscriptionPageState extends State<TranscriptionPage> {
  late final TranscriptionBloc _bloc;
  bool _isFallbackDialogVisible = false;

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
          final messenger = ScaffoldMessenger.of(context);
          if (state is TranscriptionError) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Theme.of(context).colorScheme.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is TranscriptionSuccess) {
            final metrics = state.metrics;
            final message = metrics == null
                ? 'Transcription completed'
                : 'Transcribed in ${metrics.durationMs}ms';
            messenger.showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: Theme.of(context).colorScheme.secondary,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is TranscriptionNotice) {
            final color = state.severity == TranscriptionNoticeSeverity.warning
                ? Theme.of(context).colorScheme.tertiary
                : Theme.of(context).colorScheme.primary;
            messenger.showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: color,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is TranscriptionFallbackPrompt) {
            _showFallbackDialog(state);
          }
        },
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Record Lectures -> Notes'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.history),
                  onPressed: () {
                    // Placeholder for history filter or settings
                  },
                  tooltip: 'History',
                ),
              ],
            ),
            body: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Enhanced Recorder Widget Container
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outline
                                    .withValues(alpha: 0.1),
                              ),
                            ),
                            child: const AudioRecorderWidget(),
                          ),
                          const SizedBox(height: 24),
                          _ModeToggle(
                            value: state.preferences.alwaysUseOffline,
                          ),
                          const SizedBox(height: 8),
                          _FastModelToggle(
                            value: state.preferences.useFastWhisperModel,
                          ),
                          const SizedBox(height: 16),
                          _buildStatus(state),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Text(
                                'Recent Transcriptions',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const Spacer(),
                            ],
                          ),
                          Text(
                            'You can leave this page—jobs keep running in the background and appear here when ready.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 16),
                          _buildHistory(state.history),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatus(TranscriptionState state) {
    if (state is CloudTranscriptionState) {
      return _CloudTranscriptionStatus(job: state.job);
    }
    if (state is TranscriptionRecording) {
      return _StatusContainer(
        icon: Icons.mic,
        color: Theme.of(context).colorScheme.error,
        label: 'Recording in progress...',
      );
    }
    if (state is TranscriptionProcessing) {
      return _StatusContainer(
        icon: Icons.cloud_upload_rounded,
        color: Theme.of(context).colorScheme.tertiary,
        label: 'Processing audio...',
      );
    }
    if (state is TranscriptionSuccess) {
      return _StatusContainer(
        icon: Icons.check_circle_rounded,
        color: Theme.of(context).colorScheme.secondary,
        label: 'Transcription ready',
      );
    }
    if (state is TranscriptionNotice) {
      final color = state.severity == TranscriptionNoticeSeverity.warning
          ? Theme.of(context).colorScheme.tertiary
          : Theme.of(context).colorScheme.primary;
      return _StatusContainer(
        icon: Icons.info_outline_rounded,
        color: color,
        label: state.message,
      );
    }
    if (state is TranscriptionError) {
      return _StatusContainer(
        icon: Icons.error_outline_rounded,
        color: Theme.of(context).colorScheme.error,
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generating Flashcards'),
        content: const Text(
          'Your flashcards are being created. Visit Study Mode to practice once they are ready.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Dismiss'),
          ),
          FilledButton(
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mic_none_rounded,
              size: 64,
              color:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No transcriptions yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Record something to get started!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final transcription = history[index];
        return Card(
          margin: EdgeInsets.zero,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TranscriptionDetailPage(
                    transcription: transcription,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.graphic_eq,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat.yMMMd()
                                  .format(transcription.timestamp),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .secondary
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${(transcription.confidence * 100).toStringAsFixed(0)}% Accuracy',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .secondary,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.play_circle_outline_rounded),
                        color: Theme.of(context).colorScheme.primary,
                        tooltip: 'Play Audio',
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Audio playback coming soon.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    transcription.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.5,
                        ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.style_outlined, size: 18),
                      label: const Text('Create Flashcards'),
                      onPressed: () {
                        _generateFlashcards(transcription.id, 'transcription');
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.tertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showFallbackDialog(
    TranscriptionFallbackPrompt state,
  ) async {
    if (!mounted || _isFallbackDialogVisible) {
      return;
    }
    _isFallbackDialogVisible = true;
    final bloc = context.read<TranscriptionBloc>();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final reason = state.reason ??
            'Switch to on-device mode to finish faster? (Possibly lesser quality).';
        return AlertDialog(
          title: const Text('Cloud transcription issue'),
          content: Text(reason),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                bloc.add(const RetryCloudFromFallback());
              },
              child: const Text('Retry online transcription'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                bloc.add(const ConfirmOfflineFallback());
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );

    if (mounted) {
      _isFallbackDialogVisible = false;
    }
  }
}

class _StatusContainer extends StatelessWidget {
  const _StatusContainer({
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: (isOn) {
        context.read<TranscriptionBloc>().add(ToggleOfflinePreference(isOn));
      },
      title: const Text('Always use offline mode'),
      subtitle: const Text(
        'Offline mode let\'s you transcribe without internet connection. You are given a raw transcription, compared to the online mode that structures the note for you.',
      ),
      contentPadding: EdgeInsets.zero,
    );
  }
}

class _FastModelToggle extends StatelessWidget {
  const _FastModelToggle({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: (isOn) {
        context.read<TranscriptionBloc>().add(ToggleFastWhisperModel(isOn));
      },
      title: const Text('Enable fast transcribe'),
      subtitle: const Text(
        'Transcribes faster but trades some accuracy for speed.',
      ),
      contentPadding: EdgeInsets.zero,
    );
  }
}

class _CloudTranscriptionStatus extends StatelessWidget {
  const _CloudTranscriptionStatus({required this.job});

  final TranscriptionJob job;

  @override
  Widget build(BuildContext context) {
    final color = _colorForStatus(context, job.status);
    final label = _labelForStatus(job);
    final progress =
        job.progress != null ? job.progress!.clamp(0, 100) / 100 : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatusContainer(
          icon: _iconForStatus(job.status),
          color: color,
          label: label,
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: progress,
          minHeight: 6,
          backgroundColor: color.withValues(alpha: 0.1),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
        const SizedBox(height: 8),
        Text(
          'You can safely leave this screen; progress is tracked in Recent Transcriptions.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        if (job.noteStatus == 'error' && job.noteError != null)
          Text(
            'Smart notes failed: ${job.noteError}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
          )
        else if (job.noteStatus == 'ready')
          Text(
            'Smart notes ready.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.w600,
                ),
          )
        else if (job.status == TranscriptionJobStatus.generatingNote)
          Text(
            'Creating structured lecture notes...',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (job.noteStatus != null) const SizedBox(height: 12),
        Row(
          children: [
            if (!job.isTerminal)
              TextButton.icon(
                onPressed: () => context
                    .read<TranscriptionBloc>()
                    .add(const CancelCloudTranscription()),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Cancel'),
              ),
            const Spacer(),
            if (job.noteStatus == 'error' && job.noteCanRetry)
              FilledButton.icon(
                onPressed: () => context
                    .read<TranscriptionBloc>()
                    .add(RetryNoteGeneration(job.id)),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry notes'),
              )
            else if (job.canRetry)
              FilledButton.icon(
                onPressed: () => context
                    .read<TranscriptionBloc>()
                    .add(RetryCloudTranscription(job.id)),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
          ],
        ),
      ],
    );
  }

  static String _labelForStatus(TranscriptionJob job) {
    switch (job.status) {
      case TranscriptionJobStatus.pending:
        return 'Preparing upload...';
      case TranscriptionJobStatus.uploading:
        return 'Uploading audio to the cloud${_formatProgress(job)}';
      case TranscriptionJobStatus.processing:
        return 'Transcribing audio${_formatProgress(job)}';
      case TranscriptionJobStatus.generatingNote:
        return 'Generating smart notes${_formatProgress(job)}';
      case TranscriptionJobStatus.done:
        return 'Cloud transcription complete';
      case TranscriptionJobStatus.error:
        return job.errorMessage ?? 'Cloud transcription failed';
    }
  }

  static IconData _iconForStatus(TranscriptionJobStatus status) {
    switch (status) {
      case TranscriptionJobStatus.pending:
      case TranscriptionJobStatus.uploading:
        return Icons.cloud_upload_outlined;
      case TranscriptionJobStatus.processing:
        return Icons.cloud_sync_outlined;
      case TranscriptionJobStatus.generatingNote:
        return Icons.auto_stories_outlined;
      case TranscriptionJobStatus.done:
        return Icons.cloud_done_outlined;
      case TranscriptionJobStatus.error:
        return Icons.cloud_off_outlined;
    }
  }

  static Color _colorForStatus(
    BuildContext context,
    TranscriptionJobStatus status,
  ) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case TranscriptionJobStatus.error:
        return scheme.error;
      case TranscriptionJobStatus.done:
        return scheme.secondary;
      default:
        return scheme.primary;
    }
  }

  static String _formatProgress(TranscriptionJob job) {
    final raw = job.progress;
    if (raw == null) {
      return '';
    }
    final clamped = raw.clamp(0, 100).round();
    if (clamped <= 0 || clamped >= 100) {
      return '';
    }
    return ' ($clamped%)';
  }
}
