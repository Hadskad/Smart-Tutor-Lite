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

enum TranscriptionNoticeSeverity { info, warning }

class TranscriptionNotice extends TranscriptionState {
  const TranscriptionNotice({
    required this.message,
    required this.severity,
    super.history = const [],
  });

  final String message;
  final TranscriptionNoticeSeverity severity;

  @override
  List<Object?> get props => [...super.props, message, severity];
}

class TranscriptionRecording extends TranscriptionState {
  const TranscriptionRecording({
    required this.startedAt,
    this.filePath,
    this.estimatedSizeBytes = 0,
    this.isInputTooLow = false,
    super.history = const [],
  });

  final DateTime startedAt;
  final String? filePath;
  final int estimatedSizeBytes;
  final bool isInputTooLow;

  TranscriptionRecording copyWith({
    DateTime? startedAt,
    String? filePath,
    int? estimatedSizeBytes,
    bool? isInputTooLow,
    List<Transcription>? history,
  }) {
    return TranscriptionRecording(
      startedAt: startedAt ?? this.startedAt,
      filePath: filePath ?? this.filePath,
      estimatedSizeBytes: estimatedSizeBytes ?? this.estimatedSizeBytes,
      isInputTooLow: isInputTooLow ?? this.isInputTooLow,
      history: history ?? this.history,
    );
  }

  @override
  List<Object?> get props => [
        ...super.props,
        startedAt,
        filePath,
        estimatedSizeBytes,
        isInputTooLow,
      ];
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
    this.metrics,
    required super.history,
  });

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
