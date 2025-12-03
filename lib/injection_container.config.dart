// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:battery_plus/battery_plus.dart' as _i117;
import 'package:cloud_firestore/cloud_firestore.dart' as _i974;
import 'package:connectivity_plus/connectivity_plus.dart' as _i895;
import 'package:dio/dio.dart' as _i361;
import 'package:firebase_storage/firebase_storage.dart' as _i457;
import 'package:get_it/get_it.dart' as _i174;
import 'package:hive/hive.dart' as _i979;
import 'package:hive_flutter/hive_flutter.dart' as _i986;
import 'package:injectable/injectable.dart' as _i526;
import 'package:logger/logger.dart' as _i974;
import 'package:smart_tutor_lite/core/network/api_client.dart' as _i114;
import 'package:smart_tutor_lite/core/network/network_info.dart' as _i440;
import 'package:smart_tutor_lite/core/utils/logger.dart' as _i496;
import 'package:smart_tutor_lite/core/utils/performance_monitor.dart' as _i366;
import 'package:smart_tutor_lite/features/quiz/data/datasources/quiz_remote_datasource.dart'
    as _i877;
import 'package:smart_tutor_lite/features/quiz/data/repositories/quiz_repository_impl.dart'
    as _i237;
import 'package:smart_tutor_lite/features/quiz/domain/repositories/quiz_repository.dart'
    as _i291;
import 'package:smart_tutor_lite/features/quiz/domain/usecases/generate_quiz.dart'
    as _i889;
import 'package:smart_tutor_lite/features/quiz/domain/usecases/submit_quiz.dart'
    as _i464;
import 'package:smart_tutor_lite/features/quiz/presentation/bloc/quiz_bloc.dart'
    as _i256;
import 'package:smart_tutor_lite/features/study_mode/data/datasources/flashcard_local_datasource.dart'
    as _i777;
import 'package:smart_tutor_lite/features/study_mode/data/datasources/flashcard_remote_datasource.dart'
    as _i794;
import 'package:smart_tutor_lite/features/study_mode/data/repositories/study_mode_repository_impl.dart'
    as _i848;
import 'package:smart_tutor_lite/features/study_mode/domain/repositories/study_mode_repository.dart'
    as _i835;
import 'package:smart_tutor_lite/features/study_mode/domain/usecases/generate_flashcards.dart'
    as _i380;
import 'package:smart_tutor_lite/features/study_mode/domain/usecases/get_progress.dart'
    as _i517;
import 'package:smart_tutor_lite/features/study_mode/domain/usecases/start_study_session.dart'
    as _i790;
import 'package:smart_tutor_lite/features/study_mode/domain/usecases/update_progress.dart'
    as _i136;
import 'package:smart_tutor_lite/features/study_mode/presentation/bloc/study_mode_bloc.dart'
    as _i111;
import 'package:smart_tutor_lite/features/summarization/data/datasources/summary_remote_datasource.dart'
    as _i82;
import 'package:smart_tutor_lite/features/summarization/data/repositories/summary_repository_impl.dart'
    as _i419;
import 'package:smart_tutor_lite/features/summarization/domain/repositories/summary_repository.dart'
    as _i1069;
import 'package:smart_tutor_lite/features/summarization/domain/usecases/summarize_pdf.dart'
    as _i447;
import 'package:smart_tutor_lite/features/summarization/domain/usecases/summarize_text.dart'
    as _i613;
import 'package:smart_tutor_lite/features/summarization/presentation/bloc/summary_bloc.dart'
    as _i569;
import 'package:smart_tutor_lite/features/text_to_speech/data/datasources/tts_remote_datasource.dart'
    as _i539;
import 'package:smart_tutor_lite/features/text_to_speech/data/repositories/tts_repository_impl.dart'
    as _i444;
import 'package:smart_tutor_lite/features/text_to_speech/domain/repositories/tts_repository.dart'
    as _i90;
import 'package:smart_tutor_lite/features/text_to_speech/domain/usecases/convert_pdf_to_audio.dart'
    as _i840;
import 'package:smart_tutor_lite/features/text_to_speech/domain/usecases/convert_text_to_audio.dart'
    as _i93;
import 'package:smart_tutor_lite/features/text_to_speech/presentation/bloc/tts_bloc.dart'
    as _i942;
import 'package:smart_tutor_lite/features/transcription/data/datasources/transcription_job_remote_datasource.dart'
    as _i1047;
import 'package:smart_tutor_lite/features/transcription/data/datasources/transcription_remote_datasource.dart'
    as _i803;
import 'package:smart_tutor_lite/features/transcription/data/datasources/whisper_local_datasource.dart'
    as _i820;
import 'package:smart_tutor_lite/features/transcription/data/repositories/transcription_job_repository_impl.dart'
    as _i438;
import 'package:smart_tutor_lite/features/transcription/data/repositories/transcription_repository_impl.dart'
    as _i690;
import 'package:smart_tutor_lite/features/transcription/domain/repositories/transcription_job_repository.dart'
    as _i80;
import 'package:smart_tutor_lite/features/transcription/domain/repositories/transcription_repository.dart'
    as _i861;
import 'package:smart_tutor_lite/features/transcription/domain/usecases/cancel_transcription_job.dart'
    as _i794;
import 'package:smart_tutor_lite/features/transcription/domain/usecases/create_transcription_job.dart'
    as _i925;
import 'package:smart_tutor_lite/features/transcription/domain/usecases/transcribe_audio.dart'
    as _i978;
import 'package:smart_tutor_lite/features/transcription/domain/usecases/watch_transcription_job.dart'
    as _i1047;
import 'package:smart_tutor_lite/features/transcription/presentation/bloc/transcription_bloc.dart'
    as _i940;
import 'package:smart_tutor_lite/injection_container.dart' as _i265;
import 'package:smart_tutor_lite/native_bridge/performance_bridge.dart' as _i99;
import 'package:smart_tutor_lite/native_bridge/whisper_ffi.dart' as _i687;
import 'package:smart_tutor_lite/native_bridge/whisper_lifecycle_observer.dart'
    as _i756;

extension GetItInjectableX on _i174.GetIt {
// initializes the registration of main-scope dependencies inside of GetIt
  Future<_i174.GetIt> init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) async {
    final gh = _i526.GetItHelper(
      this,
      environment,
      environmentFilter,
    );
    final externalModule = _$ExternalModule();
    await gh.factoryAsync<_i986.HiveInterface>(
      () => externalModule.hive(),
      preResolve: true,
    );
    gh.lazySingleton<_i895.Connectivity>(() => externalModule.connectivity);
    gh.lazySingleton<_i974.Logger>(() => externalModule.logger());
    gh.lazySingleton<_i117.Battery>(() => externalModule.battery());
    gh.lazySingleton<_i974.FirebaseFirestore>(() => externalModule.firestore());
    gh.lazySingleton<_i457.FirebaseStorage>(
        () => externalModule.firebaseStorage());
    gh.lazySingleton<_i99.PerformanceBridge>(() => _i99.PerformanceBridge());
    gh.lazySingleton<_i687.WhisperFfi>(() => _i687.WhisperFfi());
    gh.lazySingleton<_i496.AppLogger>(
        () => _i496.AppLogger(gh<_i974.Logger>()));
    gh.lazySingleton<_i366.PerformanceMonitor>(
        () => _i366.PerformanceMonitor(gh<_i117.Battery>()));
    gh.lazySingleton<_i1047.TranscriptionJobRemoteDataSource>(
        () => _i1047.TranscriptionJobRemoteDataSourceImpl(
              gh<_i974.FirebaseFirestore>(),
              gh<_i457.FirebaseStorage>(),
            ));
    gh.lazySingleton<_i777.FlashcardLocalDataSource>(
        () => _i777.FlashcardLocalDataSourceImpl(gh<_i979.HiveInterface>()));
    gh.lazySingleton<_i756.WhisperLifecycleObserver>(
        () => _i756.WhisperLifecycleObserver(gh<_i687.WhisperFfi>()));
    gh.lazySingleton<_i440.NetworkInfo>(
        () => _i440.NetworkInfoImpl(gh<_i895.Connectivity>()));
    gh.lazySingleton<_i820.WhisperLocalDataSource>(
        () => _i820.WhisperLocalDataSourceImpl(gh<_i687.WhisperFfi>()));
    gh.lazySingleton<_i80.TranscriptionJobRepository>(
        () => _i438.TranscriptionJobRepositoryImpl(
              gh<_i1047.TranscriptionJobRemoteDataSource>(),
              gh<_i440.NetworkInfo>(),
            ));
    gh.lazySingleton<_i794.CancelTranscriptionJob>(() =>
        _i794.CancelTranscriptionJob(gh<_i80.TranscriptionJobRepository>()));
    gh.lazySingleton<_i925.CreateTranscriptionJob>(() =>
        _i925.CreateTranscriptionJob(gh<_i80.TranscriptionJobRepository>()));
    gh.lazySingleton<_i1047.WatchTranscriptionJob>(() =>
        _i1047.WatchTranscriptionJob(gh<_i80.TranscriptionJobRepository>()));
    gh.lazySingleton<_i361.Dio>(
        () => externalModule.dio(gh<_i496.AppLogger>()));
    gh.lazySingleton<_i114.ApiClient>(() => _i114.ApiClient(
          gh<_i361.Dio>(),
          gh<_i440.NetworkInfo>(),
        ));
    gh.lazySingleton<_i539.TtsRemoteDataSource>(
        () => _i539.TtsRemoteDataSourceImpl(gh<_i114.ApiClient>()));
    gh.lazySingleton<_i82.SummaryRemoteDataSource>(
        () => _i82.SummaryRemoteDataSourceImpl(gh<_i114.ApiClient>()));
    gh.lazySingleton<_i803.TranscriptionRemoteDataSource>(
        () => _i803.TranscriptionRemoteDataSourceImpl(gh<_i114.ApiClient>()));
    gh.lazySingleton<_i877.QuizRemoteDataSource>(
        () => _i877.QuizRemoteDataSourceImpl(gh<_i114.ApiClient>()));
    gh.lazySingleton<_i861.TranscriptionRepository>(
        () => _i690.TranscriptionRepositoryImpl(
              localDataSource: gh<_i820.WhisperLocalDataSource>(),
              remoteDataSource: gh<_i803.TranscriptionRemoteDataSource>(),
              networkInfo: gh<_i440.NetworkInfo>(),
              hive: gh<_i979.HiveInterface>(),
            ));
    gh.lazySingleton<_i794.FlashcardRemoteDataSource>(
        () => _i794.FlashcardRemoteDataSourceImpl(gh<_i114.ApiClient>()));
    gh.lazySingleton<_i978.TranscribeAudio>(
        () => _i978.TranscribeAudio(gh<_i861.TranscriptionRepository>()));
    gh.lazySingleton<_i90.TtsRepository>(() => _i444.TtsRepositoryImpl(
          remoteDataSource: gh<_i539.TtsRemoteDataSource>(),
          networkInfo: gh<_i440.NetworkInfo>(),
          hive: gh<_i979.HiveInterface>(),
        ));
    gh.lazySingleton<_i1069.SummaryRepository>(
        () => _i419.SummaryRepositoryImpl(
              remoteDataSource: gh<_i82.SummaryRemoteDataSource>(),
              networkInfo: gh<_i440.NetworkInfo>(),
              hive: gh<_i979.HiveInterface>(),
            ));
    gh.lazySingleton<_i840.ConvertPdfToAudio>(
        () => _i840.ConvertPdfToAudio(gh<_i90.TtsRepository>()));
    gh.lazySingleton<_i93.ConvertTextToAudio>(
        () => _i93.ConvertTextToAudio(gh<_i90.TtsRepository>()));
    gh.factory<_i940.TranscriptionBloc>(() => _i940.TranscriptionBloc(
          gh<_i978.TranscribeAudio>(),
          gh<_i99.PerformanceBridge>(),
          gh<_i861.TranscriptionRepository>(),
        ));
    gh.lazySingleton<_i835.StudyModeRepository>(
        () => _i848.StudyModeRepositoryImpl(
              remoteDataSource: gh<_i794.FlashcardRemoteDataSource>(),
              localDataSource: gh<_i777.FlashcardLocalDataSource>(),
              networkInfo: gh<_i440.NetworkInfo>(),
            ));
    gh.lazySingleton<_i291.QuizRepository>(() => _i237.QuizRepositoryImpl(
          remoteDataSource: gh<_i877.QuizRemoteDataSource>(),
          networkInfo: gh<_i440.NetworkInfo>(),
          hive: gh<_i979.HiveInterface>(),
        ));
    gh.lazySingleton<_i889.GenerateQuiz>(
        () => _i889.GenerateQuiz(gh<_i291.QuizRepository>()));
    gh.lazySingleton<_i464.SubmitQuiz>(
        () => _i464.SubmitQuiz(gh<_i291.QuizRepository>()));
    gh.lazySingleton<_i380.GenerateFlashcards>(
        () => _i380.GenerateFlashcards(gh<_i835.StudyModeRepository>()));
    gh.lazySingleton<_i517.GetProgress>(
        () => _i517.GetProgress(gh<_i835.StudyModeRepository>()));
    gh.lazySingleton<_i790.StartStudySession>(
        () => _i790.StartStudySession(gh<_i835.StudyModeRepository>()));
    gh.lazySingleton<_i136.UpdateProgress>(
        () => _i136.UpdateProgress(gh<_i835.StudyModeRepository>()));
    gh.lazySingleton<_i447.SummarizePdf>(
        () => _i447.SummarizePdf(gh<_i1069.SummaryRepository>()));
    gh.lazySingleton<_i613.SummarizeText>(
        () => _i613.SummarizeText(gh<_i1069.SummaryRepository>()));
    gh.factory<_i942.TtsBloc>(() => _i942.TtsBloc(
          gh<_i840.ConvertPdfToAudio>(),
          gh<_i93.ConvertTextToAudio>(),
          gh<_i90.TtsRepository>(),
        ));
    gh.factory<_i256.QuizBloc>(() => _i256.QuizBloc(
          gh<_i889.GenerateQuiz>(),
          gh<_i464.SubmitQuiz>(),
          gh<_i291.QuizRepository>(),
          gh<_i99.PerformanceBridge>(),
          gh<_i496.AppLogger>(),
        ));
    gh.factory<_i569.SummaryBloc>(() => _i569.SummaryBloc(
          gh<_i613.SummarizeText>(),
          gh<_i447.SummarizePdf>(),
          gh<_i1069.SummaryRepository>(),
          gh<_i99.PerformanceBridge>(),
          gh<_i496.AppLogger>(),
        ));
    gh.factory<_i111.StudyModeBloc>(() => _i111.StudyModeBloc(
          gh<_i380.GenerateFlashcards>(),
          gh<_i790.StartStudySession>(),
          gh<_i136.UpdateProgress>(),
          gh<_i517.GetProgress>(),
          gh<_i835.StudyModeRepository>(),
          gh<_i99.PerformanceBridge>(),
          gh<_i496.AppLogger>(),
        ));
    return this;
  }
}

class _$ExternalModule extends _i265.ExternalModule {}
