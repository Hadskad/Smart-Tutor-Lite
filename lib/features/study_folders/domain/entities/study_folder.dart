import 'package:equatable/equatable.dart';

/// Represents a study folder that organizes study materials.
class StudyFolder extends Equatable {
  const StudyFolder({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
        id,
        name,
        createdAt,
      ];
}

