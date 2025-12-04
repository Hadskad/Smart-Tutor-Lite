import 'package:injectable/injectable.dart';

import '../../domain/entities/transcription_preferences.dart';
import '../../domain/repositories/transcription_preferences_repository.dart';
import '../datasources/transcription_preferences_local_data_source.dart';

@LazySingleton(as: TranscriptionPreferencesRepository)
class TranscriptionPreferencesRepositoryImpl
    implements TranscriptionPreferencesRepository {
  TranscriptionPreferencesRepositoryImpl(this._localDataSource);

  final TranscriptionPreferencesLocalDataSource _localDataSource;

  @override
  Future<TranscriptionPreferences> loadPreferences() async {
    final alwaysOffline = await _localDataSource.getAlwaysUseOffline();
    final fastModel = await _localDataSource.getUseFastWhisperModel();
    return TranscriptionPreferences(
      alwaysUseOffline: alwaysOffline,
      useFastWhisperModel: fastModel,
    );
  }

  @override
  Future<TranscriptionPreferences> setAlwaysUseOffline(bool value) async {
    await _localDataSource.setAlwaysUseOffline(value);
    final fastModel = await _localDataSource.getUseFastWhisperModel();
    return TranscriptionPreferences(
      alwaysUseOffline: value,
      useFastWhisperModel: fastModel,
    );
  }

  @override
  Future<TranscriptionPreferences> setUseFastWhisperModel(bool value) async {
    await _localDataSource.setUseFastWhisperModel(value);
    final alwaysOffline = await _localDataSource.getAlwaysUseOffline();
    return TranscriptionPreferences(
      alwaysUseOffline: alwaysOffline,
      useFastWhisperModel: value,
    );
  }
}


