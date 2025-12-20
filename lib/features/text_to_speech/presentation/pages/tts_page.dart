import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../injection_container.dart';
import '../../domain/entities/tts_job.dart';
import '../../../transcription/domain/entities/transcription.dart';
import '../bloc/tts_bloc.dart';
import '../bloc/tts_event.dart';
import '../bloc/tts_state.dart';
import '../widgets/note_picker_sheet.dart';

// --- Local Color Palette for TTS Page ---
const Color _kBackgroundColor = Color(0xFF1E1E1E);
const Color _kCardColor = Color(0xFF333333);
const Color _kAccentBlue = Color(0xFF00BFFF); // Vibrant Electric Blue
const Color _kAccentCoral = Color(0xFFFF7043); // Soft Coral/Orange
const Color _kWhite = Colors.white;
const Color _kLightGray = Color(0xFFCCCCCC);
const Color _kDarkGray = Color(0xFF888888);

enum TtsSource {
  pdf,
  note,
}

class TtsPage extends StatefulWidget {
  const TtsPage({super.key});

  @override
  State<TtsPage> createState() => _TtsPageState();
}

class _TtsPageState extends State<TtsPage> {
  late final TtsBloc _bloc;
  String? _uploadedPdfUrl;
  bool _isUploadingPdf = false;
  String _selectedVoice = 'en-US-Neural2-D'; // Neural2-D (default)
  TtsSource _selectedSource = TtsSource.pdf;
  Transcription? _selectedTranscription;

  final List<Map<String, String>> _voices = [
    {'value': 'en-US-Neural2-A', 'label': 'Neural2-A (Female)'},
    {'value': 'en-US-Neural2-B', 'label': 'Neural2-B (Male)'},
    {'value': 'en-US-Neural2-C', 'label': 'Neural2-C (Female)'},
    {'value': 'en-US-Neural2-D', 'label': 'Neural2-D (Male) - Default'},
    {'value': 'en-US-Neural2-E', 'label': 'Neural2-E (Female)'},
    {'value': 'en-US-Neural2-F', 'label': 'Neural2-F (Female)'},
    {'value': 'en-US-Neural2-G', 'label': 'Neural2-G (Female)'},
    {'value': 'en-US-Neural2-H', 'label': 'Neural2-H (Female)'},
    {'value': 'en-US-Neural2-I', 'label': 'Neural2-I (Male)'},
    {'value': 'en-US-Neural2-J', 'label': 'Neural2-J (Male)'},
  ];

  @override
  void initState() {
    super.initState();
    _bloc = getIt<TtsBloc>();
    _bloc.add(const LoadTtsJobsEvent());
  }

  @override
  void dispose() {
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
        final fileName = 'tts/${DateTime.now().millisecondsSinceEpoch}.pdf';

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
            backgroundColor: _kAccentCoral,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _convertPdfToAudio() {
    if (_uploadedPdfUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please upload a PDF first'),
          backgroundColor: _kAccentCoral,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _bloc.add(ConvertPdfToAudioEvent(
        pdfUrl: _uploadedPdfUrl!, voice: _selectedVoice));
  }

  void _convertNoteToAudio() {
    final note = _selectedTranscription;
    if (note == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a note first'),
          backgroundColor: _kAccentCoral,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (note.text == null || note.text!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Selected note has no text to convert'),
          backgroundColor: _kAccentCoral,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _bloc.add(
      ConvertTextToAudioEvent(
        text: note.text!,
        voice: _selectedVoice,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: _kBackgroundColor,
        appBar: AppBar(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          title: const Text(
            'Audio Notes',
            style: TextStyle(
                color: _kWhite, fontWeight: FontWeight.bold, fontSize: 25),
          ),
          backgroundColor: _kCardColor,
          elevation: 0,
          iconTheme: const IconThemeData(color: _kWhite),
        ),
        body: SafeArea(
          child: BlocConsumer<TtsBloc, TtsState>(
            listener: (context, state) {
              if (state is TtsError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: _kAccentCoral,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else if (state is TtsSuccess) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Audio conversion completed'),
                    backgroundColor: _kAccentBlue,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            builder: (context, state) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildInputSection(state),
                    const SizedBox(height: 24),
                    _buildLatestJob(state),
                    const SizedBox(height: 24),
                    _buildJobsList(state),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildInputSection(TtsState state) {
    return Container(
      decoration: BoxDecoration(
        color: _kCardColor,
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Convert to Audio Note',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _kWhite,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'Source: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: _kLightGray,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: _kCardColor.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kCardColor, width: 1.0),
                    ),
                    child: DropdownButton<TtsSource>(
                      value: _selectedSource,
                      isExpanded: true,
                      dropdownColor: _kCardColor,
                      style: const TextStyle(color: _kWhite),
                      items: const [
                        DropdownMenuItem(
                          value: TtsSource.pdf,
                          child: Text(
                            'Upload PDF',
                            style: TextStyle(color: _kWhite),
                          ),
                        ),
                        DropdownMenuItem(
                          value: TtsSource.note,
                          child: Text(
                            'Note Taker',
                            style: TextStyle(color: _kWhite),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedSource = value;
                          if (_selectedSource == TtsSource.pdf) {
                            _selectedTranscription = null;
                          }
                        });
                      },
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: _kAccentBlue,
                      ),
                      underline: const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text(
                  'Voice: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: _kLightGray,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: _kCardColor.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kCardColor, width: 1.0),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedVoice,
                      isExpanded: true,
                      dropdownColor: _kCardColor,
                      style: const TextStyle(color: _kWhite),
                      items: _voices.map((voice) {
                        return DropdownMenuItem(
                          value: voice['value'],
                          child: Text(
                            voice['label']!,
                            style: const TextStyle(color: _kWhite),
                          ),
                        );
                      }).toList(),
                      onChanged: state is TtsProcessing
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _selectedVoice = value);
                              }
                            },
                      icon: const Icon(Icons.arrow_drop_down,
                          color: _kAccentBlue),
                      underline: const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_selectedSource == TtsSource.pdf && _uploadedPdfUrl != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _kAccentBlue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kAccentBlue, width: 1.5),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.check_circle, color: _kAccentBlue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'PDF uploaded',
                        style: TextStyle(color: _kAccentBlue),
                      ),
                    ),
                  ],
                ),
              )
            else if (_selectedSource == TtsSource.pdf)
              OutlinedButton.icon(
                onPressed: _isUploadingPdf ? null : _pickAndUploadPdf,
                icon: _isUploadingPdf
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _kAccentBlue,
                        ),
                      )
                    : const Icon(Icons.upload_file),
                label: Text(_isUploadingPdf ? 'Uploading...' : 'Upload PDF'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: const BorderSide(color: _kAccentBlue, width: 1.5),
                  foregroundColor: _kAccentBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            if (_selectedSource == TtsSource.note)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final selected = await NotePickerSheet.show(context);
                      if (!mounted) return;

                      setState(() {
                        _selectedTranscription = selected;
                      });

                      if (selected != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Selected note: ${selected.title ?? 'Untitled note'}',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.auto_stories_outlined),
                    label: const Text('Select note from Note Taker'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(
                        color: _kAccentBlue,
                        width: 1.5,
                      ),
                      foregroundColor: _kAccentBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_selectedTranscription != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _kCardColor.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _kAccentBlue.withOpacity(0.6),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedTranscription!.title ?? 'Selected note',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _kWhite,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _selectedTranscription!.text ?? 'No text available',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _kLightGray,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const Text(
                      'Pick an existing note from Automatic Notes Taker to convert it to audio.',
                      style: TextStyle(
                        color: _kLightGray,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isConvertDisabled(state)
                  ? null
                  : () {
                      if (_selectedSource == TtsSource.pdf) {
                        _convertPdfToAudio();
                      } else {
                        _convertNoteToAudio();
                      }
                    },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor:
                    _isConvertDisabled(state) ? _kDarkGray : _kAccentBlue,
                foregroundColor: _kWhite,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation:
                    (state is TtsProcessing || _uploadedPdfUrl == null) ? 0 : 4,
              ),
              child: Text(
                _selectedSource == TtsSource.pdf
                    ? 'Convert PDF to Audio Note'
                    : 'Convert Note to Audio',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: _kWhite,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isConvertDisabled(TtsState state) {
    if (state is TtsProcessing) {
      return true;
    }
    if (_selectedSource == TtsSource.pdf) {
      return _uploadedPdfUrl == null;
    }
    return _selectedTranscription == null;
  }

  Widget _buildLatestJob(TtsState state) {
    if (state is TtsSuccess) {
      return Container(
        decoration: BoxDecoration(
          color: _kAccentBlue.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20.0),
          border: Border.all(color: _kAccentBlue.withOpacity(0.3), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.audiotrack, color: _kAccentBlue),
                  SizedBox(width: 8),
                  Text(
                    'Latest Conversion',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _kAccentBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Status: ${state.job.status}',
                style: TextStyle(
                  fontSize: 14,
                  color: _getStatusColor(state.job.status),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Source: ${state.job.sourceType} • ${_formatDate(state.job.createdAt)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: _kLightGray,
                ),
              ),
              if (state.job.status == 'completed' &&
                  state.job.audioUrl.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildAudioPlayer(state.job.audioUrl, state),
              ],
            ],
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildJobsList(TtsState state) {
    final jobs = state.jobs;

    if (jobs.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: _kCardColor,
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.audiotrack,
                  size: 48,
                  color: _kDarkGray,
                ),
                const SizedBox(height: 12),
                const Text(
                  'No audio conversions yet',
                  style: TextStyle(color: _kLightGray),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Convert a PDF or note to audio above',
                  style: TextStyle(
                    color: _kDarkGray,
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
          'Past Conversions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _kWhite,
          ),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: jobs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final job = jobs[index];
            return _buildJobCard(job, state);
          },
        ),
      ],
    );
  }

  Widget _buildJobCard(TtsJob job, TtsState state) {
    return Container(
      decoration: BoxDecoration(
        color: _kCardColor,
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: ListTile(
        leading: Icon(
          _getStatusIcon(job.status),
          color: _getStatusColor(job.status),
        ),
        title: Text(
          '${job.sourceType.toUpperCase()} • ${job.status}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: _kWhite,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatDate(job.createdAt),
              style: const TextStyle(color: _kLightGray),
            ),
            if (job.status == 'completed' && job.audioUrl.isNotEmpty)
              const SizedBox(height: 4),
            if (job.status == 'completed' && job.audioUrl.isNotEmpty)
              _buildAudioPlayer(job.audioUrl, state),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: _kAccentCoral),
          onPressed: () {
            _bloc.add(DeleteTtsJobEvent(job.id));
          },
        ),
      ),
    );
  }

  Widget _buildAudioPlayer(String audioUrl, TtsState state) {
    final isPlaying = state is TtsPlaying &&
        state.currentAudioUrl == audioUrl &&
        state.isPlaying;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
          onPressed: () {
            if (isPlaying) {
              _bloc.add(const PauseAudioEvent());
            } else {
              _bloc.add(PlayAudioEvent(audioUrl));
            }
          },
          color: _kAccentBlue,
        ),
        if (isPlaying)
          IconButton(
            icon: const Icon(Icons.stop),
            onPressed: () {
              _bloc.add(const StopAudioEvent());
            },
            color: _kAccentCoral,
          ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'processing':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'processing':
        return Icons.hourglass_empty;
      case 'failed':
        return Icons.error;
      default:
        return Icons.pending;
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, y • h:mm a').format(date);
  }
}
