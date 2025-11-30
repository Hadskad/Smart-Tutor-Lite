import 'package:equatable/equatable.dart';

import '../../../transcription/domain/entities/transcription.dart';
import '../../../../native_bridge/performance_bridge.dart';

abstract class TranscriptionState extends Equatable {
  const TranscriptionState({
    this.history = const <Transcription>[],
  });

  final List<Transcription> history;

  @override
  List<Object?> get props => [history];
}

class TranscriptionInitial extends TranscriptionState {
  const TranscriptionInitial({super.history = const []});
}

class TranscriptionRecording extends TranscriptionState {
  const TranscriptionRecording({
    required this.startedAt,
    this.filePath,
    super.history = const [],
  });

  final DateTime startedAt;
  final String? filePath;

  @override
  List<Object?> get props => [...super.props, startedAt, filePath];
}

class TranscriptionProcessing extends TranscriptionState {
  const TranscriptionProcessing({
    required this.audioPath,
    super.history = const [],
  });

  final String audioPath;

  @override
  List<Object?> get props => [...super.props, audioPath];
}

class TranscriptionSuccess extends TranscriptionState {
  const TranscriptionSuccess({
    required this.transcription,
    required List<Transcription> history,
    this.metrics,
  }) : super(history: history);

  final Transcription transcription;
  final PerformanceMetrics? metrics;

  @override
  List<Object?> get props => [...super.props, transcription, metrics];
}

class TranscriptionError extends TranscriptionState {
  const TranscriptionError({
    required this.message,
    super.history = const [],
  });

  final String message;

  @override
  List<Object?> get props => [...super.props, message];
}
