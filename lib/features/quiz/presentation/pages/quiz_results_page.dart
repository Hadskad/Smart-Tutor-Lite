import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../injection_container.dart';
import '../../../summarization/domain/repositories/summary_repository.dart';
import '../../../transcription/domain/repositories/transcription_repository.dart';
import '../../domain/entities/quiz.dart';
import '../../domain/entities/quiz_result.dart';
import '../bloc/quiz_bloc.dart';
import 'quiz_taking_page.dart';

class QuizResultsPage extends StatelessWidget {
  const QuizResultsPage({
    super.key,
    required this.quiz,
    required this.result,
  });

  final Quiz quiz;
  final QuizResult result;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<QuizBloc>(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quiz Results'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildScoreCard(),
              const SizedBox(height: 24),
              _buildQuestionsReview(),
              const SizedBox(height: 24),
              _buildActions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreCard() {
    final percentage = result.percentage;
    final color = percentage >= 70
        ? Colors.green
        : percentage >= 50
            ? Colors.orange
            : Colors.red;
    final emoji = percentage >= 70
        ? '🎉'
        : percentage >= 50
            ? '👍'
            : '📚';

    return Card(
      color: color.shade50,
      child: Padding(
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
                color: color.shade900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${percentage.toInt()}% Correct',
              style: TextStyle(
                fontSize: 24,
                color: color.shade700,
              ),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: color.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionsReview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Review Answers',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...quiz.questions.asMap().entries.map((entry) {
          final index = entry.key;
          final question = entry.value;
          final selectedAnswer = result.answers[question.id];
          final isCorrect = selectedAnswer == question.correctAnswer;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            color: isCorrect ? Colors.green.shade50 : Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isCorrect ? Icons.check_circle : Icons.cancel,
                        color: isCorrect ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Question ${index + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    question.question,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  ...question.options.asMap().entries.map((optEntry) {
                    final optIndex = optEntry.key;
                    final option = optEntry.value;
                    final isSelected = selectedAnswer == optIndex;
                    final isCorrectAnswer = optIndex == question.correctAnswer;

                    Color? backgroundColor;
                    IconData? icon;
                    if (isCorrectAnswer) {
                      backgroundColor = Colors.green.shade100;
                      icon = Icons.check;
                    } else if (isSelected && !isCorrect) {
                      backgroundColor = Colors.red.shade100;
                      icon = Icons.close;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected || isCorrectAnswer
                              ? (isCorrectAnswer ? Colors.green : Colors.red)
                              : Colors.grey.shade300,
                          width: isSelected || isCorrectAnswer ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          if (icon != null)
                            Icon(
                              icon,
                              color: isCorrectAnswer ? Colors.green : Colors.red,
                              size: 20,
                            )
                          else
                            const SizedBox(width: 20),
                          Expanded(child: Text(option)),
                          if (isSelected && !isCorrectAnswer)
                            const Text(
                              'Your answer',
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
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
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lightbulb_outline,
                              color: Colors.blue.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              question.explanation!,
                              style: TextStyle(color: Colors.blue.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
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
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => QuizTakingPage(quiz: quiz),
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
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Back to Quizzes'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }
}

