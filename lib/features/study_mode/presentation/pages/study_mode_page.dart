import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../injection_container.dart';
import '../../domain/entities/flashcard.dart';
import '../bloc/study_mode_bloc.dart';
import '../bloc/study_mode_event.dart';
import '../bloc/study_mode_state.dart';
import 'flashcard_viewer_page.dart';
import 'study_progress_page.dart';

class StudyModePage extends StatefulWidget {
  const StudyModePage({super.key});

  @override
  State<StudyModePage> createState() => _StudyModePageState();
}

class _StudyModePageState extends State<StudyModePage> {
  late final StudyModeBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = getIt<StudyModeBloc>();
    _bloc.add(const LoadFlashcardsEvent());
    _bloc.add(const LoadProgressEvent());
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Study Mode'),
          actions: [
            IconButton(
              icon: const Icon(Icons.bar_chart),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const StudyProgressPage(),
                  ),
                );
              },
            ),
          ],
        ),
        body: BlocConsumer<StudyModeBloc, StudyModeState>(
          listener: (context, state) {
            if (state is StudyModeError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message)),
              );
            }
          },
          builder: (context, state) {
            if (state is StudyModeLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is StudyModeFlashcardsLoaded) {
              return _FlashcardsList(flashcards: state.flashcards);
            }

            if (state is StudyModeProgressLoaded) {
              return _FlashcardsList(flashcards: []);
            }

            return _FlashcardsList(flashcards: []);
          },
        ),
      ),
    );
  }
}

class _FlashcardsList extends StatelessWidget {
  const _FlashcardsList({required this.flashcards});

  final List<Flashcard> flashcards;

  @override
  Widget build(BuildContext context) {
    if (flashcards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.style, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No flashcards yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Generate flashcards from summaries or transcriptions',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Group flashcards by source
    final grouped = <String, List<Flashcard>>{};
    for (final flashcard in flashcards) {
      final key = '${flashcard.sourceType}_${flashcard.sourceId ?? 'unknown'}';
      grouped.putIfAbsent(key, () => []).add(flashcard);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Study all button
        Card(
          color: Colors.blue.shade50,
          child: ListTile(
            leading: const Icon(Icons.play_circle_filled, size: 48),
            title: const Text('Study All Flashcards'),
            subtitle: Text('${flashcards.length} cards'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FlashcardViewerPage(flashcards: flashcards),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        // Grouped flashcards
        ...grouped.entries.map((entry) {
          final sourceType = entry.value.first.sourceType ?? 'unknown';
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              leading: Icon(
                sourceType == 'summary' ? Icons.summarize : Icons.mic,
              ),
              title: Text(
                'From ${sourceType == 'summary' ? 'Summary' : 'Transcription'}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('${entry.value.length} flashcards'),
              children: [
                ...entry.value.map((flashcard) {
                  return ListTile(
                    title: Text(
                      flashcard.front,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      flashcard.isKnown ? 'Known' : 'Unknown',
                      style: TextStyle(
                        color: flashcard.isKnown ? Colors.green : Colors.orange,
                      ),
                    ),
                    trailing: flashcard.reviewCount > 0
                        ? Chip(
                            label: Text('${flashcard.reviewCount}x'),
                            padding: EdgeInsets.zero,
                          )
                        : null,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FlashcardViewerPage(
                            flashcards: [flashcard],
                          ),
                        ),
                      );
                    },
                  );
                }),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FlashcardViewerPage(
                            flashcards: entry.value,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Study This Set'),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

