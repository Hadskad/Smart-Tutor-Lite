import 'package:equatable/equatable.dart';

import '../../domain/entities/tts_job.dart';

abstract class TtsState extends Equatable {
  const TtsState({
    this.jobs = const <TtsJob>[],
  });

  final List<TtsJob> jobs;

  @override
  List<Object?> get props => [jobs];
}

class TtsInitial extends TtsState {
  const TtsInitial({super.jobs = const []});
}

class TtsProcessing extends TtsState {
  const TtsProcessing({super.jobs = const []});
}

class TtsSuccess extends TtsState {
  const TtsSuccess({
    required this.job,
    required super.jobs,
  });

  final TtsJob job;

  @override
  List<Object?> get props => [...super.props, job];
}

class TtsPlaying extends TtsState {
  const TtsPlaying({
    required this.currentAudioUrl,
    required this.isPlaying,
    super.jobs = const [],
  });

  final String currentAudioUrl;
  final bool isPlaying;

  @override
  List<Object?> get props => [...super.props, currentAudioUrl, isPlaying];
}

class TtsError extends TtsState {
  const TtsError({
    required this.message,
    super.jobs = const [],
  });

  final String message;

  @override
  List<Object?> get props => [...super.props, message];
}

