import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../injection_container.dart';
import '../../../study_mode/presentation/bloc/study_mode_bloc.dart';
import '../../../study_mode/presentation/bloc/study_mode_event.dart';
import '../../../study_mode/presentation/bloc/study_mode_state.dart';
import '../../domain/entities/summary.dart';

// --- Local Color Palette for Summary Detail Page ---
const Color _kBackgroundColor = Color(0xFF1E1E1E);
const Color _kCardColor = Color(0xFF333333);
const Color _kAccentBlue = Color(0xFF00BFFF); // Vibrant Electric Blue
const Color _kWhite = Colors.white;
const Color _kLightGray = Color(0xFFCCCCCC);

class SummaryDetailPage extends StatefulWidget {
  const SummaryDetailPage({
    super.key,
    required this.summary,
  });

  final Summary summary;

  @override
  State<SummaryDetailPage> createState() => _SummaryDetailPageState();
}

class _SummaryDetailPageState extends State<SummaryDetailPage> {
  late final StudyModeBloc _studyModeBloc;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _studyModeBloc = getIt<StudyModeBloc>();
  }

  void _generateFlashcards(BuildContext context) {
    setState(() {
      _isGenerating = true;
    });

    _studyModeBloc.add(GenerateFlashcardsEvent(
      sourceId: widget.summary.id,
      sourceType: 'summary',
      numFlashcards: 10,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final displayTitle = widget.summary.title ?? 'Untitled Summary';
    
    return BlocProvider.value(
      value: _studyModeBloc,
      child: BlocListener<StudyModeBloc, StudyModeState>(
        listener: (context, state) {
          if (state is StudyModeFlashcardsLoaded) {
            setState(() {
              _isGenerating = false;
            });
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
            setState(() {
              _isGenerating = false;
            });
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
            title: Text(
              displayTitle,
              style: const TextStyle(
                color: _kWhite,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            iconTheme: const IconThemeData(color: _kWhite),
          ),
          body: SafeArea(
            child: Column(
              children: [
                // Full Summary Section - takes full screen
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: SelectableText(
                      widget.summary.summaryText,
                      style: const TextStyle(
                        color: _kLightGray,
                        fontSize: 16,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
                // Actions Section - fixed at bottom
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: _buildActionsSection(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.summary.summaryText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Summary copied to clipboard'),
        backgroundColor: _kAccentBlue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildActionsSection(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.content_copy, size: 18),
            label: const Text('Copy'),
            onPressed: () => _copyToClipboard(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              foregroundColor: _kAccentBlue,
              side: const BorderSide(color: _kAccentBlue),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            icon: _isGenerating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _kWhite,
                    ),
                  )
                : const Icon(Icons.style_outlined, size: 18),
            label: Text(_isGenerating ? 'Generating...' : 'Create Flashcards'),
            onPressed: _isGenerating ? null : () => _generateFlashcards(context),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              backgroundColor: _kAccentBlue,
              foregroundColor: _kWhite,
              disabledBackgroundColor: _kAccentBlue.withOpacity(0.5),
              disabledForegroundColor: _kWhite.withOpacity(0.7),
            ),
          ),
        ),
      ],
    );
  }
}

