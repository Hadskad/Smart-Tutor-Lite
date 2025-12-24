import 'package:equatable/equatable.dart';

/// Represents a study folder that organizes study materials.
class StudyFolder extends Equatable {
  const StudyFolder({
    required this.id,
    required this.name,
    required this.createdAt,
    this.materialCount = 0,
  });

  final String id;
  final String name;
  final DateTime createdAt;
  
  /// Total count of materials in this folder
  final int materialCount;

  /// Creates a copy of this folder with optional field overrides
  StudyFolder copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    int? materialCount,
  }) {
    return StudyFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      materialCount: materialCount ?? this.materialCount,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        createdAt,
        materialCount,
      ];
}

