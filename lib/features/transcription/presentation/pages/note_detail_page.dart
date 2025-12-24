import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../../injection_container.dart';
import '../../../quiz/presentation/bloc/quiz_bloc.dart';
import '../../../quiz/presentation/bloc/quiz_event.dart';
import '../../../quiz/presentation/bloc/quiz_state.dart';
import '../../../quiz/presentation/pages/quiz_taking_page.dart';
import '../../../study_mode/presentation/bloc/study_mode_bloc.dart';
import '../../../study_mode/presentation/bloc/study_mode_event.dart';
import '../../../study_mode/presentation/bloc/study_mode_state.dart';
import '../../domain/entities/transcription.dart';
import '../bloc/transcription_bloc.dart';
import '../bloc/transcription_event.dart';
import '../bloc/transcription_state.dart';

// --- Color Palette (matching transcription_page.dart) ---
const Color _kBackgroundColor = Color(0xFF1E1E1E);
const Color _kCardColor = Color(0xFF333333);
const Color _kAccentBlue = Color(0xFF00BFFF);
const Color _kWhite = Colors.white;
const Color _kLightGray = Color(0xFFCCCCCC);
const Color _kDarkGray = Color(0xFF888888);

class NoteDetailPage extends StatefulWidget {
  const NoteDetailPage({
    super.key,
    required this.transcription,
  });

  final Transcription transcription;

  @override
  State<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends State<NoteDetailPage> {
  late final StudyModeBloc _studyModeBloc;
  late final TranscriptionBloc _transcriptionBloc;
  late final QuizBloc _quizBloc;
  bool _isGeneratingFlashcards = false;
  bool _isGeneratingQuiz = false;
  Transcription? _currentTranscription;

  @override
  void initState() {
    super.initState();
    _studyModeBloc = getIt<StudyModeBloc>();
    _transcriptionBloc = getIt<TranscriptionBloc>();
    _quizBloc = getIt<QuizBloc>();
    _currentTranscription = widget.transcription;
  }

  @override
  void dispose() {
    _quizBloc.close();
    super.dispose();
  }

  void _generateFlashcards(BuildContext context) {
    final transcription = _currentTranscription ?? widget.transcription;
    setState(() {
      _isGeneratingFlashcards = true;
    });

    _studyModeBloc.add(GenerateFlashcardsEvent(
      sourceId: transcription.id,
      sourceType: 'note',
      numFlashcards: 10,
    ));
  }

  void _generateQuiz(BuildContext context) {
    final transcription = _currentTranscription ?? widget.transcription;
    setState(() {
      _isGeneratingQuiz = true;
    });

    _quizBloc.add(GenerateQuizEvent(
      sourceId: transcription.id,
      sourceType: 'transcription',
      numQuestions: 5,
      difficulty: 'medium',
    ));
  }

  String _formatStructuredNoteForCopy() {
    final transcription = _currentTranscription ?? widget.transcription;
    if (transcription.structuredNote == null) {
      return transcription.text ?? '';
    }

    final note = transcription.structuredNote!;
    final buffer = StringBuffer();

    // Title
    final title = transcription.title ?? note['title'] as String? ?? 'Note';
    buffer.writeln(title);
    buffer.writeln('=' * title.length);
    buffer.writeln();

    // Summary
    final summary = note['summary'] as String?;
    if (summary != null && summary.isNotEmpty) {
      buffer.writeln('Summary:');
      buffer.writeln(summary);
      buffer.writeln();
    }

    // Key Points
    final keyPoints = note['key_points'] as List? ?? note['keyPoints'] as List?;
    if (keyPoints != null && keyPoints.isNotEmpty) {
      buffer.writeln('Key Points:');
      for (final point in keyPoints) {
        buffer.writeln('• ${point.toString()}');
      }
      buffer.writeln();
    }

    // Action Items
    final actionItems =
        note['action_items'] as List? ?? note['actionItems'] as List?;
    if (actionItems != null && actionItems.isNotEmpty) {
      buffer.writeln('Action Items:');
      for (final item in actionItems) {
        buffer.writeln('• ${item.toString()}');
      }
      buffer.writeln();
    }

    // Study Questions
    final studyQuestions = note['study_questions'] as List? ??
        note['studyQuestions'] as List?;
    if (studyQuestions != null && studyQuestions.isNotEmpty) {
      buffer.writeln('Study Questions:');
      for (int i = 0; i < studyQuestions.length; i++) {
        buffer.writeln('${i + 1}. ${studyQuestions[i].toString()}');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  void _copyToClipboard(BuildContext context) {
    final textToCopy = _formatStructuredNoteForCopy();
    Clipboard.setData(ClipboardData(text: textToCopy));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Note copied to clipboard'),
        backgroundColor: _kAccentBlue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _formatNote(BuildContext context) {
    final transcription = _currentTranscription ?? widget.transcription;
    _transcriptionBloc.add(FormatTranscriptionNote(transcription.id));
  }

  @override
  Widget build(BuildContext context) {
    final transcription = _currentTranscription ?? widget.transcription;
    final noteTitle = transcription.title ??
        (transcription.text != null && transcription.text!.length > 50
            ? '${transcription.text!.substring(0, 50)}...'
            : transcription.text) ?? 'Untitled Note';
    final structuredNote = transcription.structuredNote;

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _studyModeBloc),
        BlocProvider.value(value: _transcriptionBloc),
        BlocProvider.value(value: _quizBloc),
      ],
      child: BlocListener<TranscriptionBloc, TranscriptionState>(
        listener: (context, state) {
          if (state is TranscriptionSuccess) {
            // Check if this is the formatted transcription
            if (state.transcription.id == _currentTranscription?.id &&
                state.transcription.structuredNote != null) {
              if (mounted) {
                setState(() {
                  _currentTranscription = state.transcription;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text('Note formatted successfully!'),
                        ),
                      ],
                    ),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          } else if (state is TranscriptionError) {
            // Only show error snackbar if mounted
            if (mounted) {
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
          }
        },
        child: BlocBuilder<TranscriptionBloc, TranscriptionState>(
          builder: (context, transcriptionState) {
            // Read formatting state from bloc
            final isFormatting = transcriptionState.formattingTranscriptionId ==
                (_currentTranscription?.id ?? widget.transcription.id);
            
            return MultiBlocListener(
        listeners: [
          BlocListener<StudyModeBloc, StudyModeState>(
            listener: (context, state) {
              if (state is StudyModeFlashcardsLoaded) {
                setState(() {
                  _isGeneratingFlashcards = false;
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
                setState(() {
                  _isGeneratingFlashcards = false;
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
          ),
          BlocListener<QuizBloc, QuizState>(
            listener: (context, state) {
              if (state is QuizLoaded) {
                setState(() {
                  _isGeneratingQuiz = false;
                });
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BlocProvider.value(
                      value: _quizBloc,
                      child: QuizTakingPage(quiz: state.quiz),
                    ),
                  ),
                );
              } else if (state is QuizError) {
                setState(() {
                  _isGeneratingQuiz = false;
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
              } else if (state is QuizQueued) {
                setState(() {
                  _isGeneratingQuiz = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: _kAccentBlue,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
        child: Scaffold(
          backgroundColor: _kBackgroundColor,
          appBar: AppBar(
            backgroundColor: _kCardColor,
            title: Text(
              noteTitle,
              style: const TextStyle(color: _kWhite),
            ),
            iconTheme: const IconThemeData(color: _kWhite),
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (structuredNote == null)
                            _buildFallbackContent()
                          else
                            _buildStructuredContent(structuredNote),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
                // Actions Section at bottom
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _kCardColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: _buildActionsSection(context, isFormatting),
                ),
              ],
            ),
          ),
        ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFallbackContent() {
    final transcription = _currentTranscription ?? widget.transcription;
    return SelectableText(
      transcription.text ?? 'No transcription text available',
      style: const TextStyle(
        color: _kLightGray,
        fontSize: 16,
        height: 1.6,
      ),
    );
  }

  Widget _buildStructuredContent(Map<String, dynamic> note) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary Section with Markdown support
        if (note['summary'] != null && (note['summary'] as String?)?.isNotEmpty == true)
          _buildSection(
            title: 'Summary',
            icon: Icons.summarize_outlined,
            child: MarkdownBody(
              data: note['summary'] as String,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(
                  color: _kLightGray,
                  fontSize: 16,
                  height: 1.6,
                ),
                h1: const TextStyle(
                  color: _kWhite,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
                h2: const TextStyle(
                  color: _kWhite,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
                h3: const TextStyle(
                  color: _kWhite,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  height: 1.4,
                ),
                h4: const TextStyle(
                  color: _kWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
                strong: const TextStyle(
                  color: _kWhite,
                  fontWeight: FontWeight.bold,
                ),
                em: const TextStyle(
                  color: _kLightGray,
                  fontStyle: FontStyle.italic,
                ),
                code: TextStyle(
                  backgroundColor: Colors.black.withOpacity(0.3),
                  color: _kAccentBlue,
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
                codeblockDecoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                listBullet: const TextStyle(
                  color: _kAccentBlue,
                  fontSize: 16,
                ),
                blockquote: TextStyle(
                  color: _kLightGray.withOpacity(0.8),
                  fontStyle: FontStyle.italic,
                ),
                blockquoteDecoration: BoxDecoration(
                  color: _kCardColor,
                  border: Border(
                    left: BorderSide(
                      color: _kAccentBlue,
                      width: 4,
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (note['summary'] != null && (note['summary'] as String?)?.isNotEmpty == true)
          const SizedBox(height: 20),

        // Key Points Section
        if (_hasList(note, 'key_points') || _hasList(note, 'keyPoints'))
          _buildSection(
            title: 'Key Points',
            icon: Icons.label_outline,
            child: _buildBulletList(
              note['key_points'] as List? ?? note['keyPoints'] as List? ?? [],
            ),
          ),
        if (_hasList(note, 'key_points') || _hasList(note, 'keyPoints'))
          const SizedBox(height: 20),

        // Action Items Section
        if (_hasList(note, 'action_items') || _hasList(note, 'actionItems'))
          _buildSection(
            title: 'Action Items',
            icon: Icons.check_circle_outline,
            child: _buildBulletList(
              note['action_items'] as List? ?? note['actionItems'] as List? ?? [],
            ),
          ),
        if (_hasList(note, 'action_items') || _hasList(note, 'actionItems'))
          const SizedBox(height: 20),

        // Study Questions Section
        if (_hasList(note, 'study_questions') || _hasList(note, 'studyQuestions'))
          _buildSection(
            title: 'Study Questions',
            icon: Icons.help_outline,
            child: _buildNumberedList(
              note['study_questions'] as List? ??
                  note['studyQuestions'] as List? ??
                  [],
            ),
          ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kCardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: _kAccentBlue,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: _kWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(
            height: 1,
            color: _kDarkGray,
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildBulletList(List items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.asMap().entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '• ',
                style: TextStyle(
                  color: _kAccentBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: SelectableText(
                  entry.value.toString(),
                  style: const TextStyle(
                    color: _kLightGray,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNumberedList(List items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.asMap().entries.map((entry) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${entry.key + 1}. ',
                style: const TextStyle(
                  color: _kAccentBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: SelectableText(
                  entry.value.toString(),
                  style: const TextStyle(
                    color: _kLightGray,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  bool _hasList(Map<String, dynamic> note, String key) {
    final list = note[key] as List?;
    return list != null && list.isNotEmpty;
  }

  Widget _buildActionsSection(BuildContext context, bool isFormatting) {
    final transcription = _currentTranscription ?? widget.transcription;
    final hasStructuredNote = transcription.structuredNote != null;
    
    // If no structured note, show Format button instead of Create Flashcards
    if (!hasStructuredNote) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.content_copy, size: 18),
                  label: const Text('Copy'),
                  onPressed: () => _copyToClipboard(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    foregroundColor: _kWhite,
                    side: const BorderSide(color: _kDarkGray),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  icon: isFormatting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _kWhite,
                          ),
                        )
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: Text(isFormatting ? 'Formatting...' : 'Format Note'),
                  onPressed: isFormatting ? null : () => _formatNote(context),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: _kAccentBlue,
                    foregroundColor: _kWhite,
                    disabledBackgroundColor: _kAccentBlue.withOpacity(0.5),
                    disabledForegroundColor: _kWhite.withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: _isGeneratingQuiz
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _kAccentBlue,
                      ),
                    )
                  : const Icon(Icons.quiz_outlined, size: 18),
              label: Text(_isGeneratingQuiz ? 'Generating Quiz...' : 'Generate Quiz'),
              onPressed: _isGeneratingQuiz ? null : () => _generateQuiz(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                foregroundColor: _kAccentBlue,
                side: const BorderSide(color: _kAccentBlue),
              ),
            ),
          ),
        ],
      );
    }

    // If structured note exists, show Copy, Create Flashcards, and Quiz buttons
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.content_copy, size: 18),
                label: const Text('Copy'),
                onPressed: () => _copyToClipboard(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  foregroundColor: _kWhite,
                  side: const BorderSide(color: _kDarkGray),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                icon: _isGeneratingFlashcards
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _kWhite,
                        ),
                      )
                    : const Icon(Icons.style_outlined, size: 18),
                label: Text(_isGeneratingFlashcards ? 'Generating...' : 'Flashcards'),
                onPressed: _isGeneratingFlashcards ? null : () => _generateFlashcards(context),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: _kAccentBlue,
                  foregroundColor: _kWhite,
                  disabledBackgroundColor: _kAccentBlue.withOpacity(0.5),
                  disabledForegroundColor: _kWhite.withOpacity(0.7),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: _isGeneratingQuiz
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _kAccentBlue,
                    ),
                  )
                : const Icon(Icons.quiz_outlined, size: 18),
            label: Text(_isGeneratingQuiz ? 'Generating Quiz...' : 'Generate Quiz'),
            onPressed: _isGeneratingQuiz ? null : () => _generateQuiz(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              foregroundColor: _kAccentBlue,
              side: const BorderSide(color: _kAccentBlue),
            ),
          ),
        ),
      ],
    );
  }
}
