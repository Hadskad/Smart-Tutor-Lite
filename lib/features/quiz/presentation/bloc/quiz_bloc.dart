import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/utils/logger.dart';
import '../../../../native_bridge/performance_bridge.dart';
import '../../domain/entities/quiz.dart';
import '../../domain/repositories/quiz_repository.dart';
import '../../domain/usecases/generate_quiz.dart';
import '../../domain/usecases/submit_quiz.dart';
import 'quiz_event.dart';
import 'quiz_state.dart';

@injectable
class QuizBloc extends Bloc<QuizEvent, QuizState> {
  QuizBloc(
    this._generateQuiz,
    this._submitQuiz,
    this._repository,
    this._performanceBridge,
    this._logger,
  ) : super(const QuizInitial()) {
    on<GenerateQuizEvent>(_onGenerateQuiz);
    on<LoadQuizEvent>(_onLoadQuiz);
    on<LoadQuizzesEvent>(_onLoadQuizzes);
    on<AnswerQuestionEvent>(_onAnswerQuestion);
    on<SubmitQuizEvent>(_onSubmitQuiz);
    on<DeleteQuizEvent>(_onDeleteQuiz);
  }

  final GenerateQuiz _generateQuiz;
  final SubmitQuiz _submitQuiz;
  final QuizRepository _repository;
  final PerformanceBridge _performanceBridge;
  final AppLogger _logger;
  final List<Quiz> _quizzes = <Quiz>[];
  Map<String, int> _currentAnswers = <String, int>{};

  Future<void> _onGenerateQuiz(
    GenerateQuizEvent event,
    Emitter<QuizState> emit,
  ) async {
    emit(QuizGenerating(quizzes: List.unmodifiable(_quizzes)));

    const segmentId = 'quiz_generation';
    await _performanceBridge.startSegment(segmentId);
    try {
      final result = await _generateQuiz(
        sourceId: event.sourceId,
        sourceType: event.sourceType,
        numQuestions: event.numQuestions,
        difficulty: event.difficulty,
      );

      result.fold(
      (failure) {
        final message = failure.message ?? 'Failed to generate quiz';
        // Check if request was queued
        if (message.contains('queued') || message.contains('Queued')) {
          emit(
            QuizQueued(
              message: message,
              quizzes: List.unmodifiable(_quizzes),
            ),
          );
        } else {
          emit(
            QuizError(
              message: message,
              quizzes: List.unmodifiable(_quizzes),
            ),
          );
        }
      },
      (quiz) {
        _quizzes.insert(0, quiz);
        _currentAnswers = <String, int>{};
        emit(
          QuizLoaded(
            quiz: quiz,
            answers: _currentAnswers,
            quizzes: List.unmodifiable(_quizzes),
          ),
        );
      },
      );
    } finally {
      await _logMetrics(segmentId);
    }
  }

  Future<void> _onLoadQuiz(
    LoadQuizEvent event,
    Emitter<QuizState> emit,
  ) async {
    emit(QuizGenerating(quizzes: List.unmodifiable(_quizzes)));

    final result = await _repository.getQuiz(event.quizId);

    result.fold(
      (failure) => emit(
        QuizError(
          message: failure.message ?? 'Failed to load quiz',
          quizzes: List.unmodifiable(_quizzes),
        ),
      ),
      (quiz) {
        _currentAnswers = <String, int>{};
        emit(
          QuizLoaded(
            quiz: quiz,
            answers: _currentAnswers,
            quizzes: List.unmodifiable(_quizzes),
          ),
        );
      },
    );
  }

  Future<void> _onLoadQuizzes(
    LoadQuizzesEvent event,
    Emitter<QuizState> emit,
  ) async {
    final result = await _repository.getAllQuizzes();

    result.fold(
      (failure) => emit(
        QuizError(
          message: failure.message ?? 'Failed to load quizzes',
          quizzes: List.unmodifiable(_quizzes),
        ),
      ),
      (quizzes) {
        _quizzes.clear();
        _quizzes.addAll(quizzes);
        emit(QuizInitial(quizzes: List.unmodifiable(_quizzes)));
      },
    );
  }

  void _onAnswerQuestion(
    AnswerQuestionEvent event,
    Emitter<QuizState> emit,
  ) {
    if (state is QuizLoaded || state is QuizTaking) {
      final currentState = state;
      Quiz? quiz;
      int currentIndex = 0;

      if (currentState is QuizLoaded) {
        quiz = currentState.quiz;
        currentIndex = 0;
      } else if (currentState is QuizTaking) {
        quiz = currentState.quiz;
        currentIndex = currentState.currentQuestionIndex;
      }

      if (quiz != null) {
        _currentAnswers[event.questionId] = event.selectedAnswer;

        // Move to next question if not last
        if (currentIndex < quiz.questions.length - 1) {
          emit(
            QuizTaking(
              quiz: quiz,
              answers: Map<String, int>.from(_currentAnswers),
              currentQuestionIndex: currentIndex + 1,
              quizzes: List.unmodifiable(_quizzes),
            ),
          );
        } else {
          // Last question answered, stay in QuizLoaded state
          emit(
            QuizLoaded(
              quiz: quiz,
              answers: Map<String, int>.from(_currentAnswers),
              quizzes: List.unmodifiable(_quizzes),
            ),
          );
        }
      }
    }
  }

  Future<void> _onSubmitQuiz(
    SubmitQuizEvent event,
    Emitter<QuizState> emit,
  ) async {
    final currentState = state;
    Quiz? quiz;

    if (currentState is QuizLoaded) {
      quiz = currentState.quiz;
    } else if (currentState is QuizTaking) {
      quiz = currentState.quiz;
    }

    if (quiz == null) {
      emit(
        QuizError(
          message: 'No quiz loaded',
          quizzes: List.unmodifiable(_quizzes),
        ),
      );
      return;
    }

    final result = await _submitQuiz(
      quizId: quiz.id,
      answers: _currentAnswers,
    );

    result.fold(
      (failure) => emit(
        QuizError(
          message: failure.message ?? 'Failed to submit quiz',
          quizzes: List.unmodifiable(_quizzes),
        ),
      ),
      (quizResult) {
        if (quiz != null) {
          emit(
            QuizSubmitted(
              quiz: quiz,
              result: quizResult,
              quizzes: List.unmodifiable(_quizzes),
            ),
          );
        }
      },
    );
  }

  Future<void> _onDeleteQuiz(
    DeleteQuizEvent event,
    Emitter<QuizState> emit,
  ) async {
    final result = await _repository.deleteQuiz(event.quizId);

    result.fold(
      (failure) => emit(
        QuizError(
          message: failure.message ?? 'Failed to delete quiz',
          quizzes: List.unmodifiable(_quizzes),
        ),
      ),
      (_) {
        _quizzes.removeWhere((q) => q.id == event.quizId);
        emit(QuizInitial(quizzes: List.unmodifiable(_quizzes)));
      },
    );
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

