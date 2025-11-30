import 'package:equatable/equatable.dart';

class Flashcard extends Equatable {
  const Flashcard({
    required this.id,
    required this.front,
    required this.back,
    this.sourceId,
    this.sourceType,
    this.createdAt,
    this.lastReviewedAt,
    this.reviewCount = 0,
    this.difficulty = FlashcardDifficulty.easy,
    this.isKnown = false,
    this.metadata,
  });

  final String id;
  final String front;
  final String back;
  final String? sourceId; // ID of the source (summary/transcription)
  final String? sourceType; // 'summary' or 'transcription'
  final DateTime? createdAt;
  final DateTime? lastReviewedAt;
  final int reviewCount;
  final FlashcardDifficulty difficulty;
  final bool isKnown;
  final Map<String, dynamic>? metadata;

  Flashcard copyWith({
    String? id,
    String? front,
    String? back,
    String? sourceId,
    String? sourceType,
    DateTime? createdAt,
    DateTime? lastReviewedAt,
    int? reviewCount,
    FlashcardDifficulty? difficulty,
    bool? isKnown,
    Map<String, dynamic>? metadata,
  }) {
    return Flashcard(
      id: id ?? this.id,
      front: front ?? this.front,
      back: back ?? this.back,
      sourceId: sourceId ?? this.sourceId,
      sourceType: sourceType ?? this.sourceType,
      createdAt: createdAt ?? this.createdAt,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      reviewCount: reviewCount ?? this.reviewCount,
      difficulty: difficulty ?? this.difficulty,
      isKnown: isKnown ?? this.isKnown,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  List<Object?> get props => [
        id,
        front,
        back,
        sourceId,
        sourceType,
        createdAt,
        lastReviewedAt,
        reviewCount,
        difficulty,
        isKnown,
        metadata,
      ];
}

enum FlashcardDifficulty {
  easy,
  medium,
  hard,
}
