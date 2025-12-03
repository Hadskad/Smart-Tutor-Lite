import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/transcription_job.dart';
import '../repositories/transcription_job_repository.dart';

@lazySingleton
class WatchTranscriptionJob {
  const WatchTranscriptionJob(this._repository);

  final TranscriptionJobRepository _repository;

  Stream<Either<Failure, TranscriptionJob>> call(String jobId) {
    return _repository.watchJob(jobId);
  }
}

