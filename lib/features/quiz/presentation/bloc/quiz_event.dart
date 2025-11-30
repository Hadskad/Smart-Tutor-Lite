import 'package:equatable/equatable.dart';

abstract class QuizEvent extends Equatable {
  const QuizEvent();

  @override
  List<Object?> get props => [];
}

class GenerateQuizEvent extends QuizEvent {
  const GenerateQuizEvent({
    required this.sourceId,
    required this.sourceType,
    this.numQuestions = 5,
    this.difficulty = 'medium',
  });

  final String sourceId;
  final String sourceType; // 'transcription' or 'summary'
  final int numQuestions;
  final String difficulty; // 'easy', 'medium', 'hard'

  @override
  List<Object?> get props => [sourceId, sourceType, numQuestions, difficulty];
}

class LoadQuizEvent extends QuizEvent {
  const LoadQuizEvent(this.quizId);

  final String quizId;

  @override
  List<Object?> get props => [quizId];
}

class LoadQuizzesEvent extends QuizEvent {
  const LoadQuizzesEvent();
}

class AnswerQuestionEvent extends QuizEvent {
  const AnswerQuestionEvent({
    required this.questionId,
    required this.selectedAnswer,
  });

  final String questionId;
  final int selectedAnswer; // Index of selected option

  @override
  List<Object?> get props => [questionId, selectedAnswer];
}

class SubmitQuizEvent extends QuizEvent {
  const SubmitQuizEvent();
}

class DeleteQuizEvent extends QuizEvent {
  const DeleteQuizEvent(this.quizId);

  final String quizId;

  @override
  List<Object?> get props => [quizId];
}

