import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../injection_container.dart';
import '../../../summarization/domain/repositories/summary_repository.dart';
import '../../../transcription/domain/repositories/transcription_repository.dart';
import '../../domain/entities/quiz.dart';
import '../../domain/entities/quiz_result.dart';
import '../bloc/quiz_bloc.dart';
import '../bloc/quiz_event.dart';
import 'quiz_taking_page.dart';

// --- Color Palette matching app theme ---
const Color _kBackgroundColor = Color(0xFF1E1E1E);
const Color _kCardColor = Color(0xFF333333);
const Color _kAccentBlue = Color(0xFF00BFFF);
const Color _kAccentCoral = Color(0xFFFF7043);
const Color _kAccentGreen = Color(0xFF4CAF50);
const Color _kAccentYellow = Color(0xFFFFB74D);
const Color _kWhite = Colors.white;
const Color _kLightGray = Color(0xFFCCCCCC);
const Color _kDarkGray = Color(0xFF888888);

class QuizResultsPage extends StatelessWidget {
  const QuizResultsPage({
    super.key,
    required this.quiz,
    required this.result,
    this.duration,
  });

  final Quiz quiz;
  final QuizResult result;
  final Duration? duration;

  String _formatDuration(Duration? duration) {
    if (duration == null) return '--:--';
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      final hours = duration.inHours.toString().padLeft(2, '0');
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackgroundColor,
      appBar: AppBar(
        backgroundColor: _kCardColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: _kWhite),
        title: const Text(
          'Quiz Results',
          style: TextStyle(
            color: _kWhite,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            // Pop back to the quiz creation page
            Navigator.of(context).popUntil((route) => route.isFirst || route.settings.name == '/quiz');
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildScoreCard(),
            const SizedBox(height: 24),
            _buildStatsRow(),
            const SizedBox(height: 24),
            _buildQuestionsReview(),
            const SizedBox(height: 24),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard() {
    final percentage = result.percentage;
    final Color color;
    final String emoji;
    final String message;

    if (percentage >= 80) {
      color = _kAccentGreen;
      emoji = '🎉';
      message = 'Excellent!';
    } else if (percentage >= 60) {
      color = _kAccentBlue;
      emoji = '👍';
      message = 'Good Job!';
    } else if (percentage >= 40) {
      color = _kAccentYellow;
      emoji = '💪';
      message = 'Keep Practicing!';
    } else {
      color = _kAccentCoral;
      emoji = '📚';
      message = 'Study More!';
    }

    return Container(
      decoration: BoxDecoration(
        color: _kCardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5), width: 2),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 64),
          ),
          const SizedBox(height: 16),
          Text(
            '${result.score}/${result.totalQuestions}',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _kWhite,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${percentage.toInt()}% Correct',
            style: TextStyle(
              fontSize: 18,
              color: color,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: _kBackgroundColor,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.check_circle_outline,
            label: 'Correct',
            value: '${result.score}',
            color: _kAccentGreen,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.cancel_outlined,
            label: 'Wrong',
            value: '${result.totalQuestions - result.score}',
            color: _kAccentCoral,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.timer_outlined,
            label: 'Time',
            value: _formatDuration(duration),
            color: _kAccentBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionsReview() {
    return Container(
      decoration: BoxDecoration(
        color: _kCardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Review Answers',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _kWhite,
            ),
          ),
          const SizedBox(height: 16),
          ...quiz.questions.asMap().entries.map((entry) {
            final index = entry.key;
            final question = entry.value;
            final selectedAnswer = result.answers[question.id];
            final isCorrect = selectedAnswer == question.correctAnswer;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: _kBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCorrect ? _kAccentGreen : _kAccentCoral,
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCorrect ? _kAccentGreen : _kAccentCoral,
                        ),
                        child: Icon(
                          isCorrect ? Icons.check : Icons.close,
                          color: _kWhite,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Question ${index + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: _kWhite,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    question.question,
                    style: const TextStyle(
                      fontSize: 16,
                      color: _kLightGray,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...question.options.asMap().entries.map((optEntry) {
                    final optIndex = optEntry.key;
                    final option = optEntry.value;
                    final isSelected = selectedAnswer == optIndex;
                    final isCorrectAnswer = optIndex == question.correctAnswer;

                    Color borderColor = _kDarkGray;
                    Color bgColor = Colors.transparent;
                    IconData? icon;

                    if (isCorrectAnswer) {
                      borderColor = _kAccentGreen;
                      bgColor = _kAccentGreen.withOpacity(0.1);
                      icon = Icons.check;
                    } else if (isSelected && !isCorrect) {
                      borderColor = _kAccentCoral;
                      bgColor = _kAccentCoral.withOpacity(0.1);
                      icon = Icons.close;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: borderColor,
                          width: isSelected || isCorrectAnswer ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          if (icon != null)
                            Icon(
                              icon,
                              color: isCorrectAnswer
                                  ? _kAccentGreen
                                  : _kAccentCoral,
                              size: 20,
                            )
                          else
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: _kDarkGray),
                              ),
                              child: Center(
                                child: Text(
                                  String.fromCharCode(65 + optIndex),
                                  style: const TextStyle(
                                    color: _kDarkGray,
                                    fontSize: 10,
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
                                color: isCorrectAnswer
                                    ? _kAccentGreen
                                    : isSelected
                                        ? _kAccentCoral
                                        : _kLightGray,
                              ),
                            ),
                          ),
                          if (isSelected && !isCorrectAnswer)
                            const Text(
                              'Your answer',
                              style: TextStyle(
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                                color: _kAccentCoral,
                              ),
                            ),
                          if (isCorrectAnswer)
                            const Text(
                              'Correct',
                              style: TextStyle(
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                                color: _kAccentGreen,
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                  if (question.explanation != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _kAccentBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _kAccentBlue.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.lightbulb_outline,
                            color: _kAccentBlue,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              question.explanation!,
                              style: const TextStyle(color: _kLightGray),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<bool> _validateSourceExists() async {
    try {
      if (quiz.sourceType == 'transcription') {
        final transcriptionRepo = getIt<TranscriptionRepository>();
        final result = await transcriptionRepo.getTranscription(quiz.sourceId);
        return result.fold(
          (_) => false,
          (_) => true,
        );
      } else if (quiz.sourceType == 'summary') {
        final summaryRepo = getIt<SummaryRepository>();
        final result = await summaryRepo.getSummary(quiz.sourceId);
        return result.fold(
          (_) => false,
          (_) => true,
        );
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _handleRetakeQuiz(BuildContext context) async {
    // Validate that source content still exists
    final sourceExists = await _validateSourceExists();

    if (!sourceExists) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The source content for this quiz has been deleted. Cannot retake quiz.',
          ),
          backgroundColor: _kAccentCoral,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    if (!context.mounted) return;
    
    // Reset quiz state and navigate to taking page
    context.read<QuizBloc>().add(LoadQuizEvent(quiz.id));
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<QuizBloc>(),
          child: QuizTakingPage(quiz: quiz),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: () => _handleRetakeQuiz(context),
          icon: const Icon(Icons.refresh),
          label: const Text('Retake Quiz'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kAccentBlue,
            foregroundColor: _kWhite,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            // Pop back to the quiz creation page
            Navigator.of(context).popUntil((route) => route.isFirst || route.settings.name == '/quiz');
          },
          icon: const Icon(Icons.arrow_back),
          label: const Text('Back to Quizzes'),
          style: OutlinedButton.styleFrom(
            foregroundColor: _kLightGray,
            side: const BorderSide(color: _kDarkGray),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
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
      decoration: BoxDecoration(
        color: _kCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: _kLightGray,
            ),
          ),
        ],
      ),
    );
  }
}
