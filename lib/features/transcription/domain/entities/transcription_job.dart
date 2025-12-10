import 'package:equatable/equatable.dart';

enum TranscriptionJobStatus {
  pending('pending'),
  uploading('uploading'),
  uploaded('uploaded'),
  processing('processing'),
  generatingNote('generating_note'),
  completed('completed'),
  error('error'),
  ;

  const TranscriptionJobStatus(this.label);

  final String label;
}

enum TranscriptionJobMode {
  onlineSoniox('online_soniox'),
  offlineWhisper('offline_whisper'),
  ;

  const TranscriptionJobMode(this.label);

  final String label;
}

class TranscriptionJob extends Equatable {
  const TranscriptionJob({
    required this.userId,
    required this.id,
    required this.status,
    required this.mode,
    required this.createdAt,
    required this.updatedAt,
    this.audioStoragePath,
    this.localAudioPath,
    this.duration,
    this.approxSizeBytes,
    this.progress,
    this.errorCode,
    this.errorMessage,
    this.transcriptId,
    this.noteId,
    this.metadata = const {},
    this.canRetry = false,
    this.noteStatus,
    this.noteError,
    this.noteCanRetry = false,
  });

  final String? userId;
  final String id;
  final TranscriptionJobStatus status;
  final TranscriptionJobMode mode;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? audioStoragePath;
  final String? localAudioPath;
  final Duration? duration;
  final int? approxSizeBytes;
  final double? progress;
  final String? errorCode;
  final String? errorMessage;
  final String? transcriptId;
  final String? noteId;
  final Map<String, dynamic> metadata;
  final bool canRetry;
  final String? noteStatus;
  final String? noteError;
  final bool noteCanRetry;

  bool get isTerminal => switch (status) {
        TranscriptionJobStatus.completed ||
        TranscriptionJobStatus.error =>
          true,
        _ => false,
      };

  @override
  List<Object?> get props => [
        userId,
        id,
        status,
        mode,
        createdAt,
        updatedAt,
        audioStoragePath,
        localAudioPath,
        duration,
        approxSizeBytes,
        progress,
        errorCode,
        errorMessage,
        transcriptId,
        noteId,
        metadata,
        canRetry,
        noteStatus,
        noteError,
        noteCanRetry,
      ];
}

