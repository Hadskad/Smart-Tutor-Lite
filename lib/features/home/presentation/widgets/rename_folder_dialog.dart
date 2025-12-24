import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../features/study_folders/presentation/bloc/study_folders_bloc.dart';
import '../../../../features/study_folders/presentation/bloc/study_folders_event.dart';
import '../../../../features/study_folders/presentation/bloc/study_folders_state.dart';

/// Dialog for renaming an existing study folder.
class RenameFolderDialog extends StatefulWidget {
  const RenameFolderDialog({
    super.key,
    required this.folderId,
    required this.currentName,
  });

  final String folderId;
  final String currentName;

  @override
  State<RenameFolderDialog> createState() => _RenameFolderDialogState();
}

class _RenameFolderDialogState extends State<RenameFolderDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _textController;
  String? _errorMessage;
  bool _isRenaming = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.currentName);
    // Select all text for easy replacement
    _textController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.currentName.length,
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _handleRename() {
    final newName = _textController.text.trim();

    if (newName.isEmpty) {
      setState(() {
        _errorMessage = 'Folder name cannot be empty';
      });
      return;
    }

    if (newName == widget.currentName) {
      // No change, just close
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _errorMessage = null;
      _isRenaming = true;
    });

    // Dispatch rename folder event
    context.read<StudyFoldersBloc>().add(RenameFolderEvent(
      folderId: widget.folderId,
      newName: newName,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<StudyFoldersBloc, StudyFoldersState>(
      listener: (context, state) {
        if (!_isRenaming) return;

        if (state is StudyFoldersError) {
          setState(() {
            _errorMessage = state.message;
            _isRenaming = false;
          });
        } else if (state is StudyFoldersLoaded) {
          // Check if folder was renamed
          final folder = state.folders.where((f) => f.id == widget.folderId).firstOrNull;
          if (folder != null && folder.name == _textController.text.trim()) {
            // Success - close dialog and return new name
            Navigator.of(context).pop(folder.name);
          }
        }
      },
      child: AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        title: const Text(
          'Rename Folder',
          style: TextStyle(
            color: AppColors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _textController,
                autofocus: true,
                enabled: !_isRenaming,
                style: const TextStyle(color: AppColors.white),
                decoration: InputDecoration(
                  hintText: 'Enter new folder name',
                  hintStyle: const TextStyle(color: AppColors.lightGray),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: const BorderSide(color: AppColors.lightGray, width: 1.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: const BorderSide(color: AppColors.lightGray, width: 1.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: const BorderSide(color: AppColors.accentBlue, width: 2.0),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: const BorderSide(color: Colors.red, width: 1.0),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide: const BorderSide(color: Colors.red, width: 2.0),
                  ),
                ),
                onChanged: (_) {
                  if (_errorMessage != null && !_isRenaming) {
                    setState(() {
                      _errorMessage = null;
                    });
                  }
                },
                onSubmitted: (_) {
                  if (!_isRenaming) {
                    _handleRename();
                  }
                },
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                ),
              ],
              if (_isRenaming) ...[
                const SizedBox(height: 12),
                const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accentBlue,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Renaming folder...',
                      style: TextStyle(
                        color: AppColors.lightGray,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isRenaming ? null : () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.lightGray),
            ),
          ),
          ElevatedButton(
            onPressed: _isRenaming ? null : _handleRename,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentBlue,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }
}

