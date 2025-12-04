import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/transcription_job.dart';
import '../../domain/entities/transcription_job_request.dart';
import '../../domain/repositories/transcription_job_repository.dart';
import '../datasources/transcription_job_remote_datasource.dart';

@LazySingleton(as: TranscriptionJobRepository)
class TranscriptionJobRepositoryImpl implements TranscriptionJobRepository {
  TranscriptionJobRepositoryImpl(
    this._remoteDataSource,
    this._networkInfo,
  );

  final TranscriptionJobRemoteDataSource _remoteDataSource;
  final NetworkInfo _networkInfo;

  @override
  Future<Either<Failure, TranscriptionJob>> createOnlineJob(
    TranscriptionJobRequest request,
  ) async {
    if (!await _networkInfo.isConnected) {
      return const Left(
        NetworkFailure(message: 'Internet connection is required'),
      );
    }
    try {
      final result = await _remoteDataSource.createOnlineJob(request);
      return Right(result);
    } on Failure catch (failure) {
      return Left(failure);
    } catch (error) {
      return Left(ServerFailure(
        message: 'Failed to create transcription job',
        cause: error,
      ));
    }
  }

  @override
  Stream<Either<Failure, TranscriptionJob>> watchJob(String jobId) {
    return _remoteDataSource
        .watchJob(jobId)
        .map<Either<Failure, TranscriptionJob>>(
          (job) => Right<Failure, TranscriptionJob>(job),
        )
        .transform(
      StreamTransformer.fromHandlers(
        handleError: (error, stackTrace, sink) {
          if (error is Failure) {
            sink.add(Left(error));
          } else {
            sink.add(
              Left(
                ServerFailure(
                  message: 'Failed to listen to job updates',
                  cause: error,
                ),
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Future<Either<Failure, Unit>> cancelJob(String jobId, {String? reason}) async {
    try {
      await _remoteDataSource.cancelJob(jobId, reason: reason);
      return const Right(unit);
    } on Failure catch (failure) {
      return Left(failure);
    } catch (error) {
      return Left(ServerFailure(
        message: 'Unable to cancel transcription job',
        cause: error,
      ));
    }
  }

  @override
  Future<Either<Failure, Unit>> requestRetry(String jobId, {String? reason}) async {
    try {
      await _remoteDataSource.requestRetry(jobId, reason: reason);
      return const Right(unit);
    } on Failure catch (failure) {
      return Left(failure);
    } catch (error) {
      return Left(ServerFailure(
        message: 'Unable to request job retry',
        cause: error,
      ));
    }
  }

  @override
  Future<Either<Failure, Unit>> requestNoteRetry(
    String jobId, {
    String? reason,
  }) async {
    try {
      await _remoteDataSource.requestNoteRetry(jobId, reason: reason);
      return const Right(unit);
    } on Failure catch (failure) {
      return Left(failure);
    } catch (error) {
      return Left(ServerFailure(
        message: 'Unable to retry note generation',
        cause: error,
      ));
    }
  }
}

