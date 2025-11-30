import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/quiz.dart';
import '../entities/quiz_result.dart';

abstract class QuizRepository {
  /// Generate a quiz from source content (transcription or summary)
  Future<Either<Failure, Quiz>> generateQuiz({
    required String sourceId,
    required String sourceType,
    int numQuestions = 5,
    String difficulty = 'medium',
  });

  /// Get quiz by ID
  Future<Either<Failure, Quiz>> getQuiz(String id);

  /// Get all quizzes
  Future<Either<Failure, List<Quiz>>> getAllQuizzes();

  /// Submit quiz answers and get results
  Future<Either<Failure, QuizResult>> submitQuiz({
    required String quizId,
    required Map<String, int> answers, // questionId -> selectedAnswerIndex
  });

  /// Get quiz results by quiz ID
  Future<Either<Failure, QuizResult>> getQuizResults(String quizId);

  /// Delete quiz
  Future<Either<Failure, Unit>> deleteQuiz(String id);
}

