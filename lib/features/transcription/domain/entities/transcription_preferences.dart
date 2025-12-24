import 'package:equatable/equatable.dart';

class TranscriptionPreferences extends Equatable {
  const TranscriptionPreferences({
    this.alwaysUseOffline = false,
    this.useFastWhisperModel = false,
  });

  final bool alwaysUseOffline;
  final bool useFastWhisperModel;

  TranscriptionPreferences copyWith({
    bool? alwaysUseOffline,
    bool? useFastWhisperModel,
  }) {
    return TranscriptionPreferences(
      alwaysUseOffline: alwaysUseOffline ?? this.alwaysUseOffline,
      useFastWhisperModel: useFastWhisperModel ?? this.useFastWhisperModel,
    );
  }

  @override
  List<Object?> get props => [alwaysUseOffline, useFastWhisperModel];
}


