import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/quiz.dart';
import '../repositories/quiz_repository.dart';

@lazySingleton
class GenerateQuiz {
  GenerateQuiz(this._repository);

  final QuizRepository _repository;

  Future<Either<Failure, Quiz>> call({
    required String sourceId,
    required String sourceType,
    int numQuestions = 5,
    String difficulty = 'medium',
  }) async {
    return _repository.generateQuiz(
      sourceId: sourceId,
      sourceType: sourceType,
      numQuestions: numQuestions,
      difficulty: difficulty,
    );
  }
}

