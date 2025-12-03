import 'package:equatable/equatable.dart';

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
