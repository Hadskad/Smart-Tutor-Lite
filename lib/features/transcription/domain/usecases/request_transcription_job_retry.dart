import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../repositories/transcription_job_repository.dart';

@lazySingleton
class RequestTranscriptionJobRetry {
  const RequestTranscriptionJobRetry(this._repository);

  final TranscriptionJobRepository _repository;

  Future<Either<Failure, Unit>> call(String jobId, {String? reason}) {
    return _repository.requestRetry(jobId, reason: reason);
  }
}

