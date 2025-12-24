import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../injection_container.dart';
import '../../../quiz/presentation/bloc/quiz_bloc.dart';
import '../../../quiz/presentation/bloc/quiz_event.dart';
import '../../../quiz/presentation/bloc/quiz_state.dart';
import '../../../quiz/presentation/pages/quiz_taking_page.dart';
import '../../../study_mode/presentation/bloc/study_mode_bloc.dart';
import '../../../study_mode/presentation/bloc/study_mode_event.dart';
import '../../../study_mode/presentation/bloc/study_mode_state.dart';
import '../../domain/entities/summary.dart';

// --- Local Color Palette for Summary Detail Page ---
const Color _kBackgroundColor = Color(0xFF1E1E1E);
const Color _kAccentBlue = Color(0xFF00BFFF); // Vibrant Electric Blue
const Color _kWhite = Colors.white;
const Color _kLightGray = Color(0xFFCCCCCC);

class SummaryDetailPage extends StatefulWidget {
  const SummaryDetailPage({
    super.key,
    required this.summary,
  });

  final Summary summary;

  @override
  State<SummaryDetailPage> createState() => _SummaryDetailPageState();
}

class _SummaryDetailPageState extends State<SummaryDetailPage> {
  late final StudyModeBloc _studyModeBloc;
  late final QuizBloc _quizBloc;
  bool _isGeneratingFlashcards = false;
  bool _isGeneratingQuiz = false;
  MaterialBanner? _warningBanner;
  bool _hasCheckedInitialState = false;

  @override
  void initState() {
    super.initState();
    _studyModeBloc = getIt<StudyModeBloc>();
    _quizBloc = getIt<QuizBloc>();
    // Check if generation already completed or is in progress while user was away
    _checkBlocState();
  }

  void _checkBlocState() {
    if (!mounted) return;

    final currentState = _studyModeBloc.state;
    if (currentState is StudyModeFlashcardsLoaded) {
      // Generation completed while user was away - reset generating flag
      setState(() {
        _isGeneratingFlashcards = false;
      });
    } else if (currentState is StudyModeError) {
      // Generation failed while user was away - reset generating flag
      setState(() {
        _isGeneratingFlashcards = false;
      });
    } else if (currentState is StudyModeLoading) {
      // Generation is still in progress - restore generating state
      setState(() {
        _isGeneratingFlashcards = true;
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
    // Don't close the StudyModeBloc - it's a singleton shared across the app
    // Closing it would stop flashcard generation that might be in progress
    _quizBloc.close();
    super.dispose();
  }

  void _generateFlashcards(BuildContext context) {
    if (!mounted) return;

    setState(() {
      _isGeneratingFlashcards = true;
    });

    _showWarningBanner(context);

    _studyModeBloc.add(GenerateFlashcardsEvent(
      sourceId: widget.summary.id,
      sourceType: 'summary',
      numFlashcards: 10,
    ));
  }

  void _generateQuiz(BuildContext context) {
    if (!mounted) return;

    setState(() {
      _isGeneratingQuiz = true;
    });

    _quizBloc.add(GenerateQuizEvent(
      sourceId: widget.summary.id,
      sourceType: 'summary',
      numQuestions: 5,
      difficulty: 'medium',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final displayTitle = widget.summary.title ?? 'Untitled Summary';

    // Check if we need to show warning banner for ongoing generation (once per page load)
    if (!_hasCheckedInitialState && _isGeneratingFlashcards) {
      _hasCheckedInitialState = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _isGeneratingFlashcards) {
          _showWarningBanner(context);
        }
      });
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _studyModeBloc),
        BlocProvider.value(value: _quizBloc),
      ],
      child: MultiBlocListener(
        listeners: [
          BlocListener<StudyModeBloc, StudyModeState>(
            listener: (context, state) {
              // Early return if widget is disposed to prevent crashes
              if (!mounted) return;

              if (state is StudyModeFlashcardsLoaded) {
                _hideWarningBanner(context);
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
                _hideWarningBanner(context);
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
              if (!mounted) return;

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
            backgroundColor: _kBackgroundColor,
            elevation: 0,
            title: Text(
              displayTitle,
              style: const TextStyle(
                color: _kWhite,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            iconTheme: const IconThemeData(color: _kWhite),
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Full Summary Section - takes full screen
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: SelectableText(
                      widget.summary.summaryText,
                      style: const TextStyle(
                        color: _kLightGray,
                        fontSize: 16,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
                // Actions Section - fixed at bottom
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: _buildActionsSection(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.summary.summaryText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Summary copied to clipboard'),
        backgroundColor: _kAccentBlue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildActionsSection(BuildContext context) {
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
                  foregroundColor: _kAccentBlue,
                  side: const BorderSide(color: _kAccentBlue),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
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
                onPressed:
                    _isGeneratingFlashcards ? null : () => _generateFlashcards(context),
                style: ElevatedButton.styleFrom(
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
