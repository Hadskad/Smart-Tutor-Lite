import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../features/study_folders/presentation/bloc/study_folders_bloc.dart';
import '../../../../features/study_folders/presentation/bloc/study_folders_state.dart';
import 'dashboard_folder_card.dart';

/// Widget that displays study folders in a 3-column grid layout.
///
/// The first item is always the "Create folder" tile.
class StudyFoldersSection extends StatelessWidget {
  const StudyFoldersSection({
    super.key,
    required this.onCreateFolderTap,
    required this.onFolderTap,
    this.searchQuery = '',
  });

  final VoidCallback onCreateFolderTap;
  final Function(String folderId, String folderName) onFolderTap;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StudyFoldersBloc, StudyFoldersState>(
      builder: (context, state) {
        if (state is StudyFoldersLoading && state.folders.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.accentBlue,
            ),
          );
        }

        if (state is StudyFoldersError && state.folders.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                state.message,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        // Get folders from state (empty list if initial/loading)
        var folders = state.folders;

        // Filter folders based on search query if provided
        if (searchQuery.isNotEmpty) {
          folders = folders.where((folder) {
            return folder.name.toLowerCase().contains(searchQuery.toLowerCase());
          }).toList();
        }

        // Total items: 1 for create tile + folders count
        final itemCount = 1 + folders.length;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8.0,
            mainAxisSpacing: 8.0,
            childAspectRatio: 0.85,
          ),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            // First item is always the "Create folder" tile
            if (index == 0) {
              return DashboardFolderCard(
                title: 'Create folder',
                isCreateTile: true,
                onTap: onCreateFolderTap,
              );
            }

            // Remaining items are actual folders
            final folder = folders[index - 1];
            return DashboardFolderCard(
              title: folder.name,
              isCreateTile: false,
              materialCount: folder.materialCount,
              onTap: () => onFolderTap(folder.id, folder.name),
            );
          },
        );
      },
    );
  }
}

