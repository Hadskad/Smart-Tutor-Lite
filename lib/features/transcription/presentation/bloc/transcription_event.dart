import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/transcription_job.dart';

abstract class TranscriptionEvent extends Equatable {
  const TranscriptionEvent();

  @override
  List<Object?> get props => [];
}

class StartRecording extends TranscriptionEvent {
  const StartRecording();
}

class StopRecording extends TranscriptionEvent {
  const StopRecording();
}

class TranscribeAudio extends TranscriptionEvent {
  const TranscribeAudio(this.audioPath);

  final String audioPath;

  @override
  List<Object?> get props => [audioPath];
}

class TranscriptionJobSnapshotReceived extends TranscriptionEvent {
  const TranscriptionJobSnapshotReceived(this.result);

  final Either<Failure, TranscriptionJob> result;

  @override
  List<Object?> get props => [result];
}

class RecordingMetricsUpdated extends TranscriptionEvent {
  const RecordingMetricsUpdated({
    required this.estimatedSizeBytes,
    required this.isInputTooLow,
  });

  final int estimatedSizeBytes;
  final bool isInputTooLow;

  @override
  List<Object?> get props => [estimatedSizeBytes, isInputTooLow];
}

class LoadTranscriptions extends TranscriptionEvent {
  const LoadTranscriptions();
}

class CancelCloudTranscription extends TranscriptionEvent {
  const CancelCloudTranscription({this.reason});

  final String? reason;

  @override
  List<Object?> get props => [reason];
}

class RetryCloudTranscription extends TranscriptionEvent {
  const RetryCloudTranscription(this.jobId);

  final String jobId;

  @override
  List<Object?> get props => [jobId];
}
