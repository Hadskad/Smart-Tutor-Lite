import 'package:equatable/equatable.dart';

import '../../domain/entities/flashcard.dart';
import '../../domain/entities/study_session.dart';
import '../../domain/repositories/study_mode_repository.dart';

abstract class StudyModeState extends Equatable {
  const StudyModeState();

  @override
  List<Object?> get props => [];
}

class StudyModeInitial extends StudyModeState {
  const StudyModeInitial();
}

class StudyModeLoading extends StudyModeState {
  const StudyModeLoading();
}

class StudyModeFlashcardsLoaded extends StudyModeState {
  const StudyModeFlashcardsLoaded({
    required this.flashcards,
  });

  final List<Flashcard> flashcards;

  @override
  List<Object?> get props => [flashcards];
}

class StudyModeSessionActive extends StudyModeState {
  const StudyModeSessionActive({
    required this.session,
    required this.currentFlashcardIndex,
    required this.currentFlashcard,
    this.isFlipped = false,
  });

  final StudySession session;
  final int currentFlashcardIndex;
  final Flashcard currentFlashcard;
  final bool isFlipped;

  StudyModeSessionActive copyWith({
    StudySession? session,
    int? currentFlashcardIndex,
    Flashcard? currentFlashcard,
    bool? isFlipped,
  }) {
    return StudyModeSessionActive(
      session: session ?? this.session,
      currentFlashcardIndex:
          currentFlashcardIndex ?? this.currentFlashcardIndex,
      currentFlashcard: currentFlashcard ?? this.currentFlashcard,
      isFlipped: isFlipped ?? this.isFlipped,
    );
  }

  bool get hasNext => currentFlashcardIndex < session.flashcardIds.length - 1;
  bool get hasPrevious => currentFlashcardIndex > 0;
  double get progress => (session.cardsReviewed / session.flashcardIds.length);

  @override
  List<Object?> get props => [
        session,
        currentFlashcardIndex,
        currentFlashcard,
        isFlipped,
      ];
}

class StudyModeSessionCompleted extends StudyModeState {
  const StudyModeSessionCompleted({
    required this.session,
    required this.flashcards,
  });

  final StudySession session;
  final List<Flashcard> flashcards;

  @override
  List<Object?> get props => [session, flashcards];
}

class StudyModeProgressLoaded extends StudyModeState {
  const StudyModeProgressLoaded({
    required this.progress,
  });

  final StudyProgress progress;

  @override
  List<Object?> get props => [progress];
}

class StudyModeError extends StudyModeState {
  const StudyModeError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

