import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../injection_container.dart';
import '../../../summarization/domain/repositories/summary_repository.dart';
import '../../../transcription/domain/repositories/transcription_repository.dart';
import '../../domain/entities/quiz.dart';
import '../../domain/repositories/quiz_repository.dart';
import '../bloc/quiz_bloc.dart';
import '../bloc/quiz_event.dart';
import '../bloc/quiz_state.dart';
import 'quiz_taking_page.dart';

// --- Local Color Palette for Quiz Creation Page ---
const Color _kBackgroundColor = Color(0xFF1E1E1E);
const Color _kCardColor = Color(0xFF333333);
const Color _kAccentBlue = Color(0xFF00BFFF);
const Color _kAccentCoral = Color(0xFFFF7043);
const Color _kWhite = Colors.white;
const Color _kLightGray = Color(0xFFCCCCCC);
const Color _kDarkGray = Color(0xFF888888);

class QuizCreationPage extends StatefulWidget {
  const QuizCreationPage({super.key});

  @override
  State<QuizCreationPage> createState() => _QuizCreationPageState();
}

class _QuizCreationPageState extends State<QuizCreationPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedSourceType = 'transcription';
  String? _selectedSourceId;
  String? _selectedSourcePreview;
  int _numQuestions = 5;
  String _difficulty = 'medium';
  List<Map<String, String>> _transcriptions = [];
  List<Map<String, String>> _summaries = [];
  List<Quiz> _previousQuizzes = [];
  bool _loadingSources = true;
  bool _loadingQuizzes = true;
  String? _deletingQuizId; // Track quiz being deleted

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSources();
    _loadPreviousQuizzes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSources() async {
    setState(() => _loadingSources = true);

    try {
      // Load summaries
      final summaryRepo = getIt<SummaryRepository>();
      final summariesResult = await summaryRepo.getAllSummaries();
      summariesResult.fold(
        (_) => {},
        (summaries) {
          setState(() {
            _summaries = summaries
                .map((s) => {
                      'id': s.id,
                      'title': s.title ??
                          (s.summaryText.length > 50
                              ? '${s.summaryText.substring(0, 50)}...'
                              : s.summaryText),
                      'date': DateFormat('MMM d, y').format(s.createdAt),
                      'preview': s.summaryText.length > 200
                          ? '${s.summaryText.substring(0, 200)}...'
                          : s.summaryText,
                    })
                .toList();
          });
        },
      );

      // Load transcriptions
      final transcriptionRepo = getIt<TranscriptionRepository>();
      final transcriptionsResult =
          await transcriptionRepo.getAllTranscriptions();
      transcriptionsResult.fold(
        (_) => {},
        (transcriptions) {
          setState(() {
            _transcriptions = transcriptions
                .map((t) => {
                      'id': t.id,
                      'title': t.title ??
                          (t.text != null && t.text!.length > 50
                              ? '${t.text!.substring(0, 50)}...'
                              : t.text) ??
                          'Untitled Note',
                      'date': DateFormat('MMM d, y').format(t.timestamp),
                      'preview': t.text != null
                          ? (t.text!.length > 200
                              ? '${t.text!.substring(0, 200)}...'
                              : t.text!)
                          : 'No content available',
                    })
                .toList();
          });
        },
      );
    } catch (e) {
      // Handle error
    } finally {
      setState(() => _loadingSources = false);
    }
  }

  Future<void> _loadPreviousQuizzes() async {
    setState(() => _loadingQuizzes = true);
    try {
      final quizRepo = getIt<QuizRepository>();
      final result = await quizRepo.getAllQuizzes();
      result.fold(
        (failure) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Failed to load quiz history. Pull down to refresh.',
                ),
                backgroundColor: _kAccentCoral,
                behavior: SnackBarBehavior.floating,
                action: SnackBarAction(
                  label: 'Retry',
                  textColor: _kWhite,
                  onPressed: _loadPreviousQuizzes,
                ),
              ),
            );
          }
        },
        (quizzes) {
          setState(() {
            _previousQuizzes = quizzes;
          });
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'An unexpected error occurred while loading quiz history.',
            ),
            backgroundColor: _kAccentCoral,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Retry',
              textColor: _kWhite,
              onPressed: _loadPreviousQuizzes,
            ),
          ),
        );
      }
    } finally {
      setState(() => _loadingQuizzes = false);
    }
  }

  void _generateQuiz() {
    if (_selectedSourceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a source'),
          backgroundColor: _kAccentCoral,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    context.read<QuizBloc>().add(
          GenerateQuizEvent(
            sourceId: _selectedSourceId!,
            sourceType: _selectedSourceType,
            numQuestions: _numQuestions,
            difficulty: _difficulty,
          ),
        );
  }

  String _getErrorMessage(String rawMessage) {
    // Map backend errors to user-friendly messages
    if (rawMessage.contains('content is empty') ||
        rawMessage.contains('too short')) {
      return 'The selected content is too short to generate meaningful questions. Please select a longer note or summary.';
    }
    if (rawMessage.contains('not found')) {
      return 'The selected content could not be found. It may have been deleted.';
    }
    if (rawMessage.contains('network') ||
        rawMessage.toLowerCase().contains('connection')) {
      return 'Unable to connect to the server. Please check your internet connection and try again.';
    }
    if (rawMessage.contains('queued')) {
      return rawMessage; // Keep queued messages as-is
    }
    return 'Failed to generate quiz. Please try again later.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackgroundColor,
      appBar: AppBar(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: const Text(
          'Practice Mode',
          style: TextStyle(
            color: _kWhite,
            fontWeight: FontWeight.bold,
            fontSize: 25,
          ),
        ),
        backgroundColor: _kCardColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: _kWhite),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _kAccentBlue,
          labelColor: _kAccentBlue,
          unselectedLabelColor: _kLightGray,
          tabs: const [
            Tab(text: 'New Quiz', icon: Icon(Icons.add_circle_outline)),
            Tab(text: 'History', icon: Icon(Icons.history)),
          ],
        ),
      ),
      body: SafeArea(
        child: BlocConsumer<QuizBloc, QuizState>(
          listener: (context, state) {
            // Handle quiz deletion success
            if (state is QuizInitial && _deletingQuizId != null) {
              final deletedId = _deletingQuizId;
              setState(() {
                _previousQuizzes.removeWhere((q) => q.id == deletedId);
                _deletingQuizId = null;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Quiz deleted successfully'),
                  backgroundColor: _kAccentBlue,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            // Handle errors (including deletion failures)
            else if (state is QuizError) {
              // Check if this was a deletion error
              final isDeletionError = _deletingQuizId != null;

              if (isDeletionError) {
                setState(() => _deletingQuizId = null);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      state.message.contains('delete')
                          ? state.message
                          : 'Failed to delete quiz. Please try again.',
                    ),
                    backgroundColor: _kAccentCoral,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 4),
                  ),
                );
              } else {
                // Quiz generation error
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_getErrorMessage(state.message)),
                    backgroundColor: _kAccentCoral,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 4),
                    action: SnackBarAction(
                      label: 'Retry',
                      textColor: _kWhite,
                      onPressed: _generateQuiz,
                    ),
                  ),
                );
              }
            } else if (state is QuizQueued) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Quiz Queued'),
                      const SizedBox(height: 4),
                      Text(
                        'Your quiz will be generated when you\'re back online.',
                        style: TextStyle(
                          fontSize: 12,
                          color: _kWhite.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: _kAccentBlue,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 5),
                ),
              );
            } else if (state is QuizLoaded) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: context.read<QuizBloc>(),
                    child: QuizTakingPage(quiz: state.quiz),
                  ),
                ),
              );
            }
          },
          builder: (context, state) {
            return TabBarView(
              controller: _tabController,
              children: [
                _buildNewQuizTab(state),
                _buildHistoryTab(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildNewQuizTab(QuizState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSourceTypeSelector(),
          const SizedBox(height: 16),
          _buildSourceSelector(),
          if (_selectedSourcePreview != null) ...[
            const SizedBox(height: 16),
            _buildContentPreview(),
          ],
          const SizedBox(height: 16),
          _buildNumQuestionsSelector(),
          const SizedBox(height: 16),
          _buildDifficultySelector(),
          const SizedBox(height: 24),
          _buildGenerateButton(state),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_loadingQuizzes) {
      return const Center(
        child: CircularProgressIndicator(color: _kAccentBlue),
      );
    }

    if (_previousQuizzes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.quiz_outlined,
              size: 64,
              color: _kDarkGray,
            ),
            const SizedBox(height: 16),
            const Text(
              'No quizzes yet',
              style: TextStyle(
                color: _kWhite,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Generate your first quiz from the "New Quiz" tab',
              style: TextStyle(
                color: _kLightGray,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPreviousQuizzes,
      color: _kAccentBlue,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _previousQuizzes.length,
        itemBuilder: (context, index) {
          final quiz = _previousQuizzes[index];
          return _buildQuizHistoryCard(quiz);
        },
      ),
    );
  }

  Widget _buildQuizHistoryCard(Quiz quiz) {
    final isDeleting = _deletingQuizId == quiz.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _kCardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isDeleting
              ? null
              : () {
                  // Load and take the quiz
                  context.read<QuizBloc>().add(LoadQuizEvent(quiz.id));
                },
          child: Opacity(
            opacity: isDeleting ? 0.5 : 1.0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _kAccentBlue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: isDeleting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _kAccentBlue,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.quiz,
                            color: _kAccentBlue,
                            size: 24,
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quiz.title,
                          style: const TextStyle(
                            color: _kWhite,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              quiz.sourceType == 'transcription'
                                  ? Icons.mic
                                  : Icons.summarize,
                              size: 14,
                              color: _kDarkGray,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${quiz.questions.length} questions',
                              style: const TextStyle(
                                color: _kDarkGray,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              DateFormat('MMM d, y').format(quiz.createdAt),
                              style: const TextStyle(
                                color: _kDarkGray,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isDeleting)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Deleting...',
                        style: TextStyle(
                          color: _kAccentCoral,
                          fontSize: 12,
                        ),
                      ),
                    )
                  else ...[
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: _kAccentCoral,
                        size: 20,
                      ),
                      onPressed: () => _showDeleteConfirmation(quiz),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: _kDarkGray,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(Quiz quiz) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _kCardColor,
        title: const Text(
          'Delete Quiz?',
          style: TextStyle(color: _kWhite),
        ),
        content: Text(
          'Are you sure you want to delete "${quiz.title}"? This action cannot be undone.',
          style: const TextStyle(color: _kLightGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: _kLightGray)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              setState(() => _deletingQuizId = quiz.id);
              context.read<QuizBloc>().add(DeleteQuizEvent(quiz.id));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAccentCoral,
              foregroundColor: _kWhite,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildContentPreview() {
    return Container(
      decoration: BoxDecoration(
        color: _kCardColor,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: _kAccentBlue.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.preview, color: _kAccentBlue, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Content Preview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _kWhite,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _selectedSourcePreview ?? 'No preview available',
            style: const TextStyle(
              color: _kLightGray,
              fontSize: 14,
              height: 1.5,
            ),
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSourceTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: _kCardColor,
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Source Type',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _kWhite,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'transcription',
                  label: Text('Notes'),
                  icon: Icon(Icons.mic),
                ),
                ButtonSegment(
                  value: 'summary',
                  label: Text('Summaries'),
                  icon: Icon(Icons.summarize),
                ),
              ],
              selected: {_selectedSourceType},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _selectedSourceType = newSelection.first;
                  _selectedSourceId = null;
                  _selectedSourcePreview = null;
                });
              },
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: _kAccentBlue,
                selectedForegroundColor: _kWhite,
                backgroundColor: _kCardColor,
                foregroundColor: _kLightGray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceSelector() {
    final sources =
        _selectedSourceType == 'transcription' ? _transcriptions : _summaries;

    return Container(
      decoration: BoxDecoration(
        color: _kCardColor,
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select ${_selectedSourceType == 'transcription' ? 'Note' : 'Summary'}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _kWhite,
              ),
            ),
            const SizedBox(height: 12),
            if (_loadingSources)
              const Center(
                child: CircularProgressIndicator(
                  color: _kAccentBlue,
                ),
              )
            else if (sources.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _kCardColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kCardColor, width: 1.0),
                ),
                child: Text(
                  _selectedSourceType == 'transcription'
                      ? 'No notes available. Create a note first from the Note Taking page.'
                      : 'No summaries available. Create a summary first from the Summarization page.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _kLightGray,
                    fontSize: 14,
                  ),
                ),
              )
            else
              ...sources.map(
                (source) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: _selectedSourceId == source['id']
                        ? _kAccentBlue.withOpacity(0.2)
                        : _kCardColor.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedSourceId == source['id']
                          ? _kAccentBlue
                          : _kCardColor,
                      width: 1.5,
                    ),
                  ),
                  child: RadioListTile<String>(
                    title: Text(
                      source['title'] ?? '',
                      style: const TextStyle(color: _kWhite),
                    ),
                    subtitle: Text(
                      source['date'] ?? '',
                      style: const TextStyle(color: _kLightGray),
                    ),
                    value: source['id'] ?? '',
                    groupValue: _selectedSourceId,
                    onChanged: (value) {
                      setState(() {
                        _selectedSourceId = value;
                        _selectedSourcePreview = source['preview'];
                      });
                    },
                    activeColor: _kAccentBlue,
                    fillColor: WidgetStateProperty.resolveWith<Color>(
                      (Set<WidgetState> states) {
                        if (states.contains(WidgetState.selected)) {
                          return _kAccentBlue;
                        }
                        return _kLightGray;
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumQuestionsSelector() {
    return Container(
      decoration: BoxDecoration(
        color: _kCardColor,
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Number of Questions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _kWhite,
              ),
            ),
            const SizedBox(height: 12),
            Slider(
              value: _numQuestions.toDouble(),
              min: 3,
              max: 30,
              divisions: 27,
              label: '$_numQuestions questions',
              onChanged: (value) {
                setState(() => _numQuestions = value.toInt());
              },
              activeColor: _kAccentBlue,
              inactiveColor: _kDarkGray,
              thumbColor: _kAccentBlue,
            ),
            Center(
              child: Text(
                '$_numQuestions questions',
                style: const TextStyle(
                  color: _kAccentBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultySelector() {
    return Container(
      decoration: BoxDecoration(
        color: _kCardColor,
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Difficulty',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _kWhite,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'easy', label: Text('Easy')),
                ButtonSegment(value: 'medium', label: Text('Medium')),
                ButtonSegment(value: 'hard', label: Text('Hard')),
              ],
              selected: {_difficulty},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() => _difficulty = newSelection.first);
              },
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: _kAccentCoral,
                selectedForegroundColor: _kWhite,
                backgroundColor: _kCardColor,
                foregroundColor: _kLightGray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateButton(QuizState state) {
    final isGenerating = state is QuizGenerating;
    final canGenerate = _selectedSourceId != null && !isGenerating;

    return ElevatedButton(
      onPressed: canGenerate ? _generateQuiz : null,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: canGenerate ? _kAccentBlue : _kDarkGray,
        foregroundColor: _kWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: canGenerate ? 4 : 0,
      ),
      child: isGenerating
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _kWhite,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Generating Quiz...',
                  style: TextStyle(
                    color: _kWhite,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            )
          : const Text(
              'Generate Quiz',
              style: TextStyle(
                color: _kWhite,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
    );
  }
}
