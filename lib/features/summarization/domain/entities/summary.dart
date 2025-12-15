import 'package:equatable/equatable.dart';

/// Represents a summary generated from text or PDF content.
class Summary extends Equatable {
  const Summary({
    required this.id,
    required this.sourceType,
    required this.summaryText,
    this.sourceId,
    this.metadata = const <String, dynamic>{},
    required this.createdAt,
    this.title,
  });

  final String id;
  final String sourceType; // 'text' or 'pdf'
  final String? sourceId; // ID of source transcription/summary if applicable
  final String summaryText;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final String? title; // Custom title for the summary (e.g., PDF filename)

  @override
  List<Object?> get props => [
        id,
        sourceType,
        sourceId,
        summaryText,
        metadata,
        createdAt,
        title,
      ];
}
