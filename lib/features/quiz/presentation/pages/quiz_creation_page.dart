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
                      'title': s.summaryText.length > 50
                          ? '${s.summaryText.substring(0, 50)}...'
                          : s.summaryText,
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
                      'title': t.text.length > 50
                          ? '${t.text.substring(0, 50)}...'
                          : t.text,
                      'date': DateFormat('MMM d, y').format(t.timestamp),
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
      final colorScheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a source'),
          backgroundColor: colorScheme.error,
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
        appBar: AppBar(
          title: const Text('Create Quiz'),
        ),
        body: BlocConsumer<QuizBloc, QuizState>(
          listener: (context, state) {
            if (state is QuizError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Theme.of(context).colorScheme.error,
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
    );
  }

  Widget _buildSourceTypeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Source Type',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'transcription',
                  label: Text('Transcription'),
                  icon: Icon(Icons.mic),
                ),
                ButtonSegment(
                  value: 'summary',
                  label: Text('Summary'),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceSelector() {
    final sources =
        _selectedSourceType == 'transcription' ? _transcriptions : _summaries;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select ${_selectedSourceType == 'transcription' ? 'Transcription' : 'Summary'}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_loadingSources)
              const Center(child: CircularProgressIndicator())
            else if (sources.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _selectedSourceType == 'transcription'
                      ? 'No transcriptions available. Create a transcription first from the Transcription page.'
                      : 'No summaries available. Create a summary first from the Summarization page.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              ...sources.map(
                (source) => RadioListTile<String>(
                  title: Text(source['title'] ?? ''),
                  subtitle: Text(source['date'] ?? ''),
                  value: source['id'] ?? '',
                  // ignore: deprecated_member_use
                  groupValue: _selectedSourceId,
                  // ignore: deprecated_member_use
                  onChanged: (value) {
                    setState(() => _selectedSourceId = value);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumQuestionsSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Number of Questions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Slider(
              value: _numQuestions.toDouble(),
              min: 3,
              max: 10,
              divisions: 7,
              label: '$_numQuestions questions',
              onChanged: (value) {
                setState(() => _numQuestions = value.toInt());
              },
            ),
            Center(child: Text('$_numQuestions questions')),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultySelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Difficulty',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
      ),
      child: isGenerating
          ? const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Generating Quiz...'),
              ],
            )
          : const Text('Generate Quiz'),
    );
  }
}
