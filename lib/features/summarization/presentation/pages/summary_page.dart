import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../injection_container.dart';
import '../../../study_mode/presentation/bloc/study_mode_bloc.dart';
import '../../../study_mode/presentation/bloc/study_mode_event.dart';
import '../../../study_mode/presentation/bloc/study_mode_state.dart';
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
  late final StudyModeBloc _studyModeBloc;
  final ScrollController _scrollController = ScrollController();
  String? _uploadedPdfUrl;
  String? _pdfFileName;

  // Upload state
  bool _isUploadingPdf = false;
  double _uploadProgress = 0.0;
  UploadTask? _currentUploadTask;

  @override
  void initState() {
    super.initState();
    _bloc = getIt<SummaryBloc>();
    _studyModeBloc = getIt<StudyModeBloc>();
    _bloc.add(const LoadSummariesEvent());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _cancelUpload();
    // Note: Don't close the bloc - it's a singleton managed by DI
    super.dispose();
  }

  void _cancelUpload() {
    _currentUploadTask?.cancel();
    _currentUploadTask = null;
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _pickAndUploadPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.single.path == null) {
        return;
      }

      final file = File(result.files.single.path!);
      final pickedFile = result.files.single;
      final fileSize = await file.length();

      // Validate file size (30MB limit)
      if (fileSize > AppConstants.maxPdfSizeBytes) {
        if (mounted) {
          final maxSizeMB = AppConstants.maxPdfSizeBytes / (1024 * 1024);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'PDF too large (${_formatFileSize(fileSize)}). '
                'Maximum size is ${maxSizeMB.toStringAsFixed(0)}MB.',
              ),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      setState(() {
        _isUploadingPdf = true;
        _uploadProgress = 0.0;
      });

      final pdfFileName = pickedFile.name.isNotEmpty
          ? pickedFile.name.replaceAll('.pdf', '').replaceAll('.PDF', '')
          : 'Untitled Document';
      final fileName = 'summaries/${DateTime.now().millisecondsSinceEpoch}.pdf';

      // Upload to Firebase Storage with progress tracking
      final storageRef = FirebaseStorage.instance.ref().child(fileName);
      _currentUploadTask = storageRef.putFile(file);

      // Listen to upload progress
      _currentUploadTask!.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          if (mounted) {
            setState(() {
              _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
            });
          }
        },
        onError: (error) {
          // Handle upload errors in the catch block below
        },
      );

      // Wait for upload to complete
      await _currentUploadTask!;
      final downloadUrl = await storageRef.getDownloadURL();

      if (mounted) {
        setState(() {
          _uploadedPdfUrl = downloadUrl;
          _pdfFileName = pdfFileName;
          _isUploadingPdf = false;
          _uploadProgress = 0.0;
          _currentUploadTask = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'PDF uploaded successfully (${_formatFileSize(fileSize)})'),
            backgroundColor: _kAccentBlue,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on FirebaseException catch (e) {
      if (e.code == 'canceled') {
        // Upload was cancelled by user
        if (mounted) {
          setState(() {
            _isUploadingPdf = false;
            _uploadProgress = 0.0;
            _currentUploadTask = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Upload cancelled'),
              backgroundColor: Colors.orange.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      rethrow;
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploadingPdf = false;
          _uploadProgress = 0.0;
          _currentUploadTask = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload PDF: ${e.toString()}'),
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

  void _cancelSummarization() {
    _bloc.add(const CancelSummarizationEvent());
  }

  void _clearUploadedPdf() {
    setState(() {
      _uploadedPdfUrl = null;
      _pdfFileName = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _bloc),
        BlocProvider.value(value: _studyModeBloc),
      ],
      child: BlocListener<StudyModeBloc, StudyModeState>(
        listener: (context, state) {
          if (state is StudyModeFlashcardsLoaded) {
            // Close any open dialogs
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${state.flashcards.length} flashcards generated!',
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                action: SnackBarAction(
                  label: 'View',
                  textColor: Colors.white,
                  onPressed: () {
                    Navigator.pushNamed(context, '/study-mode');
                  },
                ),
              ),
            );
          } else if (state is StudyModeError) {
            // Close any open dialogs
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(child: Text(state.message)),
                  ],
                ),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
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
                      duration: const Duration(seconds: 5),
                    ),
                  );
                } else if (state is SummaryCancelled) {
                  // Handle cancelled state - show user feedback
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Summary generation cancelled'),
                      backgroundColor: Colors.grey.shade700,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                } else if (state is SummaryQueued) {
                  // Handle queued state - show user feedback
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.schedule, color: _kWhite, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              state.message,
                              style: const TextStyle(color: _kWhite),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.orange.shade700,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 4),
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
      ),
    );
  }

  Widget _buildInputSection(SummaryState state) {
    final isLoading = state is SummaryLoading;

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
              const Expanded(
                child: Text(
                  'Summarize PDF Handout',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: _kWhite,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Max file size: ${(AppConstants.maxPdfSizeBytes / (1024 * 1024)).toStringAsFixed(0)}MB',
            style: TextStyle(
              color: _kDarkGray,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),

          // Upload section with progress
          if (_isUploadingPdf)
            _buildUploadProgressSection()
          else if (_uploadedPdfUrl != null)
            _buildUploadedFileSection()
          else
            _buildUploadButton(),

          const SizedBox(height: 20),

          // Generate button or loading state with cancel
          if (isLoading)
            _buildLoadingStateWithCancel()
          else
            ElevatedButton(
              onPressed: _uploadedPdfUrl == null ? null : _summarizePdf,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAccentBlue,
                foregroundColor: _kWhite,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
                disabledBackgroundColor: _kAccentBlue.withOpacity(0.3),
                disabledForegroundColor: _kWhite.withOpacity(0.5),
              ),
              child: const Text(
                'Generate Summary',
                style: TextStyle(
                  color: _kWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUploadProgressSection() {
    final progressPercent = (_uploadProgress * 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kAccentBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kAccentBlue.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(_kAccentBlue),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Uploading... $progressPercent%',
                  style: TextStyle(
                    color: _kLightGray,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: _cancelUpload,
                icon: const Icon(Icons.close, size: 20),
                color: _kDarkGray,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Cancel upload',
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _uploadProgress,
              backgroundColor: _kDarkGray.withOpacity(0.3),
              valueColor: AlwaysStoppedAnimation<Color>(_kAccentBlue),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadedFileSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kAccentBlue.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kAccentBlue, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: _kAccentBlue, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _pdfFileName ?? 'PDF uploaded',
                  style: TextStyle(
                    color: _kWhite,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Ready to generate summary',
                  style: TextStyle(
                    color: _kAccentBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _clearUploadedPdf,
            icon: const Icon(Icons.close, size: 20),
            color: _kDarkGray,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'Remove file',
          ),
        ],
      ),
    );
  }

  Widget _buildUploadButton() {
    return InkWell(
      onTap: _pickAndUploadPdf,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: _kCardColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kDarkGray.withOpacity(0.5), width: 1.0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.upload_file, color: _kAccentBlue, size: 24),
            const SizedBox(width: 12),
            Text(
              'Upload PDF File',
              style: TextStyle(
                color: _kLightGray,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingStateWithCancel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kAccentBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kAccentBlue.withOpacity(0.3), width: 1),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(_kAccentBlue),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Generating summary...',
                    style: TextStyle(
                      color: _kLightGray,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'This may take a few minutes for large documents',
                style: TextStyle(
                  color: _kDarkGray,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _cancelSummarization,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: BorderSide(color: Colors.red.shade400),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: Colors.red.shade400,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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
    _studyModeBloc.add(GenerateFlashcardsEvent(
      sourceId: sourceId,
      sourceType: sourceType,
      numFlashcards: 10,
    ));

    // Show loading dialog - will auto-dismiss when BlocListener receives state change
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _kCardColor,
        title: const Text(
          'Generating Flashcards',
          style: TextStyle(color: _kWhite),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: _kAccentBlue),
            const SizedBox(height: 16),
            Text(
              'Your flashcards are being created. Please wait...',
              style: TextStyle(color: _kLightGray),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Note: Generation will continue in background
            },
            child: Text(
              'Dismiss',
              style: TextStyle(color: _kLightGray),
            ),
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
          style: const TextStyle(color: _kWhite),
          cursorColor: _kAccentBlue,
          decoration: InputDecoration(
            hintText: 'Enter title',
            hintStyle: TextStyle(color: _kDarkGray),
            filled: true,
            fillColor: _kBackgroundColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _kAccentBlue),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _kDarkGray),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
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
