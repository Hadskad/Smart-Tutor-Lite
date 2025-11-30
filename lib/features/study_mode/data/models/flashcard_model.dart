import 'package:equatable/equatable.dart';

import '../../domain/entities/flashcard.dart';

class FlashcardModel extends Equatable {
  const FlashcardModel({
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
  final String? sourceId;
  final String? sourceType;
  final DateTime? createdAt;
  final DateTime? lastReviewedAt;
  final int reviewCount;
  final FlashcardDifficulty difficulty;
  final bool isKnown;
  final Map<String, dynamic>? metadata;

  factory FlashcardModel.fromJson(Map<String, dynamic> json) {
    return FlashcardModel(
      id: json['id'] as String,
      front: json['front'] as String,
      back: json['back'] as String,
      sourceId: json['sourceId'] as String?,
      sourceType: json['sourceType'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      lastReviewedAt: json['lastReviewedAt'] != null
          ? DateTime.parse(json['lastReviewedAt'] as String)
          : null,
      reviewCount: json['reviewCount'] as int? ?? 0,
      difficulty: _parseDifficulty(json['difficulty'] as String?),
      isKnown: json['isKnown'] as bool? ?? false,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'front': front,
      'back': back,
      if (sourceId != null) 'sourceId': sourceId,
      if (sourceType != null) 'sourceType': sourceType,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (lastReviewedAt != null)
        'lastReviewedAt': lastReviewedAt!.toIso8601String(),
      'reviewCount': reviewCount,
      'difficulty': difficulty.name,
      'isKnown': isKnown,
      if (metadata != null) 'metadata': metadata,
    };
  }

  factory FlashcardModel.fromEntity(Flashcard flashcard) {
    return FlashcardModel(
      id: flashcard.id,
      front: flashcard.front,
      back: flashcard.back,
      sourceId: flashcard.sourceId,
      sourceType: flashcard.sourceType,
      createdAt: flashcard.createdAt,
      lastReviewedAt: flashcard.lastReviewedAt,
      reviewCount: flashcard.reviewCount,
      difficulty: flashcard.difficulty,
      isKnown: flashcard.isKnown,
      metadata: flashcard.metadata,
    );
  }

  Flashcard toEntity() {
    return Flashcard(
      id: id,
      front: front,
      back: back,
      sourceId: sourceId,
      sourceType: sourceType,
      createdAt: createdAt,
      lastReviewedAt: lastReviewedAt,
      reviewCount: reviewCount,
      difficulty: difficulty,
      isKnown: isKnown,
      metadata: metadata,
    );
  }

  static FlashcardDifficulty _parseDifficulty(String? difficulty) {
    switch (difficulty) {
      case 'easy':
        return FlashcardDifficulty.easy;
      case 'medium':
        return FlashcardDifficulty.medium;
      case 'hard':
        return FlashcardDifficulty.hard;
      default:
        return FlashcardDifficulty.easy;
    }
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

