import 'package:equatable/equatable.dart';

import 'question.dart';

/// Represents a quiz generated from source content (transcription or summary).
class Quiz extends Equatable {
  const Quiz({
    required this.id,
    required this.title,
    required this.sourceId,
    required this.sourceType,
    required this.questions,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String sourceId; // ID of source transcription or summary
  final String sourceType; // 'transcription' or 'summary'
  final List<Question> questions;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
        id,
        title,
        sourceId,
        sourceType,
        questions,
        createdAt,
      ];
}
