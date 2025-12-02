import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../injection_container.dart';
import '../../../study_mode/presentation/bloc/study_mode_bloc.dart';
import '../../../study_mode/presentation/bloc/study_mode_event.dart';
import '../../domain/entities/summary.dart';
import '../bloc/summary_bloc.dart';
import '../bloc/summary_event.dart';
import '../bloc/summary_state.dart';

class SummaryPage extends StatefulWidget {
  const SummaryPage({super.key});

  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  late final SummaryBloc _bloc;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _uploadedPdfUrl;
  bool _isUploadingPdf = false;

  @override
  void initState() {
    super.initState();
    _bloc = getIt<SummaryBloc>();
    _bloc.add(const LoadSummariesEvent());
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _bloc.close();
    super.dispose();
  }

  Future<void> _pickAndUploadPdf() async {
    setState(() => _isUploadingPdf = true);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileName =
            'summaries/${DateTime.now().millisecondsSinceEpoch}.pdf';

        // Upload to Firebase Storage
        final storageRef = FirebaseStorage.instance.ref().child(fileName);
        await storageRef.putFile(file);
        final downloadUrl = await storageRef.getDownloadURL();

        setState(() {
          _uploadedPdfUrl = downloadUrl;
          _isUploadingPdf = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF uploaded successfully')),
          );
        }
      } else {
        setState(() => _isUploadingPdf = false);
      }
    } catch (e) {
      setState(() => _isUploadingPdf = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload PDF: $e')),
        );
      }
    }
  }

  void _summarizeText() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some text to summarize')),
      );
      return;
    }

    _bloc.add(SummarizeTextEvent(text: text));
    _textController.clear();
  }

  void _summarizePdf() {
    if (_uploadedPdfUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a PDF first')),
      );
      return;
    }

    _bloc.add(SummarizePdfEvent(pdfUrl: _uploadedPdfUrl!));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Summarization'),
        ),
        body: BlocConsumer<SummaryBloc, SummaryState>(
          listener: (context, state) {
            final colorScheme = Theme.of(context).colorScheme;
            if (state is SummaryError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: colorScheme.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } else if (state is SummarySuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Summary generated successfully'),
                  backgroundColor: colorScheme.secondary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
          builder: (context, state) {
            return SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildInputSection(state),
                  const SizedBox(height: 24),
                  _buildLatestSummary(state),
                  const SizedBox(height: 24),
                  _buildSummariesList(state),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInputSection(SummaryState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Summarize Text',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Enter text to summarize...',
                border: OutlineInputBorder(),
              ),
              enabled: state is! SummaryLoading,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: state is SummaryLoading ? null : _summarizeText,
              child: const Text('Summarize Text'),
            ),
            const Divider(height: 32),
            const Text(
              'Summarize PDF',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_uploadedPdfUrl != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'PDF uploaded',
                        style: TextStyle(color: Colors.green.shade900),
                      ),
                    ),
                  ],
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: _isUploadingPdf ? null : _pickAndUploadPdf,
                icon: _isUploadingPdf
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file),
                label: Text(_isUploadingPdf ? 'Uploading...' : 'Pick PDF'),
              ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: state is SummaryLoading || _uploadedPdfUrl == null
                  ? null
                  : _summarizePdf,
              child: const Text('Summarize PDF'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLatestSummary(SummaryState state) {
    if (state is SummarySuccess) {
      final colorScheme = Theme.of(context).colorScheme;
      return Card(
        color: colorScheme.secondary.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.summarize, color: colorScheme.secondary),
                  const SizedBox(width: 8),
                  Text(
                    'Latest Summary',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                state.summary.summaryText,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Source: ${state.summary.sourceType} • ${_formatDate(state.summary.createdAt)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildSummariesList(SummaryState state) {
    final summaries = state.summaries;

    if (summaries.isEmpty) {
      final colorScheme = Theme.of(context).colorScheme;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.description,
                  size: 48,
                  color: colorScheme.outline.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 12),
                Text(
                  'No summaries yet',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Create your first summary above',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Past Summaries',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: summaries.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final summary = summaries[index];
            return _buildSummaryCard(summary);
          },
        ),
      ],
    );
  }

  Widget _buildSummaryCard(Summary summary) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.summarize),
            title: Text(
              summary.summaryText.length > 100
                  ? '${summary.summaryText.substring(0, 100)}...'
                  : summary.summaryText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${summary.sourceType} • ${_formatDate(summary.createdAt)}',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                _bloc.add(DeleteSummaryEvent(summary.id));
              },
            ),
            onTap: () {
              _showSummaryDialog(summary);
            },
          ),
          ButtonBar(
            alignment: MainAxisAlignment.start,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.style, size: 18),
                label: const Text('Generate Flashcards'),
                onPressed: () {
                  _generateFlashcards(summary.id, 'summary');
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _generateFlashcards(String sourceId, String sourceType) {
    final studyModeBloc = getIt<StudyModeBloc>();
    studyModeBloc.add(GenerateFlashcardsEvent(
      sourceId: sourceId,
      sourceType: sourceType,
      numFlashcards: 10,
    ));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Flashcards Generating'),
        content: const Text(
          'Your flashcards are being generated. Go to Study Mode to view them when ready.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/study-mode');
            },
            child: const Text('Go to Study Mode'),
          ),
        ],
      ),
    );
  }

  void _showSummaryDialog(Summary summary) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Summary (${summary.sourceType})'),
        content: SingleChildScrollView(
          child: Text(summary.summaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, y • h:mm a').format(date);
  }
}
