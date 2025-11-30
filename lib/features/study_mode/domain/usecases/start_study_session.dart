import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/study_session.dart';
import '../repositories/study_mode_repository.dart';

@lazySingleton
class StartStudySession {
  const StartStudySession(this.repository);

  final StudyModeRepository repository;

  Future<Either<Failure, StudySession>> call({
    required List<String> flashcardIds,
  }) async {
    return await repository.startStudySession(flashcardIds: flashcardIds);
  }
}

