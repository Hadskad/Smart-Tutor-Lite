import 'package:flutter/material.dart';

import '../../../../injection_container.dart';
import '../../../transcription/domain/entities/transcription.dart';
import '../../../transcription/domain/repositories/transcription_repository.dart';
import '../../../transcription/presentation/widgets/note_list_card.dart';

const Color _kBackgroundColor = Color(0xFF1E1E1E);
const Color _kAccentBlue = Color(0xFF00BFFF);
const Color _kAccentCoral = Color(0xFFFF7043);
const Color _kWhite = Colors.white;
const Color _kLightGray = Color(0xFFCCCCCC);
const Color _kDarkGray = Color(0xFF888888);

class NotePickerSheet extends StatefulWidget {
  const NotePickerSheet({super.key});

  static Future<Transcription?> show(BuildContext context) {
    return showModalBottomSheet<Transcription>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const NotePickerSheet(),
    );
  }

  @override
  State<NotePickerSheet> createState() => _NotePickerSheetState();
}

class _NotePickerSheetState extends State<NotePickerSheet> {
  late Future<dynamic> _transcriptionsFuture;
  @override
   
void initState() {
    super.initState();
    _loadTranscriptions();
  }

  void _loadTranscriptions() {
    final repository = getIt<TranscriptionRepository>();
    setState(() {
      _transcriptionsFuture = repository.getAllTranscriptions();
    });
  }
@override
  Widget build(BuildContext context) {
   

    return Container(
      decoration: const BoxDecoration(
        color: _kBackgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: const [
              Expanded(
                child: Text(
                  'Select Note',
                  style: TextStyle(
                    color: _kWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 320,
            child: FutureBuilder(
              
                future: _transcriptionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _kAccentBlue),
                  );
                }
                if (snapshot.hasError) {
                  return _ErrorState(
                    message: 'Failed to load notes',
                    onRetry: _loadTranscriptions,
                  );
                }

                final result = snapshot.data;
                if (result == null) {
                  return _ErrorState(
                    message: 'Unable to load notes',
                    onRetry: _loadTranscriptions,
                  );
                }

                return result.fold(
                  (failure) => _ErrorState(
                    message: failure.message ?? 'Failed to load notes',
                    onRetry: _loadTranscriptions
                  ),
                  (notes) {
                    if (notes.isEmpty) {
                      return const _EmptyState();
                    }
                    return ListView.separated(
                      itemCount: notes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final note = notes[index];
                        return NoteListCard(
                          transcription: note,
                          onTap: () {
                            Navigator.of(context).pop(note);
                          },
                          showActions: false,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_stories_outlined, color: _kDarkGray, size: 40),
          SizedBox(height: 8),
          Text(
            'No notes found',
            style: TextStyle(color: _kLightGray),
          ),
          SizedBox(height: 4),
          Text(
            'Create a note in Automatic Notes Taker first.',
            style: TextStyle(color: _kDarkGray, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: _kAccentCoral, size: 40),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: _kLightGray),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: _kAccentBlue,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}


