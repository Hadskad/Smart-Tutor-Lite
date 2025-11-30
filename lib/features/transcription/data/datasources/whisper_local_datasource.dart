import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../native_bridge/whisper_ffi.dart';

abstract class WhisperLocalDataSource {
  Future<String> transcribe(String audioPath);
}

@LazySingleton(as: WhisperLocalDataSource)
class WhisperLocalDataSourceImpl implements WhisperLocalDataSource {
  WhisperLocalDataSourceImpl(this._whisperFfi);

  final WhisperFfi _whisperFfi;

  @override
  Future<String> transcribe(String audioPath) async {
    try {
      return await _whisperFfi.transcribeFile(audioPath);
    } on UnsupportedError catch (error) {
      throw LocalFailure(message: error.message, cause: error);
    } on ArgumentError catch (error) {
      throw LocalFailure(message: error.message, cause: error);
    } catch (error) {
      throw LocalFailure(
          message: 'Failed to run on-device transcription', cause: error);
    }
  }
}
