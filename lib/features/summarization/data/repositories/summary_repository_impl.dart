import 'package:dartz/dartz.dart';
import 'package:hive/hive.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/summary.dart';
import '../../domain/repositories/summary_repository.dart';
import '../datasources/summary_queue_local_datasource.dart';
import '../datasources/summary_remote_datasource.dart';
import '../models/summary_model.dart';
import '../models/summary_queue_model.dart';

const _summaryCacheBox = 'summary_cache';

@LazySingleton(as: SummaryRepository)
class SummaryRepositoryImpl implements SummaryRepository {
  SummaryRepositoryImpl({
    required SummaryRemoteDataSource remoteDataSource,
    required SummaryQueueLocalDataSource queueDataSource,
    required NetworkInfo networkInfo,
    required HiveInterface hive,
  })  : _remoteDataSource = remoteDataSource,
        _queueDataSource = queueDataSource,
        _networkInfo = networkInfo,
        _hive = hive;

  final SummaryRemoteDataSource _remoteDataSource;
  final SummaryQueueLocalDataSource _queueDataSource;
  final NetworkInfo _networkInfo;
  final HiveInterface _hive;
  final Uuid _uuid = const Uuid();

  Future<Box<Map>> _openCacheBox() async {
    if (_hive.isBoxOpen(_summaryCacheBox)) {
      return _hive.box<Map>(_summaryCacheBox);
    }
    return _hive.openBox<Map>(_summaryCacheBox);
  }

  Future<void> _cacheSummary(SummaryModel model) async {
    final box = await _openCacheBox();
    await box.put(model.id, model.toJson());
  }

  Future<SummaryModel?> _readFromCache(String id) async {
    final box = await _openCacheBox();
    final data = box.get(id);
    if (data == null) {
      return null;
    }
    return SummaryModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<List<SummaryModel>> _getAllFromCache() async {
    final box = await _openCacheBox();
    final summaries = <SummaryModel>[];
    for (final key in box.keys) {
      final data = box.get(key);
      if (data != null) {
        summaries.add(
          SummaryModel.fromJson(Map<String, dynamic>.from(data)),
        );
      }
    }
    summaries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return summaries;
  }

  @override
  Future<Either<Failure, Summary>> summarizeText({
    required String text,
    int maxLength = 200,
  }) async {
    try {
      // Check if online before attempting remote call
      final connected = await _networkInfo.isConnected;
      if (!connected) {
        // Queue the request for later processing
        final queueItem = SummaryQueueModel(
          id: _uuid.v4(),
          sourceType: 'text',
          text: text,
          maxLength: maxLength,
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
      final remoteModel = await _remoteDataSource.summarizeText(
        text: text,
        maxLength: maxLength,
      );

      // Cache locally
      await _cacheSummary(remoteModel);

      return Right(remoteModel.toEntity());
    } on Failure catch (failure) {
      return Left(failure);
    } catch (error) {
      return Left(
        ServerFailure(
          message: 'Failed to summarize text',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, Summary>> summarizePdf({
    required String pdfUrl,
    int maxLength = 200,
  }) async {
    try {
      // Check if online before attempting remote call
      final connected = await _networkInfo.isConnected;
      if (!connected) {
        // Queue the request for later processing
        final queueItem = SummaryQueueModel(
          id: _uuid.v4(),
          sourceType: 'pdf',
          pdfUrl: pdfUrl,
          maxLength: maxLength,
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
      final remoteModel = await _remoteDataSource.summarizePdf(
        pdfUrl: pdfUrl,
        maxLength: maxLength,
      );

      // Cache locally
      await _cacheSummary(remoteModel);

      return Right(remoteModel.toEntity());
    } on Failure catch (failure) {
      return Left(failure);
    } catch (error) {
      return Left(
        ServerFailure(
          message: 'Failed to summarize PDF',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, Summary>> getSummary(String id) async {
    try {
      // Try cache first
      final cached = await _readFromCache(id);
      if (cached != null) {
        return Right(cached.toEntity());
      }

      // If not in cache and online, fetch from remote
      if (await _networkInfo.isConnected) {
        final remoteModel = await _remoteDataSource.getSummary(id);
        await _cacheSummary(remoteModel);
        return Right(remoteModel.toEntity());
      }

      return const Left(
        CacheFailure(message: 'Summary not found locally'),
      );
    } on Failure catch (failure) {
      return Left(failure);
    } catch (error) {
      return Left(
        LocalFailure(
          message: 'Failed to get summary',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<Summary>>> getAllSummaries() async {
    try {
      // Get from cache (offline-first)
      final cached = await _getAllFromCache();
      return Right(cached.map((model) => model.toEntity()).toList());
    } catch (error) {
      return Left(
        LocalFailure(
          message: 'Failed to get summaries',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteSummary(String id) async {
    try {
      final box = await _openCacheBox();
      await box.delete(id);

      // If online, also delete from remote (fire and forget)
      if (await _networkInfo.isConnected) {
        // Note: Remote delete endpoint not implemented yet
        // When implemented, call: await _remoteDataSource.deleteSummary(id);
      }

      return const Right(unit);
    } catch (error) {
      return Left(
        LocalFailure(
          message: 'Failed to delete summary',
          cause: error,
        ),
      );
    }
  }

  /// Process all pending queued summaries
  Future<void> processQueuedSummaries() async {
    try {
      final connected = await _networkInfo.isConnected;
      if (!connected) {
        return; // Not online, skip processing
      }

      final pendingItems = await _queueDataSource.getPendingItems();
      const maxRetries = 3;

      for (final item in pendingItems) {
        // Skip items that have exceeded max retries
        if (item.retryCount >= maxRetries) {
          await _queueDataSource.markAsFailed(
            item.id,
            'Maximum retry count exceeded',
          );
          continue;
        }

        try {
          // Mark as processing
          await _queueDataSource.markAsProcessing(item.id);

          SummaryModel result;
          if (item.sourceType == 'text' && item.text != null) {
            result = await _remoteDataSource.summarizeText(
              text: item.text!,
              maxLength: item.maxLength,
            );
          } else if (item.sourceType == 'pdf' && item.pdfUrl != null) {
            result = await _remoteDataSource.summarizePdf(
              pdfUrl: item.pdfUrl!,
              maxLength: item.maxLength,
            );
          } else {
            await _queueDataSource.markAsFailed(
              item.id,
              'Invalid queue item: missing required data',
            );
            continue;
          }

          // Cache the result
          await _cacheSummary(result);

          // Mark as completed (removes from queue)
          await _queueDataSource.markAsCompleted(item.id);
        } catch (error) {
          // Mark as failed, will retry later
          await _queueDataSource.markAsFailed(
            item.id,
            error.toString(),
          );
        }
      }
    } catch (error) {
      // Log error but don't throw - queue processing should be resilient
      // In production, you might want to log this to a monitoring service
    }
  }
}
