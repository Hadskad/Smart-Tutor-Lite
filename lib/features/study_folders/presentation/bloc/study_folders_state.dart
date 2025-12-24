import 'package:equatable/equatable.dart';

import '../../domain/entities/folder_material.dart';
import '../../domain/entities/study_folder.dart';

abstract class StudyFoldersState extends Equatable {
  const StudyFoldersState({
    this.folders = const <StudyFolder>[],
    this.currentFolderMaterials = const <FolderMaterial>[],
    this.materialCountsByType = const <MaterialType, int>{},
  });

  /// All folders
  final List<StudyFolder> folders;
  
  /// Materials in the currently viewed folder
  final List<FolderMaterial> currentFolderMaterials;
  
  /// Material counts by type for the current folder
  final Map<MaterialType, int> materialCountsByType;

  @override
  List<Object?> get props => [folders, currentFolderMaterials, materialCountsByType];
}

class StudyFoldersInitial extends StudyFoldersState {
  const StudyFoldersInitial({super.folders = const []});
}

class StudyFoldersLoading extends StudyFoldersState {
  const StudyFoldersLoading({
    super.folders = const [],
    super.currentFolderMaterials = const [],
    super.materialCountsByType = const {},
  });
}

class StudyFoldersLoaded extends StudyFoldersState {
  const StudyFoldersLoaded({
    required super.folders,
    super.currentFolderMaterials = const [],
    super.materialCountsByType = const {},
  });
}

class FolderMaterialsLoaded extends StudyFoldersState {
  const FolderMaterialsLoaded({
    required super.folders,
    required super.currentFolderMaterials,
    required super.materialCountsByType,
    required this.folderId,
  });

  /// ID of the folder whose materials are loaded
  final String folderId;

  @override
  List<Object?> get props => [...super.props, folderId];
}

class StudyFoldersError extends StudyFoldersState {
  const StudyFoldersError({
    required this.message,
    super.folders = const [],
    super.currentFolderMaterials = const [],
    super.materialCountsByType = const {},
  });

  final String message;

  @override
  List<Object?> get props => [...super.props, message];
}

