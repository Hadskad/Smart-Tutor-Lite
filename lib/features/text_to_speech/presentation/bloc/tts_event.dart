import 'package:equatable/equatable.dart';

abstract class TtsEvent extends Equatable {
  const TtsEvent();

  @override
  List<Object?> get props => [];
}

class ConvertPdfToAudioEvent extends TtsEvent {
  const ConvertPdfToAudioEvent({
    required this.pdfUrl,
    this.voice = '21m00Tcm4TlvDq8ikWAM', // Rachel
  });

  final String pdfUrl;
  final String voice;

  @override
  List<Object?> get props => [pdfUrl, voice];
}

class ConvertTextToAudioEvent extends TtsEvent {
  const ConvertTextToAudioEvent({
    required this.text,
    this.voice = '21m00Tcm4TlvDq8ikWAM', // Rachel
  });

  final String text;
  final String voice;

  @override
  List<Object?> get props => [text, voice];
}

class LoadTtsJobsEvent extends TtsEvent {
  const LoadTtsJobsEvent();
}

class PlayAudioEvent extends TtsEvent {
  const PlayAudioEvent(this.audioUrl);

  final String audioUrl;

  @override
  List<Object?> get props => [audioUrl];
}

class PauseAudioEvent extends TtsEvent {
  const PauseAudioEvent();
}

class StopAudioEvent extends TtsEvent {
  const StopAudioEvent();
}

class DeleteTtsJobEvent extends TtsEvent {
  const DeleteTtsJobEvent(this.jobId);

  final String jobId;

  @override
  List<Object?> get props => [jobId];
}

class ProcessQueuedJobsEvent extends TtsEvent {
  const ProcessQueuedJobsEvent();
}
