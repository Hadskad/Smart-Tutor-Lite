import '../../domain/entities/transcription.dart';

class TranscriptionModel extends Transcription {
  const TranscriptionModel({
    required super.id,
    required super.text,
    required super.audioPath,
    required super.duration,
    required super.timestamp,
    required super.confidence,
    super.metadata = const <String, dynamic>{},
  });

  factory TranscriptionModel.fromJson(Map<String, dynamic> json) {
    return TranscriptionModel(
      id: json['id'] as String? ?? '',
      text: json['text'] as String? ?? '',
      audioPath: json['audio_path'] as String? ?? '',
      duration: Duration(
        milliseconds: json['duration_ms'] is int
            ? json['duration_ms'] as int
            : (json['duration_ms'] as num?)?.toInt() ?? 0,
      ),
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(
            json['timestamp_ms'] is int
                ? json['timestamp_ms'] as int
                : (json['timestamp_ms'] as num?)?.toInt() ??
                    DateTime.now().millisecondsSinceEpoch,
          ),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      metadata: Map<String, dynamic>.from(
        json['metadata'] as Map? ?? const <String, dynamic>{},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'text': text,
      'audio_path': audioPath,
      'duration_ms': duration.inMilliseconds,
      'timestamp': timestamp.toIso8601String(),
      'confidence': confidence,
      'metadata': metadata,
    };
  }

  TranscriptionModel copyWith({
    String? id,
    String? text,
    String? audioPath,
    Duration? duration,
    DateTime? timestamp,
    double? confidence,
    Map<String, dynamic>? metadata,
  }) {
    return TranscriptionModel(
      id: id ?? this.id,
      text: text ?? this.text,
      audioPath: audioPath ?? this.audioPath,
      duration: duration ?? this.duration,
      timestamp: timestamp ?? this.timestamp,
      confidence: confidence ?? this.confidence,
      metadata: metadata ?? this.metadata,
    );
  }

  factory TranscriptionModel.fromEntity(Transcription entity) {
    return TranscriptionModel(
      id: entity.id,
      text: entity.text,
      audioPath: entity.audioPath,
      duration: entity.duration,
      timestamp: entity.timestamp,
      confidence: entity.confidence,
      metadata: Map<String, dynamic>.from(entity.metadata),
    );
  }

  Transcription toEntity() {
    return Transcription(
      id: id,
      text: text,
      audioPath: audioPath,
      duration: duration,
      timestamp: timestamp,
      confidence: confidence,
      metadata: metadata,
    );
  }
}
