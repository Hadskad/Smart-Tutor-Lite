import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/quiz_result.dart';
import '../repositories/quiz_repository.dart';

@lazySingleton
class SubmitQuiz {
  SubmitQuiz(this._repository);

  final QuizRepository _repository;

  Future<Either<Failure, QuizResult>> call({
    required String quizId,
    required Map<String, int> answers,
  }) async {
    return _repository.submitQuiz(quizId: quizId, answers: answers);
  }
}

