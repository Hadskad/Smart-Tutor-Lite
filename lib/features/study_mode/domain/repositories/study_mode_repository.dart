import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/flashcard.dart';
import '../entities/study_session.dart';

abstract class StudyModeRepository {
  /// Generate flashcards from a source (summary or transcription)
  Future<Either<Failure, List<Flashcard>>> generateFlashcards({
    required String sourceId,
    required String sourceType,
    int? numFlashcards,
  });

  /// Get all flashcards
  Future<Either<Failure, List<Flashcard>>> getAllFlashcards();

  /// Get flashcards by source
  Future<Either<Failure, List<Flashcard>>> getFlashcardsBySource({
    required String sourceId,
    required String sourceType,
  });

  /// Save a flashcard
  Future<Either<Failure, Flashcard>> saveFlashcard(Flashcard flashcard);

  /// Update flashcard progress (mark as known/unknown, update difficulty)
  Future<Either<Failure, Flashcard>> updateFlashcardProgress({
    required String flashcardId,
    bool? isKnown,
    FlashcardDifficulty? difficulty,
  });

  /// Delete a flashcard
  Future<Either<Failure, void>> deleteFlashcard(String flashcardId);

  /// Delete multiple flashcards at once
  Future<Either<Failure, void>> deleteFlashcards(List<String> flashcardIds);

  /// Start a new study session
  Future<Either<Failure, StudySession>> startStudySession({
    required List<String> flashcardIds,
  });

  /// Get a study session by ID
  Future<Either<Failure, StudySession>> getStudySession(String sessionId);

  /// Update study session progress
  Future<Either<Failure, StudySession>> updateStudySessionProgress({
    required String sessionId,
    int? cardsReviewed,
    int? cardsKnown,
    int? cardsUnknown,
  });

  /// End a study session
  Future<Either<Failure, StudySession>> endStudySession(String sessionId);

  /// Get all study sessions
  Future<Either<Failure, List<StudySession>>> getAllStudySessions();

  /// Get study progress statistics
  Future<Either<Failure, StudyProgress>> getStudyProgress();
}

class StudyProgress {
  const StudyProgress({
    this.totalFlashcards = 0,
    this.totalKnown = 0,
    this.totalUnknown = 0,
    this.totalReviewed = 0,
    this.totalSessions = 0,
    this.averageSessionDuration = 0,
    this.retentionRate = 0.0,
  });

  final int totalFlashcards;
  final int totalKnown;
  final int totalUnknown;
  final int totalReviewed;
  final int totalSessions;
  final int averageSessionDuration; // in seconds
  final double retentionRate; // percentage

  double get knownPercentage {
    if (totalFlashcards == 0) return 0.0;
    return (totalKnown / totalFlashcards) * 100;
  }
}

