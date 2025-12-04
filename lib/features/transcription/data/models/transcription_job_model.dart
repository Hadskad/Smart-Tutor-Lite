import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/transcription_job.dart';

class TranscriptionJobModel extends TranscriptionJob {
  const TranscriptionJobModel({
    required super.id,
    required super.userId,
    required super.status,
    required super.mode,
    required super.createdAt,
    required super.updatedAt,
    super.audioStoragePath,
    super.localAudioPath,
    super.duration,
    super.approxSizeBytes,
    super.progress,
    super.errorCode,
    super.errorMessage,
    super.transcriptId,
    super.noteId,
    super.metadata,
    super.canRetry = false,
    super.noteStatus,
    super.noteError,
    super.noteCanRetry = false,
  });

  factory TranscriptionJobModel.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? <String, dynamic>{};
    return TranscriptionJobModel(
      id: snapshot.id,
      userId: data['userId'] as String?,
      status: _parseStatus(data['status'] as String?),
      mode: _parseMode(data['mode'] as String?),
      createdAt: _parseTimestamp(data['createdAt']) ?? DateTime.now(),
      updatedAt: _parseTimestamp(data['updatedAt']) ?? DateTime.now(),
      audioStoragePath: data['audioStoragePath'] as String?,
      localAudioPath: data['localAudioPath'] as String?,
      duration: _parseDuration(data['durationSeconds']),
      approxSizeBytes: (data['approxSizeBytes'] as num?)?.toInt(),
      progress: (data['progress'] as num?)?.toDouble(),
      errorCode: data['errorCode'] as String?,
      errorMessage: data['errorMessage'] as String?,
      transcriptId: data['transcriptId'] as String?,
      noteId: data['noteId'] as String?,
      metadata: Map<String, dynamic>.from(data['metadata'] as Map? ?? {}),
      noteStatus: data['noteStatus'] as String?,
      noteError: data['noteError'] as String?,
      noteCanRetry: data['noteCanRetry'] as bool? ?? false,
      canRetry: data['canRetry'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'status': status.label,
        'mode': mode.label,
        'audioStoragePath': audioStoragePath,
        'localAudioPath': localAudioPath,
        'durationSeconds': duration?.inSeconds,
        'approxSizeBytes': approxSizeBytes,
        'progress': progress,
        'errorCode': errorCode,
        'errorMessage': errorMessage,
        'transcriptId': transcriptId,
        'noteId': noteId,
        'metadata': metadata,
        'noteStatus': noteStatus,
        'noteError': noteError,
        'noteCanRetry': noteCanRetry,
        'canRetry': canRetry,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  static TranscriptionJobStatus _parseStatus(String? raw) {
    return TranscriptionJobStatus.values.firstWhere(
      (value) => value.label == raw || value.name == raw,
      orElse: () => TranscriptionJobStatus.pending,
    );
  }

  static TranscriptionJobMode _parseMode(String? raw) {
    return TranscriptionJobMode.values.firstWhere(
      (value) => value.label == raw || value.name == raw,
      orElse: () => TranscriptionJobMode.onlineSoniox,
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return null;
  }

  static Duration? _parseDuration(dynamic value) {
    if (value is Duration) {
      return value;
    }
    if (value is num) {
      return Duration(seconds: value.toInt());
    }
    return null;
  }
}

