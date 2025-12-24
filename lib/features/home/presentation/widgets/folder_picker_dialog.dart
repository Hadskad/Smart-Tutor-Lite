import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../features/study_folders/domain/entities/study_folder.dart';
import '../../../../features/study_folders/presentation/bloc/study_folders_bloc.dart';
import '../../../../features/study_folders/presentation/bloc/study_folders_event.dart';
import '../../../../features/study_folders/presentation/bloc/study_folders_state.dart';
import '../../../../injection_container.dart';
import 'create_folder_dialog.dart';

/// A dialog for selecting a folder to save a material to.
///
/// Can be used from any feature page (transcription, summary, quiz, etc.)
/// to allow users to organize their materials into folders.
class FolderPickerDialog extends StatefulWidget {
  const FolderPickerDialog({
    super.key,
    this.title = 'Save to Folder',
    this.subtitle,
    this.selectedFolderId,
  });

  /// Dialog title
  final String title;
  
  /// Optional subtitle/description
  final String? subtitle;
  
  /// Currently selected folder ID (for editing existing associations)
  final String? selectedFolderId;

  /// Shows the folder picker dialog and returns the selected folder, or null if cancelled.
  static Future<StudyFolder?> show(
    BuildContext context, {
    String title = 'Save to Folder',
    String? subtitle,
    String? selectedFolderId,
  }) {
    return showDialog<StudyFolder>(
      context: context,
      builder: (context) => FolderPickerDialog(
        title: title,
        subtitle: subtitle,
        selectedFolderId: selectedFolderId,
      ),
    );
  }

  @override
  State<FolderPickerDialog> createState() => _FolderPickerDialogState();
}

class _FolderPickerDialogState extends State<FolderPickerDialog> {
  late final StudyFoldersBloc _studyFoldersBloc;
  String? _selectedFolderId;

  @override
  void initState() {
    super.initState();
    _studyFoldersBloc = getIt<StudyFoldersBloc>();
    _selectedFolderId = widget.selectedFolderId;
    
    // Ensure folders are loaded
    if (_studyFoldersBloc.state.folders.isEmpty) {
      _studyFoldersBloc.add(const LoadFoldersEvent());
    }
  }

  void _showCreateFolderDialog() async {
    await showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: _studyFoldersBloc,
        child: const CreateFolderDialog(),
      ),
    );
    
    // After creating, reload folders
    _studyFoldersBloc.add(const LoadFoldersEvent());
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _studyFoldersBloc,
      child: Dialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
            maxWidth: 400,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.title,
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: AppColors.lightGray),
                          onPressed: () => Navigator.of(context).pop(),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle!,
                        style: TextStyle(
                          color: AppColors.lightGray.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              const Divider(height: 1, color: AppColors.background),
              
              // Folder list
              Flexible(
                child: BlocBuilder<StudyFoldersBloc, StudyFoldersState>(
                  builder: (context, state) {
                    if (state is StudyFoldersLoading && state.folders.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.accentBlue,
                          ),
                        ),
                      );
                    }

                    final folders = state.folders;

                    if (folders.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.folder_off_outlined,
                              size: 48,
                              color: AppColors.lightGray.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No folders yet',
                              style: TextStyle(
                                color: AppColors.lightGray,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Create a folder to organize your materials',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.lightGray.withOpacity(0.7),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: folders.length,
                      itemBuilder: (context, index) {
                        final folder = folders[index];
                        final isSelected = folder.id == _selectedFolderId;
                        
                        return ListTile(
                          leading: Icon(
                            isSelected ? Icons.folder : Icons.folder_outlined,
                            color: isSelected ? AppColors.accentBlue : AppColors.lightGray,
                          ),
                          title: Text(
                            folder.name,
                            style: TextStyle(
                              color: isSelected ? AppColors.accentBlue : AppColors.white,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          trailing: folder.materialCount > 0
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${folder.materialCount}',
                                    style: const TextStyle(
                                      color: AppColors.lightGray,
                                      fontSize: 12,
                                    ),
                                  ),
                                )
                              : null,
                          selected: isSelected,
                          selectedTileColor: AppColors.accentBlue.withOpacity(0.1),
                          onTap: () {
                            setState(() {
                              _selectedFolderId = folder.id;
                            });
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              
              const Divider(height: 1, color: AppColors.background),
              
              // Actions
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Create new folder button
                    TextButton.icon(
                      onPressed: _showCreateFolderDialog,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('New Folder'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accentBlue,
                      ),
                    ),
                    const Spacer(),
                    // Cancel button
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: AppColors.lightGray),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Save button
                    BlocBuilder<StudyFoldersBloc, StudyFoldersState>(
                      builder: (context, state) {
                        final selectedFolder = _selectedFolderId != null
                            ? state.folders.where((f) => f.id == _selectedFolderId).firstOrNull
                            : null;
                        
                        return ElevatedButton(
                          onPressed: selectedFolder != null
                              ? () => Navigator.of(context).pop(selectedFolder)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentBlue,
                            foregroundColor: AppColors.white,
                            disabledBackgroundColor: AppColors.background,
                            disabledForegroundColor: AppColors.darkGray,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                          child: const Text('Save'),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

