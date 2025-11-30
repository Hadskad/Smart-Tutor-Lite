import '../../domain/entities/question.dart';

class QuestionModel extends Question {
  const QuestionModel({
    required super.id,
    required super.question,
    required super.options,
    required super.correctAnswer,
    super.explanation,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json) {
    return QuestionModel(
      id: json['id'] as String? ?? '',
      question: json['question'] as String? ?? '',
      options: List<String>.from(json['options'] as List? ?? []),
      correctAnswer: (json['correctAnswer'] as num?)?.toInt() ?? 0,
      explanation: json['explanation'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'question': question,
      'options': options,
      'correctAnswer': correctAnswer,
      if (explanation != null) 'explanation': explanation,
    };
  }

  QuestionModel copyWith({
    String? id,
    String? question,
    List<String>? options,
    int? correctAnswer,
    String? explanation,
  }) {
    return QuestionModel(
      id: id ?? this.id,
      question: question ?? this.question,
      options: options ?? this.options,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      explanation: explanation ?? this.explanation,
    );
  }

  factory QuestionModel.fromEntity(Question entity) {
    return QuestionModel(
      id: entity.id,
      question: entity.question,
      options: List<String>.from(entity.options),
      correctAnswer: entity.correctAnswer,
      explanation: entity.explanation,
    );
  }

  Question toEntity() {
    return Question(
      id: id,
      question: question,
      options: options,
      correctAnswer: correctAnswer,
      explanation: explanation,
    );
  }
}

