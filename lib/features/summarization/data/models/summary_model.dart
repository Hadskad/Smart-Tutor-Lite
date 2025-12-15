import '../../domain/entities/summary.dart';

class SummaryModel extends Summary {
  const SummaryModel({
    required super.id,
    required super.sourceType,
    required super.summaryText,
    super.sourceId,
    super.metadata = const <String, dynamic>{},
    required super.createdAt,
    super.title,
  });

  factory SummaryModel.fromJson(Map<String, dynamic> json) {
    return SummaryModel(
      id: json['id'] as String? ?? '',
      sourceType: json['sourceType'] as String? ?? 'text',
      sourceId: json['sourceId'] as String?,
      summaryText: json['summaryText'] as String? ?? '',
      metadata: Map<String, dynamic>.from(
        json['metadata'] as Map? ?? const <String, dynamic>{},
      ),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      title: json['title'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'sourceType': sourceType,
      'sourceId': sourceId,
      'summaryText': summaryText,
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
      if (title != null) 'title': title,
    };
  }

  SummaryModel copyWith({
    String? id,
    String? sourceType,
    String? sourceId,
    String? summaryText,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    String? title,
  }) {
    return SummaryModel(
      id: id ?? this.id,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      summaryText: summaryText ?? this.summaryText,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      title: title ?? this.title,
    );
  }

  factory SummaryModel.fromEntity(Summary entity) {
    return SummaryModel(
      id: entity.id,
      sourceType: entity.sourceType,
      sourceId: entity.sourceId,
      summaryText: entity.summaryText,
      metadata: Map<String, dynamic>.from(entity.metadata),
      createdAt: entity.createdAt,
      title: entity.title,
    );
  }

  Summary toEntity() {
    return Summary(
      id: id,
      sourceType: sourceType,
      sourceId: sourceId,
      summaryText: summaryText,
      metadata: metadata,
      createdAt: createdAt,
      title: title,
    );
  }
}
