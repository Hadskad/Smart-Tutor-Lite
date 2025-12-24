import 'package:equatable/equatable.dart';

abstract class TtsEvent extends Equatable {
  const TtsEvent();

  @override
  List<Object?> get props => [];
}

class ConvertPdfToAudioEvent extends TtsEvent {
  const ConvertPdfToAudioEvent({
    required this.pdfUrl,
    this.voice = 'en-US-Neural2-D', // Neural2-D (default)
  });

  final String pdfUrl;
  final String voice;

  @override
  List<Object?> get props => [pdfUrl, voice];
}

class ConvertTextToAudioEvent extends TtsEvent {
  const ConvertTextToAudioEvent({
    required this.text,
    this.voice = 'en-US-Neural2-D', // Neural2-D (default)
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

/// Starts polling for processing job status updates
class StartPollingEvent extends TtsEvent {
  const StartPollingEvent();
}

/// Stops polling for job status updates
class StopPollingEvent extends TtsEvent {
  const StopPollingEvent();
}

/// Internal event triggered when a job status is updated from polling
class JobStatusUpdatedEvent extends TtsEvent {
  const JobStatusUpdatedEvent(this.jobId);

  final String jobId;

  @override
  List<Object?> get props => [jobId];
}

/// Retry a failed TTS job
class RetryTtsJobEvent extends TtsEvent {
  const RetryTtsJobEvent(this.jobId);

  final String jobId;

  @override
  List<Object?> get props => [jobId];
}