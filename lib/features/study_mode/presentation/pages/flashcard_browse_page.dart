import 'package:flutter/material.dart';

import '../../domain/entities/flashcard.dart';
import '../widgets/flip_card_widget.dart';
import 'flashcard_viewer_page.dart';

// Color Palette matching Home Dashboard
const Color _kBackgroundColor = Color(0xFF1E1E1E);
const Color _kCardColor = Color(0xFF333333);
const Color _kAccentBlue = Color(0xFF00BFFF);
const Color _kAccentCoral = Color(0xFFFF7043);
const Color _kWhite = Colors.white;
const Color _kLightGray = Color(0xFFCCCCCC);
const Color _kDarkGray = Color(0xFF888888);

class FlashcardBrowsePage extends StatefulWidget {
  const FlashcardBrowsePage({
    super.key,
    required this.flashcards,
    this.title,
  });

  final List<Flashcard> flashcards;
  final String? title;

  @override
  State<FlashcardBrowsePage> createState() => _FlashcardBrowsePageState();
}

class _FlashcardBrowsePageState extends State<FlashcardBrowsePage> {
  final Set<int> _flippedCards = {};
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.flashcards.isEmpty) {
      return Scaffold(
        backgroundColor: _kBackgroundColor,
        appBar: AppBar(
          backgroundColor: _kBackgroundColor,
          elevation: 0,
          title: Text(
            widget.title ?? 'Browse Flashcards',
            style: const TextStyle(
              color: _kWhite,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          iconTheme: const IconThemeData(color: _kWhite),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.style_outlined,
                size: 64,
                color: _kDarkGray,
              ),
              const SizedBox(height: 16),
              const Text(
                'No flashcards to browse',
                style: TextStyle(
                  color: _kWhite,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _kBackgroundColor,
      appBar: AppBar(
        backgroundColor: _kBackgroundColor,
        elevation: 0,
        title: Text(
          widget.title ?? 'Browse Flashcards',
          style: const TextStyle(
            color: _kWhite,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: _kWhite),
        actions: [
          // Progress indicator
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '${widget.flashcards.length} cards',
                style: const TextStyle(
                  color: _kAccentBlue,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Info banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _kCardColor,
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 20,
                  color: _kAccentBlue,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: const Text(
                    'Tap any card to flip and view the answer',
                    style: TextStyle(
                      color: _kLightGray,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Flashcards list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: widget.flashcards.length,
              itemBuilder: (context, index) {
                final flashcard = widget.flashcards[index];
                final isFlipped = _flippedCards.contains(index);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Card number
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 8),
                        child: Text(
                          'Card ${index + 1} of ${widget.flashcards.length}',
                          style: const TextStyle(
                            color: _kLightGray,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      // Flashcard
                      FlipCardWidget(
                        front: Text(
                          flashcard.front,
                          style: const TextStyle(
                            color: _kWhite,
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        back: Text(
                          flashcard.back,
                          style: const TextStyle(
                            color: _kWhite,
                            fontSize: 16,
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        frontBackgroundColor: _kCardColor,
                        backBackgroundColor: _kCardColor,
                        textColor: _kWhite,
                        isFlipped: isFlipped,
                        height: 250,
                        onTap: () {
                          setState(() {
                            if (isFlipped) {
                              _flippedCards.remove(index);
                            } else {
                              _flippedCards.add(index);
                            }
                          });
                        },
                      ),
                      // Metadata
                      if (flashcard.reviewCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(left: 8, top: 8),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.visibility_outlined,
                                size: 14,
                                color: _kDarkGray,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Reviewed ${flashcard.reviewCount}x',
                                style: const TextStyle(
                                  color: _kDarkGray,
                                  fontSize: 12,
                                ),
                              ),
                              if (flashcard.isKnown) ...[
                                const SizedBox(width: 12),
                                const Icon(
                                  Icons.check_circle,
                                  size: 14,
                                  color: _kAccentBlue,
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'Known',
                                  style: TextStyle(
                                    color: _kAccentBlue,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      // FAB to start study session
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => FlashcardViewerPage(
                flashcards: widget.flashcards,
              ),
            ),
          );
        },
        icon: const Icon(Icons.school),
        label: const Text('Start Study Session'),
        backgroundColor: _kAccentBlue,
        foregroundColor: _kWhite,
      ),
    );
  }
}
