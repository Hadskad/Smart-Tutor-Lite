import 'package:equatable/equatable.dart';

import 'flashcard.dart';

class StudySession extends Equatable {
  const StudySession({
    required this.id,
    required this.flashcardIds,
    this.startTime,
    this.endTime,
    this.durationSeconds,
    this.cardsReviewed = 0,
    this.cardsKnown = 0,
    this.cardsUnknown = 0,
    this.flashcards,
    this.metadata,
  });

  final String id;
  final List<String> flashcardIds;
  final DateTime? startTime;
  final DateTime? endTime;
  final int? durationSeconds;
  final int cardsReviewed;
  final int cardsKnown;
  final int cardsUnknown;
  final List<Flashcard>? flashcards; // Optional: populated flashcards
  final Map<String, dynamic>? metadata;

  StudySession copyWith({
    String? id,
    List<String>? flashcardIds,
    DateTime? startTime,
    DateTime? endTime,
    int? durationSeconds,
    int? cardsReviewed,
    int? cardsKnown,
    int? cardsUnknown,
    List<Flashcard>? flashcards,
    Map<String, dynamic>? metadata,
  }) {
    return StudySession(
      id: id ?? this.id,
      flashcardIds: flashcardIds ?? this.flashcardIds,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      cardsReviewed: cardsReviewed ?? this.cardsReviewed,
      cardsKnown: cardsKnown ?? this.cardsKnown,
      cardsUnknown: cardsUnknown ?? this.cardsUnknown,
      flashcards: flashcards ?? this.flashcards,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get isCompleted => endTime != null;

  double get completionPercentage {
    if (flashcardIds.isEmpty) return 0.0;
    return (cardsReviewed / flashcardIds.length) * 100;
  }

  @override
  List<Object?> get props => [
        id,
        flashcardIds,
        startTime,
        endTime,
        durationSeconds,
        cardsReviewed,
        cardsKnown,
        cardsUnknown,
        flashcards,
        metadata,
      ];
}

