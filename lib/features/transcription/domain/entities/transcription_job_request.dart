import 'package:equatable/equatable.dart';

import 'transcription_job.dart';

class TranscriptionJobRequest extends Equatable {
  const TranscriptionJobRequest({
    required this.localFilePath,
    required this.duration,
    required this.fileSizeBytes,
    this.displayName,
    this.metadata = const {},
    this.mode = TranscriptionJobMode.onlineSoniox,
  });

  final String localFilePath;
  final Duration duration;
  final int fileSizeBytes;
  final String? displayName;
  final Map<String, dynamic> metadata;
  final TranscriptionJobMode mode;

  @override
  List<Object?> get props => [
        localFilePath,
        duration,
        fileSizeBytes,
        displayName,
        metadata,
        mode,
      ];
}

