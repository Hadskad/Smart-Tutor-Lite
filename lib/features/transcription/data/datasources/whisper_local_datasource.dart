import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../native_bridge/whisper_ffi.dart';

abstract class WhisperLocalDataSource {
  Future<String> transcribe(
    String audioPath, {
    String? modelAssetPath,
  });
}

@LazySingleton(as: WhisperLocalDataSource)
class WhisperLocalDataSourceImpl implements WhisperLocalDataSource {
  WhisperLocalDataSourceImpl(this._whisperFfi);

  final WhisperFfi _whisperFfi;

  @override
  Future<String> transcribe(
    String audioPath, {
    String? modelAssetPath,
  }) async {
    final preparedPath = await _prepareAudio(audioPath);
    try {
      return await _whisperFfi.transcribeFile(
        preparedPath,
        modelAssetPath: modelAssetPath ?? AppConstants.whisperDefaultModel,
      );
    } on WhisperException catch (error) {
      switch (error.type) {
        case WhisperErrorType.init:
          throw WhisperInitFailure(message: error.message, cause: error);
        case WhisperErrorType.noSpeech:
          throw WhisperNoSpeechFailure(message: error.message, cause: error);
        case WhisperErrorType.runtime:
          throw WhisperRuntimeFailure(message: error.message, cause: error);
      }
    } on UnsupportedError catch (error) {
      throw WhisperRuntimeFailure(message: error.message, cause: error);
    } on ArgumentError catch (error) {
      throw WhisperRuntimeFailure(message: error.message, cause: error);
    } catch (error) {
      throw LocalFailure(
        message: 'Failed to run on-device transcription',
        cause: error,
      );
    } finally {
      if (preparedPath != audioPath) {
        try {
          await File(preparedPath).delete();
        } catch (_) {
          // ignore cleanup failures
        }
      }
    }
  }

  Future<String> _prepareAudio(String sourcePath) async {
    // Offline recordings are already in WAV/16kHz/mono format via RecordConfig
    // Simply verify the file has .wav extension
    final hasWavExtension = p.extension(sourcePath).toLowerCase() == '.wav';
    
    if (!hasWavExtension) {
      throw WhisperRuntimeFailure(
        message: 'Only WAV files are supported for offline transcription. '
            'Offline recordings are automatically saved in the correct format.',
        cause: Exception('Unsupported audio format: ${p.extension(sourcePath)}'),
      );
    }
    
    return sourcePath;
  }
}
