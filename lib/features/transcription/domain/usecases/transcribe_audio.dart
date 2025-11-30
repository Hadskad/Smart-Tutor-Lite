import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/transcription.dart';
import '../repositories/transcription_repository.dart';

@lazySingleton
class TranscribeAudio {
  const TranscribeAudio(this._repository);

  final TranscriptionRepository _repository;

  Future<Either<Failure, Transcription>> call(String audioPath) {
    return _repository.transcribeAudio(audioPath);
  }
}
