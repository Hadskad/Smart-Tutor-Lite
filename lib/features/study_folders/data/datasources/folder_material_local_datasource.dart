import 'package:hive/hive.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/folder_material.dart';
import '../models/folder_material_model.dart';

/// Local data source for managing folder-material associations.
abstract class FolderMaterialLocalDataSource {
  /// Gets all materials associated with a specific folder
  Future<List<FolderMaterialModel>> getMaterialsForFolder(String folderId);

  /// Gets all folder associations for a specific material
  Future<List<FolderMaterialModel>> getFoldersForMaterial(
    String materialId,
    MaterialType materialType,
  );

  /// Adds a material to a folder
  Future<FolderMaterialModel> addMaterialToFolder(FolderMaterialModel association);

  /// Removes a material from a folder
  Future<void> removeMaterialFromFolder(String folderId, String materialId);

  /// Removes all associations for a folder (when folder is deleted)
  Future<void> removeAllForFolder(String folderId);

  /// Removes all associations for a material (when material is deleted)
  Future<void> removeAllForMaterial(String materialId, MaterialType materialType);

  /// Checks if a material is in a specific folder
  Future<bool> isMaterialInFolder(String folderId, String materialId);

  /// Gets the count of materials in a folder
  Future<int> getMaterialCountForFolder(String folderId);

  /// Gets counts of materials by type for a folder
  Future<Map<MaterialType, int>> getMaterialCountsByType(String folderId);
}

@LazySingleton(as: FolderMaterialLocalDataSource)
class FolderMaterialLocalDataSourceImpl implements FolderMaterialLocalDataSource {
  FolderMaterialLocalDataSourceImpl(this._hive);

  static const String _boxName = 'folder_materials';

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
  Future<List<FolderMaterialModel>> getMaterialsForFolder(String folderId) async {
    try {
      final box = await _getBox();
      final associations = box.values
          .map((data) => FolderMaterialModel.fromJson(Map<String, dynamic>.from(data)))
          .where((assoc) => assoc.folderId == folderId)
          .toList();
      // Sort by addedAt, most recent first
      associations.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      return associations;
    } catch (e) {
      throw CacheFailure(
        message: 'Failed to get materials for folder: ${e.toString()}',
      );
    }
  }

  @override
  Future<List<FolderMaterialModel>> getFoldersForMaterial(
    String materialId,
    MaterialType materialType,
  ) async {
    try {
      final box = await _getBox();
      final associations = box.values
          .map((data) => FolderMaterialModel.fromJson(Map<String, dynamic>.from(data)))
          .where((assoc) =>
              assoc.materialId == materialId && assoc.materialType == materialType)
          .toList();
      return associations;
    } catch (e) {
      throw CacheFailure(
        message: 'Failed to get folders for material: ${e.toString()}',
      );
    }
  }

  @override
  Future<FolderMaterialModel> addMaterialToFolder(FolderMaterialModel association) async {
    try {
      final box = await _getBox();
      
      // Check if association already exists
      final existing = box.values.any((data) {
        final assoc = FolderMaterialModel.fromJson(Map<String, dynamic>.from(data));
        return assoc.folderId == association.folderId &&
            assoc.materialId == association.materialId;
      });
      
      if (existing) {
        throw const CacheFailure(
          message: 'Material is already in this folder',
        );
      }
      
      await box.put(association.id, association.toJson());
      return association;
    } catch (e) {
      if (e is CacheFailure) rethrow;
      throw CacheFailure(
        message: 'Failed to add material to folder: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> removeMaterialFromFolder(String folderId, String materialId) async {
    try {
      final box = await _getBox();
      
      // Find and remove the association
      String? keyToRemove;
      for (final entry in box.toMap().entries) {
        final assoc = FolderMaterialModel.fromJson(
          Map<String, dynamic>.from(entry.value),
        );
        if (assoc.folderId == folderId && assoc.materialId == materialId) {
          keyToRemove = entry.key.toString();
          break;
        }
      }
      
      if (keyToRemove != null) {
        await box.delete(keyToRemove);
      }
    } catch (e) {
      throw CacheFailure(
        message: 'Failed to remove material from folder: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> removeAllForFolder(String folderId) async {
    try {
      final box = await _getBox();
      final keysToRemove = <dynamic>[];
      
      for (final entry in box.toMap().entries) {
        final assoc = FolderMaterialModel.fromJson(
          Map<String, dynamic>.from(entry.value),
        );
        if (assoc.folderId == folderId) {
          keysToRemove.add(entry.key);
        }
      }
      
      if (keysToRemove.isNotEmpty) {
        await box.deleteAll(keysToRemove);
      }
    } catch (e) {
      throw CacheFailure(
        message: 'Failed to remove all materials from folder: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> removeAllForMaterial(
    String materialId,
    MaterialType materialType,
  ) async {
    try {
      final box = await _getBox();
      final keysToRemove = <dynamic>[];
      
      for (final entry in box.toMap().entries) {
        final assoc = FolderMaterialModel.fromJson(
          Map<String, dynamic>.from(entry.value),
        );
        if (assoc.materialId == materialId && assoc.materialType == materialType) {
          keysToRemove.add(entry.key);
        }
      }
      
      if (keysToRemove.isNotEmpty) {
        await box.deleteAll(keysToRemove);
      }
    } catch (e) {
      throw CacheFailure(
        message: 'Failed to remove material associations: ${e.toString()}',
      );
    }
  }

  @override
  Future<bool> isMaterialInFolder(String folderId, String materialId) async {
    try {
      final box = await _getBox();
      
      for (final data in box.values) {
        final assoc = FolderMaterialModel.fromJson(
          Map<String, dynamic>.from(data),
        );
        if (assoc.folderId == folderId && assoc.materialId == materialId) {
          return true;
        }
      }
      
      return false;
    } catch (e) {
      throw CacheFailure(
        message: 'Failed to check material in folder: ${e.toString()}',
      );
    }
  }

  @override
  Future<int> getMaterialCountForFolder(String folderId) async {
    try {
      final box = await _getBox();
      int count = 0;
      
      for (final data in box.values) {
        final assoc = FolderMaterialModel.fromJson(
          Map<String, dynamic>.from(data),
        );
        if (assoc.folderId == folderId) {
          count++;
        }
      }
      
      return count;
    } catch (e) {
      throw CacheFailure(
        message: 'Failed to get material count: ${e.toString()}',
      );
    }
  }

  @override
  Future<Map<MaterialType, int>> getMaterialCountsByType(String folderId) async {
    try {
      final box = await _getBox();
      final counts = <MaterialType, int>{};
      
      for (final type in MaterialType.values) {
        counts[type] = 0;
      }
      
      for (final data in box.values) {
        final assoc = FolderMaterialModel.fromJson(
          Map<String, dynamic>.from(data),
        );
        if (assoc.folderId == folderId) {
          counts[assoc.materialType] = (counts[assoc.materialType] ?? 0) + 1;
        }
      }
      
      return counts;
    } catch (e) {
      throw CacheFailure(
        message: 'Failed to get material counts by type: ${e.toString()}',
      );
    }
  }
}

