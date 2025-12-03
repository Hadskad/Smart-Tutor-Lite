import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/transcription_job.dart';
import '../entities/transcription_job_request.dart';

abstract class TranscriptionJobRepository {
  Future<Either<Failure, TranscriptionJob>> createOnlineJob(
    TranscriptionJobRequest request,
  );

  Stream<Either<Failure, TranscriptionJob>> watchJob(String jobId);

  Future<Either<Failure, Unit>> cancelJob(String jobId, {String? reason});
}

