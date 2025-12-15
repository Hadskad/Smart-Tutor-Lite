import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:hive/hive.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/tts_job.dart';
import '../../domain/repositories/tts_repository.dart';
import '../datasources/tts_queue_local_datasource.dart';
import '../datasources/tts_remote_datasource.dart';
import '../models/tts_job_model.dart';
import '../models/tts_queue_model.dart';

const _ttsJobCacheBox = 'tts_job_cache';
const _defaultElevenLabsVoiceId = '21m00Tcm4TlvDq8ikWAM';

@LazySingleton(as: TtsRepository)
class TtsRepositoryImpl implements TtsRepository {
  TtsRepositoryImpl({
    required TtsRemoteDataSource remoteDataSource,
    required TtsQueueLocalDataSource queueDataSource,
    required NetworkInfo networkInfo,
    required HiveInterface hive,
  })  : _remoteDataSource = remoteDataSource,
        _queueDataSource = queueDataSource,
        _networkInfo = networkInfo,
        _hive = hive;

  final TtsRemoteDataSource _remoteDataSource;
  final TtsQueueLocalDataSource _queueDataSource;
  final NetworkInfo _networkInfo;
  final HiveInterface _hive;
  final Uuid _uuid = const Uuid();

  // Track items currently being processed to prevent race conditions
  final Set<String> _processingItemIds = {};

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
        // Queue the request for later processing
        final queueItem = TtsQueueModel(
          id: _uuid.v4(),
          sourceType: 'pdf',
          pdfUrl: pdfUrl,
          voice: voice,
          createdAt: DateTime.now(),
        );
        await _queueDataSource.addToQueue(queueItem);

        // Return a special failure that indicates the request was queued
        return Left(
          NetworkFailure(
            message: 'Request queued. Will be processed when online.',
          ),
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
        // Queue the request for later processing
        final queueItem = TtsQueueModel(
          id: _uuid.v4(),
          sourceType: 'text',
          text: text,
          voice: voice,
          createdAt: DateTime.now(),
        );
        await _queueDataSource.addToQueue(queueItem);

        // Return a special failure that indicates the request was queued
        return Left(
          NetworkFailure(
            message: 'Request queued. Will be processed when online.',
          ),
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

  /// Process all pending queued TTS jobs
  @override
  Future<void> processQueuedTtsJobs() async {
    try {
      final connected = await _networkInfo.isConnected;
      if (!connected) {
        return; // Not online, skip processing
      }

      // First, recover stuck "processing" items older than 5 minutes
      final allItems = await _queueDataSource.getAllItems();
      const processingTimeout = Duration(minutes: 5);
      final now = DateTime.now();

      for (final item in allItems) {
        if (item.status == 'processing' && item.updatedAt != null) {
          final timeSinceUpdate = now.difference(item.updatedAt!);
          if (timeSinceUpdate > processingTimeout) {
            // Skip if currently being processed (not truly stuck)
            if (_processingItemIds.contains(item.id)) {
              continue;
            }
            // Reset stuck processing item back to pending for retry
            await _queueDataSource.markAsPending(item.id);
          }
        }
      }

      final pendingItems = await _queueDataSource.getPendingItems();
      const maxRetries = 3;
      const requestTimeout = Duration(minutes: 10);

      for (final item in pendingItems) {
        // Skip items that have exceeded max retries (should already be filtered, but double-check)
        if (item.retryCount >= maxRetries) {
          continue;
        }

        // Skip items currently being processed (race condition protection)
        if (_processingItemIds.contains(item.id)) {
          continue;
        }

        // Lock item for processing
        _processingItemIds.add(item.id);

        try {
          // Mark as processing
          await _queueDataSource.markAsProcessing(item.id);

          TtsJobModel result;
          if (item.sourceType == 'text' && item.text != null) {
            result = await _remoteDataSource
                .convertTextToAudio(
              text: item.text!,
              voice: item.voice,
            )
                .timeout(
              requestTimeout,
              onTimeout: () {
                throw TimeoutException(
                  'Request timeout after ${requestTimeout.inMinutes} minutes',
                );
              },
            );
          } else if (item.sourceType == 'pdf' && item.pdfUrl != null) {
            result = await _remoteDataSource
                .convertPdfToAudio(
              pdfUrl: item.pdfUrl!,
              voice: item.voice,
            )
                .timeout(
              requestTimeout,
              onTimeout: () {
                throw TimeoutException(
                  'Request timeout after ${requestTimeout.inMinutes} minutes',
                );
              },
            );
          } else {
            await _queueDataSource.markAsFailed(
              item.id,
              'Invalid queue item: missing required data',
            );
            continue;
          }

          // Cache the result
          await _cacheTtsJob(result);

          // Mark as completed (removes from queue)
          await _queueDataSource.markAsCompleted(item.id);
        } on TimeoutException catch (error) {
          // Mark as failed due to timeout, will retry later
          await _queueDataSource.markAsFailed(
            item.id,
            error.toString(),
          );
        } catch (error) {
          // Mark as failed, will retry later
          await _queueDataSource.markAsFailed(
            item.id,
            error.toString(),
          );
        } finally {
          // Always unlock the item
          _processingItemIds.remove(item.id);
        }
      }
    } catch (error) {
      // Log error but don't throw - queue processing should be resilient
      // In production, you might want to log this to a monitoring service
    }
  }
}
