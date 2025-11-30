import 'package:dartz/dartz.dart';
import 'package:hive/hive.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/tts_job.dart';
import '../../domain/repositories/tts_repository.dart';
import '../datasources/tts_remote_datasource.dart';
import '../models/tts_job_model.dart';

const _ttsJobCacheBox = 'tts_job_cache';
const _defaultElevenLabsVoiceId = '21m00Tcm4TlvDq8ikWAM';

@LazySingleton(as: TtsRepository)
class TtsRepositoryImpl implements TtsRepository {
  TtsRepositoryImpl({
    required TtsRemoteDataSource remoteDataSource,
    required NetworkInfo networkInfo,
    required HiveInterface hive,
  })  : _remoteDataSource = remoteDataSource,
        _networkInfo = networkInfo,
        _hive = hive;

  final TtsRemoteDataSource _remoteDataSource;
  final NetworkInfo _networkInfo;
  final HiveInterface _hive;

  Future<Box<Map>> _openCacheBox() async {
    if (_hive.isBoxOpen(_ttsJobCacheBox)) {
      return _hive.box<Map>(_ttsJobCacheBox);
    }
    return _hive.openBox<Map>(_ttsJobCacheBox);
  }

  Future<void> _cacheTtsJob(TtsJobModel model) async {
    final box = await _openCacheBox();
    await box.put(model.id, model.toJson());
  }

  Future<TtsJobModel?> _readFromCache(String id) async {
    final box = await _openCacheBox();
    final data = box.get(id);
    if (data == null) {
      return null;
    }
    return TtsJobModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<List<TtsJobModel>> _getAllFromCache() async {
    final box = await _openCacheBox();
    final jobs = <TtsJobModel>[];
    for (final key in box.keys) {
      final data = box.get(key);
      if (data != null) {
        jobs.add(TtsJobModel.fromJson(Map<String, dynamic>.from(data)));
      }
    }
    jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return jobs;
  }

  @override
  Future<Either<Failure, TtsJob>> convertPdfToAudio({
    required String pdfUrl,
    String voice = _defaultElevenLabsVoiceId,
  }) async {
    try {
      // Check if online before attempting remote call
      final connected = await _networkInfo.isConnected;
      if (!connected) {
        return const Left(
          NetworkFailure(message: 'No internet connection'),
        );
      }

      // Call remote API
      final remoteModel = await _remoteDataSource.convertPdfToAudio(
        pdfUrl: pdfUrl,
        voice: voice,
      );

      // Cache locally
      await _cacheTtsJob(remoteModel);

      return Right(remoteModel.toEntity());
    } on Failure catch (failure) {
      return Left(failure);
    } catch (error) {
      return Left(
        ServerFailure(
          message: 'Failed to convert PDF to audio',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, TtsJob>> convertTextToAudio({
    required String text,
    String voice = _defaultElevenLabsVoiceId,
  }) async {
    try {
      // Check if online before attempting remote call
      final connected = await _networkInfo.isConnected;
      if (!connected) {
        return const Left(
          NetworkFailure(message: 'No internet connection'),
        );
      }

      // Call remote API
      final remoteModel = await _remoteDataSource.convertTextToAudio(
        text: text,
        voice: voice,
      );

      // Cache locally
      await _cacheTtsJob(remoteModel);

      return Right(remoteModel.toEntity());
    } on Failure catch (failure) {
      return Left(failure);
    } catch (error) {
      return Left(
        ServerFailure(
          message: 'Failed to convert text to audio',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, TtsJob>> getTtsJob(String id) async {
    try {
      // Try cache first
      final cached = await _readFromCache(id);
      if (cached != null) {
        return Right(cached.toEntity());
      }

      // If not in cache and online, fetch from remote
      if (await _networkInfo.isConnected) {
        final remoteModel = await _remoteDataSource.getTtsJob(id);
        await _cacheTtsJob(remoteModel);
        return Right(remoteModel.toEntity());
      }

      return const Left(
        CacheFailure(message: 'TTS job not found locally'),
      );
    } on Failure catch (failure) {
      return Left(failure);
    } catch (error) {
      return Left(
        LocalFailure(
          message: 'Failed to get TTS job',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<TtsJob>>> getAllTtsJobs() async {
    try {
      // Get from cache (offline-first)
      final cached = await _getAllFromCache();
      return Right(cached.map((model) => model.toEntity()).toList());
    } catch (error) {
      return Left(
        LocalFailure(
          message: 'Failed to get TTS jobs',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteTtsJob(String id) async {
    try {
      final box = await _openCacheBox();
      await box.delete(id);
      return const Right(unit);
    } catch (error) {
      return Left(
        LocalFailure(
          message: 'Failed to delete TTS job',
          cause: error,
        ),
      );
    }
  }
}
