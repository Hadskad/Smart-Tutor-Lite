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

class LoadTranscriptions extends TranscriptionEvent {
  const LoadTranscriptions();
}
