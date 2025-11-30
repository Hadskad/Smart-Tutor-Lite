import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/flashcard.dart';
import '../repositories/study_mode_repository.dart';

@lazySingleton
class GenerateFlashcards {
  const GenerateFlashcards(this.repository);

  final StudyModeRepository repository;

  Future<Either<Failure, List<Flashcard>>> call({
    required String sourceId,
    required String sourceType,
    int? numFlashcards,
  }) async {
    return await repository.generateFlashcards(
      sourceId: sourceId,
      sourceType: sourceType,
      numFlashcards: numFlashcards,
    );
  }
}

