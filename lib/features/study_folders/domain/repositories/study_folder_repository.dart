import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/study_folder.dart';

abstract class StudyFolderRepository {
  /// Get all study folders
  Future<Either<Failure, List<StudyFolder>>> getAllFolders();

  /// Get a study folder by ID
  Future<Either<Failure, StudyFolder?>> getFolderById(String id);

  /// Create a new study folder
  Future<Either<Failure, StudyFolder>> createFolder(String name);

  /// Update an existing study folder
  Future<Either<Failure, StudyFolder>> updateFolder(StudyFolder folder);

  /// Delete a study folder by ID
  Future<Either<Failure, Unit>> deleteFolder(String id);

  /// Check if a folder name already exists
  Future<Either<Failure, bool>> folderNameExists(String name, {String? excludeId});
}

