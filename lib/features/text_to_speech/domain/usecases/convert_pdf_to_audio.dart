import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../entities/tts_job.dart';
import '../repositories/tts_repository.dart';

@lazySingleton
class ConvertPdfToAudio {
  ConvertPdfToAudio(this._repository);

  final TtsRepository _repository;

  Future<Either<Failure, TtsJob>> call({
    required String pdfUrl,
    String voice = 'en-US-Standard-B',
  }) async {
    return _repository.convertPdfToAudio(pdfUrl: pdfUrl, voice: voice);
  }
}

