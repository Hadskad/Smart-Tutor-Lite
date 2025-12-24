import 'package:flutter/material.dart' hide MaterialType;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../injection_container.dart';
import '../../../home/presentation/widgets/rename_folder_dialog.dart';
import '../../domain/entities/folder_material.dart';
import '../bloc/study_folders_bloc.dart';
import '../bloc/study_folders_event.dart';
import '../bloc/study_folders_state.dart';

/// Detail page for viewing and managing a study folder.
///
/// Displays study materials organized by type with tabs.
class StudyFolderDetailPage extends StatefulWidget {
  const StudyFolderDetailPage({
    super.key,
    required this.folderId,
    required this.folderName,
  });

  final String folderId;
  final String folderName;

  @override
  State<StudyFolderDetailPage> createState() => _StudyFolderDetailPageState();
}

class _StudyFolderDetailPageState extends State<StudyFolderDetailPage>
    with SingleTickerProviderStateMixin {
  late final StudyFoldersBloc _studyFoldersBloc;
  late TabController _tabController;
  bool _isDeleting = false;
  String _currentFolderName = '';

  @override
  void initState() {
    super.initState();
    _studyFoldersBloc = getIt<StudyFoldersBloc>();
    _currentFolderName = widget.folderName;
    _tabController = TabController(length: MaterialType.values.length, vsync: this);
    
    // Load folder materials
    _studyFoldersBloc.add(LoadFolderMaterialsEvent(folderId: widget.folderId));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _isDeleting = false;
    super.dispose();
  }

  void _showRenameDialog(BuildContext context) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: _studyFoldersBloc,
        child: RenameFolderDialog(
          folderId: widget.folderId,
          currentName: _currentFolderName,
        ),
      ),
    );
    
    if (newName != null && mounted) {
      setState(() {
        _currentFolderName = newName;
      });
    }
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        title: const Text(
          'Delete Folder',
          style: TextStyle(
            color: AppColors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "$_currentFolderName"? This action cannot be undone.\n\nNote: Materials inside will be unlinked but not deleted.',
          style: const TextStyle(
            color: AppColors.lightGray,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.lightGray),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteFolder(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentCoral,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deleteFolder(BuildContext context) {
    _isDeleting = true;
    _studyFoldersBloc.add(DeleteFolderEvent(folderId: widget.folderId));
  }

  List<FolderMaterial> _filterMaterialsByType(
    List<FolderMaterial> materials,
    MaterialType type,
  ) {
    return materials.where((m) => m.materialType == type).toList();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _studyFoldersBloc,
      child: BlocListener<StudyFoldersBloc, StudyFoldersState>(
        listener: (context, state) {
          if (state is StudyFoldersError) {
            _isDeleting = false;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is StudyFoldersLoaded && _isDeleting) {
            final folderStillExists =
                state.folders.any((f) => f.id == widget.folderId);
            if (!folderStillExists && mounted) {
              _isDeleting = false;
              Navigator.of(context).pop();
            }
          }
        },
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              _currentFolderName,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: AppColors.lightGray),
                onPressed: () => _showRenameDialog(context),
                tooltip: 'Rename folder',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.lightGray),
                onPressed: () => _showDeleteConfirmationDialog(context),
                tooltip: 'Delete folder',
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              indicatorColor: AppColors.accentBlue,
              labelColor: AppColors.accentBlue,
              unselectedLabelColor: AppColors.lightGray,
              tabAlignment: TabAlignment.start,
              tabs: MaterialType.values.map((type) {
                return BlocBuilder<StudyFoldersBloc, StudyFoldersState>(
                  builder: (context, state) {
                    final count = state.materialCountsByType[type] ?? 0;
                    return Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(type.displayName),
                          if (count > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accentBlue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                count.toString(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),
          body: BlocBuilder<StudyFoldersBloc, StudyFoldersState>(
            builder: (context, state) {
              if (state is StudyFoldersLoading) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.accentBlue,
                  ),
                );
              }

              final materials = state.currentFolderMaterials;

              return TabBarView(
                controller: _tabController,
                children: MaterialType.values.map((type) {
                  final typeMaterials = _filterMaterialsByType(materials, type);
                  
                  if (typeMaterials.isEmpty) {
                    return _buildEmptyState(type);
                  }
                  
                  return _buildMaterialList(typeMaterials, type);
                }).toList(),
              );
            },
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddMaterialSheet(context),
            backgroundColor: AppColors.accentBlue,
            foregroundColor: AppColors.white,
            icon: const Icon(Icons.add),
            label: const Text('Add Material'),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(MaterialType type) {
    IconData icon;
    switch (type) {
      case MaterialType.transcription:
        icon = Icons.auto_stories_outlined;
        break;
      case MaterialType.summary:
        icon = Icons.summarize_outlined;
        break;
      case MaterialType.quiz:
        icon = Icons.quiz_outlined;
        break;
      case MaterialType.flashcard:
        icon = Icons.style_outlined;
        break;
      case MaterialType.tts:
        icon = Icons.headphones_outlined;
        break;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: AppColors.lightGray.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No ${type.displayName.toLowerCase()}',
              style: const TextStyle(
                color: AppColors.lightGray,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap "Add Material" to add ${type.displayName.toLowerCase()} to this folder',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.lightGray.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialList(List<FolderMaterial> materials, MaterialType type) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: materials.length,
      itemBuilder: (context, index) {
        final material = materials[index];
        return _buildMaterialCard(material, type);
      },
    );
  }

  Widget _buildMaterialCard(FolderMaterial material, MaterialType type) {
    Color typeColor;
    IconData typeIcon;
    
    switch (type) {
      case MaterialType.transcription:
        typeColor = AppColors.materialNotes;
        typeIcon = Icons.auto_stories;
        break;
      case MaterialType.summary:
        typeColor = AppColors.materialSummary;
        typeIcon = Icons.summarize;
        break;
      case MaterialType.quiz:
        typeColor = AppColors.materialQuiz;
        typeIcon = Icons.quiz;
        break;
      case MaterialType.flashcard:
        typeColor = AppColors.materialFlashcard;
        typeIcon = Icons.style;
        break;
      case MaterialType.tts:
        typeColor = AppColors.materialAudio;
        typeIcon = Icons.headphones;
        break;
    }

    return Dismissible(
      key: Key(material.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: AppColors.accentCoral,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.remove_circle_outline,
          color: AppColors.white,
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
            ),
            title: const Text(
              'Remove from Folder',
              style: TextStyle(
                color: AppColors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text(
              'Remove this material from the folder? The material itself will not be deleted.',
              style: TextStyle(
                color: AppColors.lightGray,
                fontSize: 14,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.lightGray),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentCoral,
                  foregroundColor: AppColors.white,
                ),
                child: const Text('Remove'),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (direction) {
        _studyFoldersBloc.add(RemoveMaterialFromFolderEvent(
          folderId: widget.folderId,
          materialId: material.materialId,
        ));
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(typeIcon, color: typeColor),
          ),
          title: Text(
            'Material ID: ${material.materialId.substring(0, 8)}...',
            style: const TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            'Added ${_formatDate(material.addedAt)}',
            style: TextStyle(
              color: AppColors.lightGray.withOpacity(0.8),
              fontSize: 12,
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right,
            color: AppColors.lightGray,
          ),
          onTap: () {
            // TODO: Navigate to the material detail page based on type
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Opening ${type.displayName.toLowerCase()}...'),
                backgroundColor: AppColors.card,
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _showAddMaterialSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add Material to Folder',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select a material type to add to "$_currentFolderName"',
                  style: TextStyle(
                    color: AppColors.lightGray.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                ...MaterialType.values.map((type) {
                  Color typeColor;
                  IconData typeIcon;
                  String description;
                  
                  switch (type) {
                    case MaterialType.transcription:
                      typeColor = AppColors.materialNotes;
                      typeIcon = Icons.auto_stories;
                      description = 'Add lecture notes or transcriptions';
                      break;
                    case MaterialType.summary:
                      typeColor = AppColors.materialSummary;
                      typeIcon = Icons.summarize;
                      description = 'Add AI-generated summaries';
                      break;
                    case MaterialType.quiz:
                      typeColor = AppColors.materialQuiz;
                      typeIcon = Icons.quiz;
                      description = 'Add practice quizzes';
                      break;
                    case MaterialType.flashcard:
                      typeColor = AppColors.materialFlashcard;
                      typeIcon = Icons.style;
                      description = 'Add flashcard sets';
                      break;
                    case MaterialType.tts:
                      typeColor = AppColors.materialAudio;
                      typeIcon = Icons.headphones;
                      description = 'Add audio notes';
                      break;
                  }
                  
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(typeIcon, color: typeColor),
                    ),
                    title: Text(
                      type.displayName,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      description,
                      style: TextStyle(
                        color: AppColors.lightGray.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: AppColors.lightGray,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      // TODO: Navigate to the respective feature page with folder context
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Opening ${type.displayName}...'),
                          backgroundColor: AppColors.card,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
