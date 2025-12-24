import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/flashcard.dart';
import '../../domain/entities/study_session.dart';
import '../../domain/repositories/study_mode_repository.dart';
import '../datasources/flashcard_local_datasource.dart';
import '../datasources/flashcard_remote_datasource.dart';
import '../models/flashcard_model.dart';
import '../models/study_session_model.dart';

@LazySingleton(as: StudyModeRepository)
class StudyModeRepositoryImpl implements StudyModeRepository {
  StudyModeRepositoryImpl({
    required FlashcardRemoteDataSource remoteDataSource,
    required FlashcardLocalDataSource localDataSource,
    required NetworkInfo networkInfo,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _networkInfo = networkInfo;

  final FlashcardRemoteDataSource _remoteDataSource;
  final FlashcardLocalDataSource _localDataSource;
  final NetworkInfo _networkInfo;
  final _uuid = const Uuid();

  @override
  Future<Either<Failure, List<Flashcard>>> generateFlashcards({
    required String sourceId,
    required String sourceType,
    int? numFlashcards,
  }) async {
    try {
      final connected = await _networkInfo.isConnected;
      if (!connected) {
        return _fallbackToLocalFlashcards(
          sourceId: sourceId,
          sourceType: sourceType,
          failure: const NetworkFailure(message: 'No internet connection'),
        );
      }

      try {
        // Check for existing flashcards from this source to prevent duplicates
        final existingFlashcards = await _localDataSource.getFlashcardsBySource(
          sourceId: sourceId,
          sourceType: sourceType,
        );

        // If flashcards already exist, return them instead of generating new ones
        if (existingFlashcards.isNotEmpty) {
          return Right(existingFlashcards.map((m) => m.toEntity()).toList());
        }

        // Generate flashcards from remote API
        final remoteFlashcards = await _remoteDataSource.generateFlashcards(
          sourceId: sourceId,
          sourceType: sourceType,
          numFlashcards: numFlashcards,
        );

        // Ensure all flashcards have proper IDs
        final flashcardsWithIds = remoteFlashcards.map((fc) {
          if (fc.id.isEmpty) {
            return FlashcardModel(
              id: _uuid.v4(),
              front: fc.front,
              back: fc.back,
              sourceId: fc.sourceId,
              sourceType: fc.sourceType,
              createdAt: fc.createdAt ?? DateTime.now(),
              reviewCount: fc.reviewCount,
              difficulty: fc.difficulty,
              isKnown: fc.isKnown,
              metadata: fc.metadata,
            );
          }
          return fc;
        }).toList();

        // Save locally (offline-first)
        await _localDataSource.saveFlashcards(flashcardsWithIds);

        return Right(flashcardsWithIds.map((m) => m.toEntity()).toList());
      } on Failure catch (failure) {
        return _fallbackToLocalFlashcards(
          sourceId: sourceId,
          sourceType: sourceType,
          failure: failure,
        );
      } catch (error) {
        return _fallbackToLocalFlashcards(
          sourceId: sourceId,
          sourceType: sourceType,
          failure: ServerFailure(
            message: 'Failed to generate flashcards',
            cause: error,
          ),
        );
      }
    } on Failure catch (failure) {
      return Left(failure);
    } catch (error) {
      return Left(
        ServerFailure(
          message: 'Failed to generate flashcards',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<Flashcard>>> getAllFlashcards() async {
    try {
      final localFlashcards = await _localDataSource.getAllFlashcards();
      return Right(localFlashcards.map((m) => m.toEntity()).toList());
    } catch (error) {
      return Left(
        LocalFailure(
          message: 'Failed to get flashcards',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<Flashcard>>> getFlashcardsBySource({
    required String sourceId,
    required String sourceType,
  }) async {
    try {
      final localFlashcards = await _localDataSource.getFlashcardsBySource(
        sourceId: sourceId,
        sourceType: sourceType,
      );
      return Right(localFlashcards.map((m) => m.toEntity()).toList());
    } catch (error) {
      return Left(
        LocalFailure(
          message: 'Failed to get flashcards by source',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, Flashcard>> saveFlashcard(Flashcard flashcard) async {
    try {
      final model = FlashcardModel.fromEntity(flashcard);
      await _localDataSource.saveFlashcard(model);
      return Right(flashcard);
    } catch (error) {
      return Left(
        LocalFailure(
          message: 'Failed to save flashcard',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, Flashcard>> updateFlashcardProgress({
    required String flashcardId,
    bool? isKnown,
    FlashcardDifficulty? difficulty,
  }) async {
    try {
      final existing = await _localDataSource.getFlashcard(flashcardId);
      final updated = FlashcardModel(
        id: existing.id,
        front: existing.front,
        back: existing.back,
        sourceId: existing.sourceId,
        sourceType: existing.sourceType,
        createdAt: existing.createdAt,
        lastReviewedAt: DateTime.now(),
        reviewCount: existing.reviewCount + 1,
        difficulty: difficulty ?? existing.difficulty,
        isKnown: isKnown ?? existing.isKnown,
        metadata: existing.metadata,
      );
      await _localDataSource.saveFlashcard(updated);
      return Right(updated.toEntity());
    } catch (error) {
      return Left(
        LocalFailure(
          message: 'Failed to update flashcard progress',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, void>> deleteFlashcard(String flashcardId) async {
    try {
      await _localDataSource.deleteFlashcard(flashcardId);
      return const Right(null);
    } catch (error) {
      return Left(
        LocalFailure(
          message: 'Failed to delete flashcard',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, void>> deleteFlashcards(List<String> flashcardIds) async {
    try {
      await _localDataSource.deleteFlashcards(flashcardIds);
      return const Right(null);
    } catch (error) {
      return Left(
        LocalFailure(
          message: 'Failed to delete flashcards',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, StudySession>> startStudySession({
    required List<String> flashcardIds,
  }) async {
    try {
      final session = StudySessionModel(
        id: _uuid.v4(),
        flashcardIds: flashcardIds,
        startTime: DateTime.now(),
        cardsReviewed: 0,
        cardsKnown: 0,
        cardsUnknown: 0,
      );
      await _localDataSource.saveStudySession(session);
      return Right(session.toEntity());
    } catch (error) {
      return Left(
        LocalFailure(
          message: 'Failed to start study session',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, StudySession>> getStudySession(
      String sessionId) async {
    try {
      final session = await _localDataSource.getStudySession(sessionId);
      if (session == null) {
        return const Left(
          CacheFailure(message: 'Study session not found'),
        );
      }
      return Right(session.toEntity());
    } catch (error) {
      return Left(
        LocalFailure(
          message: 'Failed to get study session',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, StudySession>> updateStudySessionProgress({
    required String sessionId,
    int? cardsReviewed,
    int? cardsKnown,
    int? cardsUnknown,
  }) async {
    try {
      final existing = await _localDataSource.getStudySession(sessionId);
      if (existing == null) {
        return const Left(
          CacheFailure(message: 'Study session not found'),
        );
      }

      final updated = StudySessionModel(
        id: existing.id,
        flashcardIds: existing.flashcardIds,
        startTime: existing.startTime,
        endTime: existing.endTime,
        durationSeconds: existing.durationSeconds,
        cardsReviewed: cardsReviewed ?? existing.cardsReviewed,
        cardsKnown: cardsKnown ?? existing.cardsKnown,
        cardsUnknown: cardsUnknown ?? existing.cardsUnknown,
        flashcards: existing.flashcards,
        metadata: existing.metadata,
      );
      await _localDataSource.saveStudySession(updated);
      return Right(updated.toEntity());
    } catch (error) {
      return Left(
        LocalFailure(
          message: 'Failed to update study session progress',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, StudySession>> endStudySession(
      String sessionId) async {
    try {
      final existing = await _localDataSource.getStudySession(sessionId);
      if (existing == null) {
        return const Left(
          CacheFailure(message: 'Study session not found'),
        );
      }

      final endTime = DateTime.now();
      final duration = existing.startTime != null
          ? endTime.difference(existing.startTime!).inSeconds
          : 0;

      final updated = StudySessionModel(
        id: existing.id,
        flashcardIds: existing.flashcardIds,
        startTime: existing.startTime,
        endTime: endTime,
        durationSeconds: duration,
        cardsReviewed: existing.cardsReviewed,
        cardsKnown: existing.cardsKnown,
        cardsUnknown: existing.cardsUnknown,
        flashcards: existing.flashcards,
        metadata: existing.metadata,
      );
      await _localDataSource.saveStudySession(updated);
      return Right(updated.toEntity());
    } catch (error) {
      return Left(
        LocalFailure(
          message: 'Failed to end study session',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<StudySession>>> getAllStudySessions() async {
    try {
      final sessions = await _localDataSource.getAllStudySessions();
      return Right(sessions.map((m) => m.toEntity()).toList());
    } catch (error) {
      return Left(
        LocalFailure(
          message: 'Failed to get study sessions',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Either<Failure, StudyProgress>> getStudyProgress() async {
    try {
      final allFlashcards = await _localDataSource.getAllFlashcards();
      final allSessions = await _localDataSource.getAllStudySessions();

      final totalFlashcards = allFlashcards.length;
      final totalKnown = allFlashcards.where((fc) => fc.isKnown).length;
      final totalUnknown = totalFlashcards - totalKnown;
      final totalReviewed =
          allFlashcards.where((fc) => fc.reviewCount > 0).length;

      final completedSessions =
          allSessions.where((s) => s.endTime != null).toList();
      final totalSessions = completedSessions.length;

      final totalDuration = completedSessions
          .where((s) => s.durationSeconds != null)
          .fold<int>(0, (sum, s) => sum + (s.durationSeconds ?? 0));
      final averageSessionDuration =
          totalSessions > 0 ? totalDuration ~/ totalSessions : 0;

      final retentionRate =
          totalFlashcards > 0 ? (totalKnown / totalFlashcards) * 100 : 0.0;

      return Right(StudyProgress(
        totalFlashcards: totalFlashcards,
        totalKnown: totalKnown,
        totalUnknown: totalUnknown,
        totalReviewed: totalReviewed,
        totalSessions: totalSessions,
        averageSessionDuration: averageSessionDuration,
        retentionRate: retentionRate,
      ));
    } catch (error) {
      return Left(
        LocalFailure(
          message: 'Failed to get study progress',
          cause: error,
        ),
      );
    }
  }

  Future<Either<Failure, List<Flashcard>>> _fallbackToLocalFlashcards({
    required String sourceId,
    required String sourceType,
    required Failure failure,
  }) async {
    try {
      final localFlashcards = await _localDataSource.getFlashcardsBySource(
        sourceId: sourceId,
        sourceType: sourceType,
      );

      if (localFlashcards.isNotEmpty) {
        return Right(localFlashcards.map((m) => m.toEntity()).toList());
      }

      // Provide more context about why generation failed
      String errorMessage;
      if (failure is NetworkFailure) {
        errorMessage = 'No internet connection. Please connect to the internet to generate new flashcards.';
        return Left(NetworkFailure(
          message: errorMessage,
          cause: failure.cause,
        ));
      } else if (failure is ServerFailure) {
        errorMessage = 'Failed to generate flashcards: ${failure.message ?? "Server error"}. Please try again later.';
        return Left(ServerFailure(
          message: errorMessage,
          cause: failure.cause,
        ));
      } else {
        errorMessage = failure.message ?? 'Failed to generate flashcards. Please try again.';
        return Left(ServerFailure(
          message: errorMessage,
          cause: failure,
        ));
      }
    } catch (error) {
      // Combine original failure with cache error for better context
      final originalMessage = failure.message ?? 'Failed to generate flashcards';
      return Left(
        LocalFailure(
          message: '$originalMessage. Also failed to load cached flashcards: ${error.toString()}',
          cause: error,
        ),
      );
    }
  }
}
