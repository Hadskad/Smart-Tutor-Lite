import 'package:dartz/dartz.dart';
import 'package:hive/hive.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/summary.dart';
import '../../domain/repositories/summary_repository.dart';
import '../datasources/summary_remote_datasource.dart';
import '../models/summary_model.dart';

const _summaryCacheBox = 'summary_cache';

@LazySingleton(as: SummaryRepository)
class SummaryRepositoryImpl implements SummaryRepository {
  SummaryRepositoryImpl({
    required SummaryRemoteDataSource remoteDataSource,
    required NetworkInfo networkInfo,
    required HiveInterface hive,
  })  : _remoteDataSource = remoteDataSource,
        _networkInfo = networkInfo,
        _hive = hive;

  final SummaryRemoteDataSource _remoteDataSource;
  final NetworkInfo _networkInfo;
  final HiveInterface _hive;

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
        return const Left(
          NetworkFailure(message: 'No internet connection'),
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
        return const Left(
          NetworkFailure(message: 'No internet connection'),
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
}
