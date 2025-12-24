import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/quiz.dart';
import '../bloc/quiz_bloc.dart';
import '../bloc/quiz_event.dart';
import '../bloc/quiz_state.dart';
import 'quiz_results_page.dart';

// --- Color Palette matching app theme ---
const Color _kBackgroundColor = Color(0xFF1E1E1E);
const Color _kCardColor = Color(0xFF333333);
const Color _kAccentBlue = Color(0xFF00BFFF);
const Color _kAccentCoral = Color(0xFFFF7043);
const Color _kAccentGreen = Color(0xFF4CAF50);
const Color _kWhite = Colors.white;
const Color _kLightGray = Color(0xFFCCCCCC);
const Color _kDarkGray = Color(0xFF888888);

class QuizTakingPage extends StatefulWidget {
  const QuizTakingPage({
    super.key,
    required this.quiz,
  });

  final Quiz quiz;

  @override
  State<QuizTakingPage> createState() => _QuizTakingPageState();
}

class _QuizTakingPageState extends State<QuizTakingPage> {
  int _currentQuestionIndex = 0;
  Map<String, int> _answers = {};
  final Set<String> _flaggedQuestions = {};
  late DateTime _startTime;
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _startTimer();
    // Load the quiz to reset answers in bloc
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<QuizBloc>().add(LoadQuizEvent(widget.quiz.id));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(_startTime);
        });
      }
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      final hours = duration.inHours.toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  void _answerQuestion(String questionId, int selectedAnswer) {
    setState(() {
      _answers[questionId] = selectedAnswer;
    });
    context.read<QuizBloc>().add(AnswerQuestionEvent(
      questionId: questionId,
      selectedAnswer: selectedAnswer,
    ));
  }

  void _goToQuestion(int index) {
    if (index >= 0 && index < widget.quiz.questions.length) {
      setState(() {
        _currentQuestionIndex = index;
      });
    }
  }

  void _toggleFlag(String questionId) {
    setState(() {
      if (_flaggedQuestions.contains(questionId)) {
        _flaggedQuestions.remove(questionId);
      } else {
        _flaggedQuestions.add(questionId);
      }
    });
  }

  void _submitQuiz() {
    _timer?.cancel();
    context.read<QuizBloc>().add(const SubmitQuizEvent());
  }

  bool _allQuestionsAnswered() {
    return widget.quiz.questions.every((q) => _answers.containsKey(q.id));
  }

  Future<bool> _onWillPop() async {
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _kCardColor,
        title: const Text(
          'Exit Quiz?',
          style: TextStyle(color: _kWhite),
        ),
        content: const Text(
          'Your progress will be lost. Are you sure you want to exit?',
          style: TextStyle(color: _kLightGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: _kLightGray)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAccentCoral,
              foregroundColor: _kWhite,
            ),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    return shouldPop ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: _kBackgroundColor,
        appBar: AppBar(
          backgroundColor: _kCardColor,
          elevation: 0,
          iconTheme: const IconThemeData(color: _kWhite),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.quiz.title,
                style: const TextStyle(
                  color: _kWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 14, color: _kLightGray),
                  const SizedBox(width: 4),
                  Text(
                    _formatDuration(_elapsed),
                    style: const TextStyle(
                      color: _kLightGray,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            BlocBuilder<QuizBloc, QuizState>(
              builder: (context, state) {
                if (state is QuizLoaded || state is QuizTaking) {
                  final answers = state is QuizLoaded
                      ? state.answers
                      : (state as QuizTaking).answers;
                  // Sync local answers with bloc answers
                  if (answers.isNotEmpty) {
                    _answers = Map.from(answers);
                  }

                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ElevatedButton(
                      onPressed: _allQuestionsAnswered() ? _submitQuiz : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _allQuestionsAnswered()
                            ? _kAccentGreen
                            : _kDarkGray,
                        foregroundColor: _kWhite,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Submit'),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        body: BlocConsumer<QuizBloc, QuizState>(
          listener: (context, state) {
            if (state is QuizSubmitted) {
              _timer?.cancel();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: context.read<QuizBloc>(),
                    child: QuizResultsPage(
                      quiz: state.quiz,
                      result: state.result,
                      duration: _elapsed,
                    ),
                  ),
                ),
              );
            } else if (state is QuizError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: _kAccentCoral,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is QuizLoaded || state is QuizTaking) {
              return _buildQuizContent();
            } else if (state is QuizError) {
              return _buildErrorView(state.message);
            }
            return const Center(
              child: CircularProgressIndicator(color: _kAccentBlue),
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorView(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: _kAccentCoral),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: _kWhite),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAccentBlue,
              foregroundColor: _kWhite,
            ),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizContent() {
    final quiz = widget.quiz;
    final question = quiz.questions[_currentQuestionIndex];
    final selectedAnswer = _answers[question.id];
    final isFlagged = _flaggedQuestions.contains(question.id);

    return Column(
      children: [
        // Progress bar
        _buildProgressSection(),
        
        // Question content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Question card
                Container(
                  decoration: BoxDecoration(
                    color: _kCardColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Question ${_currentQuestionIndex + 1} of ${quiz.questions.length}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: _kLightGray,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              isFlagged ? Icons.flag : Icons.flag_outlined,
                              color: isFlagged ? _kAccentCoral : _kDarkGray,
                            ),
                            onPressed: () => _toggleFlag(question.id),
                            tooltip: 'Flag for review',
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        question.question,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _kWhite,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ...question.options.asMap().entries.map((entry) {
                        final index = entry.key;
                        final option = entry.value;
                        final isSelected = selectedAnswer == index;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GestureDetector(
                            onTap: () => _answerQuestion(question.id, index),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? _kAccentBlue.withOpacity(0.2)
                                    : _kBackgroundColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? _kAccentBlue : _kDarkGray,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? _kAccentBlue
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: isSelected
                                            ? _kAccentBlue
                                            : _kDarkGray,
                                        width: 2,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Icon(
                                            Icons.check,
                                            size: 16,
                                            color: _kWhite,
                                          )
                                        : Center(
                                            child: Text(
                                              String.fromCharCode(65 + index),
                                              style: const TextStyle(
                                                color: _kDarkGray,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      option,
                                      style: TextStyle(
                                        color: isSelected
                                            ? _kWhite
                                            : _kLightGray,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Navigation buttons
        _buildNavigationBar(),
      ],
    );
  }

  Widget _buildProgressSection() {
    final quiz = widget.quiz;
    final answeredCount = _answers.length;
    final progress = answeredCount / quiz.questions.length;

    return Container(
      color: _kCardColor,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Question indicators
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(quiz.questions.length, (index) {
                final question = quiz.questions[index];
                final isAnswered = _answers.containsKey(question.id);
                final isCurrent = index == _currentQuestionIndex;
                final isFlagged = _flaggedQuestions.contains(question.id);

                return GestureDetector(
                  onTap: () => _goToQuestion(index),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCurrent
                          ? _kAccentBlue
                          : isAnswered
                              ? _kAccentGreen
                              : _kBackgroundColor,
                      border: Border.all(
                        color: isFlagged
                            ? _kAccentCoral
                            : isCurrent
                                ? _kAccentBlue
                                : isAnswered
                                    ? _kAccentGreen
                                    : _kDarkGray,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: isCurrent || isAnswered
                              ? _kWhite
                              : _kLightGray,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
          // Progress bar
          Row(
            children: [
              Text(
                '$answeredCount/${quiz.questions.length} answered',
                style: const TextStyle(
                  color: _kLightGray,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  color: _kAccentBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: _kBackgroundColor,
            valueColor: const AlwaysStoppedAnimation<Color>(_kAccentBlue),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationBar() {
    final isFirst = _currentQuestionIndex == 0;
    final isLast = _currentQuestionIndex == widget.quiz.questions.length - 1;

    return Container(
      color: _kCardColor,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isFirst ? null : () => _goToQuestion(_currentQuestionIndex - 1),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Previous'),
              style: OutlinedButton.styleFrom(
                foregroundColor: isFirst ? _kDarkGray : _kAccentBlue,
                side: BorderSide(
                  color: isFirst ? _kDarkGray : _kAccentBlue,
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: isLast
                  ? (_allQuestionsAnswered() ? _submitQuiz : null)
                  : () => _goToQuestion(_currentQuestionIndex + 1),
              icon: Icon(isLast ? Icons.check : Icons.arrow_forward),
              label: Text(isLast ? 'Submit' : 'Next'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isLast
                    ? (_allQuestionsAnswered() ? _kAccentGreen : _kDarkGray)
                    : _kAccentBlue,
                foregroundColor: _kWhite,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
