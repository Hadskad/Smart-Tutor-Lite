import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:characters/characters.dart';
import '../../domain/entities/transcription.dart';

const Color _kCardColor = Color(0xFF333333);
const Color _kAccentBlue = Color(0xFF00BFFF);
const Color _kAccentCoral = Color(0xFFFF7043);
const Color _kWhite = Colors.white;
const Color _kLightGray = Color(0xFFCCCCCC);
const Color _kDarkGray = Color(0xFF888888);

class NoteListCard extends StatelessWidget {
  const NoteListCard({
    super.key,
    required this.transcription,
    this.onTap,
    this.onEditTitle,
    this.onDelete,
    this.onCreateFlashcards,
    this.onRetry,
    this.showActions = true,
  });

  final Transcription transcription;
  final VoidCallback? onTap;
  final VoidCallback? onEditTitle;
  final VoidCallback? onDelete;
  final VoidCallback? onCreateFlashcards;
  final VoidCallback? onRetry;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    final isFailed = transcription.isFailed;
    final rawText = transcription.text ?? '';
    final baseTitle = transcription.title ?? rawText;

    final title = isFailed
        ? 'Failed note generation'
        : (baseTitle.characters.length > 50
            ? '${baseTitle.characters.take(50)}...'
            : baseTitle);

    final previewText = isFailed ? '' : rawText;

    return Container(
      decoration: BoxDecoration(
        color: _kCardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: isFailed ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: _kWhite,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (!isFailed && onEditTitle != null)
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            color: _kDarkGray,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: onEditTitle,
                          ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat.yMMMd().format(transcription.timestamp),
                    style: const TextStyle(
                      color: _kDarkGray,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (previewText.isNotEmpty)
                Text(
                  previewText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _kLightGray,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              if (showActions) ...[
                const SizedBox(height: 16),
                Divider(
                  height: 1,
                  color: _kDarkGray.withOpacity(0.3),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (isFailed && onRetry != null)
                      Flexible(
                        child: TextButton.icon(
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Retry'),
                          onPressed: onRetry,
                          style: TextButton.styleFrom(
                            foregroundColor: _kAccentCoral,
                          ),
                        ),
                      )
                    else ...[
                      if (onDelete != null)
                        Flexible(
                          child: TextButton.icon(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Delete Note'),
                            onPressed: onDelete,
                            style: TextButton.styleFrom(
                              foregroundColor: _kAccentCoral,
                            ),
                          ),
                        ),
                      if (!isFailed && onCreateFlashcards != null)
                        Flexible(
                          child: TextButton.icon(
                            icon: const Icon(Icons.style_outlined, size: 15),
                            label: const Text('Create Flashcards'),
                            onPressed: onCreateFlashcards,
                            style: TextButton.styleFrom(
                              foregroundColor: _kAccentBlue,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
