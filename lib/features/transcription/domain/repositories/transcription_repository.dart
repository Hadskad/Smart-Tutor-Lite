import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/transcription.dart';

abstract class TranscriptionRepository {
  Future<Either<Failure, Transcription>> transcribeAudio(
    String audioPath, {
    bool preferLocal = false,
    String? modelAssetPath,
  });

  Future<Either<Failure, Transcription>> getTranscription(String id);

  Future<Either<Failure, List<Transcription>>> getAllTranscriptions();

  Future<Either<Failure, Unit>> deleteTranscription(String id);
}
