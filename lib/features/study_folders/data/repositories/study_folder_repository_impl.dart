import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/folder_material.dart';
import '../../domain/entities/study_folder.dart';
import '../../domain/repositories/study_folder_repository.dart';
import '../datasources/folder_material_local_datasource.dart';
import '../datasources/study_folder_local_datasource.dart';
import '../models/folder_material_model.dart';
import '../models/study_folder_model.dart';

@LazySingleton(as: StudyFolderRepository)
class StudyFolderRepositoryImpl implements StudyFolderRepository {
  StudyFolderRepositoryImpl(
    this._localDataSource,
    this._materialDataSource,
  );

  final StudyFolderLocalDataSource _localDataSource;
  final FolderMaterialLocalDataSource _materialDataSource;
  static const _uuid = Uuid();

  // --- Folder CRUD Operations ---

  @override
  Future<Either<Failure, List<StudyFolder>>> getAllFolders() async {
    try {
      final folders = await _localDataSource.getAllFolders();
      
      // Enrich folders with material counts
      final enrichedFolders = <StudyFolder>[];
      for (final folder in folders) {
        final count = await _materialDataSource.getMaterialCountForFolder(folder.id);
        enrichedFolders.add(folder.copyWith(materialCount: count).toEntity());
      }
      
      return Right(enrichedFolders);
    } on CacheFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(CacheFailure(
        message: 'Unexpected error getting folders: ${e.toString()}',
        cause: e,
      ));
    }
  }

  @override
  Future<Either<Failure, StudyFolder?>> getFolderById(String id) async {
    try {
      final folder = await _localDataSource.getFolderById(id);
      if (folder == null) return const Right(null);
      
      // Enrich with material count
      final count = await _materialDataSource.getMaterialCountForFolder(id);
      return Right(folder.copyWith(materialCount: count).toEntity());
    } on CacheFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(CacheFailure(
        message: 'Unexpected error getting folder: ${e.toString()}',
        cause: e,
      ));
    }
  }

  @override
  Future<Either<Failure, StudyFolder>> createFolder(String name) async {
    try {
      final trimmedName = name.trim();
      
      // Validate name is not empty
      if (trimmedName.isEmpty) {
        return const Left(
          LocalFailure(message: 'Folder name cannot be empty'),
        );
      }

      // Check if name already exists
      final nameExists = await _localDataSource.folderNameExists(trimmedName);
      if (nameExists) {
        return const Left(
          LocalFailure(message: 'A folder with this name already exists'),
        );
      }

      // Create new folder
      final folder = StudyFolderModel(
        id: _uuid.v4(),
        name: trimmedName,
        createdAt: DateTime.now(),
        materialCount: 0,
      );

      final created = await _localDataSource.createFolder(folder);
      return Right(created.toEntity());
    } on CacheFailure catch (e) {
      return Left(e);
    } on LocalFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(LocalFailure(
        message: 'Unexpected error creating folder: ${e.toString()}',
        cause: e,
      ));
    }
  }

  @override
  Future<Either<Failure, StudyFolder>> updateFolder(StudyFolder folder) async {
    try {
      final trimmedName = folder.name.trim();
      
      // Validate name is not empty
      if (trimmedName.isEmpty) {
        return const Left(
          LocalFailure(message: 'Folder name cannot be empty'),
        );
      }

      // Check if name already exists (excluding current folder)
      final nameExists =
          await _localDataSource.folderNameExists(trimmedName, excludeId: folder.id);
      if (nameExists) {
        return const Left(
          LocalFailure(message: 'A folder with this name already exists'),
        );
      }

      // Update folder
      final folderModel = StudyFolderModel.fromEntity(folder).copyWith(
        name: trimmedName,
      );

      final updated = await _localDataSource.updateFolder(folderModel);
      
      // Return with current material count
      final count = await _materialDataSource.getMaterialCountForFolder(folder.id);
      return Right(updated.copyWith(materialCount: count).toEntity());
    } on CacheFailure catch (e) {
      return Left(e);
    } on LocalFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(LocalFailure(
        message: 'Unexpected error updating folder: ${e.toString()}',
        cause: e,
      ));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteFolder(String id) async {
    try {
      // First, remove all material associations
      await _materialDataSource.removeAllForFolder(id);
      
      // Then delete the folder
      await _localDataSource.deleteFolder(id);
      return const Right(unit);
    } on CacheFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(CacheFailure(
        message: 'Unexpected error deleting folder: ${e.toString()}',
        cause: e,
      ));
    }
  }

  @override
  Future<Either<Failure, bool>> folderNameExists(String name, {String? excludeId}) async {
    try {
      final trimmedName = name.trim();
      final exists = await _localDataSource.folderNameExists(trimmedName, excludeId: excludeId);
      return Right(exists);
    } on CacheFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(CacheFailure(
        message: 'Unexpected error checking folder name: ${e.toString()}',
        cause: e,
      ));
    }
  }

  // --- Folder-Material Association Operations ---

  @override
  Future<Either<Failure, FolderMaterial>> addMaterialToFolder({
    required String folderId,
    required String materialId,
    required MaterialType materialType,
  }) async {
    try {
      final association = FolderMaterialModel(
        id: _uuid.v4(),
        folderId: folderId,
        materialId: materialId,
        materialType: materialType,
        addedAt: DateTime.now(),
      );
      
      final created = await _materialDataSource.addMaterialToFolder(association);
      return Right(created.toEntity());
    } on CacheFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(CacheFailure(
        message: 'Failed to add material to folder: ${e.toString()}',
        cause: e,
      ));
    }
  }

  @override
  Future<Either<Failure, Unit>> removeMaterialFromFolder({
    required String folderId,
    required String materialId,
  }) async {
    try {
      await _materialDataSource.removeMaterialFromFolder(folderId, materialId);
      return const Right(unit);
    } on CacheFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(CacheFailure(
        message: 'Failed to remove material from folder: ${e.toString()}',
        cause: e,
      ));
    }
  }

  @override
  Future<Either<Failure, List<FolderMaterial>>> getMaterialsInFolder(String folderId) async {
    try {
      final materials = await _materialDataSource.getMaterialsForFolder(folderId);
      return Right(materials.map((m) => m.toEntity()).toList());
    } on CacheFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(CacheFailure(
        message: 'Failed to get materials in folder: ${e.toString()}',
        cause: e,
      ));
    }
  }

  @override
  Future<Either<Failure, List<FolderMaterial>>> getFoldersForMaterial({
    required String materialId,
    required MaterialType materialType,
  }) async {
    try {
      final folders = await _materialDataSource.getFoldersForMaterial(
        materialId,
        materialType,
      );
      return Right(folders.map((f) => f.toEntity()).toList());
    } on CacheFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(CacheFailure(
        message: 'Failed to get folders for material: ${e.toString()}',
        cause: e,
      ));
    }
  }

  @override
  Future<Either<Failure, bool>> isMaterialInFolder({
    required String folderId,
    required String materialId,
  }) async {
    try {
      final isInFolder = await _materialDataSource.isMaterialInFolder(folderId, materialId);
      return Right(isInFolder);
    } on CacheFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(CacheFailure(
        message: 'Failed to check material in folder: ${e.toString()}',
        cause: e,
      ));
    }
  }

  @override
  Future<Either<Failure, Map<MaterialType, int>>> getMaterialCountsByType(String folderId) async {
    try {
      final counts = await _materialDataSource.getMaterialCountsByType(folderId);
      return Right(counts);
    } on CacheFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(CacheFailure(
        message: 'Failed to get material counts: ${e.toString()}',
        cause: e,
      ));
    }
  }
}
