import 'package:equatable/equatable.dart';

/// Represents a text-to-speech conversion job.
class TtsJob extends Equatable {
  const TtsJob({
    required this.id,
    required this.sourceType,
    required this.sourceId,
    required this.audioUrl,
    required this.status,
    required this.createdAt,
    this.voice,
    this.errorMessage,
  });

  final String id;
  final String sourceType; // 'pdf' or 'text'
  final String sourceId; // ID of source PDF or text content
  final String audioUrl; // URL to the generated audio file
  final String status; // 'pending', 'processing', 'completed', 'failed'
  final DateTime createdAt;
  final String? voice; // Voice name (e.g., 'en-US-Standard-B')
  final String? errorMessage; // Error message if status is 'failed'

  @override
  List<Object?> get props => [
        id,
        sourceType,
        sourceId,
        audioUrl,
        status,
        createdAt,
        voice,
        errorMessage,
      ];
}

