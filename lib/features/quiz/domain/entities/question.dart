import 'package:equatable/equatable.dart';

/// Represents a quiz question with multiple choice options.
class Question extends Equatable {
  const Question({
    required this.id,
    required this.question,
    required this.options,
    required this.correctAnswer,
    this.explanation,
  });

  final String id;
  final String question;
  final List<String> options; // Multiple choice options
  final int correctAnswer; // Index of correct answer in options list
  final String? explanation; // Explanation of the correct answer

  @override
  List<Object?> get props => [
        id,
        question,
        options,
        correctAnswer,
        explanation,
      ];
}

