import 'dart:collection';

import 'package:equatable/equatable.dart';

/// Represents a transcription generated from an audio source.
class Transcription extends Equatable {
  const Transcription({
    required this.id,
    required this.text,
    required this.audioPath,
    required this.duration,
    required this.timestamp,
    required this.confidence,
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final String text;
  final String audioPath;
  final Duration duration;
  final DateTime timestamp;
  final double confidence;
  final Map<String, dynamic> metadata;

  /// Returns an unmodifiable view to keep the entity immutable.
  UnmodifiableMapView<String, dynamic> get metadataView =>
      UnmodifiableMapView(metadata);

  @override
  List<Object?> get props => [
        id,
        text,
        audioPath,
        duration,
        timestamp,
        confidence,
        metadata,
      ];
}
