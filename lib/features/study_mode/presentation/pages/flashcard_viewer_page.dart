import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../injection_container.dart';
import '../../domain/entities/flashcard.dart';
import '../../domain/entities/study_session.dart';
import '../bloc/study_mode_bloc.dart';
import '../bloc/study_mode_event.dart';
import '../bloc/study_mode_state.dart';

class FlashcardViewerPage extends StatelessWidget {
  const FlashcardViewerPage({
    super.key,
    required this.flashcards,
  });

  final List<Flashcard> flashcards;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<StudyModeBloc>()..add(StartStudySessionEvent(flashcardIds: flashcards.map((f) => f.id).toList())),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Study Session'),
        ),
        body: BlocBuilder<StudyModeBloc, StudyModeState>(
          builder: (context, state) {
            if (state is StudyModeSessionActive) {
              return _StudySessionView(sessionState: state);
            } else if (state is StudyModeSessionCompleted) {
              return _SessionCompletedView(session: state.session, flashcards: state.flashcards);
            } else if (state is StudyModeError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(state.message),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Go Back'),
                    ),
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
}

class _StudySessionView extends StatefulWidget {
  const _StudySessionView({required this.sessionState});

  final StudyModeSessionActive sessionState;

  @override
  State<_StudySessionView> createState() => _StudySessionViewState();
}

class _StudySessionViewState extends State<_StudySessionView> {
  bool _isFlipped = false;

  @override
  void initState() {
    super.initState();
    _isFlipped = widget.sessionState.isFlipped;
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<StudyModeBloc>();
    return BlocConsumer<StudyModeBloc, StudyModeState>(
      listener: (context, state) {
        if (state is StudyModeSessionActive) {
          setState(() {
            _isFlipped = state.isFlipped;
          });
        }
      },
      builder: (context, state) {
        if (state is! StudyModeSessionActive) {
          return const Center(child: CircularProgressIndicator());
        }

        final session = state.session;
        final flashcard = state.currentFlashcard;
        final progress = state.progress;
        final cardNumber = state.currentFlashcardIndex + 1;
        final totalCards = session.flashcardIds.length;

        return Column(
          children: [
            // Progress bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Card $cardNumber of $totalCards',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            // Flashcard
            Expanded(
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    bloc.flipCard();
                    setState(() {
                      _isFlipped = !_isFlipped;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Card(
                      elevation: 8,
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Text(
                              _isFlipped ? flashcard.back : flashcard.front,
                              key: ValueKey(_isFlipped),
                              style: Theme.of(context).textTheme.headlineSmall,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Action buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      bloc.add(MarkFlashcardUnknownEvent(flashcardId: flashcard.id));
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Didn\'t Know'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade100,
                      foregroundColor: Colors.red.shade900,
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      bloc.add(MarkFlashcardKnownEvent(flashcardId: flashcard.id));
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Knew It'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade100,
                      foregroundColor: Colors.green.shade900,
                    ),
                  ),
                ],
              ),
            ),
            // Hint text
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Tap card to flip • Swipe to navigate',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SessionCompletedView extends StatelessWidget {
  const _SessionCompletedView({
    required this.session,
    required this.flashcards,
  });

  final StudySession session;
  final List<Flashcard> flashcards;

  @override
  Widget build(BuildContext context) {
    final knownPercentage = session.flashcardIds.isEmpty
        ? 0.0
        : (session.cardsKnown / session.flashcardIds.length) * 100;
    final durationMinutes = session.durationSeconds != null
        ? (session.durationSeconds! / 60).toStringAsFixed(1)
        : '0';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.celebration, size: 64, color: Colors.green),
            const SizedBox(height: 24),
            Text(
              'Session Complete!',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 32),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _StatRow(
                      label: 'Cards Reviewed',
                      value: '${session.cardsReviewed}/${session.flashcardIds.length}',
                    ),
                    const Divider(),
                    _StatRow(
                      label: 'Cards Known',
                      value: '${session.cardsKnown}',
                    ),
                    const Divider(),
                    _StatRow(
                      label: 'Mastery',
                      value: '${knownPercentage.toStringAsFixed(1)}%',
                    ),
                    const Divider(),
                    _StatRow(
                      label: 'Duration',
                      value: '$durationMinutes minutes',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}

