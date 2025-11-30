import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/study_mode_repository.dart';

@lazySingleton
class GetProgress {
  const GetProgress(this.repository);

  final StudyModeRepository repository;

  Future<Either<Failure, StudyProgress>> call() async {
    return await repository.getStudyProgress();
  }
}

