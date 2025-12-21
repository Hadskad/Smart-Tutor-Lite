import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../features/study_folders/presentation/bloc/study_folders_bloc.dart';
import '../../../../features/study_folders/presentation/bloc/study_folders_event.dart';
import '../../../../features/study_folders/presentation/bloc/study_folders_state.dart';

// Reuse colors from home_dashboard_page.dart
const Color _kCardColor = Color(0xFF333333);
const Color _kAccentBlue = Color(0xFF00BFFF);
const Color _kWhite = Colors.white;
const Color _kLightGray = Color(0xFFCCCCCC);
const Color _kBackgroundColor = Color(0xFF1E1E1E);

/// Dialog for creating a new study folder.
///
/// Matches the dark theme of the home dashboard.
class CreateFolderDialog extends StatefulWidget {
  const CreateFolderDialog({super.key});

  @override
  State<CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends State<CreateFolderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  String? _errorMessage;
  bool _isCreating = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _handleCreate() {
    final folderName = _textController.text.trim();

    if (folderName.isEmpty) {
      setState(() {
        _errorMessage = 'Folder name cannot be empty';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _isCreating = true;
    });

    // Dispatch create folder event
    context.read<StudyFoldersBloc>().add(CreateFolderEvent(name: folderName));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<StudyFoldersBloc, StudyFoldersState>(
      listener: (context, state) {
        if (!_isCreating) return; // Only handle states during creation

        if (state is StudyFoldersError) {
          // Show error in dialog and allow retry
          setState(() {
            _errorMessage = state.message;
            _isCreating = false;
          });
        } else if (state is StudyFoldersLoaded) {
          // Success - close dialog
          Navigator.of(context).pop();
        }
      },
      child: AlertDialog(
        backgroundColor: _kCardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        title: const Text(
          'New Folder',
          style: TextStyle(
            color: _kWhite,
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
                enabled: !_isCreating,
                style: const TextStyle(color: _kWhite),
                decoration: InputDecoration(
                  hintText: 'Enter folder name',
                  hintStyle: const TextStyle(color: _kLightGray),
                  filled: true,
                  fillColor: _kBackgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide:
                        const BorderSide(color: _kLightGray, width: 1.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide:
                        const BorderSide(color: _kLightGray, width: 1.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    borderSide:
                        const BorderSide(color: _kAccentBlue, width: 2.0),
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
                  // Clear error when user starts typing
                  if (_errorMessage != null && !_isCreating) {
                    setState(() {
                      _errorMessage = null;
                    });
                  }
                },
                onSubmitted: (_) {
                  if (!_isCreating) {
                    _handleCreate();
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
              if (_isCreating) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _kAccentBlue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Creating folder...',
                      style: const TextStyle(
                        color: _kLightGray,
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
            onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: _kLightGray),
            ),
          ),
          ElevatedButton(
            onPressed: _isCreating ? null : _handleCreate,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAccentBlue,
              foregroundColor: _kWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
