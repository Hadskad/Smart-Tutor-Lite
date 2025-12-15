import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/transcription.dart';
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
  const TranscribeAudio(
    this.audioPath, {
    this.preferLocal = false,
    this.modelAssetPath,
  });

  final String audioPath;
  final bool preferLocal;
  final String? modelAssetPath;

  @override
  List<Object?> get props => [audioPath, preferLocal, modelAssetPath];
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

class LoadTranscriptionPreferences extends TranscriptionEvent {
  const LoadTranscriptionPreferences();
}

class ToggleOfflinePreference extends TranscriptionEvent {
  const ToggleOfflinePreference(this.alwaysUseOffline);

  final bool alwaysUseOffline;

  @override
  List<Object?> get props => [alwaysUseOffline];
}

class ToggleFastWhisperModel extends TranscriptionEvent {
  const ToggleFastWhisperModel(this.useFastModel);

  final bool useFastModel;

  @override
  List<Object?> get props => [useFastModel];
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

class RetryNoteGeneration extends TranscriptionEvent {
  const RetryNoteGeneration(this.jobId);

  final String jobId;

  @override
  List<Object?> get props => [jobId];
}

class ConfirmOfflineFallback extends TranscriptionEvent {
  const ConfirmOfflineFallback();
}

class RetryCloudFromFallback extends TranscriptionEvent {
  const RetryCloudFromFallback();
}

class DeleteTranscription extends TranscriptionEvent {
  const DeleteTranscription(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

class UpdateTranscription extends TranscriptionEvent {
  const UpdateTranscription(this.transcription);

  final Transcription transcription;

  @override
  List<Object?> get props => [transcription];
}

class FormatTranscriptionNote extends TranscriptionEvent {
  const FormatTranscriptionNote(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}
