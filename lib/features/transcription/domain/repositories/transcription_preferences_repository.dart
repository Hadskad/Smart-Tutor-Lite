import '../entities/transcription_preferences.dart';

abstract class TranscriptionPreferencesRepository {
  Future<TranscriptionPreferences> loadPreferences();
  Future<TranscriptionPreferences> setAlwaysUseOffline(bool value);
  Future<TranscriptionPreferences> setUseFastWhisperModel(bool value);
}


