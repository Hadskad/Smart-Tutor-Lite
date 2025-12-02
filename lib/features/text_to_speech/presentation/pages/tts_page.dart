import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../injection_container.dart';
import '../../domain/entities/tts_job.dart';
import '../bloc/tts_bloc.dart';
import '../bloc/tts_event.dart';
import '../bloc/tts_state.dart';

class TtsPage extends StatefulWidget {
  const TtsPage({super.key});

  @override
  State<TtsPage> createState() => _TtsPageState();
}

class _TtsPageState extends State<TtsPage> {
  late final TtsBloc _bloc;
  final TextEditingController _textController = TextEditingController();
  String? _uploadedPdfUrl;
  bool _isUploadingPdf = false;
  String _selectedVoice = '21m00Tcm4TlvDq8ikWAM'; // Rachel (default)

  final List<Map<String, String>> _voices = [
    {'value': '21m00Tcm4TlvDq8ikWAM', 'label': 'Rachel (Female)'},
    {'value': 'pNInz6obpgDQGcFmaJgB', 'label': 'Adam (Male)'},
    {'value': 'EXAVITQu4vr4xnSDxMaL', 'label': 'Bella (Female)'},
    {'value': 'ErXwobaYiN019PkySvjV', 'label': 'Antoni (Male)'},
  ];

  @override
  void initState() {
    super.initState();
    _bloc = getIt<TtsBloc>();
    _bloc.add(const LoadTtsJobsEvent());
  }

  @override
  void dispose() {
    _textController.dispose();
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
          final colorScheme = Theme.of(context).colorScheme;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('PDF uploaded successfully'),
              backgroundColor: colorScheme.secondary,
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
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload PDF: $e'),
            backgroundColor: colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _convertTextToAudio() {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      final colorScheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter some text to convert'),
          backgroundColor: colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _bloc.add(ConvertTextToAudioEvent(text: text, voice: _selectedVoice));
    _textController.clear();
  }

  void _convertPdfToAudio() {
    if (_uploadedPdfUrl == null) {
      final colorScheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please upload a PDF first'),
          backgroundColor: colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _bloc.add(ConvertPdfToAudioEvent(
        pdfUrl: _uploadedPdfUrl!, voice: _selectedVoice));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Text-to-Speech'),
        ),
        body: BlocConsumer<TtsBloc, TtsState>(
          listener: (context, state) {
            final colorScheme = Theme.of(context).colorScheme;
            if (state is TtsError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: colorScheme.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } else if (state is TtsSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Audio conversion completed'),
                  backgroundColor: colorScheme.secondary,
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
    );
  }

  Widget _buildInputSection(TtsState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Convert Text to Audio',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Voice: ',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String>(
                    value: _selectedVoice,
                    isExpanded: true,
                    items: _voices.map((voice) {
                      return DropdownMenuItem(
                        value: voice['value'],
                        child: Text(voice['label']!),
                      );
                    }).toList(),
                    onChanged: state is TtsProcessing
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _selectedVoice = value);
                            }
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Enter text to convert to audio...',
                border: OutlineInputBorder(),
              ),
              enabled: state is! TtsProcessing,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: state is TtsProcessing ? null : _convertTextToAudio,
              child: const Text('Convert Text to Audio'),
            ),
            const Divider(height: 32),
            const Text(
              'Convert PDF to Audio',
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
              onPressed: state is TtsProcessing || _uploadedPdfUrl == null
                  ? null
                  : _convertPdfToAudio,
              child: const Text('Convert PDF to Audio'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLatestJob(TtsState state) {
    if (state is TtsSuccess) {
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
                  Icon(Icons.audiotrack, color: colorScheme.secondary),
                  const SizedBox(width: 8),
                  Text(
                    'Latest Conversion',
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
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
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
      final colorScheme = Theme.of(context).colorScheme;
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.audiotrack,
                  size: 48,
                  color: colorScheme.outline.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 12),
                Text(
                  'No audio conversions yet',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Text(
                  'Convert text or PDF to audio above',
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
          'Past Conversions',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
    return Card(
      child: ListTile(
        leading: Icon(
          _getStatusIcon(job.status),
          color: _getStatusColor(job.status),
        ),
        title: Text(
          '${job.sourceType.toUpperCase()} • ${job.status}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_formatDate(job.createdAt)}'),
            if (job.status == 'completed' && job.audioUrl.isNotEmpty)
              const SizedBox(height: 4),
            if (job.status == 'completed' && job.audioUrl.isNotEmpty)
              _buildAudioPlayer(job.audioUrl, state),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
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
          color: Theme.of(context).colorScheme.primary,
        ),
        if (isPlaying)
          IconButton(
            icon: const Icon(Icons.stop),
            onPressed: () {
              _bloc.add(const StopAudioEvent());
            },
            color: Theme.of(context).colorScheme.error,
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
