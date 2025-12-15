import 'package:hive/hive.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../models/study_folder_model.dart';

abstract class StudyFolderLocalDataSource {
  /// Get all study folders
  Future<List<StudyFolderModel>> getAllFolders();

  /// Get a study folder by ID
  Future<StudyFolderModel?> getFolderById(String id);

  /// Create a new study folder
  Future<StudyFolderModel> createFolder(StudyFolderModel folder);

  /// Update an existing study folder
  Future<StudyFolderModel> updateFolder(StudyFolderModel folder);

  /// Delete a study folder by ID
  Future<void> deleteFolder(String id);

  /// Check if a folder name already exists
  Future<bool> folderNameExists(String name, {String? excludeId});
}

@LazySingleton(as: StudyFolderLocalDataSource)
class StudyFolderLocalDataSourceImpl implements StudyFolderLocalDataSource {
  StudyFolderLocalDataSourceImpl(this._hive);

  static const String _boxName = 'study_folders';

  final HiveInterface _hive;
  Box<Map>? _box;

  Future<Box<Map>> _getBox() async {
    if (_box?.isOpen ?? false) {
      return _box!;
    }
    _box = await _hive.openBox<Map>(_boxName);
    return _box!;
  }

  @override
  Future<List<StudyFolderModel>> getAllFolders() async {
    try {
      final box = await _getBox();
      final folders = box.values
          .map((data) =>
              StudyFolderModel.fromJson(Map<String, dynamic>.from(data)))
          .toList();
      // Sort by createdAt, most recent first
      folders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return folders;
    } catch (e) {
      throw CacheFailure(
        message: 'Failed to get study folders: ${e.toString()}',
      );
    }
  }

  @override
  Future<StudyFolderModel?> getFolderById(String id) async {
    try {
      final box = await _getBox();
      final data = box.get(id);
      if (data == null) return null;
      return StudyFolderModel.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      throw CacheFailure(
        message: 'Failed to get study folder: ${e.toString()}',
      );
    }
  }

  @override
  Future<StudyFolderModel> createFolder(StudyFolderModel folder) async {
    try {
      final box = await _getBox();
      await box.put(folder.id, folder.toJson());
      return folder;
    } catch (e) {
      throw CacheFailure(
        message: 'Failed to create study folder: ${e.toString()}',
      );
    }
  }

  @override
  Future<StudyFolderModel> updateFolder(StudyFolderModel folder) async {
    try {
      final box = await _getBox();
      await box.put(folder.id, folder.toJson());
      return folder;
    } catch (e) {
      throw CacheFailure(
        message: 'Failed to update study folder: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> deleteFolder(String id) async {
    try {
      final box = await _getBox();
      await box.delete(id);
    } catch (e) {
      throw CacheFailure(
        message: 'Failed to delete study folder: ${e.toString()}',
      );
    }
  }

  @override
  Future<bool> folderNameExists(String name, {String? excludeId}) async {
    try {
      final box = await _getBox();
      for (final entry in box.toMap().entries) {
        final folder =
            StudyFolderModel.fromJson(Map<String, dynamic>.from(entry.value));
        // Skip the folder we're checking against (for updates)
        if (excludeId != null && folder.id == excludeId) {
          continue;
        }
        if (folder.name.trim().toLowerCase() == name.trim().toLowerCase()) {
          return true;
        }
      }
      return false;
    } catch (e) {
      throw CacheFailure(
        message: 'Failed to check folder name existence: ${e.toString()}',
      );
    }
  }
}

