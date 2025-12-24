import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/study_folder.dart';
import '../../domain/repositories/study_folder_repository.dart';
import 'study_folders_event.dart';
import 'study_folders_state.dart';

@lazySingleton
class StudyFoldersBloc extends Bloc<StudyFoldersEvent, StudyFoldersState> {
  StudyFoldersBloc(this._repository) : super(const StudyFoldersInitial()) {
    // Folder CRUD events
    on<LoadFoldersEvent>(_onLoadFolders);
    on<CreateFolderEvent>(_onCreateFolder);
    on<RenameFolderEvent>(_onRenameFolder);
    on<DeleteFolderEvent>(_onDeleteFolder);
    
    // Folder-Material events
    on<LoadFolderMaterialsEvent>(_onLoadFolderMaterials);
    on<AddMaterialToFolderEvent>(_onAddMaterialToFolder);
    on<RemoveMaterialFromFolderEvent>(_onRemoveMaterialFromFolder);
  }

  final StudyFolderRepository _repository;

  // --- Folder CRUD Handlers ---

  Future<void> _onLoadFolders(
    LoadFoldersEvent event,
    Emitter<StudyFoldersState> emit,
  ) async {
    // Preserve current folders in case of error
    final currentFolders = state.folders;
    emit(StudyFoldersLoading(folders: currentFolders));

    final result = await _repository.getAllFolders();

    result.fold(
      (failure) => emit(
        StudyFoldersError(
          message: failure.message ?? 'Failed to load folders',
          folders: currentFolders,
        ),
      ),
      (folders) => emit(StudyFoldersLoaded(folders: folders)),
    );
  }

  Future<void> _onCreateFolder(
    CreateFolderEvent event,
    Emitter<StudyFoldersState> emit,
  ) async {
    // Keep current folders in state during creation
    final currentFolders = state.folders;

    final result = await _repository.createFolder(event.name);

    result.fold(
      (failure) => emit(
        StudyFoldersError(
          message: failure.message ?? 'Failed to create folder',
          folders: currentFolders,
        ),
      ),
      (newFolder) {
        // Add the new folder to the beginning of the list (most recent first)
        final updatedFolders = [newFolder, ...currentFolders];
        emit(StudyFoldersLoaded(folders: updatedFolders));
      },
    );
  }

  Future<void> _onRenameFolder(
    RenameFolderEvent event,
    Emitter<StudyFoldersState> emit,
  ) async {
    final currentFolders = state.folders;
    
    // Find the folder to rename
    final folderIndex = currentFolders.indexWhere((f) => f.id == event.folderId);
    if (folderIndex == -1) {
      emit(StudyFoldersError(
        message: 'Folder not found',
        folders: currentFolders,
      ));
      return;
    }
    
    final folder = currentFolders[folderIndex];
    final updatedFolder = StudyFolder(
      id: folder.id,
      name: event.newName,
      createdAt: folder.createdAt,
      materialCount: folder.materialCount,
    );

    final result = await _repository.updateFolder(updatedFolder);

    result.fold(
      (failure) => emit(
        StudyFoldersError(
          message: failure.message ?? 'Failed to rename folder',
          folders: currentFolders,
        ),
      ),
      (renamedFolder) {
        // Update the folder in the list
        final updatedFolders = List<StudyFolder>.from(currentFolders);
        updatedFolders[folderIndex] = renamedFolder;
        emit(StudyFoldersLoaded(folders: updatedFolders));
      },
    );
  }

  Future<void> _onDeleteFolder(
    DeleteFolderEvent event,
    Emitter<StudyFoldersState> emit,
  ) async {
    // Keep current folders in state during deletion
    final currentFolders = state.folders;

    final result = await _repository.deleteFolder(event.folderId);

    result.fold(
      (failure) => emit(
        StudyFoldersError(
          message: failure.message ?? 'Failed to delete folder',
          folders: currentFolders,
        ),
      ),
      (_) {
        // Remove the deleted folder from the list
        final updatedFolders =
            currentFolders.where((f) => f.id != event.folderId).toList();
        emit(StudyFoldersLoaded(folders: updatedFolders));
      },
    );
  }

  // --- Folder-Material Handlers ---

  Future<void> _onLoadFolderMaterials(
    LoadFolderMaterialsEvent event,
    Emitter<StudyFoldersState> emit,
  ) async {
    final currentFolders = state.folders;
    emit(StudyFoldersLoading(folders: currentFolders));

    final materialsResult = await _repository.getMaterialsInFolder(event.folderId);
    final countsResult = await _repository.getMaterialCountsByType(event.folderId);

    if (materialsResult.isLeft() || countsResult.isLeft()) {
      final error = materialsResult.fold(
        (f) => f.message ?? 'Failed to load materials',
        (_) => countsResult.fold(
          (f) => f.message ?? 'Failed to load material counts',
          (_) => 'Unknown error',
        ),
      );
      emit(StudyFoldersError(
        message: error,
        folders: currentFolders,
      ));
      return;
    }

    final materials = materialsResult.getOrElse(() => []);
    final counts = countsResult.getOrElse(() => {});

    emit(FolderMaterialsLoaded(
      folders: currentFolders,
      currentFolderMaterials: materials,
      materialCountsByType: counts,
      folderId: event.folderId,
    ));
  }

  Future<void> _onAddMaterialToFolder(
    AddMaterialToFolderEvent event,
    Emitter<StudyFoldersState> emit,
  ) async {
    final currentFolders = state.folders;
    final currentMaterials = state.currentFolderMaterials;

    final result = await _repository.addMaterialToFolder(
      folderId: event.folderId,
      materialId: event.materialId,
      materialType: event.materialType,
    );

    result.fold(
      (failure) => emit(
        StudyFoldersError(
          message: failure.message ?? 'Failed to add material to folder',
          folders: currentFolders,
          currentFolderMaterials: currentMaterials,
        ),
      ),
      (newAssociation) async {
        // Update the material count for the folder
        final updatedFolders = currentFolders.map((f) {
          if (f.id == event.folderId) {
            return f.copyWith(materialCount: f.materialCount + 1);
          }
          return f;
        }).toList();

        // If we're viewing this folder, add the new material to the list
        final updatedMaterials = [newAssociation, ...currentMaterials];
        
        // Update counts
        final countsResult = await _repository.getMaterialCountsByType(event.folderId);
        final counts = countsResult.getOrElse(() => state.materialCountsByType);

        emit(FolderMaterialsLoaded(
          folders: updatedFolders,
          currentFolderMaterials: updatedMaterials,
          materialCountsByType: counts,
          folderId: event.folderId,
        ));
      },
    );
  }

  Future<void> _onRemoveMaterialFromFolder(
    RemoveMaterialFromFolderEvent event,
    Emitter<StudyFoldersState> emit,
  ) async {
    final currentFolders = state.folders;
    final currentMaterials = state.currentFolderMaterials;

    final result = await _repository.removeMaterialFromFolder(
      folderId: event.folderId,
      materialId: event.materialId,
    );

    result.fold(
      (failure) => emit(
        StudyFoldersError(
          message: failure.message ?? 'Failed to remove material from folder',
          folders: currentFolders,
          currentFolderMaterials: currentMaterials,
        ),
      ),
      (_) async {
        // Update the material count for the folder
        final updatedFolders = currentFolders.map((f) {
          if (f.id == event.folderId) {
            return f.copyWith(materialCount: (f.materialCount - 1).clamp(0, f.materialCount));
          }
          return f;
        }).toList();

        // Remove the material from the current list
        final updatedMaterials = currentMaterials
            .where((m) => m.materialId != event.materialId)
            .toList();
        
        // Update counts
        final countsResult = await _repository.getMaterialCountsByType(event.folderId);
        final counts = countsResult.getOrElse(() => state.materialCountsByType);

        emit(FolderMaterialsLoaded(
          folders: updatedFolders,
          currentFolderMaterials: updatedMaterials,
          materialCountsByType: counts,
          folderId: event.folderId,
        ));
      },
    );
  }
}
