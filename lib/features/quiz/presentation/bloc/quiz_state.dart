import 'package:equatable/equatable.dart';

import '../../domain/entities/quiz.dart';
import '../../domain/entities/quiz_result.dart';

abstract class QuizState extends Equatable {
  const QuizState({
    this.quizzes = const <Quiz>[],
  });

  final List<Quiz> quizzes;

  @override
  List<Object?> get props => [quizzes];
}

class QuizInitial extends QuizState {
  const QuizInitial({super.quizzes = const []});
}

class QuizGenerating extends QuizState {
  const QuizGenerating({super.quizzes = const []});
}

class QuizLoaded extends QuizState {
  const QuizLoaded({
    required this.quiz,
    required this.answers,
    super.quizzes = const [],
  });

  final Quiz quiz;
  final Map<String, int> answers; // questionId -> selectedAnswerIndex

  @override
  List<Object?> get props => [...super.props, quiz, answers];
}

class QuizTaking extends QuizState {
  const QuizTaking({
    required this.quiz,
    required this.answers,
    required this.currentQuestionIndex,
    super.quizzes = const [],
  });

  final Quiz quiz;
  final Map<String, int> answers;
  final int currentQuestionIndex;

  @override
  List<Object?> get props => [
        ...super.props,
        quiz,
        answers,
        currentQuestionIndex,
      ];
}

class QuizSubmitted extends QuizState {
  const QuizSubmitted({
    required this.quiz,
    required this.result,
    super.quizzes = const [],
  });

  final Quiz quiz;
  final QuizResult result;

  @override
  List<Object?> get props => [...super.props, quiz, result];
}

class QuizError extends QuizState {
  const QuizError({
    required this.message,
    super.quizzes = const [],
  });

  final String message;

  @override
  List<Object?> get props => [...super.props, message];
}

class QuizQueued extends QuizState {
  const QuizQueued({
    required this.message,
    super.quizzes = const [],
  });

  final String message;

  @override
  List<Object?> get props => [...super.props, message];
}

