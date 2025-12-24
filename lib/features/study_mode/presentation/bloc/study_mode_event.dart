import 'package:equatable/equatable.dart';

import '../../domain/entities/flashcard.dart';

abstract class StudyModeEvent extends Equatable {
  const StudyModeEvent();

  @override
  List<Object?> get props => [];
}

class GenerateFlashcardsEvent extends StudyModeEvent {
  const GenerateFlashcardsEvent({
    required this.sourceId,
    required this.sourceType,
    this.numFlashcards = 10,
  });

  final String sourceId;
  final String sourceType; // 'transcription' or 'summary'
  final int numFlashcards;

  @override
  List<Object?> get props => [sourceId, sourceType, numFlashcards];
}

class LoadFlashcardsEvent extends StudyModeEvent {
  const LoadFlashcardsEvent();
}

class LoadFlashcardsBySourceEvent extends StudyModeEvent {
  const LoadFlashcardsBySourceEvent({
    required this.sourceId,
    required this.sourceType,
  });

  final String sourceId;
  final String sourceType;

  @override
  List<Object?> get props => [sourceId, sourceType];
}

class StartStudySessionEvent extends StudyModeEvent {
  const StartStudySessionEvent({
    required this.flashcardIds,
    this.shuffle = false,
  });

  final List<String> flashcardIds;
  final bool shuffle;

  @override
  List<Object?> get props => [flashcardIds, shuffle];
}

class MarkFlashcardKnownEvent extends StudyModeEvent {
  const MarkFlashcardKnownEvent({
    required this.flashcardId,
    this.difficulty,
  });

  final String flashcardId;
  final FlashcardDifficulty? difficulty;

  @override
  List<Object?> get props => [flashcardId, difficulty];
}

class MarkFlashcardUnknownEvent extends StudyModeEvent {
  const MarkFlashcardUnknownEvent({
    required this.flashcardId,
    this.difficulty,
  });

  final String flashcardId;
  final FlashcardDifficulty? difficulty;

  @override
  List<Object?> get props => [flashcardId, difficulty];
}

class EndStudySessionEvent extends StudyModeEvent {
  const EndStudySessionEvent();
}

class DeleteFlashcardEvent extends StudyModeEvent {
  const DeleteFlashcardEvent(this.flashcardId);

  final String flashcardId;

  @override
  List<Object?> get props => [flashcardId];
}

/// Event to delete multiple flashcards at once (batch operation)
class DeleteFlashcardsBatchEvent extends StudyModeEvent {
  const DeleteFlashcardsBatchEvent(this.flashcardIds);

  final List<String> flashcardIds;

  @override
  List<Object?> get props => [flashcardIds];
}

class LoadProgressEvent extends StudyModeEvent {
  const LoadProgressEvent();
}

class FlipCardEvent extends StudyModeEvent {
  const FlipCardEvent();
}

/// Event to undo the last card marking action
class UndoLastActionEvent extends StudyModeEvent {
  const UndoLastActionEvent();
}
