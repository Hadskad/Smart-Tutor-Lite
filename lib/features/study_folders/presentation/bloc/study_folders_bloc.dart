import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/repositories/study_folder_repository.dart';
import 'study_folders_event.dart';
import 'study_folders_state.dart';

@injectable
class StudyFoldersBloc extends Bloc<StudyFoldersEvent, StudyFoldersState> {
  StudyFoldersBloc(this._repository) : super(const StudyFoldersInitial()) {
    on<LoadFoldersEvent>(_onLoadFolders);
    on<CreateFolderEvent>(_onCreateFolder);
    on<DeleteFolderEvent>(_onDeleteFolder);
  }

  final StudyFolderRepository _repository;

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
}

