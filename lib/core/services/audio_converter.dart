import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;

import '../errors/failures.dart';

/// Service for converting audio files between formats.
/// 
/// Primarily used to convert M4A/AAC recordings to WAV format
/// for on-device Whisper transcription.
/// 
/// NOTE: FFmpeg Kit is currently disabled due to the package being discontinued.
/// Audio conversion functionality is temporarily unavailable.
/// For offline transcription, please use WAV format recordings or online mode.
@lazySingleton
class AudioConverter {
  /// Converts an audio file to WAV format suitable for Whisper.
  /// 
  /// Whisper requires: 16kHz sample rate, mono channel, WAV format.
  /// 
  /// Returns the path to the converted WAV file.
  /// Throws [AudioConversionFailure] if conversion fails.
  /// 
  /// NOTE: Currently throws an error as FFmpeg Kit is disabled.
  /// Use online mode or WAV recordings for transcription.
  Future<String> convertToWav(String inputPath) async {
    final inputFile = File(inputPath);
    if (!await inputFile.exists()) {
      throw AudioConversionFailure(
        message: 'Input audio file not found: $inputPath',
      );
    }

    // FFmpeg Kit is currently disabled due to package discontinuation
    // The package's Maven artifacts are no longer available
    debugPrint('[AudioConverter] FFmpeg Kit is disabled - audio conversion unavailable');
    debugPrint('[AudioConverter] Input file: $inputPath');
    
    // Check if file is already WAV - if so, return it directly
    if (isWavFormat(inputPath)) {
      debugPrint('[AudioConverter] File is already WAV format, returning as-is');
      return inputPath;
    }
    
    throw AudioConversionFailure(
      message: 'Audio conversion is temporarily unavailable. '
          'The FFmpeg Kit package has been discontinued. '
          'Please use online mode for transcription, or record in WAV format. '
          'File: ${p.basename(inputPath)}',
    );
  }

  /// Checks if a file is already in WAV format.
  bool isWavFormat(String path) {
    return p.extension(path).toLowerCase() == '.wav';
  }

  /// Cleans up a converted file if it exists.
  /// 
  /// Call this after transcription is complete to remove temporary files.
  Future<void> cleanupConvertedFile(String convertedPath) async {
    try {
      final file = File(convertedPath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('[AudioConverter] Cleaned up converted file: $convertedPath');
      }
    } catch (e) {
      debugPrint('[AudioConverter] Failed to cleanup converted file: $e');
      // Best-effort cleanup, don't throw
    }
  }
}

