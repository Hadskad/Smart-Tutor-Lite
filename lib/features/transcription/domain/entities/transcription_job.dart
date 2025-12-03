import 'package:equatable/equatable.dart';

enum TranscriptionJobStatus {
  pending,
  uploading,
  processing,
  generatingNote,
  done,
  error,
}

enum TranscriptionJobMode {
  onlineSoniox,
  offlineWhisper,
}

class TranscriptionJob extends Equatable {
  const TranscriptionJob({
    required this.id,
    required this.status,
    required this.mode,
    required this.createdAt,
    required this.updatedAt,
    this.audioStoragePath,
    this.duration,
    this.approxSizeBytes,
    this.progress,
    this.errorCode,
    this.errorMessage,
    this.transcriptId,
    this.noteId,
    this.metadata = const {},
  });

  final String id;
  final TranscriptionJobStatus status;
  final TranscriptionJobMode mode;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? audioStoragePath;
  final Duration? duration;
  final int? approxSizeBytes;
  final double? progress;
  final String? errorCode;
  final String? errorMessage;
  final String? transcriptId;
  final String? noteId;
  final Map<String, dynamic> metadata;

  bool get isTerminal => switch (status) {
        TranscriptionJobStatus.done ||
        TranscriptionJobStatus.error =>
          true,
        _ => false,
      };

  @override
  List<Object?> get props => [
        id,
        status,
        mode,
        createdAt,
        updatedAt,
        audioStoragePath,
        duration,
        approxSizeBytes,
        progress,
        errorCode,
        errorMessage,
        transcriptId,
        noteId,
        metadata,
      ];
}

