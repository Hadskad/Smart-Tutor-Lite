import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/tts_job.dart';

abstract class TtsRepository {
  /// Convert PDF to audio
  Future<Either<Failure, TtsJob>> convertPdfToAudio({
    required String pdfUrl,
    String voice = 'en-US-Neural2-D',
  });

  /// Convert text to audio
  Future<Either<Failure, TtsJob>> convertTextToAudio({
    required String text,
    String voice = 'en-US-Neural2-D',
  });

  /// Get TTS job by ID
  Future<Either<Failure, TtsJob>> getTtsJob(String id);

  /// Get all TTS jobs
  Future<Either<Failure, List<TtsJob>>> getAllTtsJobs();

  /// Delete TTS job
  Future<Either<Failure, Unit>> deleteTtsJob(String id);

  /// Process all pending queued TTS jobs (internal use by sync service)
  Future<void> processQueuedTtsJobs();
}
