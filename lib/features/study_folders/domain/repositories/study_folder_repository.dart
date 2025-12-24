import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/folder_material.dart';
import '../entities/study_folder.dart';

abstract class StudyFolderRepository {
  // --- Folder CRUD Operations ---

  /// Get all study folders with their material counts
  Future<Either<Failure, List<StudyFolder>>> getAllFolders();

  /// Get a study folder by ID
  Future<Either<Failure, StudyFolder?>> getFolderById(String id);

  /// Create a new study folder
  Future<Either<Failure, StudyFolder>> createFolder(String name);

  /// Update an existing study folder (e.g., rename)
  Future<Either<Failure, StudyFolder>> updateFolder(StudyFolder folder);

  /// Delete a study folder by ID (also removes all material associations)
  Future<Either<Failure, Unit>> deleteFolder(String id);

  /// Check if a folder name already exists
  Future<Either<Failure, bool>> folderNameExists(String name, {String? excludeId});

  // --- Folder-Material Association Operations ---

  /// Add a material to a folder
  Future<Either<Failure, FolderMaterial>> addMaterialToFolder({
    required String folderId,
    required String materialId,
    required MaterialType materialType,
  });

  /// Remove a material from a folder
  Future<Either<Failure, Unit>> removeMaterialFromFolder({
    required String folderId,
    required String materialId,
  });

  /// Get all materials in a folder
  Future<Either<Failure, List<FolderMaterial>>> getMaterialsInFolder(String folderId);

  /// Get the folders a material belongs to
  Future<Either<Failure, List<FolderMaterial>>> getFoldersForMaterial({
    required String materialId,
    required MaterialType materialType,
  });

  /// Check if a material is in a specific folder
  Future<Either<Failure, bool>> isMaterialInFolder({
    required String folderId,
    required String materialId,
  });

  /// Get material counts by type for a folder
  Future<Either<Failure, Map<MaterialType, int>>> getMaterialCountsByType(String folderId);
}

