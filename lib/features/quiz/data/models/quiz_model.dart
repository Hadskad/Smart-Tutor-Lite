import '../../domain/entities/quiz.dart';
import '../../domain/entities/question.dart';
import 'question_model.dart';

class QuizModel extends Quiz {
  const QuizModel({
    required super.id,
    required super.title,
    required super.sourceId,
    required super.sourceType,
    required super.questions,
    required super.createdAt,
  });

  factory QuizModel.fromJson(Map<String, dynamic> json) {
    return QuizModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      sourceId: json['sourceId'] as String? ?? '',
      sourceType: json['sourceType'] as String? ?? 'transcription',
      questions: (json['questions'] as List?)
              ?.map((q) => QuestionModel.fromJson(q as Map<String, dynamic>))
              .toList() ??
          const <Question>[],
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'sourceId': sourceId,
      'sourceType': sourceType,
      'questions': questions
          .map((q) => QuestionModel.fromEntity(q).toJson())
          .toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  QuizModel copyWith({
    String? id,
    String? title,
    String? sourceId,
    String? sourceType,
    List<Question>? questions,
    DateTime? createdAt,
  }) {
    return QuizModel(
      id: id ?? this.id,
      title: title ?? this.title,
      sourceId: sourceId ?? this.sourceId,
      sourceType: sourceType ?? this.sourceType,
      questions: questions ?? this.questions,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory QuizModel.fromEntity(Quiz entity) {
    return QuizModel(
      id: entity.id,
      title: entity.title,
      sourceId: entity.sourceId,
      sourceType: entity.sourceType,
      questions: entity.questions,
      createdAt: entity.createdAt,
    );
  }

  Quiz toEntity() {
    return Quiz(
      id: id,
      title: title,
      sourceId: sourceId,
      sourceType: sourceType,
      questions: questions,
      createdAt: createdAt,
    );
  }
}

