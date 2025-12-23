import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/services/audio_converter.dart';
import '../../../../native_bridge/whisper_ffi.dart';

abstract class WhisperLocalDataSource {
  Future<String> transcribe(
    String audioPath, {
    String? modelAssetPath,
  });
}

@LazySingleton(as: WhisperLocalDataSource)
class WhisperLocalDataSourceImpl implements WhisperLocalDataSource {
  WhisperLocalDataSourceImpl(this._whisperFfi, this._audioConverter);

  final WhisperFfi _whisperFfi;
  final AudioConverter _audioConverter;

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
    // Check if file is already in WAV format
    final hasWavExtension = p.extension(sourcePath).toLowerCase() == '.wav';
    
    if (hasWavExtension) {
      // Offline recordings are already in WAV/16kHz/mono format via RecordConfig
      return sourcePath;
    }
    
    // Non-WAV files need conversion (e.g., M4A from online mode fallback)
    debugPrint('[WhisperLocalDataSource] Converting non-WAV file: $sourcePath');
    try {
      final convertedPath = await _audioConverter.convertToWav(sourcePath);
      debugPrint('[WhisperLocalDataSource] Conversion successful: $convertedPath');
      return convertedPath;
    } on AudioConversionFailure catch (e) {
      throw WhisperRuntimeFailure(
        message: 'Failed to convert audio file for transcription: ${e.message}',
        cause: e,
      );
    } catch (e) {
      throw WhisperRuntimeFailure(
        message: 'Unexpected error during audio conversion',
        cause: e,
      );
    }
  }
}
