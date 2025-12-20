import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../injection_container.dart';
import '../../../summarization/domain/repositories/summary_repository.dart';
import '../../../transcription/domain/repositories/transcription_repository.dart';
import '../bloc/quiz_bloc.dart';
import '../bloc/quiz_event.dart';
import '../bloc/quiz_state.dart';
import 'quiz_taking_page.dart';

// --- Local Color Palette for Quiz Creation Page ---
const Color _kBackgroundColor = Color(0xFF1E1E1E);
const Color _kCardColor = Color(0xFF333333);
const Color _kAccentBlue = Color(0xFF00BFFF); // Vibrant Electric Blue
const Color _kAccentCoral = Color(0xFFFF7043); // Soft Coral/Orange
const Color _kWhite = Colors.white;
const Color _kLightGray = Color(0xFFCCCCCC);
const Color _kDarkGray = Color(0xFF888888);

class QuizCreationPage extends StatefulWidget {
  const QuizCreationPage({super.key});

  @override
  State<QuizCreationPage> createState() => _QuizCreationPageState();
}

class _QuizCreationPageState extends State<QuizCreationPage> {
  late final QuizBloc _bloc;
  String _selectedSourceType = 'transcription';
  String? _selectedSourceId;
  int _numQuestions = 5;
  String _difficulty = 'medium';
  List<Map<String, String>> _transcriptions = [];
  List<Map<String, String>> _summaries = [];
  bool _loadingSources = true;

  @override
  void initState() {
    super.initState();
    _bloc = getIt<QuizBloc>();
    _loadSources();
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  Future<void> _loadSources() async {
    setState(() => _loadingSources = true);

    try {
      // Load summaries
      final summaryRepo = getIt<SummaryRepository>();
      final summariesResult = await summaryRepo.getAllSummaries();
      summariesResult.fold(
        (_) => {},
        (summaries) {
          setState(() {
            _summaries = summaries
                .map((s) => {
                      'id': s.id,
                      'title': s.title ??
                          (s.summaryText.length > 50
                              ? '${s.summaryText.substring(0, 50)}...'
                              : s.summaryText),
                      'date': DateFormat('MMM d, y').format(s.createdAt),
                    })
                .toList();
          });
        },
      );

      // Load transcriptions
      final transcriptionRepo = getIt<TranscriptionRepository>();
      final transcriptionsResult =
          await transcriptionRepo.getAllTranscriptions();
      transcriptionsResult.fold(
        (_) => {},
        (transcriptions) {
          setState(() {
            _transcriptions = transcriptions
                .map((t) => {
                      'id': t.id,
                      'title': t.title ??
                          (t.text != null && t.text!.length > 50
                              ? '${t.text!.substring(0, 50)}...'
                              : t.text) ?? 'Untitled Note',
                      'date': DateFormat('MMM d, y').format(t.timestamp),
                    })
                .map((m) => {
                      'id': m['id'] as String,
                      'title': m['title'] as String,
                      'date': m['date'] as String,
                    })
                .toList();
          });
        },
      );
    } catch (e) {
      // Handle error
    } finally {
      setState(() => _loadingSources = false);
    }
  }

  void _generateQuiz() {
    if (_selectedSourceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a source'),
          backgroundColor: _kAccentCoral,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _bloc.add(
      GenerateQuizEvent(
        sourceId: _selectedSourceId!,
        sourceType: _selectedSourceType,
        numQuestions: _numQuestions,
        difficulty: _difficulty,
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          title: const Text(
            'Create Quiz',
            style: TextStyle(
              color: _kWhite,
              fontWeight: FontWeight.bold,
              fontSize: 25
            ),
          ),
          backgroundColor: _kCardColor,
          elevation: 0,
          iconTheme: const IconThemeData(color: _kWhite),
        ),
        body: SafeArea(
          child: BlocConsumer<QuizBloc, QuizState>(
            listener: (context, state) {
              if (state is QuizError) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.message),
                    backgroundColor: _kAccentCoral,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } else if (state is QuizLoaded) {
                // Navigate to quiz taking page
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuizTakingPage(quiz: state.quiz),
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
                    _buildSourceTypeSelector(),
                    const SizedBox(height: 16),
                    _buildSourceSelector(),
                    const SizedBox(height: 16),
                    _buildNumQuestionsSelector(),
                    const SizedBox(height: 16),
                    _buildDifficultySelector(),
                    const SizedBox(height: 24),
                    _buildGenerateButton(state),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSourceTypeSelector() {
    return Container(
      decoration: BoxDecoration(
        color: _kCardColor,
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Source Type',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _kWhite,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'transcription',
                  label: Text('Notes'),
                  icon: Icon(Icons.mic),
                ),
                ButtonSegment(
                  value: 'summary',
                  label: Text('Summaries'),
                  icon: Icon(Icons.summarize),
                ),
              ],
              selected: {_selectedSourceType},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _selectedSourceType = newSelection.first;
                  _selectedSourceId = null; // Reset selection
                });
              },
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: _kAccentBlue,
                selectedForegroundColor: _kWhite,
                backgroundColor: _kCardColor,
                foregroundColor: _kLightGray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceSelector() {
    final sources =
        _selectedSourceType == 'transcription' ? _transcriptions : _summaries;

    return Container(
      decoration: BoxDecoration(
        color: _kCardColor,
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select ${_selectedSourceType == 'transcription' ? 'Note' : 'Summary'}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _kWhite,
              ),
            ),
            const SizedBox(height: 12),
            if (_loadingSources)
              const Center(
                child: CircularProgressIndicator(
                  color: _kAccentBlue,
                ),
              )
            else if (sources.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _kCardColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kCardColor, width: 1.0),
                ),
                child: Text(
                  _selectedSourceType == 'transcription'
                      ? 'No notes available. Create a note first from the Note Taking page.'
                      : 'No summaries available. Create a summary first from the Summarization page.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _kLightGray,
                    fontSize: 14,
                  ),
                ),
              )
            else
              ...sources.map(
                (source) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: _selectedSourceId == source['id']
                        ? _kAccentBlue.withOpacity(0.2)
                        : _kCardColor.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedSourceId == source['id']
                          ? _kAccentBlue
                          : _kCardColor,
                      width: 1.5,
                    ),
                  ),
                  child: RadioListTile<String>(
                    title: Text(
                      source['title'] ?? '',
                      style: const TextStyle(color: _kWhite),
                    ),
                    subtitle: Text(
                      source['date'] ?? '',
                      style: const TextStyle(color: _kLightGray),
                    ),
                    value: source['id'] ?? '',
                    // ignore: deprecated_member_use
                    groupValue: _selectedSourceId,
                    // ignore: deprecated_member_use
                    onChanged: (value) {
                      setState(() => _selectedSourceId = value);
                    },
                    activeColor: _kAccentBlue,
                    fillColor: MaterialStateProperty.resolveWith<Color>(
                      (Set<MaterialState> states) {
                        if (states.contains(MaterialState.selected)) {
                          return _kAccentBlue;
                        }
                        return _kLightGray;
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumQuestionsSelector() {
    return Container(
      decoration: BoxDecoration(
        color: _kCardColor,
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Number of Questions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _kWhite,
              ),
            ),
            const SizedBox(height: 12),
            Slider(
              value: _numQuestions.toDouble(),
              min: 3,
              max: 30,
              divisions: 27,
              label: '$_numQuestions questions',
              onChanged: (value) {
                setState(() => _numQuestions = value.toInt());
              },
              activeColor: _kAccentBlue,
              inactiveColor: _kDarkGray,
              thumbColor: _kAccentBlue,
            ),
            Center(
              child: Text(
                '$_numQuestions questions',
                style: const TextStyle(
                  color: _kAccentBlue,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultySelector() {
    return Container(
      decoration: BoxDecoration(
        color: _kCardColor,
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Difficulty',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _kWhite,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'easy', label: Text('Easy')),
                ButtonSegment(value: 'medium', label: Text('Medium')),
                ButtonSegment(value: 'hard', label: Text('Hard')),
              ],
              selected: {_difficulty},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() => _difficulty = newSelection.first);
              },
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: _kAccentCoral,
                selectedForegroundColor: _kWhite,
                backgroundColor: _kCardColor,
                foregroundColor: _kLightGray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateButton(QuizState state) {
    final isGenerating = state is QuizGenerating;
    final canGenerate = _selectedSourceId != null && !isGenerating;

    return ElevatedButton(
      onPressed: canGenerate ? _generateQuiz : null,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: canGenerate ? _kAccentBlue : _kDarkGray,
        foregroundColor: _kWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: canGenerate ? 4 : 0,
      ),
      child: isGenerating
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _kWhite,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Generating Quiz...',
                  style: TextStyle(
                    color: _kWhite,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            )
          : const Text(
              'Generate Quiz',
              style: TextStyle(
                color: _kWhite,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
    );
  }
}
