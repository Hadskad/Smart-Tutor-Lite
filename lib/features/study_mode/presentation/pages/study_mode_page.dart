import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../injection_container.dart';
import '../../domain/entities/flashcard.dart';
import '../../../transcription/domain/repositories/transcription_repository.dart';
import '../../../summarization/domain/repositories/summary_repository.dart';
import '../bloc/study_mode_bloc.dart';
import '../bloc/study_mode_event.dart';
import '../bloc/study_mode_state.dart';
import 'flashcard_browse_page.dart';
import 'flashcard_viewer_page.dart';
import 'study_progress_page.dart';

// Color Palette matching Home Dashboard
const Color _kBackgroundColor = Color(0xFF1E1E1E);
const Color _kCardColor = Color(0xFF333333);
const Color _kAccentBlue = Color(0xFF00BFFF);
const Color _kAccentCoral = Color(0xFFFF7043);
const Color _kWhite = Colors.white;
const Color _kLightGray = Color(0xFFCCCCCC);
const Color _kDarkGray = Color(0xFF888888);

class StudyModePage extends StatefulWidget {
  const StudyModePage({super.key});

  @override
  State<StudyModePage> createState() => _StudyModePageState();
}

class _StudyModePageState extends State<StudyModePage> {
  late final StudyModeBloc _bloc;
  List<Flashcard> _cachedFlashcards = [];

  @override
  void initState() {
    super.initState();
    _bloc = getIt<StudyModeBloc>();
    _bloc.add(const LoadFlashcardsEvent());
    _bloc.add(const LoadProgressEvent());
  }

  @override
  void dispose() {
    // Don't close the bloc - it's a singleton shared across the app
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: _kBackgroundColor,
        appBar: AppBar(
          backgroundColor: _kBackgroundColor,
          elevation: 0,
          title: const Text(
            'Study Mode',
            style: TextStyle(
              color: _kWhite,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconTheme: const IconThemeData(color: _kWhite),
          actions: [
            IconButton(
              icon: const Icon(Icons.bar_chart, color: _kAccentBlue),
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
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Theme.of(context).colorScheme.error,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            // Cache flashcards when they're loaded
            if (state is StudyModeFlashcardsLoaded) {
              _cachedFlashcards = state.flashcards;
            }
          },
          builder: (context, state) {
            // Show loading only if we don't have cached flashcards
            if (state is StudyModeLoading && _cachedFlashcards.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(
                  color: _kAccentBlue,
                ),
              );
            }

            // Use cached flashcards if progress is loaded but we have flashcards cached
            if (state is StudyModeProgressLoaded) {
              return _FlashcardsList(flashcards: _cachedFlashcards);
            }

            // Show flashcards when they're loaded
            if (state is StudyModeFlashcardsLoaded) {
              return _FlashcardsList(flashcards: state.flashcards);
            }

            // Fallback: show cached flashcards if available, otherwise empty
            return _FlashcardsList(flashcards: _cachedFlashcards);
          },
        ),
      ),
    );
  }
}

class _FlashcardsList extends StatefulWidget {
  const _FlashcardsList({required this.flashcards});

  final List<Flashcard> flashcards;

  @override
  State<_FlashcardsList> createState() => _FlashcardsListState();
}

class _FlashcardsListState extends State<_FlashcardsList> {
  final Map<String, String> _sourceTitles = {};
  bool _isLoadingTitles = true;

  @override
  void initState() {
    super.initState();
    _loadSourceTitles();
  }

  @override
  void didUpdateWidget(covariant _FlashcardsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.flashcards != oldWidget.flashcards) {
      _loadSourceTitles();
    }
  }

  Future<void> _loadSourceTitles() async {
     if (mounted) {
      setState(() {
        _isLoadingTitles = true;
      });
    }

    final transcriptionRepo = getIt<TranscriptionRepository>();
    final summaryRepo = getIt<SummaryRepository>();

    // Group flashcards by source
    final grouped = <String, List<Flashcard>>{};
    for (final flashcard in widget.flashcards) {
      final key = '${flashcard.sourceType}_${flashcard.sourceId ?? 'unknown'}';
      grouped.putIfAbsent(key, () => []).add(flashcard);
    }

    // Fetch titles for each source
    final titleMap = <String, String>{};
    for (final entry in grouped.entries) {
      final sourceType = entry.value.first.sourceType;
      final sourceId = entry.value.first.sourceId;
      final key = entry.key;

      if (sourceId == null) {
        titleMap[key] = _getDefaultSourceName(sourceType ?? 'unknown');
        continue;
      }

      try {
        String? title;
        if (sourceType == 'transcription' || sourceType == 'note') {
          final result = await transcriptionRepo.getTranscription(sourceId);
          result.fold(
            (_) => null,
            (transcription) => title = transcription.title,
          );
        } else if (sourceType == 'summary') {
          final result = await summaryRepo.getSummary(sourceId);
          result.fold(
            (_) => null,
            (summary) => title = summary.title,
          );
        }

        titleMap[key] = title?.trim().isNotEmpty == true
            ? title!
            : _getDefaultSourceName(sourceType ?? 'unknown');
      } catch (e) {
        titleMap[key] = _getDefaultSourceName(sourceType ?? 'unknown');
      }
    }

    if (mounted) {
      setState(() {
        _sourceTitles.addAll(titleMap);
        _isLoadingTitles = false;
      });
    }
  }

  String _getDefaultSourceName(String sourceType) {
    switch (sourceType) {
      case 'summary':
        return 'Summary';
      case 'note':
        return 'Note';
      case 'transcription':
        return 'Transcription';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.flashcards.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _kAccentBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.style_outlined,
                  size: 64,
                  color: _kAccentBlue,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'No flashcards yet',
                style: TextStyle(
                  color: _kWhite,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Generate flashcards from your notes, transcriptions, or summaries to start studying!',
                style: const TextStyle(
                  color: _kLightGray,
                  fontSize: 16,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _EmptyStateActionButton(
                    icon: Icons.mic,
                    label: 'Notes',
                    onTap: () => Navigator.pushNamed(context, '/transcription'),
                  ),
                  const SizedBox(width: 16),
                  _EmptyStateActionButton(
                    icon: Icons.summarize,
                    label: 'Summaries',
                    onTap: () => Navigator.pushNamed(context, '/summary'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Tap on any note or summary, then select "Generate Flashcards"',
                style: TextStyle(
                  color: _kDarkGray,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Group flashcards by source
    final grouped = <String, List<Flashcard>>{};
    for (final flashcard in widget.flashcards) {
      final key = '${flashcard.sourceType}_${flashcard.sourceId ?? 'unknown'}';
      grouped.putIfAbsent(key, () => []).add(flashcard);
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Study all button
        Container(
          decoration: BoxDecoration(
            color: _kCardColor,
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _kAccentBlue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.school,
                        size: 32,
                        color: _kAccentBlue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'All Flashcards',
                            style: TextStyle(
                              color: _kWhite,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Builder(
                            builder: (context) {
                              final knownCount = widget.flashcards
                                  .where((f) => f.isKnown)
                                  .length;
                              final totalCount = widget.flashcards.length;
                              final progress = totalCount > 0
                                  ? knownCount / totalCount
                                  : 0.0;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '$knownCount/$totalCount mastered',
                                        style: TextStyle(
                                          color: knownCount == totalCount && totalCount > 0
                                              ? _kAccentBlue
                                              : _kLightGray,
                                          fontSize: 13,
                                          fontWeight: knownCount == totalCount && totalCount > 0
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                      if (knownCount == totalCount && totalCount > 0)
                                        Padding(
                                          padding: const EdgeInsets.only(left: 4),
                                          child: Icon(
                                            Icons.check_circle,
                                            size: 14,
                                            color: _kAccentBlue,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: progress,
                                      minHeight: 6,
                                      backgroundColor: _kBackgroundColor,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        progress >= 1.0
                                            ? _kAccentBlue
                                            : _kAccentBlue.withOpacity(0.7),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FlashcardBrowsePage(
                                flashcards: widget.flashcards,
                                title: 'All Flashcards',
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.view_list, color: _kAccentBlue),
                        label: const Text('Browse',
                            style: TextStyle(color: _kAccentBlue)),
                        style: OutlinedButton.styleFrom(
                          side:
                              const BorderSide(color: _kAccentBlue, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _showStudySessionDialog(context, widget.flashcards);
                        },
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Study'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kAccentBlue,
                          foregroundColor: _kWhite,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Section header
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: const Text(
            'By Source',
            style: TextStyle(
              color: _kLightGray,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // Simplified grouped flashcards
        ...grouped.entries.map((entry) {
          final sourceType = entry.value.first.sourceType ?? 'unknown';
          final flashcardList = entry.value;
          final key = entry.key;

          IconData sourceIcon;
          String sourceName;

          // Get the actual title or fallback to default
          if (_isLoadingTitles || !_sourceTitles.containsKey(key)) {
            // Show default name while loading
            switch (sourceType) {
              case 'summary':
                sourceIcon = Icons.summarize;
                sourceName = 'Summary';
                break;
              case 'note':
                sourceIcon = Icons.note_alt_outlined;
                sourceName = 'Note';
                break;
              case 'transcription':
                sourceIcon = Icons.mic;
                sourceName = 'Transcription';
                break;
              default:
                sourceIcon = Icons.style;
                sourceName = 'Unknown';
            }
          } else {
            // Use the fetched title
            sourceName =
                _sourceTitles[key] ?? _getDefaultSourceName(sourceType);
            switch (sourceType) {
              case 'summary':
                sourceIcon = Icons.summarize;
                break;
              case 'note':
                sourceIcon = Icons.note_alt_outlined;
                break;
              case 'transcription':
                sourceIcon = Icons.mic;
                break;
              default:
                sourceIcon = Icons.style;
            }
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: _kCardColor,
              borderRadius: BorderRadius.circular(20.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _kAccentBlue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          sourceIcon,
                          color: _kAccentBlue,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sourceName,
                              style: const TextStyle(
                                color: _kWhite,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            // Mastery progress
                            Builder(
                              builder: (context) {
                                final knownCount = flashcardList
                                    .where((f) => f.isKnown)
                                    .length;
                                final totalCount = flashcardList.length;
                                final progress = totalCount > 0
                                    ? knownCount / totalCount
                                    : 0.0;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '$knownCount/$totalCount mastered',
                                          style: TextStyle(
                                            color: knownCount == totalCount && totalCount > 0
                                                ? _kAccentBlue
                                                : _kLightGray,
                                            fontSize: 13,
                                            fontWeight: knownCount == totalCount && totalCount > 0
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                        ),
                                        if (knownCount == totalCount && totalCount > 0)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 4),
                                            child: Icon(
                                              Icons.check_circle,
                                              size: 14,
                                              color: _kAccentBlue,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        minHeight: 6,
                                        backgroundColor: _kBackgroundColor,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          progress >= 1.0
                                              ? _kAccentBlue
                                              : _kAccentBlue.withOpacity(0.7),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      // Delete icon button
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: _kAccentCoral,
                        ),
                        onPressed: () {
                          final title = _isLoadingTitles ||
                                  !_sourceTitles.containsKey(key)
                              ? sourceName
                              : _sourceTitles[key] ?? sourceName;
                          _showDeleteConfirmationDialog(
                            context,
                            flashcardList,
                            title,
                          );
                        },
                        tooltip: 'Delete flashcards',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final title = _isLoadingTitles ||
                                    !_sourceTitles.containsKey(key)
                                ? sourceName
                                : _sourceTitles[key] ?? sourceName;
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => FlashcardBrowsePage(
                                  flashcards: flashcardList,
                                  title: title,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.view_list,
                              size: 18, color: _kAccentBlue),
                          label: const Text('Browse',
                              style: TextStyle(color: _kAccentBlue)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: _kAccentBlue, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _showStudySessionDialog(context, flashcardList);
                          },
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: const Text('Study'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kAccentBlue,
                            foregroundColor: _kWhite,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  void _showStudySessionDialog(
    BuildContext context,
    List<Flashcard> flashcards,
  ) {
    bool shuffle = false;
    
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: _kCardColor,
          title: const Text(
            'Start Study Session',
            style: TextStyle(color: _kWhite),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${flashcards.length} flashcards to study',
                style: const TextStyle(color: _kLightGray, fontSize: 16),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Switch(
                    value: shuffle,
                    onChanged: (value) {
                      setDialogState(() {
                        shuffle = value;
                      });
                    },
                    activeColor: _kAccentBlue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Shuffle cards',
                          style: TextStyle(color: _kWhite, fontSize: 16),
                        ),
                        Text(
                          'Randomize the order of flashcards',
                          style: TextStyle(color: _kDarkGray, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel', style: TextStyle(color: _kLightGray)),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FlashcardViewerPage(
                      flashcards: flashcards,
                      shuffle: shuffle,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kAccentBlue,
                foregroundColor: _kWhite,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmationDialog(
    BuildContext context,
    List<Flashcard> flashcards,
    String sourceName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _kCardColor,
        title: const Text(
          'Delete Flashcards',
          style: TextStyle(color: _kWhite),
        ),
        content: Text(
          'Are you sure you want to delete ${flashcards.length} flashcards from $sourceName? This action cannot be undone.',
          style: const TextStyle(color: _kLightGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: _kLightGray)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteFlashcards(context, flashcards);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAccentCoral,
              foregroundColor: _kWhite,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFlashcards(
    BuildContext context,
    List<Flashcard> flashcards,
  ) async {
    final bloc = context.read<StudyModeBloc>();
    final messenger = ScaffoldMessenger.of(context);

    // Show loading indicator
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Deleting ${flashcards.length} flashcards...'),
            ),
          ],
        ),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // Use batch delete event for efficient deletion
    bloc.add(DeleteFlashcardsBatchEvent(
      flashcards.map((f) => f.id).toList(),
    ));

    // Listen for the result
    final subscription = bloc.stream.listen((state) {
      if (state is StudyModeFlashcardsLoaded) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Deleted ${flashcards.length} flashcards'),
            backgroundColor: _kAccentBlue,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (state is StudyModeError) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text(state.message),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    // Cancel subscription after a reasonable timeout
    Future.delayed(const Duration(seconds: 10), () {
      subscription.cancel();
    });
  }
}

class _EmptyStateActionButton extends StatelessWidget {
  const _EmptyStateActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kCardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: _kAccentBlue, size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: _kWhite,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
