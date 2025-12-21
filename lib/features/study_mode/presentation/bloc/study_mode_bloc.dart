import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/utils/logger.dart';
import '../../../../native_bridge/performance_bridge.dart';
import '../../domain/repositories/study_mode_repository.dart';
import '../../domain/usecases/generate_flashcards.dart';
import '../../domain/usecases/get_progress.dart';
import '../../domain/usecases/start_study_session.dart';
import '../../domain/usecases/update_progress.dart';
import '../bloc/study_mode_event.dart';
import '../bloc/study_mode_state.dart';

@injectable
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
    on<LoadProgressEvent>(_onLoadProgress);
    on<FlipCardEvent>(_onFlipCard);
  }

  final GenerateFlashcards _generateFlashcards;
  final StartStudySession _startStudySession;
  final UpdateProgress _updateProgress;
  final GetProgress _getProgress;
  final StudyModeRepository _repository;
  final PerformanceBridge _performanceBridge;
  final AppLogger _logger;

  StudyModeSessionActive? _currentSessionState;
  bool _isGeneratingFlashcards = false;

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
        emit(StudyModeError(failure.message ?? 'Failed to generate flashcards'));
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
            final sessionFlashcards = allFlashcards
                .where((fc) => session.flashcardIds.contains(fc.id))
                .toList();

            if (sessionFlashcards.isEmpty) {
              emit(const StudyModeError('Flashcards not found'));
              return;
            }

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
        if (nextIndex >= session.flashcardIds.length) {
          // Session completed
          final endResult = await _repository.endStudySession(session.id);
          endResult.fold(
            (failure) => emit(
                StudyModeError(failure.message ?? 'Failed to end session')),
            (completedSession) async {
              // Load all flashcards for the completion view
              final allFlashcardsResult = await _repository.getAllFlashcards();
              allFlashcardsResult.fold(
                (failure) => emit(StudyModeError(
                    failure.message ?? 'Failed to load flashcards')),
                (flashcards) {
                  final sessionFlashcards = flashcards
                      .where(
                          (fc) => completedSession.flashcardIds.contains(fc.id))
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
        } else {
          // Load next flashcard
          final allFlashcardsResult = await _repository.getAllFlashcards();
          allFlashcardsResult.fold(
            (failure) => emit(
                StudyModeError(failure.message ?? 'Failed to load flashcards')),
            (allFlashcards) {
              final sessionFlashcards = allFlashcards
                  .where((fc) => updatedSession.flashcardIds.contains(fc.id))
                  .toList();

              if (nextIndex < sessionFlashcards.length) {
                final nextFlashcard = sessionFlashcards[nextIndex];
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
