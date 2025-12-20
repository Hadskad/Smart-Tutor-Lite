import 'package:equatable/equatable.dart';

/// Status of a queued transcription job
enum QueuedTranscriptionJobStatus {
  /// Job is waiting to be processed
  waiting,

  /// Job is currently being processed
  processing,

  /// Job completed successfully
  success,

  /// Job failed with an error
  failed,
}

/// Represents a transcription job in the processing queue
class QueuedTranscriptionJob extends Equatable {
  const QueuedTranscriptionJob({
    required this.id,
    required this.audioPath,
    required this.status,
    required this.createdAt,
    this.errorMessage,
    this.updatedAt,
    this.noteId,
    this.isOnlineMode,
    this.duration,
    this.fileSizeBytes,
  });

  /// Unique identifier for this job
  final String id;

  /// Path to the audio file to be processed
  final String audioPath;

  /// Current status of the job
  final QueuedTranscriptionJobStatus status;

  /// Error message if status is [QueuedTranscriptionJobStatus.failed]
  final String? errorMessage;

  /// Timestamp when the job was created
  final DateTime createdAt;

  /// Timestamp when the job was last updated
  final DateTime? updatedAt;

  /// ID of the created note/transcription (when status is [QueuedTranscriptionJobStatus.success])
  final String? noteId;

  /// Whether this job uses online mode (true) or offline mode (false)
  final bool? isOnlineMode;

  /// Duration of the audio file
  final Duration? duration;

  /// File size in bytes
  final int? fileSizeBytes;

  /// Creates a copy of this job with updated fields
  QueuedTranscriptionJob copyWith({
    String? id,
    String? audioPath,
    QueuedTranscriptionJobStatus? status,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? noteId,
    bool? isOnlineMode,
    Duration? duration,
    int? fileSizeBytes,
  }) {
    return QueuedTranscriptionJob(
      id: id ?? this.id,
      audioPath: audioPath ?? this.audioPath,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      noteId: noteId ?? this.noteId,
      isOnlineMode: isOnlineMode ?? this.isOnlineMode,
      duration: duration ?? this.duration,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
    );
  }

  @override
  List<Object?> get props => [
        id,
        audioPath,
        status,
        errorMessage,
        createdAt,
        updatedAt,
        noteId,
        isOnlineMode,
        duration,
        fileSizeBytes,
      ];
}

