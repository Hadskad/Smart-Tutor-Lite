import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../injection_container.dart';
import '../bloc/study_folders_bloc.dart';
import '../bloc/study_folders_event.dart';
import '../bloc/study_folders_state.dart';

// Reuse colors from home dashboard
const Color _kBackgroundColor = Color(0xFF1E1E1E);
const Color _kCardColor = Color(0xFF333333);
const Color _kAccentCoral = Color(0xFFFF7043);
const Color _kWhite = Colors.white;
const Color _kLightGray = Color(0xFFCCCCCC);

/// Detail page for viewing and managing a study folder.
///
/// This page will later display study materials (notes, summaries, quizzes, etc.)
/// that have been assigned to this folder.
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

class _StudyFolderDetailPageState extends State<StudyFolderDetailPage> {
  late final StudyFoldersBloc _studyFoldersBloc;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _studyFoldersBloc = getIt<StudyFoldersBloc>();
  }

  @override
  void dispose() {
    // Reset deletion flag in case widget is disposed during deletion
    _isDeleting = false;
    // Don't close the bloc here as it's shared with the home page
    // The home page will manage its lifecycle
    super.dispose();
  }

  void _showDeleteConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _kCardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        title: const Text(
          'Delete Folder',
          style: TextStyle(
            color: _kWhite,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${widget.folderName}"? This action cannot be undone.',
          style: const TextStyle(
            color: _kLightGray,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: _kLightGray),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteFolder(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAccentCoral,
              foregroundColor: _kWhite,
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
    // Navigation will be handled by the BlocListener when deletion succeeds
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
            // Check if the deleted folder is no longer in the list
            final folderStillExists =
                state.folders.any((f) => f.id == widget.folderId);
            if (!folderStillExists && mounted) {
              // Folder was successfully deleted, navigate back
              _isDeleting = false;
              Navigator.of(context).pop();
            }
          }
        },
        child: Scaffold(
          backgroundColor: _kBackgroundColor,
          appBar: AppBar(
            backgroundColor: _kBackgroundColor,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: _kWhite),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              widget.folderName,
              style: const TextStyle(
                color: _kWhite,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline, color: _kLightGray),
                onPressed: () => _showDeleteConfirmationDialog(context),
                tooltip: 'Delete folder',
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Empty state placeholder
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.folder_open_outlined,
                            size: 80,
                            color: _kLightGray.withOpacity(0.5),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'No materials yet',
                            style: TextStyle(
                              color: _kLightGray,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Study materials from Note Taker, Summary,\nQuiz, Audio Notes, and Study Mode will\nappear here once added to this folder.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _kLightGray.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
