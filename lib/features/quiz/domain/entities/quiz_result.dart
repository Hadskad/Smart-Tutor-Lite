import 'package:equatable/equatable.dart';

/// Represents the result of a completed quiz.
class QuizResult extends Equatable {
  const QuizResult({
    required this.quizId,
    required this.answers,
    required this.score,
    required this.totalQuestions,
    required this.completedAt,
  });

  final String quizId;
  final Map<String, int> answers; // Map of questionId -> selectedAnswerIndex
  final int score; // Number of correct answers
  final int totalQuestions;
  final DateTime completedAt;

  /// Percentage score (0-100)
  double get percentage => (score / totalQuestions) * 100;

  @override
  List<Object?> get props => [
        quizId,
        answers,
        score,
        totalQuestions,
        completedAt,
      ];
}

