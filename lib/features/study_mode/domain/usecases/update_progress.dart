import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/flashcard.dart';
import '../repositories/study_mode_repository.dart';

@lazySingleton
class UpdateProgress {
  const UpdateProgress(this.repository);

  final StudyModeRepository repository;

  Future<Either<Failure, Flashcard>> call({
    required String flashcardId,
    bool? isKnown,
    FlashcardDifficulty? difficulty,
  }) async {
    return await repository.updateFlashcardProgress(
      flashcardId: flashcardId,
      isKnown: isKnown,
      difficulty: difficulty,
    );
  }
}

