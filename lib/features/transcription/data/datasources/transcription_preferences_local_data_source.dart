import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class TranscriptionPreferencesLocalDataSource {
  Future<bool> getAlwaysUseOffline();
  Future<void> setAlwaysUseOffline(bool value);
  Future<bool> getUseFastWhisperModel();
  Future<void> setUseFastWhisperModel(bool value);
}

@LazySingleton(as: TranscriptionPreferencesLocalDataSource)
class TranscriptionPreferencesLocalDataSourceImpl
    implements TranscriptionPreferencesLocalDataSource {
  TranscriptionPreferencesLocalDataSourceImpl(this._prefs);

  final SharedPreferences _prefs;
  static const _keyAlwaysOffline = 'transcription_always_offline';
  static const _keyFastWhisperModel = 'transcription_fast_whisper_model';

  @override
  Future<bool> getAlwaysUseOffline() async {
    return _prefs.getBool(_keyAlwaysOffline) ?? false;
  }

  @override
  Future<void> setAlwaysUseOffline(bool value) async {
    await _prefs.setBool(_keyAlwaysOffline, value);
  }

  @override
  Future<bool> getUseFastWhisperModel() async {
    return _prefs.getBool(_keyFastWhisperModel) ?? false;
  }

  @override
  Future<void> setUseFastWhisperModel(bool value) async {
    await _prefs.setBool(_keyFastWhisperModel, value);
  }
}


