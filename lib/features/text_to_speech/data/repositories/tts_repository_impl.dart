import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';
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
const _defaultGoogleVoiceId = 'en-US-Neural2-D';

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
  final Dio _dio = Dio();

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
    String voice = _defaultGoogleVoiceId,
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
    String voice = _defaultGoogleVoiceId,
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
      
      // Check for local audio paths for each completed job
      final jobsWithLocalPaths = <TtsJob>[];
      for (final job in cached) {
        if (job.status == 'completed' && job.audioUrl.isNotEmpty) {
          // Check if local path is already set or exists
          String? localPath = job.localPath;
          if (localPath == null || localPath.isEmpty) {
            localPath = await _getLocalAudioPath(job.id);
            if (localPath != null) {
              // Update cache with local path
              final updatedJob = job.copyWith(localPath: localPath);
              await _cacheTtsJob(updatedJob);
              jobsWithLocalPaths.add(updatedJob.toEntity());
              continue;
            }
          }
        }
        jobsWithLocalPaths.add(job.toEntity());
      }
      
      return Right(jobsWithLocalPaths);
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
      // Delete from local cache
      final box = await _openCacheBox();
      await box.delete(id);
      
      // Delete local audio file if exists
      try {
        final localPath = await _getLocalAudioPath(id);
        if (localPath != null) {
          final file = File(localPath);
          if (await file.exists()) {
            await file.delete();
            debugPrint('Deleted local audio file for job $id');
          }
        }
      } catch (e) {
        // Ignore errors deleting local file
        debugPrint('Failed to delete local audio file for job $id: $e');
      }
      
      // Delete from remote backend (if online)
      try {
        final connected = await _networkInfo.isConnected;
        if (connected) {
          await _remoteDataSource.deleteTtsJob(id);
          debugPrint('Deleted TTS job from backend: $id');
        }
      } catch (e) {
        // Don't fail if remote delete fails - local is already deleted
        debugPrint('Failed to delete TTS job from backend: $e');
      }
      
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

      // Recover stuck "processing" items
      // For async batch processing, very large jobs can take hours
      // Use 24-hour timeout to allow legitimate long-running batch jobs to complete
      final allItems = await _queueDataSource.getAllItems();
      const recoveryTimeout = Duration(hours: 24); // 24 hours for very large batch jobs
      final now = DateTime.now();

      for (final item in allItems) {
        if (item.status == 'processing' && item.updatedAt != null) {
          final timeSinceUpdate = now.difference(item.updatedAt!);
          if (timeSinceUpdate > recoveryTimeout) {
            // After app restart, _processingItemIds is always empty,
            // so we reset all items that exceed the timeout
            // The recoveryTimeout ensures we don't reset legitimately processing items
            await _queueDataSource.markAsPending(item.id);
          }
        }
      }

      final pendingItems = await _queueDataSource.getPendingItems();
      const maxRetries = 3;
      // No request timeout - async batch jobs are handled by backend
      // The backend submits the job and returns immediately, then polls for completion

      for (final item in pendingItems) {
        // Skip items that have exceeded max retries (should already be filtered, but double-check)
        if (item.retryCount >= maxRetries) {
          continue;
        }

        // Atomically lock item for processing (skip if already processing)
       if (!_processingItemIds.add(item.id)) {
         continue; // Item already being processed
      }

        try {
          // Mark as processing
          await _queueDataSource.markAsProcessing(item.id);

          TtsJobModel result;
          if (item.sourceType == 'text' && item.text != null) {
            // For async batch processing, the backend submits the job and returns immediately
            // No timeout needed - job submission is fast, processing happens asynchronously
            result = await _remoteDataSource.convertTextToAudio(
              text: item.text!,
              voice: item.voice,
            );
          } else if (item.sourceType == 'pdf' && item.pdfUrl != null) {
            // For async batch processing, the backend submits the job and returns immediately
            // No timeout needed - job submission is fast, processing happens asynchronously
            result = await _remoteDataSource.convertPdfToAudio(
              pdfUrl: item.pdfUrl!,
              voice: item.voice,
            );
          } else {
            await _queueDataSource.markAsFailed(
              item.id,
              'Invalid queue item: missing required data',
            );
            continue;
          }

          // Cache the job metadata (includes audioUrl when job completes)
          await _cacheTtsJob(result);

          // If job is completed and has audio URL, download audio for offline access
          if (result.status == 'completed' && result.audioUrl.isNotEmpty) {
            try {
              await _downloadAudioToLocalCache(result);
            } catch (error) {
              // Don't fail the job if download fails - metadata is already cached
              // Audio can still be accessed via URL when online
              // Log error for monitoring
              debugPrint('Failed to download audio for job ${result.id}: $error');
            }
          }

          // Mark as completed (removes from queue)
          await _queueDataSource.markAsCompleted(item.id);
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

  /// Download audio file from Firebase Storage URL to local cache
  /// Stores audio in app's documents directory for offline access
  /// Returns the local path if successful, null otherwise
  Future<String?> _downloadAudioToLocalCache(TtsJobModel job) async {
    if (job.audioUrl.isEmpty) {
      return null; // No audio URL to download
    }

    try {
      // Get app's documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final audioDir = Directory('${appDir.path}/tts_audio_cache');
      if (!await audioDir.exists()) {
        await audioDir.create(recursive: true);
      }

      // Download audio file
      final audioPath = '${audioDir.path}/${job.id}.mp3';
      final response = await _dio.download(
        job.audioUrl,
        audioPath,
        options: Options(
          receiveTimeout: const Duration(minutes: 10), // 10 min timeout for download
          followRedirects: true,
        ),
      );

      if (response.statusCode == 200) {
        debugPrint('Audio downloaded successfully for job ${job.id} to $audioPath');
        
        // Update the cached job with the local path
        final updatedJob = job.copyWith(localPath: audioPath);
        await _cacheTtsJob(updatedJob);
        
        return audioPath;
      }
      return null;
    } catch (error) {
      // Download failed - don't throw, just log
      // The audioUrl in cached metadata can still be used when online
      debugPrint('Failed to download audio for job ${job.id}: $error');
      return null;
    }
  }

  /// Check if audio file exists locally and return the path
  Future<String?> _getLocalAudioPath(String jobId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final audioPath = '${appDir.path}/tts_audio_cache/$jobId.mp3';
      final file = File(audioPath);
      if (await file.exists()) {
        return audioPath;
      }
    } catch (e) {
      // Ignore errors - just return null
    }
    return null;
  }
}
