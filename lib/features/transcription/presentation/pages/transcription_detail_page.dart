import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../injection_container.dart';
import '../../../study_mode/presentation/bloc/study_mode_bloc.dart';
import '../../../study_mode/presentation/bloc/study_mode_event.dart';
import '../../../study_mode/presentation/bloc/study_mode_state.dart';
import '../../domain/entities/transcription.dart';

class TranscriptionDetailPage extends StatefulWidget {
  const TranscriptionDetailPage({
    super.key,
    required this.transcription,
  });

  final Transcription transcription;

  @override
  State<TranscriptionDetailPage> createState() =>
      _TranscriptionDetailPageState();
}

class _TranscriptionDetailPageState extends State<TranscriptionDetailPage> {
  late final StudyModeBloc _studyModeBloc;
  bool _isGenerating = false;
  MaterialBanner? _warningBanner;
  bool _hasCheckedInitialState = false;

  @override
  void initState() {
    super.initState();
    _studyModeBloc = getIt<StudyModeBloc>();
    // Check if generation already completed or is in progress while user was away
    _checkBlocState();
  }

  void _checkBlocState() {
    if (!mounted) return;

    final currentState = _studyModeBloc.state;
    if (currentState is StudyModeFlashcardsLoaded) {
      // Generation completed while user was away - reset generating flag
      setState(() {
        _isGenerating = false;
      });
    } else if (currentState is StudyModeError) {
      // Generation failed while user was away - reset generating flag
      setState(() {
        _isGenerating = false;
      });
    } else if (currentState is StudyModeLoading) {
      // Generation is still in progress - restore generating state
      // Note: We don't show the warning banner here because we only show it
      // when the user actively starts generation from this page
      setState(() {
        _isGenerating = true;
      });
    }
  }

  void _showWarningBanner(BuildContext context) {
    if (!mounted) return;

    _warningBanner = MaterialBanner(
      content: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Do not close the app while flashcards are generating',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.orange.shade50,
      leadingPadding: const EdgeInsets.only(left: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: const [], // No dismiss button - persistent warning
    );

    ScaffoldMessenger.of(context).showMaterialBanner(_warningBanner!);
  }

  void _hideWarningBanner(BuildContext context) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
    _warningBanner = null;
  }

  @override
  void dispose() {
    // Note: We don't explicitly dismiss the banner here because context is not
    // available in dispose(). The ScaffoldMessenger will automatically clean up
    // the banner when the widget tree is torn down.
    // Don't close the bloc - it's a singleton shared across the app
    // Closing it would stop flashcard generation that might be in progress
    super.dispose();
  }

  void _generateFlashcards(BuildContext context) {
    if (!mounted) return;

    setState(() {
      _isGenerating = true;
    });

    _showWarningBanner(context);

    _studyModeBloc.add(GenerateFlashcardsEvent(
      sourceId: widget.transcription.id,
      sourceType: 'transcription',
      numFlashcards: 10,
    ));
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.transcription.text ?? ''));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Transcription copied to clipboard'),
        backgroundColor: Theme.of(context).colorScheme.secondary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    // Check if we need to show warning banner for ongoing generation (once per page load)
    if (!_hasCheckedInitialState && _isGenerating) {
      _hasCheckedInitialState = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isGenerating) {
          _showWarningBanner(context);
        }
      });
    }

    return BlocProvider.value(
      value: _studyModeBloc,
      child: BlocListener<StudyModeBloc, StudyModeState>(
        listener: (context, state) {
          // Early return if widget is disposed to prevent crashes
          if (!mounted) return;

          if (state is StudyModeFlashcardsLoaded) {
            _hideWarningBanner(context);
            setState(() {
              _isGenerating = false;
            });
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
            _hideWarningBanner(context);
            setState(() {
              _isGenerating = false;
            });
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
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Transcription Details'),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header Card
                        _buildHeaderCard(context),
                        const SizedBox(height: 20),

                        // Full Text Section
                        _buildFullTextCard(context),
                        const SizedBox(height: 20),

                        // Actions Section
                        _buildActionsSection(context),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
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
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat.yMMMd()
                            .add_jm()
                            .format(widget.transcription.timestamp),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondary
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${(widget.transcription.confidence * 100).toStringAsFixed(0)}% Accuracy',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                          if (widget.transcription.duration.inSeconds > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .tertiary
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _formatDuration(widget.transcription.duration),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .tertiary,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullTextCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.notes,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Transcription',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            SelectableText(
              widget.transcription.text ?? 'No transcription text available',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsSection(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.content_copy, size: 18),
            label: const Text('Copy'),
            onPressed: () => _copyToClipboard(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            icon: _isGenerating
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.onTertiary,
                    ),
                  )
                : const Icon(Icons.style_outlined, size: 18),
            label: Text(_isGenerating ? 'Generating...' : 'Create Flashcards'),
            onPressed:
                _isGenerating ? null : () => _generateFlashcards(context),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              backgroundColor: Theme.of(context).colorScheme.tertiary,
            ),
          ),
        ),
      ],
    );
  }
}
