import 'package:dartz/dartz.dart';
import 'package:hive/hive.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/transcription.dart';
import '../../domain/repositories/transcription_repository.dart';
import '../datasources/transcription_remote_datasource.dart';
import '../datasources/whisper_local_datasource.dart';
import '../models/transcription_model.dart';

const _transcriptionCacheBox = 'transcription_cache';

@LazySingleton(as: TranscriptionRepository)
class TranscriptionRepositoryImpl implements TranscriptionRepository {
  TranscriptionRepositoryImpl({
    required WhisperLocalDataSource localDataSource,
    required TranscriptionRemoteDataSource remoteDataSource,
    required NetworkInfo networkInfo,
    required HiveInterface hive,
  })  : _localDataSource = localDataSource,
        _remoteDataSource = remoteDataSource,
        _networkInfo = networkInfo,
        _hive = hive;

  final WhisperLocalDataSource _localDataSource;
  final TranscriptionRemoteDataSource _remoteDataSource;
  final NetworkInfo _networkInfo;
  final HiveInterface _hive;
  final Uuid _uuid = const Uuid();

  Future<Box<Map>> _openCacheBox() async {
    if (_hive.isBoxOpen(_transcriptionCacheBox)) {
      return _hive.box<Map>(_transcriptionCacheBox);
    }
    return _hive.openBox<Map>(_transcriptionCacheBox);
  }

  Future<void> _cacheTranscription(TranscriptionModel model) async {
    final box = await _openCacheBox();
    await box.put(model.id, model.toJson());
  }

  Future<TranscriptionModel?> _readFromCache(String id) async {
    final box = await _openCacheBox();
    final data = box.get(id);
    if (data == null) {
      return null;
    }
    return TranscriptionModel.fromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<Either<Failure, Transcription>> transcribeAudio(
      String audioPath) async {
    try {
      final rawText = await _localDataSource.transcribe(audioPath);
      final model = TranscriptionModel(
        id: _uuid.v4(),
        text: rawText,
        audioPath: audioPath,
        duration: Duration.zero,
        timestamp: DateTime.now(),
        confidence: 0.95,
      );
      await _cacheTranscription(model);
      return Right(model.toEntity());
    } on Failure catch (failure) {
      final connected = await _networkInfo.isConnected;
      if (!connected) {
        return Left(
          NetworkFailure(
            message:
                'No internet connection for cloud transcription. Please reconnect or retry once you are online.',
            cause: failure,
          ),
        );
      }
      try {
        final remoteModel = await _remoteDataSource.transcribeAudio(audioPath);
        await _cacheTranscription(remoteModel);
        return Right(remoteModel.toEntity());
      } on Failure catch (remoteFailure) {
        return Left(remoteFailure);
      } catch (error) {
        return Left(ServerFailure(
            message: 'Remote transcription failed', cause: error));
      }
    } catch (error) {
      return Left(
          LocalFailure(message: 'Failed to transcribe audio', cause: error));
    }
  }

  @override
  Future<Either<Failure, Transcription>> getTranscription(String id) async {
    try {
      final cached = await _readFromCache(id);
      if (cached != null) {
        return Right(cached.toEntity());
      }
      if (await _networkInfo.isConnected) {
        final remoteModel = await _remoteDataSource.fetchTranscription(id);
        await _cacheTranscription(remoteModel);
        return Right(remoteModel.toEntity());
      }
      return const Left(
          CacheFailure(message: 'Transcription not found locally'));
    } on Failure catch (failure) {
      return Left(failure);
    } catch (error) {
      return Left(
          LocalFailure(message: 'Unable to load transcription', cause: error));
    }
  }

  @override
  Future<Either<Failure, List<Transcription>>> getAllTranscriptions() async {
    try {
      final box = await _openCacheBox();
      final transcriptions = <TranscriptionModel>[];
      for (final key in box.keys) {
        final data = box.get(key);
        if (data != null) {
          transcriptions.add(
            TranscriptionModel.fromJson(Map<String, dynamic>.from(data)),
          );
        }
      }
      // Sort by timestamp, most recent first
      transcriptions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return Right(transcriptions.map((m) => m.toEntity()).toList());
    } catch (error) {
      return Left(
        LocalFailure(
          message: 'Failed to get transcriptions',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteTranscription(String id) async {
    try {
      final box = await _openCacheBox();
      await box.delete(id);
      if (await _networkInfo.isConnected) {
        await _remoteDataSource.deleteTranscription(id);
      }
      return const Right(unit);
    } on Failure catch (failure) {
      return Left(failure);
    } catch (error) {
      return Left(LocalFailure(
          message: 'Unable to delete transcription', cause: error));
    }
  }
}
