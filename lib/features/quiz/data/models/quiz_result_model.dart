import '../../domain/entities/quiz_result.dart';

class QuizResultModel extends QuizResult {
  const QuizResultModel({
    required super.quizId,
    required super.answers,
    required super.score,
    required super.totalQuestions,
    required super.completedAt,
  });

  factory QuizResultModel.fromJson(Map<String, dynamic> json) {
    return QuizResultModel(
      quizId: json['quizId'] as String? ?? '',
      answers: Map<String, int>.from(
        json['answers'] as Map? ?? const <String, int>{},
      ),
      score: (json['score'] as num?)?.toInt() ?? 0,
      totalQuestions: (json['totalQuestions'] as num?)?.toInt() ?? 0,
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'quizId': quizId,
      'answers': answers,
      'score': score,
      'totalQuestions': totalQuestions,
      'completedAt': completedAt.toIso8601String(),
    };
  }

  QuizResultModel copyWith({
    String? quizId,
    Map<String, int>? answers,
    int? score,
    int? totalQuestions,
    DateTime? completedAt,
  }) {
    return QuizResultModel(
      quizId: quizId ?? this.quizId,
      answers: answers ?? this.answers,
      score: score ?? this.score,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  factory QuizResultModel.fromEntity(QuizResult entity) {
    return QuizResultModel(
      quizId: entity.quizId,
      answers: Map<String, int>.from(entity.answers),
      score: entity.score,
      totalQuestions: entity.totalQuestions,
      completedAt: entity.completedAt,
    );
  }

  QuizResult toEntity() {
    return QuizResult(
      quizId: quizId,
      answers: answers,
      score: score,
      totalQuestions: totalQuestions,
      completedAt: completedAt,
    );
  }
}

