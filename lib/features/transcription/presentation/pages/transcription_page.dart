import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../injection_container.dart';
import '../../../study_mode/presentation/bloc/study_mode_bloc.dart';
import '../../../study_mode/presentation/bloc/study_mode_event.dart';
import '../../../study_mode/presentation/bloc/study_mode_state.dart';
import '../../domain/entities/transcription.dart';
import '../../domain/entities/transcription_job.dart';
import '../../domain/repositories/transcription_repository.dart';
import '../bloc/transcription_bloc.dart';
import '../bloc/transcription_event.dart';
import '../bloc/transcription_state.dart';
import '../widgets/audio_recorder_widget.dart';
import '../widgets/note_list_card.dart';
import '../widgets/queued_job_card.dart';
import '../bloc/queued_transcription_job.dart';
import 'note_detail_page.dart';

// --- Color Palette (matching home dashboard) ---
const Color _kBackgroundColor = Color(0xFF1E1E1E);
const Color _kCardColor = Color(0xFF333333);
const Color _kAccentBlue = Color(0xFF00BFFF);
const Color _kAccentCoral = Color(0xFFFF7043);
const Color _kWhite = Colors.white;
const Color _kLightGray = Color(0xFFCCCCCC);
const Color _kDarkGray = Color(0xFF888888);

class TranscriptionPage extends StatefulWidget {
  const TranscriptionPage({super.key});

  @override
  State<TranscriptionPage> createState() => _TranscriptionPageState();
}

class _TranscriptionPageState extends State<TranscriptionPage> {
  late final TranscriptionBloc _bloc;
  late final StudyModeBloc _studyModeBloc;
  bool _isFallbackDialogVisible = false;
  int _previousHistoryLength = 0;

  @override
  void initState() {
    super.initState();
    _bloc = getIt<TranscriptionBloc>();
    _studyModeBloc = getIt<StudyModeBloc>();
    _bloc.add(const LoadTranscriptions());
  }

  @override
  void dispose() {
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _bloc),
        BlocProvider.value(value: _studyModeBloc),
      ],
      child: BlocListener<StudyModeBloc, StudyModeState>(
        listener: (context, state) {
          if (state is StudyModeFlashcardsLoaded) {
            // Close any open dialogs
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${state.flashcards.length} flashcards generated!',
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                action: SnackBarAction(
                  label: 'View',
                  textColor: Colors.white,
                  onPressed: () {
                    Navigator.pushNamed(context, '/study-mode');
                  },
                ),
              ),
            );
          } else if (state is StudyModeError) {
            // Close any open dialogs
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(child: Text(state.message)),
                  ],
                ),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
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
              _previousHistoryLength = state.history.length;
            } else if (state is TranscriptionNotice) {
              final color =
                  state.severity == TranscriptionNoticeSeverity.warning
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
            } else if (state is TranscriptionInitial) {
              // Detect deletion by checking if history length decreased
              if (_previousHistoryLength > 0 &&
                  state.history.length < _previousHistoryLength) {
                messenger.showSnackBar(
                  SnackBar(
                    content: const Text('Note deleted successfully'),
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
              _previousHistoryLength = state.history.length;
            }
          },
          builder: (context, state) {
            return Scaffold(
              backgroundColor: _kBackgroundColor,
              appBar: AppBar(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                backgroundColor: _kCardColor,
                title: const Text(
                  'Automatic Notes Taker',
                  style: TextStyle(
                      color: _kWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: 25),
                ),
                iconTheme: const IconThemeData(color: _kWhite),
              ),
              body: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: CustomScrollView(
                        slivers: [
                          // Enhanced Recorder Widget Container
                          SliverToBoxAdapter(
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: _kCardColor,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: _kAccentBlue.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const AudioRecorderWidget(),
                            ),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 24)),
                          SliverToBoxAdapter(
                            child: _ModeToggle(
                              value: state.preferences.alwaysUseOffline,
                            ),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 8)),
                          SliverToBoxAdapter(
                            child: _FastModelToggle(
                              value: state.preferences.useFastWhisperModel,
                            ),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 16)),
                          SliverToBoxAdapter(
                            child: _buildStatus(state),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 24)),
                          SliverToBoxAdapter(
                            child: _buildPendingTranscriptions(state.queue),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 24)),
                          SliverToBoxAdapter(
                            child: Row(
                              children: [
                                Text(
                                  'Recent Notes',
                                  style: const TextStyle(
                                    color: _kWhite,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                              ],
                            ),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 8)),
                          SliverToBoxAdapter(
                            child: Text(
                              'You can leave this page—jobs keep running in the background and appear here when ready.',
                              style: const TextStyle(
                                color: _kLightGray,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SliverToBoxAdapter(child: SizedBox(height: 16)),
                          _buildHistorySliver(state.history),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatus(TranscriptionState state) {
    final queueLength = state.queueLength;
    final hasQueue = queueLength > 0;

    if (state is CloudTranscriptionState) {
      return Column(
        children: [
          _CloudTranscriptionStatus(job: state.job),
          if (hasQueue) ...[
            const SizedBox(height: 12),
            _QueueStatusContainer(queueLength: queueLength),
          ],
        ],
      );
    }
    if (state is TranscriptionRecording) {
      return Column(
        children: [
          _StatusContainer(
            icon: Icons.mic,
            color: _kAccentCoral,
            label: 'Recording in progress...',
          ),
          if (hasQueue) ...[
            const SizedBox(height: 12),
            _QueueStatusContainer(queueLength: queueLength),
          ],
        ],
      );
    }
    if (state is TranscriptionStopping) {
      return Column(
        children: [
          _StatusContainer(
            icon: Icons.stop_circle_rounded,
            color: _kAccentBlue,
            label: 'Finalizing recording...',
          ),
          if (hasQueue) ...[
            const SizedBox(height: 12),
            _QueueStatusContainer(queueLength: queueLength),
          ],
        ],
      );
    }
    if (state is TranscriptionProcessing) {
      return Column(
        children: [
          _StatusContainer(
            icon: Icons.cloud_upload_rounded,
            color: _kAccentBlue,
            label: hasQueue
                ? 'Processing audio... ($queueLength in queue)'
                : 'Processing audio...',
          ),
          if (hasQueue) ...[
            const SizedBox(height: 12),
            _QueueStatusContainer(queueLength: queueLength),
          ],
        ],
      );
    }
    if (state is TranscriptionSuccess) {
      return Column(
        children: [
          _StatusContainer(
            icon: Icons.check_circle_rounded,
            color: _kAccentBlue,
            label: 'Transcription ready',
          ),
          if (hasQueue) ...[
            const SizedBox(height: 12),
            _QueueStatusContainer(queueLength: queueLength),
          ],
        ],
      );
    }
    if (state is TranscriptionNotice) {
      final color = state.severity == TranscriptionNoticeSeverity.warning
          ? _kAccentCoral
          : _kAccentBlue;
      return Column(
        children: [
          _StatusContainer(
            icon: Icons.info_outline_rounded,
            color: color,
            label: state.message,
          ),
          if (hasQueue) ...[
            const SizedBox(height: 12),
            _QueueStatusContainer(queueLength: queueLength),
          ],
        ],
      );
    }
    if (state is TranscriptionError) {
      return Column(
        children: [
          _StatusContainer(
            icon: Icons.error_outline_rounded,
            color: _kAccentCoral,
            label: state.message,
          ),
          if (hasQueue) ...[
            const SizedBox(height: 12),
            _QueueStatusContainer(queueLength: queueLength),
          ],
        ],
      );
    }
    return const SizedBox.shrink();
  }

  void _generateFlashcards(String sourceId, String sourceType) {
    _studyModeBloc.add(GenerateFlashcardsEvent(
      sourceId: sourceId,
      sourceType: sourceType,
      numFlashcards: 10,
    ));

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>  AlertDialog(
          title: const Text('Generating Flashcards'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text(
                'Your flashcards are being created. Please wait...',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Note: Generation will continue in background
              },
              child: const Text('Dismiss'),
            ),
          ],
        ),
      
    );
  }

  Future<void> _showDeleteConfirmationDialog(
    BuildContext context,
    Transcription transcription,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text(
          'Are you sure you want to delete this note? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: _kAccentCoral,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      _bloc.add(DeleteTranscription(transcription.id));
    }
  }

  Widget _buildPendingTranscriptions(List<QueuedTranscriptionJob> queue) {
    // Show all non-empty queue items (including success for brief period)
    // Success jobs will be in Recent Notes, but we show them here temporarily
    // with a "View note" button
    if (queue.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Pending Transcriptions (${queue.length})',
              style: const TextStyle(
                color: _kWhite,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'These recordings are waiting to be processed or are currently being transcribed.',
          style: const TextStyle(
            color: _kLightGray,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: queue.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final job = queue[index];
            return QueuedJobCard(
              job: job,
              onCancel: job.status == QueuedTranscriptionJobStatus.waiting ||
                      job.status == QueuedTranscriptionJobStatus.failed
                  ? () {
                      context
                          .read<TranscriptionBloc>()
                          .add(QueueJobCancelled(job.id));
                    }
                  : null,
              onRetry: job.status == QueuedTranscriptionJobStatus.failed
                  ? () {
                      context
                          .read<TranscriptionBloc>()
                          .add(QueueJobRetried(job.id));
                    }
                  : null,
              onViewNote: job.status == QueuedTranscriptionJobStatus.success &&
                      job.noteId != null
                  ? () {
                      _navigateToNote(context, job.noteId!);
                    }
                  : null,
            );
          },
        ),
      ],
    );
  }

  Future<void> _navigateToNote(BuildContext context, String noteId) async {
    try {
      // Find transcription in history by noteId
      final bloc = context.read<TranscriptionBloc>();
      final currentState = bloc.state;

      // Try to find in history first (fast path)
      Transcription? transcription;
      try {
        transcription = currentState.history.firstWhere(
          (t) => t.id == noteId,
        );
      } catch (e) {
        // Not in history - will fetch from repository (handles race condition)
        transcription = null;
      }

      // If not in history (race condition), fetch from repository
      if (transcription == null) {
        try {
          final repository = getIt<TranscriptionRepository>();
          final result = await repository.getTranscription(noteId);

          final fetchedTranscription = result.fold<Transcription?>(
            (failure) {
              // Show error and return null
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Note not found. It may have been deleted.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              return null;
            },
            (t) => t,
          );

          if (fetchedTranscription == null) {
            return; // Error already shown
          }

          transcription = fetchedTranscription;
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error loading note: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
          debugPrint('Error fetching transcription in _navigateToNote: $e');
          return;
        }
      }

      // Navigate to note detail page with error handling
      // At this point, transcription is guaranteed to be non-null
      // (either found in history or successfully fetched from repository)
      if (context.mounted) {
        try {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NoteDetailPage(
                transcription: transcription!,
              ),
            ),
          );
        } catch (e) {
          // Handle navigation failures gracefully
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Unable to open note: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
          debugPrint('Navigation error in _navigateToNote: $e');
        }
      }
    } catch (e) {
      // Catch any unexpected errors (e.g., bloc/repository access failures)
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      debugPrint('Unexpected error in _navigateToNote: $e');
    }
  }

  Widget _buildHistorySliver(List<Transcription> history) {
    if (history.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 64),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.mic_none_rounded,
                  size: 64,
                  color: _kDarkGray,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No transcriptions yet',
                  style: TextStyle(
                    color: _kLightGray,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Record something to get started!',
                  style: TextStyle(
                    color: _kDarkGray,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverList.separated(
      itemCount: history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final transcription = history[index];
        final isFailed = transcription.isFailed;

        return NoteListCard(
          transcription: transcription,
          onTap: isFailed
              ? null
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => NoteDetailPage(
                        transcription: transcription,
                      ),
                    ),
                  );
                },
          onEditTitle: isFailed
              ? null
              : () {
                  _showEditTitleDialog(context, transcription);
                },
          onDelete: () {
            _showDeleteConfirmationDialog(context, transcription);
          },
          onCreateFlashcards: isFailed
              ? null
              : () {
                  _generateFlashcards(transcription.id, 'transcription');
                },
          onRetry: isFailed
              ? () {
                  context
                      .read<TranscriptionBloc>()
                      .add(RetryFailedTranscription(transcription));
                }
              : null,
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
    final bloc = _bloc;

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

  void _showEditTitleDialog(BuildContext context, Transcription transcription) {
    final textController =
        TextEditingController(text: transcription.title ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _kCardColor,
        title: const Text(
          'Edit Title',
          style: TextStyle(color: _kWhite),
        ),
        content: TextField(
          controller: textController,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            hintText: 'Enter title',
            hintStyle: TextStyle(color: _kDarkGray),
            border: OutlineInputBorder(
              borderSide: BorderSide(color: _kAccentBlue),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: _kAccentBlue),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: _kAccentBlue, width: 2),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: _kAccentBlue),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final newTitle = textController.text.trim();
              final updatedTranscription = Transcription(
                id: transcription.id,
                text: transcription.text,
                audioPath: transcription.audioPath,
                duration: transcription.duration,
                timestamp: transcription.timestamp,
                confidence: transcription.confidence,
                metadata: transcription.metadata,
                title: newTitle.isEmpty ? null : newTitle,
                structuredNote: transcription.structuredNote,
              );
              _bloc.add(UpdateTranscription(updatedTranscription));
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAccentBlue,
              foregroundColor: _kWhite,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: (isOn) {
          context.read<TranscriptionBloc>().add(ToggleOfflinePreference(isOn));
        },
        title: const Text(
          'Use offline mode',
          style: TextStyle(
            color: _kWhite,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: const Text(
          'Offline mode let\'s you take notes without internet connection. You are given a raw note, compared to the online mode that structures the note for you.',
          style: TextStyle(
            color: _kLightGray,
            fontSize: 14,
          ),
        ),
        activeColor: _kAccentBlue,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

class _FastModelToggle extends StatelessWidget {
  const _FastModelToggle({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: (isOn) {
          context.read<TranscriptionBloc>().add(ToggleFastWhisperModel(isOn));
        },
        title: const Text(
          'Enable fast note taking',
          style: TextStyle(
            color: _kWhite,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: const Text(
          'Takes notes faster but trades some accuracy for speed.',
          style: TextStyle(
            color: _kLightGray,
            fontSize: 14,
          ),
        ),
        activeColor: _kAccentBlue,
        contentPadding: EdgeInsets.zero,
      ),
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
          backgroundColor: color.withOpacity(0.1),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
        const SizedBox(height: 8),
        const Text(
          'You can safely leave this screen; progress is tracked in Recent Transcriptions.',
          style: TextStyle(
            color: _kLightGray,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        if (job.noteStatus == 'error' && job.noteError != null)
          Text(
            'Smart notes failed: ${job.noteError}',
            style: const TextStyle(
              color: _kAccentCoral,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          )
        else if (job.noteStatus == 'ready')
          const Text(
            'Smart notes ready.',
            style: TextStyle(
              color: _kAccentBlue,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          )
        else if (job.status == TranscriptionJobStatus.generatingNote)
          const Text(
            'Creating structured lecture notes...',
            style: TextStyle(
              color: _kLightGray,
              fontSize: 12,
            ),
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
      case TranscriptionJobStatus.uploaded:
        return 'Audio uploaded, processing...';
      case TranscriptionJobStatus.processing:
        return 'Transcribing audio${_formatProgress(job)}';
      case TranscriptionJobStatus.generatingNote:
        return 'Generating smart notes${_formatProgress(job)}';
      case TranscriptionJobStatus.completed:
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
      case TranscriptionJobStatus.uploaded:
        return Icons.cloud_upload_outlined;
      case TranscriptionJobStatus.processing:
        return Icons.cloud_sync_outlined;
      case TranscriptionJobStatus.generatingNote:
        return Icons.auto_stories_outlined;
      case TranscriptionJobStatus.completed:
        return Icons.cloud_done_outlined;
      case TranscriptionJobStatus.error:
        return Icons.cloud_off_outlined;
    }
  }

  static Color _colorForStatus(
    BuildContext context,
    TranscriptionJobStatus status,
  ) {
    switch (status) {
      case TranscriptionJobStatus.error:
        return _kAccentCoral;
      case TranscriptionJobStatus.completed:
        return _kAccentBlue;
      default:
        return _kAccentBlue;
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

class _QueueStatusContainer extends StatelessWidget {
  const _QueueStatusContainer({required this.queueLength});

  final int queueLength;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kAccentBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _kAccentBlue.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.queue_music_rounded, color: _kAccentBlue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$queueLength audio${queueLength > 1 ? 's' : ''} in queue',
              style: const TextStyle(
                color: _kAccentBlue,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
