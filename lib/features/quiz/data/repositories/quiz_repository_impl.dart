import 'package:dartz/dartz.dart';
import 'package:hive/hive.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/quiz.dart';
import '../../domain/entities/quiz_result.dart';
import '../../domain/repositories/quiz_repository.dart';
import '../datasources/quiz_queue_local_datasource.dart';
import '../datasources/quiz_remote_datasource.dart';
import '../models/quiz_model.dart';
import '../models/quiz_queue_model.dart';
import '../models/quiz_result_model.dart';

const _quizCacheBoxName = 'quiz_cache';
const _quizResultCacheBoxName = 'quiz_result_cache';

@LazySingleton(as: QuizRepository)
class QuizRepositoryImpl implements QuizRepository {
  QuizRepositoryImpl({
    required QuizRemoteDataSource remoteDataSource,
    required QuizQueueLocalDataSource queueDataSource,
    required NetworkInfo networkInfo,
    required HiveInterface hive,
  })  : _remoteDataSource = remoteDataSource,
        _queueDataSource = queueDataSource,
        _networkInfo = networkInfo,
        _hive = hive;

  final QuizRemoteDataSource _remoteDataSource;
  final QuizQueueLocalDataSource _queueDataSource;
  final NetworkInfo _networkInfo;
  final HiveInterface _hive;
  final Uuid _uuid = const Uuid();
  Box<Map>? _quizCacheBox;
  Box<Map>? _quizResultCacheBox;

  Future<Box<Map>> _getQuizCacheBox() async {
    if (_quizCacheBox?.isOpen ?? false) {
      return _quizCacheBox!;
    }
    _quizCacheBox = await _hive.openBox<Map>(_quizCacheBoxName);
    return _quizCacheBox!;
  }

  Future<Box<Map>> _getQuizResultCacheBox() async {
    if (_quizResultCacheBox?.isOpen ?? false) {
      return _quizResultCacheBox!;
    }
    _quizResultCacheBox = await _hive.openBox<Map>(_quizResultCacheBoxName);
    return _quizResultCacheBox!;
  }

  Future<void> _cacheQuiz(QuizModel model) async {
    final box = await _getQuizCacheBox();
    await box.put(model.id, model.toJson());
  }

  Future<QuizModel?> _readQuizFromCache(String id) async {
    final box = await _getQuizCacheBox();
    final data = box.get(id);
    if (data == null) {
      return null;
    }
    return QuizModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<List<QuizModel>> _getAllQuizzesFromCache() async {
    final box = await _getQuizCacheBox();
    final quizzes = <QuizModel>[];
    for (final key in box.keys) {
      final data = box.get(key);
      if (data != null) {
        quizzes.add(QuizModel.fromJson(Map<String, dynamic>.from(data)));
      }
    }
    quizzes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return quizzes;
  }

  Future<void> _cacheQuizResult(QuizResultModel model) async {
    final box = await _getQuizResultCacheBox();
    await box.put(model.quizId, model.toJson());
  }

  Future<QuizResultModel?> _readQuizResultFromCache(String quizId) async {
    final box = await _getQuizResultCacheBox();
    final data = box.get(quizId);
    if (data == null) {
      return null;
    }
    return QuizResultModel.fromJson(Map<String, dynamic>.from(data));
  }

  @override
  Future<Either<Failure, Quiz>> generateQuiz({
    required String sourceId,
    required String sourceType,
    int numQuestions = 5,
    String difficulty = 'medium',
  }) async {
    try {
      // Check if online before attempting remote call
      final connected = await _networkInfo.isConnected;
      if (!connected) {
        // Queue the request for later processing
        final queueItem = QuizQueueModel(
          id: _uuid.v4(),
          sourceId: sourceId,
          sourceType: sourceType,
          numQuestions: numQuestions,
          difficulty: difficulty,
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
      final remoteModel = await _remoteDataSource.generateQuiz(
        sourceId: sourceId,
        sourceType: sourceType,
        numQuestions: numQuestions,
        difficulty: difficulty,
      );

      // Cache locally
      await _cacheQuiz(remoteModel);

      return Right(remoteModel.toEntity());
    } on Failure catch (failure) {
      return Left(failure);
    } catch (error) {
      return Left(
        ServerFailure(
          message: 'Failed to generate quiz',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, Quiz>> getQuiz(String id) async {
    try {
      // Try cache first
      final cached = await _readQuizFromCache(id);
      if (cached != null) {
        return Right(cached.toEntity());
      }

      // If not in cache and online, fetch from remote
      if (await _networkInfo.isConnected) {
        final remoteModel = await _remoteDataSource.getQuiz(id);
        await _cacheQuiz(remoteModel);
        return Right(remoteModel.toEntity());
      }

      return const Left(
        CacheFailure(message: 'Quiz not found locally'),
      );
    } on Failure catch (failure) {
      return Left(failure);
    } catch (error) {
      return Left(
        LocalFailure(
          message: 'Failed to get quiz',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<Quiz>>> getAllQuizzes() async {
    try {
      // Get from cache (offline-first)
      final cached = await _getAllQuizzesFromCache();
      return Right(cached.map((model) => model.toEntity()).toList());
    } catch (error) {
      return Left(
        LocalFailure(
          message: 'Failed to get quizzes',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, QuizResult>> submitQuiz({
    required String quizId,
    required Map<String, int> answers,
  }) async {
    try {
      // Get quiz to calculate score
      final quizResult = await getQuiz(quizId);
      return quizResult.fold(
        (failure) => Left(failure),
        (quiz) async {
          // Calculate score locally
          int score = 0;
          for (final question in quiz.questions) {
            final selectedAnswer = answers[question.id];
            if (selectedAnswer == question.correctAnswer) {
              score++;
            }
          }

          final result = QuizResultModel(
            quizId: quizId,
            answers: answers,
            score: score,
            totalQuestions: quiz.questions.length,
            completedAt: DateTime.now(),
          );

          // Cache result locally
          await _cacheQuizResult(result);

          return Right(result.toEntity());
        },
      );
    } catch (error) {
      return Left(
        LocalFailure(
          message: 'Failed to submit quiz',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, QuizResult>> getQuizResults(String quizId) async {
    try {
      final cached = await _readQuizResultFromCache(quizId);
      if (cached != null) {
        return Right(cached.toEntity());
      }

      return const Left(
        CacheFailure(message: 'Quiz results not found'),
      );
    } catch (error) {
      return Left(
        LocalFailure(
          message: 'Failed to get quiz results',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteQuiz(String id) async {
    try {
      final box = await _getQuizCacheBox();
      await box.delete(id);

      // Also delete associated result
      final resultBox = await _getQuizResultCacheBox();
      await resultBox.delete(id);

      return const Right(unit);
    } catch (error) {
      return Left(
        LocalFailure(
          message: 'Failed to delete quiz',
          cause: error,
        ),
      );
    }
  }

  /// Process all pending queued quizzes
  Future<void> processQueuedQuizzes() async {
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

          // Call remote API
          final result = await _remoteDataSource.generateQuiz(
            sourceId: item.sourceId,
            sourceType: item.sourceType,
            numQuestions: item.numQuestions,
            difficulty: item.difficulty,
          );

          // Cache the result
          await _cacheQuiz(result);

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
