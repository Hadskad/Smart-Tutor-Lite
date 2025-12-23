import 'package:equatable/equatable.dart';

import '../../domain/entities/transcription.dart';
import '../../domain/entities/transcription_job.dart';
import '../../domain/entities/transcription_preferences.dart';
import '../../../../native_bridge/performance_bridge.dart';
import 'queued_transcription_job.dart';

abstract class TranscriptionState extends Equatable {
  const TranscriptionState({
    this.history = const <Transcription>[],
    this.preferences = const TranscriptionPreferences(),
    this.queueLength = 0,
    this.queue = const <QueuedTranscriptionJob>[],
    this.formattingTranscriptionId,
  });

  final List<Transcription> history;
  final TranscriptionPreferences preferences;
  final int queueLength;
  final List<QueuedTranscriptionJob> queue;
  final String? formattingTranscriptionId;

  @override
  List<Object?> get props => [history, preferences, queueLength, queue, formattingTranscriptionId];
}

class TranscriptionInitial extends TranscriptionState {
  const TranscriptionInitial({
    super.history = const [],
    super.preferences = const TranscriptionPreferences(),
    super.queueLength = 0,
    super.queue = const [],
    super.formattingTranscriptionId,
  });
}

enum TranscriptionNoticeSeverity { info, warning }

class TranscriptionNotice extends TranscriptionState {
  const TranscriptionNotice({
    required this.message,
    required this.severity,
    super.history = const [],
    super.preferences = const TranscriptionPreferences(),
    super.queueLength = 0,
    super.queue = const [],
    super.formattingTranscriptionId,
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
    super.preferences = const TranscriptionPreferences(),
    super.queueLength = 0,
    super.queue = const [],
    super.formattingTranscriptionId,
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
    TranscriptionPreferences? preferences,
    int? queueLength,
    List<QueuedTranscriptionJob>? queue,
    String? formattingTranscriptionId,
  }) {
    return TranscriptionRecording(
      startedAt: startedAt ?? this.startedAt,
      filePath: filePath ?? this.filePath,
      estimatedSizeBytes: estimatedSizeBytes ?? this.estimatedSizeBytes,
      isInputTooLow: isInputTooLow ?? this.isInputTooLow,
      history: history ?? this.history,
      preferences: preferences ?? this.preferences,
      queueLength: queueLength ?? this.queueLength,
      queue: queue ?? this.queue,
      formattingTranscriptionId: formattingTranscriptionId ?? this.formattingTranscriptionId,
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

class TranscriptionStopping extends TranscriptionState {
  const TranscriptionStopping({
    super.history = const [],
    super.preferences = const TranscriptionPreferences(),
    super.queueLength = 0,
    super.queue = const [],
    super.formattingTranscriptionId,
  });
}

class TranscriptionProcessing extends TranscriptionState {
  const TranscriptionProcessing({
    required this.audioPath,
    super.history = const [],
    super.preferences = const TranscriptionPreferences(),
    super.queueLength = 0,
    super.queue = const [],
    super.formattingTranscriptionId,
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
    super.preferences = const TranscriptionPreferences(),
    super.queueLength = 0,
    super.queue = const [],
    super.formattingTranscriptionId,
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
    super.preferences = const TranscriptionPreferences(),
    super.queueLength = 0,
    super.queue = const [],
    super.formattingTranscriptionId,
  });

  final String message;

  @override
  List<Object?> get props => [...super.props, message];
}

class CloudTranscriptionState extends TranscriptionState {
  const CloudTranscriptionState({
    required this.job,
    super.history = const [],
    super.preferences = const TranscriptionPreferences(),
    super.queueLength = 0,
    super.queue = const [],
    super.formattingTranscriptionId,
  });

  final TranscriptionJob job;

  CloudTranscriptionState copyWithJob(TranscriptionJob updatedJob) {
    return CloudTranscriptionState(
      job: updatedJob,
      history: history,
      preferences: preferences,
      queueLength: queueLength,
      queue: queue,
      formattingTranscriptionId: formattingTranscriptionId,
    );
  }

  @override
  List<Object?> get props => [...super.props, job];
}

class TranscriptionFallbackPrompt extends TranscriptionState {
  const TranscriptionFallbackPrompt({
    required this.audioPath,
    required this.duration,
    required this.fileSizeBytes,
    this.reason,
    super.history = const [],
    super.preferences = const TranscriptionPreferences(),
    super.queueLength = 0,
    super.queue = const [],
    super.formattingTranscriptionId,
  });

  final String audioPath;
  final Duration duration;
  final int fileSizeBytes;
  final String? reason;

  @override
  List<Object?> get props =>
      [...super.props, audioPath, duration, fileSizeBytes, reason];
}
