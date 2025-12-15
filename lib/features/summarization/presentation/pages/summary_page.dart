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
import 'summary_detail_page.dart';

// --- Local Color Palette for Summary Page ---
const Color _kBackgroundColor = Color(0xFF1E1E1E);
const Color _kCardColor = Color(0xFF333333);
const Color _kAccentBlue = Color(0xFF00BFFF); // Vibrant Electric Blue
const Color _kWhite = Colors.white;
const Color _kLightGray = Color(0xFFCCCCCC);
const Color _kDarkGray = Color(0xFF888888);

class SummaryPage extends StatefulWidget {
  const SummaryPage({super.key});

  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  late final SummaryBloc _bloc;
  final ScrollController _scrollController = ScrollController();
  String? _uploadedPdfUrl;
  String? _pdfFileName;
  bool _isUploadingPdf = false;

  @override
  void initState() {
    super.initState();
    _bloc = getIt<SummaryBloc>();
    _bloc.add(const LoadSummariesEvent());
  }

  @override
  void dispose() {
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
        final pickedFile = result.files.single;
        final pdfFileName = pickedFile.name.isNotEmpty
            ? pickedFile.name.replaceAll('.pdf', '').replaceAll('.PDF', '')
            : 'Untitled Document';
        final fileName =
            'summaries/${DateTime.now().millisecondsSinceEpoch}.pdf';

        // Upload to Firebase Storage
        final storageRef = FirebaseStorage.instance.ref().child(fileName);
        await storageRef.putFile(file);
        final downloadUrl = await storageRef.getDownloadURL();

        setState(() {
          _uploadedPdfUrl = downloadUrl;
          _pdfFileName = pdfFileName;
          _isUploadingPdf = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('PDF uploaded successfully'),
              backgroundColor: _kAccentBlue,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        setState(() => _isUploadingPdf = false);
      }
    } catch (e) {
      setState(() => _isUploadingPdf = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload PDF: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _summarizePdf() {
    if (_uploadedPdfUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please upload a PDF first'),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
        ),
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
        backgroundColor: _kBackgroundColor,
        appBar: AppBar(
          backgroundColor: _kBackgroundColor,
          elevation: 0,
          title: const Text(
            'Summary Bot',
            style: TextStyle(
              color: _kWhite,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconTheme: const IconThemeData(color: _kWhite),
        ),
        body: SafeArea(
          child: BlocConsumer<SummaryBloc, SummaryState>(
            listener: (context, state) {
              if (state is SummaryError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: Colors.red.shade700,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else if (state is SummarySuccess) {
                // Update summary with PDF filename if available
                if (_pdfFileName != null && state.summary.title == null) {
                  final updatedSummary = Summary(
                    id: state.summary.id,
                    sourceType: state.summary.sourceType,
                    summaryText: state.summary.summaryText,
                    sourceId: state.summary.sourceId,
                    metadata: state.summary.metadata,
                    createdAt: state.summary.createdAt,
                    title: _pdfFileName,
                  );
                  _bloc.add(UpdateSummaryEvent(updatedSummary));
                }
                // Reset upload state to allow uploading another PDF
                setState(() {
                  _uploadedPdfUrl = null;
                  _pdfFileName = null;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Summary generated successfully'),
                    backgroundColor: _kAccentBlue,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            builder: (context, state) {
              return SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),
                    _buildInputSection(state),
                    const SizedBox(height: 24),
                    _buildSummariesList(state),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInputSection(SummaryState state) {
    return Container(
      decoration: BoxDecoration(
        color: _kCardColor,
        borderRadius: BorderRadius.circular(20.0),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // --- Summarize PDF Handout ---
          Row(
            children: [
              Icon(Icons.description, color: _kAccentBlue, size: 28),
              const SizedBox(width: 12),
              const Text(
                'Summarize PDF Handout',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _kWhite,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_uploadedPdfUrl != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _kAccentBlue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kAccentBlue, width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: _kAccentBlue, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'PDF uploaded successfully, proceed to generate summary',
                      style: TextStyle(
                        color: _kAccentBlue,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            InkWell(
              onTap: _isUploadingPdf ? null : _pickAndUploadPdf,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: _kCardColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _kCardColor, width: 1.0),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isUploadingPdf)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(_kAccentBlue),
                        ),
                      )
                    else
                      Icon(Icons.upload_file, color: _kAccentBlue, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      _isUploadingPdf ? 'Uploading...' : 'Upload PDF File',
                      style: TextStyle(
                        color: _isUploadingPdf ? _kDarkGray : _kLightGray,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: state is SummaryLoading || _uploadedPdfUrl == null
                ? null
                : _summarizePdf,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAccentBlue,
              foregroundColor: _kWhite,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: state is SummaryLoading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(_kWhite),
                    ),
                  )
                : const Text(
                    'Generate Summary',
                    style: TextStyle(
                      color: _kWhite,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
          ),
      )],
      ),
    );
  }

  Widget _buildSummariesList(SummaryState state) {
    final summaries = state.summaries;

    if (summaries.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: _kCardColor,
          borderRadius: BorderRadius.circular(20.0),
        ),
        padding: const EdgeInsets.all(48),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.description_outlined,
                size: 64,
                color: _kDarkGray,
              ),
              const SizedBox(height: 16),
              Text(
                'No summaries yet',
                style: TextStyle(
                  color: _kLightGray,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Upload a PDF to create your first summary',
                style: TextStyle(
                  color: _kDarkGray,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Past Summaries',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: _kWhite,
          ),
        ),
        const SizedBox(height: 16),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: summaries.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final summary = summaries[index];
            return _buildSummaryCard(summary);
          },
        ),
      ],
    );
  }

  Widget _buildSummaryCard(Summary summary) {
    final displayTitle = summary.title ?? 'Untitled Document';

    return Container(
      decoration: BoxDecoration(
        color: _kCardColor,
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SummaryDetailPage(
                    summary: summary,
                  ),
                ),
              );
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _kAccentBlue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.summarize, color: _kAccentBlue, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                displayTitle,
                                style: const TextStyle(
                                  color: _kWhite,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              color: _kDarkGray,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                _showEditTitleDialog(summary);
                              },
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _formatDate(summary.createdAt),
                          style: TextStyle(
                            color: _kDarkGray,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: _kDarkGray),
                    onPressed: () {
                      _showDeleteConfirmationDialog(summary);
                    },
                  ),
                ],
              ),
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: _kDarkGray.withOpacity(0.3),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: InkWell(
              onTap: () {
                _generateFlashcards(summary.id, 'summary');
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _kAccentBlue.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.style, color: _kAccentBlue, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Generate Flashcards',
                      style: TextStyle(
                        color: _kAccentBlue,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
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
        backgroundColor: _kCardColor,
        title: const Text(
          'Flashcards Generating',
          style: TextStyle(color: _kWhite),
        ),
        content: Text(
          'Your flashcards are being generated. Go to Study Mode to view them when ready.',
          style: TextStyle(color: _kLightGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(color: _kAccentBlue),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/study-mode');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAccentBlue,
              foregroundColor: _kWhite,
            ),
            child: const Text('Go to Study Mode'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, y • h:mm a').format(date);
  }

  void _showEditTitleDialog(Summary summary) {
    final textController = TextEditingController(text: summary.title ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _kCardColor,
        title: const Text(
          'Edit Title',
          style: TextStyle(color: _kWhite),
        ),
        content: TextField(
          controller: textController,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            hintText: 'Enter title',
            hintStyle: TextStyle(color: _kDarkGray),
            border: OutlineInputBorder(
              borderSide: BorderSide(color: _kAccentBlue),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: _kAccentBlue),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: _kAccentBlue, width: 2),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: _kAccentBlue),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final newTitle = textController.text.trim();
              if (newTitle.isNotEmpty) {
                final updatedSummary = Summary(
                  id: summary.id,
                  sourceType: summary.sourceType,
                  summaryText: summary.summaryText,
                  sourceId: summary.sourceId,
                  metadata: summary.metadata,
                  createdAt: summary.createdAt,
                  title: newTitle,
                );
                _bloc.add(UpdateSummaryEvent(updatedSummary));
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAccentBlue,
              foregroundColor: _kWhite,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmationDialog(Summary summary) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _kCardColor,
        title: const Text(
          'Delete Summary',
          style: TextStyle(color: _kWhite),
        ),
        content: Text(
          'Are you sure you want to delete this summary? This action cannot be undone.',
          style: TextStyle(color: _kLightGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: _kAccentBlue),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _bloc.add(DeleteSummaryEvent(summary.id));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: _kWhite,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
