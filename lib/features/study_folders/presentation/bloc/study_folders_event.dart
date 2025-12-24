import 'package:equatable/equatable.dart';

import '../../domain/entities/folder_material.dart';

abstract class StudyFoldersEvent extends Equatable {
  const StudyFoldersEvent();

  @override
  List<Object?> get props => [];
}

// --- Folder CRUD Events ---

class LoadFoldersEvent extends StudyFoldersEvent {
  const LoadFoldersEvent();
}

class CreateFolderEvent extends StudyFoldersEvent {
  const CreateFolderEvent({required this.name});

  final String name;

  @override
  List<Object?> get props => [name];
}

class RenameFolderEvent extends StudyFoldersEvent {
  const RenameFolderEvent({
    required this.folderId,
    required this.newName,
  });

  final String folderId;
  final String newName;

  @override
  List<Object?> get props => [folderId, newName];
}

class DeleteFolderEvent extends StudyFoldersEvent {
  const DeleteFolderEvent({required this.folderId});

  final String folderId;

  @override
  List<Object?> get props => [folderId];
}

// --- Folder-Material Association Events ---

class LoadFolderMaterialsEvent extends StudyFoldersEvent {
  const LoadFolderMaterialsEvent({required this.folderId});

  final String folderId;

  @override
  List<Object?> get props => [folderId];
}

class AddMaterialToFolderEvent extends StudyFoldersEvent {
  const AddMaterialToFolderEvent({
    required this.folderId,
    required this.materialId,
    required this.materialType,
  });

  final String folderId;
  final String materialId;
  final MaterialType materialType;

  @override
  List<Object?> get props => [folderId, materialId, materialType];
}

class RemoveMaterialFromFolderEvent extends StudyFoldersEvent {
  const RemoveMaterialFromFolderEvent({
    required this.folderId,
    required this.materialId,
  });

  final String folderId;
  final String materialId;

  @override
  List<Object?> get props => [folderId, materialId];
}

