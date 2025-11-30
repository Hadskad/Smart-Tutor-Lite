import '../../domain/entities/tts_job.dart';

class TtsJobModel extends TtsJob {
  const TtsJobModel({
    required super.id,
    required super.sourceType,
    required super.sourceId,
    required super.audioUrl,
    required super.status,
    required super.createdAt,
    super.voice,
    super.errorMessage,
  });

  factory TtsJobModel.fromJson(Map<String, dynamic> json) {
    return TtsJobModel(
      id: json['id'] as String? ?? '',
      sourceType: json['sourceType'] as String? ?? 'text',
      sourceId: json['sourceId'] as String? ?? '',
      audioUrl: json['audioUrl'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      voice: json['voice'] as String?,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'sourceType': sourceType,
      'sourceId': sourceId,
      'audioUrl': audioUrl,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      if (voice != null) 'voice': voice,
      if (errorMessage != null) 'errorMessage': errorMessage,
    };
  }

  TtsJobModel copyWith({
    String? id,
    String? sourceType,
    String? sourceId,
    String? audioUrl,
    String? status,
    DateTime? createdAt,
    String? voice,
    String? errorMessage,
  }) {
    return TtsJobModel(
      id: id ?? this.id,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      audioUrl: audioUrl ?? this.audioUrl,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      voice: voice ?? this.voice,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  factory TtsJobModel.fromEntity(TtsJob entity) {
    return TtsJobModel(
      id: entity.id,
      sourceType: entity.sourceType,
      sourceId: entity.sourceId,
      audioUrl: entity.audioUrl,
      status: entity.status,
      createdAt: entity.createdAt,
      voice: entity.voice,
      errorMessage: entity.errorMessage,
    );
  }

  TtsJob toEntity() {
    return TtsJob(
      id: id,
      sourceType: sourceType,
      sourceId: sourceId,
      audioUrl: audioUrl,
      status: status,
      createdAt: createdAt,
      voice: voice,
      errorMessage: errorMessage,
    );
  }
}

