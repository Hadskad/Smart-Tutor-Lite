import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/study_folder.dart';
import '../../domain/repositories/study_folder_repository.dart';
import '../datasources/study_folder_local_datasource.dart';
import '../models/study_folder_model.dart';

@LazySingleton(as: StudyFolderRepository)
class StudyFolderRepositoryImpl implements StudyFolderRepository {
  StudyFolderRepositoryImpl(this._localDataSource);

  final StudyFolderLocalDataSource _localDataSource;
  static const _uuid = Uuid();

  @override
  Future<Either<Failure, List<StudyFolder>>> getAllFolders() async {
    try {
      final folders = await _localDataSource.getAllFolders();
      return Right(folders.map((model) => model.toEntity()).toList());
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
      return Right(folder?.toEntity());
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
      return Right(updated.toEntity());
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
}

