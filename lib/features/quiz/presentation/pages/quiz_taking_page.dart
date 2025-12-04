import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../injection_container.dart';
import '../../domain/entities/quiz.dart';
import '../bloc/quiz_bloc.dart';
import '../bloc/quiz_event.dart';
import '../bloc/quiz_state.dart';
import 'quiz_results_page.dart';

class QuizTakingPage extends StatefulWidget {
  const QuizTakingPage({
    super.key,
    required this.quiz,
  });

  final Quiz quiz;

  @override
  State<QuizTakingPage> createState() => _QuizTakingPageState();
}

class _QuizTakingPageState extends State<QuizTakingPage> {
  late final QuizBloc _bloc;
  Map<String, int> _answers = {};

  @override
  void initState() {
    super.initState();
    _bloc = getIt<QuizBloc>();
    _bloc.add(LoadQuizEvent(widget.quiz.id));
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  void _answerQuestion(String questionId, int selectedAnswer) {
    _bloc.add(AnswerQuestionEvent(
      questionId: questionId,
      selectedAnswer: selectedAnswer,
    ));
  }

  void _submitQuiz() {
    _bloc.add(const SubmitQuizEvent());
  }

  bool _allQuestionsAnswered(Quiz quiz) {
    return quiz.questions.every((q) => _answers.containsKey(q.id));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.quiz.title),
          actions: [
            BlocBuilder<QuizBloc, QuizState>(
              builder: (context, state) {
                if (state is QuizLoaded || state is QuizTaking) {
                  final quiz = state is QuizLoaded
                      ? state.quiz
                      : (state as QuizTaking).quiz;
                  final answers = state is QuizLoaded
                      ? state.answers
                      : (state as QuizTaking).answers;
                  _answers = answers;

                  return ElevatedButton(
                    onPressed: _allQuestionsAnswered(quiz)
                        ? _submitQuiz
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Submit'),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        body: BlocConsumer<QuizBloc, QuizState>(
          listener: (context, state) {
            if (state is QuizSubmitted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => QuizResultsPage(
                    quiz: state.quiz,
                    result: state.result,
                  ),
                ),
              );
            } else if (state is QuizError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message)),
              );
            }
          },
          builder: (context, state) {
            if (state is QuizLoaded) {
              return _buildQuizView(state.quiz, state.answers, 0);
            } else if (state is QuizTaking) {
              return _buildQuizView(
                state.quiz,
                state.answers,
                state.currentQuestionIndex,
              );
            } else if (state is QuizError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(state.message),
                  ],
                ),
              );
            }
            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }

  Widget _buildQuizView(Quiz quiz, Map<String, int> answers, int currentIndex) {
    final question = quiz.questions[currentIndex];
    final selectedAnswer = answers[question.id];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildProgressIndicator(quiz, currentIndex),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Question ${currentIndex + 1} of ${quiz.questions.length}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    question.question,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ...question.options.asMap().entries.map((entry) {
                    final index = entry.key;
                    final option = entry.value;
                    final isSelected = selectedAnswer == index;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: RadioListTile<int>(
                        title: Text(option),
                        value: index,
                        // ignore: deprecated_member_use
                        groupValue: selectedAnswer,
                        // ignore: deprecated_member_use
                        onChanged: (value) {
                          if (value != null) {
                            _answerQuestion(question.id, value);
                          }
                        },
                        selected: isSelected,
                        tileColor: isSelected
                            ? Colors.blue.shade50
                            : Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: isSelected
                                ? Colors.blue
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(Quiz quiz, int currentIndex) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progress: ${currentIndex + 1}/${quiz.questions.length}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              '${((currentIndex + 1) / quiz.questions.length * 100).toInt()}%',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: (currentIndex + 1) / quiz.questions.length,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
      ],
    );
  }
}

