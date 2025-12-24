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
const Color _kYellow = Color(0xFFFFB74D);

class NoteListCard extends StatelessWidget {
  const NoteListCard({
    super.key,
    required this.transcription,
    this.onTap,
    this.onEditTitle,
    this.onDelete,
    this.onCreateFlashcards,
    this.onRetry,
    this.onFormatNote,
    this.showActions = true,
    this.isFormatting = false,
  });

  final Transcription transcription;
  final VoidCallback? onTap;
  final VoidCallback? onEditTitle;
  final VoidCallback? onDelete;
  final VoidCallback? onCreateFlashcards;
  final VoidCallback? onRetry;
  final VoidCallback? onFormatNote;
  final bool showActions;
  final bool isFormatting;

  @override
  Widget build(BuildContext context) {
    final isFailed = transcription.isFailed;
    final rawText = transcription.text ?? '';
    final baseTitle = transcription.title ?? rawText;
    final isNoSpeechDetected =
        transcription.metadata['no_speech_detected'] == true;
    final isUnformatted =
        !isFailed && transcription.structuredNote == null && rawText.isNotEmpty;

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
              if (isNoSpeechDetected) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kAccentCoral.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kAccentCoral.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 14,
                        color: _kAccentCoral,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'No speech detected',
                        style: TextStyle(
                          color: _kAccentCoral,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // Show unformatted badge for offline notes
              if (isUnformatted && !isNoSpeechDetected) ...[
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kYellow.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _kYellow.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 14,
                        color: _kYellow,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Raw note - tap to format',
                        style: TextStyle(
                          color: _kYellow,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (previewText.isNotEmpty && !isNoSpeechDetected)
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
                      // Show Format button for unformatted notes
                      if (isUnformatted && onFormatNote != null)
                        Flexible(
                          child: TextButton.icon(
                            icon: isFormatting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _kYellow,
                                    ),
                                  )
                                : const Icon(Icons.auto_awesome, size: 15),
                            label: Text(isFormatting ? 'Formatting...' : 'Format'),
                            onPressed: isFormatting ? null : onFormatNote,
                            style: TextButton.styleFrom(
                              foregroundColor: _kYellow,
                              disabledForegroundColor: _kYellow.withOpacity(0.5),
                            ),
                          ),
                        )
                      // Show Create Flashcards for formatted notes
                      else if (!isFailed && onCreateFlashcards != null)
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
