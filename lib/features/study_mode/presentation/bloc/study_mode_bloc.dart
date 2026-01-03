import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/utils/logger.dart';
import '../../../../native_bridge/performance_bridge.dart';
import '../../domain/entities/flashcard.dart';
import '../../domain/entities/study_session.dart';
import '../../domain/repositories/study_mode_repository.dart';
import '../../domain/usecases/generate_flashcards.dart';
import '../../domain/usecases/get_progress.dart';
import '../../domain/usecases/start_study_session.dart';
import '../../domain/usecases/update_progress.dart';
import '../bloc/study_mode_event.dart';
import '../bloc/study_mode_state.dart';

@lazySingleton
class StudyModeBloc extends Bloc<StudyModeEvent, StudyModeState> {
  StudyModeBloc(
    this._generateFlashcards,
    this._startStudySession,
    this._updateProgress,
    this._getProgress,
    this._repository,
    this._performanceBridge,
    this._logger,
  ) : super(const StudyModeInitial()) {
    on<GenerateFlashcardsEvent>(_onGenerateFlashcards);
    on<LoadFlashcardsEvent>(_onLoadFlashcards);
    on<LoadFlashcardsBySourceEvent>(_onLoadFlashcardsBySource);
    on<StartStudySessionEvent>(_onStartStudySession);
    on<MarkFlashcardKnownEvent>(_onMarkFlashcardKnown);
    on<MarkFlashcardUnknownEvent>(_onMarkFlashcardUnknown);
    on<EndStudySessionEvent>(_onEndStudySession);
    on<DeleteFlashcardEvent>(_onDeleteFlashcard);
    on<DeleteFlashcardsBatchEvent>(_onDeleteFlashcardsBatch);
    on<LoadProgressEvent>(_onLoadProgress);
    on<FlipCardEvent>(_onFlipCard);
    on<UndoLastActionEvent>(_onUndoLastAction);
  }

  final GenerateFlashcards _generateFlashcards;
  final StartStudySession _startStudySession;
  final UpdateProgress _updateProgress;
  final GetProgress _getProgress;
  final StudyModeRepository _repository;
  final PerformanceBridge _performanceBridge;
  final AppLogger _logger;

  StudyModeSessionActive? _currentSessionState;
  List<Flashcard>? _sessionFlashcardsCache;
  bool _isGeneratingFlashcards = false;

  // Undo support: store history of session states
  final List<_SessionHistoryEntry> _sessionHistory = [];

  Future<void> _onGenerateFlashcards(
    GenerateFlashcardsEvent event,
    Emitter<StudyModeState> emit,
  ) async {
    // Prevent concurrent generation for the same source
    if (_isGeneratingFlashcards) {
      emit(const StudyModeError(
        'Flashcard generation already in progress. Please wait.',
      ));
      return;
    }

    _isGeneratingFlashcards = true;
    emit(const StudyModeLoading());

    const segmentId = 'flashcard_generation';
    await _performanceBridge.startSegment(segmentId);
    try {
      final result = await _generateFlashcards(
        sourceId: event.sourceId,
        sourceType: event.sourceType,
        numFlashcards: event.numFlashcards,
      );

      result.fold(
        (failure) {
          emit(StudyModeError(
              failure.message ?? 'Failed to generate flashcards'));
        },
        (flashcards) {
          // Repository already handles duplicates, just emit the result
          emit(StudyModeFlashcardsLoaded(
            flashcards: List.unmodifiable(flashcards),
          ));
        },
      );
    } finally {
      _isGeneratingFlashcards = false;
      await _logMetrics(segmentId);
    }
  }

  Future<void> _onLoadFlashcards(
    LoadFlashcardsEvent event,
    Emitter<StudyModeState> emit,
  ) async {
    emit(const StudyModeLoading());

    final result = await _repository.getAllFlashcards();

    result.fold(
      (failure) => emit(
        StudyModeError(failure.message ?? 'Failed to load flashcards'),
      ),
      (flashcards) {
        emit(StudyModeFlashcardsLoaded(
          flashcards: List.unmodifiable(flashcards),
        ));
      },
    );
  }

  Future<void> _onLoadFlashcardsBySource(
    LoadFlashcardsBySourceEvent event,
    Emitter<StudyModeState> emit,
  ) async {
    emit(const StudyModeLoading());

    final result = await _repository.getFlashcardsBySource(
      sourceId: event.sourceId,
      sourceType: event.sourceType,
    );

    result.fold(
      (failure) => emit(
        StudyModeError(failure.message ?? 'Failed to load flashcards'),
      ),
      (flashcards) {
        emit(StudyModeFlashcardsLoaded(
          flashcards: List.unmodifiable(flashcards),
        ));
      },
    );
  }

  Future<void> _onStartStudySession(
    StartStudySessionEvent event,
    Emitter<StudyModeState> emit,
  ) async {
    emit(const StudyModeLoading());

    final result = await _startStudySession(flashcardIds: event.flashcardIds);

    result.fold(
      (failure) => emit(
        StudyModeError(failure.message ?? 'Failed to start study session'),
      ),
      (session) async {
        // Load the first flashcard
        if (session.flashcardIds.isEmpty) {
          emit(const StudyModeError('No flashcards to study'));
          return;
        }

        // Get all flashcards to find the ones in the session
        final allFlashcardsResult = await _repository.getAllFlashcards();
        allFlashcardsResult.fold(
          (failure) => emit(
            StudyModeError(failure.message ?? 'Failed to load flashcards'),
          ),
          (allFlashcards) {
            var sessionFlashcards = allFlashcards
                .where((fc) => session.flashcardIds.contains(fc.id))
                .toList();

            if (sessionFlashcards.isEmpty) {
              emit(const StudyModeError('Flashcards not found'));
              return;
            }

            // Shuffle if requested
            if (event.shuffle) {
              sessionFlashcards = List.from(sessionFlashcards)..shuffle();
            }

            // Cache the session flashcards to avoid repeated DB calls
            _sessionFlashcardsCache = sessionFlashcards;

            // Clear history for new session
            _sessionHistory.clear();

            final currentFlashcard = sessionFlashcards.first;
            _currentSessionState = StudyModeSessionActive(
              session: session,
              currentFlashcardIndex: 0,
              currentFlashcard: currentFlashcard,
              isFlipped: false,
            );

            emit(_currentSessionState!);
          },
        );
      },
    );
  }

  Future<void> _onMarkFlashcardKnown(
    MarkFlashcardKnownEvent event,
    Emitter<StudyModeState> emit,
  ) async {
    if (_currentSessionState == null) {
      emit(const StudyModeError('No active study session'));
      return;
    }

    final result = await _updateProgress(
      flashcardId: event.flashcardId,
      isKnown: true,
      difficulty: event.difficulty,
    );

    result.fold(
      (failure) =>
          emit(StudyModeError(failure.message ?? 'Failed to update progress')),
      (updatedFlashcard) async {
        await _advanceToNextCard(
          _currentSessionState!,
          known: true,
          emit: emit,
        );
      },
    );
  }

  Future<void> _onMarkFlashcardUnknown(
    MarkFlashcardUnknownEvent event,
    Emitter<StudyModeState> emit,
  ) async {
    if (_currentSessionState == null) {
      emit(const StudyModeError('No active study session'));
      return;
    }

    final result = await _updateProgress(
      flashcardId: event.flashcardId,
      isKnown: false,
      difficulty: event.difficulty,
    );

    result.fold(
      (failure) =>
          emit(StudyModeError(failure.message ?? 'Failed to update progress')),
      (updatedFlashcard) async {
        await _advanceToNextCard(
          _currentSessionState!,
          known: false,
          emit: emit,
        );
      },
    );
  }

  Future<void> _advanceToNextCard(
    StudyModeSessionActive currentState, {
    required bool known,
    required Emitter<StudyModeState> emit,
  }) async {
    final session = currentState.session;
    final nextIndex = currentState.currentFlashcardIndex + 1;

    // Save history for undo (limit to last 5 actions)
    _sessionHistory.add(_SessionHistoryEntry(
      session: session,
      flashcard: currentState.currentFlashcard,
      flashcardId: currentState.currentFlashcard.id,
      previousIndex: currentState.currentFlashcardIndex,
      wasMarkedKnown: known,
    ));
    if (_sessionHistory.length > 5) {
      _sessionHistory.removeAt(0);
    }

    // Update session progress
    final updateResult = await _repository.updateStudySessionProgress(
      sessionId: session.id,
      cardsReviewed: session.cardsReviewed + 1,
      cardsKnown: session.cardsKnown + (known ? 1 : 0),
      cardsUnknown: session.cardsUnknown + (known ? 0 : 1),
    );

    updateResult.fold(
      (failure) =>
          emit(StudyModeError(failure.message ?? 'Failed to update session')),
      (updatedSession) async {
        // Use cached flashcards if available
        final sessionFlashcards = _sessionFlashcardsCache;

        if (nextIndex >= session.flashcardIds.length) {
          // Session completed
          final endResult = await _repository.endStudySession(session.id);
          endResult.fold(
            (failure) => emit(
                StudyModeError(failure.message ?? 'Failed to end session')),
            (completedSession) {
              _currentSessionState = null;
              _sessionFlashcardsCache = null; // Clear cache on session end
              _sessionHistory.clear(); // Clear history on session end
              emit(StudyModeSessionCompleted(
                session: completedSession,
                flashcards: sessionFlashcards ?? [],
              ));
            },
          );
        } else {
          // Get next flashcard from cache
          if (sessionFlashcards != null &&
              nextIndex < sessionFlashcards.length) {
            final nextFlashcard = sessionFlashcards[nextIndex];
            _currentSessionState = currentState.copyWith(
              session: updatedSession,
              currentFlashcardIndex: nextIndex,
              currentFlashcard: nextFlashcard,
              isFlipped: false,
            );
            emit(_currentSessionState!);
          } else {
            // Fallback: load from repository if cache is empty
            final allFlashcardsResult = await _repository.getAllFlashcards();
            allFlashcardsResult.fold(
              (failure) => emit(StudyModeError(
                  failure.message ?? 'Failed to load flashcards')),
              (allFlashcards) {
                final freshSessionFlashcards = allFlashcards
                    .where((fc) => updatedSession.flashcardIds.contains(fc.id))
                    .toList();

                // Update cache
                _sessionFlashcardsCache = freshSessionFlashcards;

                if (nextIndex < freshSessionFlashcards.length) {
                  final nextFlashcard = freshSessionFlashcards[nextIndex];
                  _currentSessionState = currentState.copyWith(
                    session: updatedSession,
                    currentFlashcardIndex: nextIndex,
                    currentFlashcard: nextFlashcard,
                    isFlipped: false,
                  );
                  emit(_currentSessionState!);
                }
              },
            );
          }
        }
      },
    );
  }

  Future<void> _onEndStudySession(
    EndStudySessionEvent event,
    Emitter<StudyModeState> emit,
  ) async {
    if (_currentSessionState == null) {
      emit(const StudyModeError('No active study session'));
      return;
    }

    final session = _currentSessionState!.session;
    final result = await _repository.endStudySession(session.id);

    result.fold(
      (failure) =>
          emit(StudyModeError(failure.message ?? 'Failed to end session')),
      (completedSession) async {
        final allFlashcardsResult = await _repository.getAllFlashcards();
        allFlashcardsResult.fold(
          (failure) => emit(
              StudyModeError(failure.message ?? 'Failed to load flashcards')),
          (flashcards) {
            final sessionFlashcards = flashcards
                .where((fc) => completedSession.flashcardIds.contains(fc.id))
                .toList();
            _currentSessionState = null;
            emit(StudyModeSessionCompleted(
              session: completedSession,
              flashcards: sessionFlashcards,
            ));
          },
        );
      },
    );
  }

  Future<void> _onDeleteFlashcard(
    DeleteFlashcardEvent event,
    Emitter<StudyModeState> emit,
  ) async {
    final result = await _repository.deleteFlashcard(event.flashcardId);

    result.fold(
      (failure) =>
          emit(StudyModeError(failure.message ?? 'Failed to delete flashcard')),
      (_) async {
        // Reload flashcards
        add(const LoadFlashcardsEvent());
      },
    );
  }

  Future<void> _onDeleteFlashcardsBatch(
    DeleteFlashcardsBatchEvent event,
    Emitter<StudyModeState> emit,
  ) async {
    if (event.flashcardIds.isEmpty) {
      return;
    }

    emit(const StudyModeLoading());

    final result = await _repository.deleteFlashcards(event.flashcardIds);

    result.fold(
      (failure) => emit(
          StudyModeError(failure.message ?? 'Failed to delete flashcards')),
      (_) async {
        // Invalidate cache since flashcards were deleted
        _sessionFlashcardsCache = null;

        // Reload flashcards after batch deletion
        add(const LoadFlashcardsEvent());
      },
    );
  }

  Future<void> _onLoadProgress(
    LoadProgressEvent event,
    Emitter<StudyModeState> emit,
  ) async {
    final result = await _getProgress();

    result.fold(
      (failure) =>
          emit(StudyModeError(failure.message ?? 'Failed to load progress')),
      (progress) => emit(StudyModeProgressLoaded(progress: progress)),
    );
  }

  void flipCard() => add(const FlipCardEvent());

  Future<void> _onFlipCard(
    FlipCardEvent event,
    Emitter<StudyModeState> emit,
  ) async {
    if (_currentSessionState == null) {
      emit(const StudyModeError('No active study session'));
      return;
    }
    final flipped = !_currentSessionState!.isFlipped;
    _currentSessionState = _currentSessionState!.copyWith(isFlipped: flipped);
    emit(_currentSessionState!);
  }

  Future<void> _onUndoLastAction(
    UndoLastActionEvent event,
    Emitter<StudyModeState> emit,
  ) async {
    if (_sessionHistory.isEmpty) {
      return;
    }

    final lastEntry = _sessionHistory.removeLast();

    // Revert the session progress in the repository
    final revertResult = await _repository.updateStudySessionProgress(
      sessionId: lastEntry.session.id,
      cardsReviewed: lastEntry.session.cardsReviewed,
      cardsKnown: lastEntry.session.cardsKnown,
      cardsUnknown: lastEntry.session.cardsUnknown,
    );

    await revertResult.fold(
      (failure) async {
        // Restore the history entry since we failed
        _sessionHistory.add(lastEntry);
        emit(StudyModeError(
            failure.message ?? 'Failed to undo session progress'));
      },
      (revertedSession) async {
        // Revert the flashcard progress to its previous state
        // Use the stored flashcard to restore all properties (difficulty, reviewCount, etc.)
        final flashcardRevertResult = await _updateProgress(
          flashcardId: lastEntry.flashcardId,
          isKnown: lastEntry.flashcard.isKnown,
          difficulty: lastEntry.flashcard.difficulty,
        );

        flashcardRevertResult.fold(
          (failure) {
            // Failed to revert flashcard - restore history and show error
            _sessionHistory.add(lastEntry);
            emit(StudyModeError(
              failure.message ?? 'Failed to undo flashcard progress',
            ));
          },
          (revertedFlashcard) {
            // Update cache if it exists
            if (_sessionFlashcardsCache != null) {
              final index = _sessionFlashcardsCache!
                  .indexWhere((fc) => fc.id == revertedFlashcard.id);
              if (index != -1) {
                _sessionFlashcardsCache![index] = revertedFlashcard;
              }
            }

            // Restore the previous state with the reverted flashcard
            _currentSessionState = StudyModeSessionActive(
              session: revertedSession,
              currentFlashcardIndex: lastEntry.previousIndex,
              currentFlashcard: revertedFlashcard,
              isFlipped: false,
            );

            emit(_currentSessionState!);
          },
        );
      },
    );
  }

  /// Check if undo is available
  bool get canUndo => _sessionHistory.isNotEmpty;

  Future<void> _logMetrics(String segmentId) async {
    final metrics = await _performanceBridge.endSegment(segmentId);
    _logger.info(
      'performance_segment_completed',
      {
        'segment': segmentId,
        'durationMs': metrics.durationMs,
        'batteryLevel': metrics.batteryLevel,
        'cpuUsage': metrics.cpuUsage,
        'memoryUsageMb': metrics.memoryUsageMb,
        if (metrics.notes != null) 'notes': metrics.notes,
      },
    );
  }
}

/// Helper class to store session history for undo functionality
class _SessionHistoryEntry {
  const _SessionHistoryEntry({
    required this.session,
    required this.flashcard,
    required this.flashcardId,
    required this.previousIndex,
    required this.wasMarkedKnown,
  });

  final StudySession session;
  final Flashcard flashcard;
  final String flashcardId;
  final int previousIndex;
  final bool wasMarkedKnown;
}
