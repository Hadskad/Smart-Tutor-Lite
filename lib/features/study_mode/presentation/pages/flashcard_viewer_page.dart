import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../injection_container.dart';
import '../../domain/entities/flashcard.dart';
import '../../domain/entities/study_session.dart';
import '../bloc/study_mode_bloc.dart';
import '../bloc/study_mode_event.dart';
import '../bloc/study_mode_state.dart';

// Color Palette matching Home Dashboard
const Color _kBackgroundColor = Color(0xFF1E1E1E);
const Color _kCardColor = Color(0xFF333333);
const Color _kAccentBlue = Color(0xFF00BFFF);
const Color _kAccentCoral = Color(0xFFFF7043);
const Color _kWhite = Colors.white;
const Color _kLightGray = Color(0xFFCCCCCC);
const Color _kDarkGray = Color(0xFF888888);

class FlashcardViewerPage extends StatelessWidget {
  const FlashcardViewerPage({
    super.key,
    required this.flashcards,
  });

  final List<Flashcard> flashcards;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<StudyModeBloc>()
        ..add(StartStudySessionEvent(
            flashcardIds: flashcards.map((f) => f.id).toList())),
      child: Scaffold(
        backgroundColor: _kBackgroundColor,
        appBar: AppBar(
          backgroundColor: _kBackgroundColor,
          elevation: 0,
          title: const Text(
            'Study Session',
            style: TextStyle(
              color: _kWhite,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconTheme: const IconThemeData(color: _kWhite),
        ),
        body: BlocBuilder<StudyModeBloc, StudyModeState>(
          builder: (context, state) {
            if (state is StudyModeSessionActive) {
              return _StudySessionView(sessionState: state);
            } else if (state is StudyModeSessionCompleted) {
              return _SessionCompletedView(
                  session: state.session, flashcards: state.flashcards);
            } else if (state is StudyModeError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: _kAccentCoral),
                    const SizedBox(height: 16),
                    Text(
                      state.message,
                      style: const TextStyle(color: _kWhite, fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kAccentBlue,
                        foregroundColor: _kWhite,
                      ),
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              );
            }
            return const Center(
              child: CircularProgressIndicator(color: _kAccentBlue),
            );
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
          return const Center(
            child: CircularProgressIndicator(color: _kAccentBlue),
          );
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
                    backgroundColor: _kCardColor,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(_kAccentBlue),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Card $cardNumber of $totalCards',
                    style: const TextStyle(
                      color: _kLightGray,
                      fontSize: 16,
                    ),
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
                    child: Container(
                      decoration: BoxDecoration(
                        color: _kCardColor,
                        borderRadius: BorderRadius.circular(20.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            _isFlipped ? flashcard.back : flashcard.front,
                            key: ValueKey(_isFlipped),
                            style: const TextStyle(
                              color: _kWhite,
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
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
                      bloc.add(
                          MarkFlashcardUnknownEvent(flashcardId: flashcard.id));
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Didn\'t Know'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kAccentCoral,
                      foregroundColor: _kWhite,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      bloc.add(
                          MarkFlashcardKnownEvent(flashcardId: flashcard.id));
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Knew It'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kAccentBlue,
                      foregroundColor: _kWhite,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                style: const TextStyle(
                  color: _kDarkGray,
                  fontSize: 12,
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
            const Icon(Icons.celebration, size: 64, color: _kAccentBlue),
            const SizedBox(height: 24),
            const Text(
              'Session Complete!',
              style: TextStyle(
                color: _kWhite,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                color: _kCardColor,
                borderRadius: BorderRadius.circular(20.0),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _StatRow(
                    label: 'Cards Reviewed',
                    value:
                        '${session.cardsReviewed}/${session.flashcardIds.length}',
                  ),
                  const Divider(color: _kDarkGray),
                  _StatRow(
                    label: 'Cards Known',
                    value: '${session.cardsKnown}',
                  ),
                  const Divider(color: _kDarkGray),
                  _StatRow(
                    label: 'Mastery',
                    value: '${knownPercentage.toStringAsFixed(1)}%',
                  ),
                  const Divider(color: _kDarkGray),
                  _StatRow(
                    label: 'Duration',
                    value: '$durationMinutes minutes',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAccentBlue,
                foregroundColor: _kWhite,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Done', style: TextStyle(fontSize: 16)),
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
            style: const TextStyle(
              color: _kLightGray,
              fontSize: 16,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: _kWhite,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
