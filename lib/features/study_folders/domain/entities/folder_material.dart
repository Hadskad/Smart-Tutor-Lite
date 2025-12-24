import 'package:equatable/equatable.dart';

/// Represents the association between a study folder and a study material.
///
/// This is a junction entity that links folders with various material types
/// (transcriptions, summaries, quizzes, flashcards, audio notes).
class FolderMaterial extends Equatable {
  const FolderMaterial({
    required this.id,
    required this.folderId,
    required this.materialId,
    required this.materialType,
    required this.addedAt,
  });

  /// Unique identifier for this folder-material association
  final String id;

  /// The folder this material belongs to
  final String folderId;

  /// The ID of the material (transcription, summary, quiz, etc.)
  final String materialId;

  /// The type of material: 'transcription', 'summary', 'quiz', 'flashcard', 'tts'
  final MaterialType materialType;

  /// When the material was added to the folder
  final DateTime addedAt;

  @override
  List<Object?> get props => [
        id,
        folderId,
        materialId,
        materialType,
        addedAt,
      ];
}

/// Types of study materials that can be added to a folder
enum MaterialType {
  transcription,
  summary,
  quiz,
  flashcard,
  tts;

  /// Converts the enum to a string for storage
  String toJson() => name;

  /// Creates an enum from a string
  static MaterialType fromJson(String value) {
    return MaterialType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MaterialType.transcription,
    );
  }

  /// Human-readable display name
  String get displayName {
    switch (this) {
      case MaterialType.transcription:
        return 'Notes';
      case MaterialType.summary:
        return 'Summaries';
      case MaterialType.quiz:
        return 'Quizzes';
      case MaterialType.flashcard:
        return 'Flashcards';
      case MaterialType.tts:
        return 'Audio Notes';
    }
  }

  /// Icon name for the material type
  String get iconName {
    switch (this) {
      case MaterialType.transcription:
        return 'auto_stories';
      case MaterialType.summary:
        return 'summarize';
      case MaterialType.quiz:
        return 'quiz';
      case MaterialType.flashcard:
        return 'style';
      case MaterialType.tts:
        return 'headphones';
    }
  }
}

