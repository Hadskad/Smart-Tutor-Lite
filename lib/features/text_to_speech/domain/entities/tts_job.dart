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
    this.operationName,
    this.storagePath,
    this.localPath,
  });

  final String id;
  final String sourceType; // 'pdf' or 'text'
  final String sourceId; // ID of source PDF or text content
  final String audioUrl; // URL to the generated audio file
  final String status; // 'pending', 'processing', 'completed', 'failed'
  final DateTime createdAt;
  final String? voice; // Voice name (e.g., 'en-US-Neural2-D')
  final String? errorMessage; // Error message if status is 'failed'
  final String? operationName; // Google Cloud Operation name for tracking long-running operations
  final String? storagePath; // Firebase Storage path for audio file
  final String? localPath; // Local file path for offline playback

  /// Creates a copy with updated localPath
  TtsJob copyWithLocalPath(String? localPath) {
    return TtsJob(
      id: id,
      sourceType: sourceType,
      sourceId: sourceId,
      audioUrl: audioUrl,
      status: status,
      createdAt: createdAt,
      voice: voice,
      errorMessage: errorMessage,
      operationName: operationName,
      storagePath: storagePath,
      localPath: localPath,
    );
  }

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
        operationName,
        storagePath,
        localPath,
      ];
}
