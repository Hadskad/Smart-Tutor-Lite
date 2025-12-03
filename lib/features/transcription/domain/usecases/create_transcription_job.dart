import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/transcription_job.dart';
import '../entities/transcription_job_request.dart';
import '../repositories/transcription_job_repository.dart';

@lazySingleton
class CreateTranscriptionJob {
  const CreateTranscriptionJob(this._repository);

  final TranscriptionJobRepository _repository;

  Future<Either<Failure, TranscriptionJob>> call(
    TranscriptionJobRequest request,
  ) {
    return _repository.createOnlineJob(request);
  }
}

