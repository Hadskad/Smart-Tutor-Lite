import 'package:equatable/equatable.dart';

import '../../domain/entities/study_session.dart';
import 'flashcard_model.dart';

class StudySessionModel extends Equatable {
  const StudySessionModel({
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
  final List<FlashcardModel>? flashcards;
  final Map<String, dynamic>? metadata;

  factory StudySessionModel.fromJson(Map<String, dynamic> json) {
    return StudySessionModel(
      id: json['id'] as String,
      flashcardIds: (json['flashcardIds'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      startTime: json['startTime'] != null
          ? DateTime.parse(json['startTime'] as String)
          : null,
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      durationSeconds: json['durationSeconds'] as int?,
      cardsReviewed: json['cardsReviewed'] as int? ?? 0,
      cardsKnown: json['cardsKnown'] as int? ?? 0,
      cardsUnknown: json['cardsUnknown'] as int? ?? 0,
      flashcards: json['flashcards'] != null
          ? (json['flashcards'] as List<dynamic>)
              .map((e) => FlashcardModel.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'flashcardIds': flashcardIds,
      if (startTime != null) 'startTime': startTime!.toIso8601String(),
      if (endTime != null) 'endTime': endTime!.toIso8601String(),
      if (durationSeconds != null) 'durationSeconds': durationSeconds,
      'cardsReviewed': cardsReviewed,
      'cardsKnown': cardsKnown,
      'cardsUnknown': cardsUnknown,
      if (flashcards != null)
        'flashcards': flashcards!.map((e) => e.toJson()).toList(),
      if (metadata != null) 'metadata': metadata,
    };
  }

  factory StudySessionModel.fromEntity(StudySession session) {
    return StudySessionModel(
      id: session.id,
      flashcardIds: session.flashcardIds,
      startTime: session.startTime,
      endTime: session.endTime,
      durationSeconds: session.durationSeconds,
      cardsReviewed: session.cardsReviewed,
      cardsKnown: session.cardsKnown,
      cardsUnknown: session.cardsUnknown,
      flashcards: session.flashcards
          ?.map((e) => FlashcardModel.fromEntity(e))
          .toList(),
      metadata: session.metadata,
    );
  }

  StudySession toEntity() {
    return StudySession(
      id: id,
      flashcardIds: flashcardIds,
      startTime: startTime,
      endTime: endTime,
      durationSeconds: durationSeconds,
      cardsReviewed: cardsReviewed,
      cardsKnown: cardsKnown,
      cardsUnknown: cardsUnknown,
      flashcards: flashcards?.map((e) => e.toEntity()).toList(),
      metadata: metadata,
    );
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

