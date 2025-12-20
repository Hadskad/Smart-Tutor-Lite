import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import '../bloc/queued_transcription_job.dart';

const Color _kCardColor = Color(0xFF333333);
const Color _kAccentBlue = Color(0xFF00BFFF);
const Color _kAccentCoral = Color(0xFFFF7043);
const Color _kWhite = Colors.white;
const Color _kDarkGray = Color(0xFF888888);
const Color _kYellow = Color(0xFFFFB74D);

class QueuedJobCard extends StatelessWidget {
  const QueuedJobCard({
    super.key,
    required this.job,
    this.onCancel,
    this.onRetry,
    this.onViewNote,
  });

  final QueuedTranscriptionJob job;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final VoidCallback? onViewNote;

  @override
  Widget build(BuildContext context) {
    final statusInfo = _getStatusInfo(job.status);
    // Derive job label from filename, recording time, or user-facing title
    final fileName = p.basename(job.audioPath);
    // Remove extension and format as user-friendly label
    final jobLabel = _formatJobLabel(fileName, job.createdAt);

    return Container(
      decoration: BoxDecoration(
        color: _kCardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusInfo.color.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            statusInfo.icon,
                            size: 18,
                            color: statusInfo.color,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              jobLabel.length > 50
                                  ? '${jobLabel.substring(0, 50)}...'
                                  : jobLabel,
                              style: const TextStyle(
                                color: _kWhite,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Status chip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusInfo.color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: statusInfo.color.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (job.status == QueuedTranscriptionJobStatus.processing)
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    statusInfo.color,
                                  ),
                                ),
                              )
                            else
                              Icon(
                                statusInfo.icon,
                                size: 12,
                                color: statusInfo.color,
                              ),
                            const SizedBox(width: 6),
                            Text(
                              statusInfo.label,
                              style: TextStyle(
                                color: statusInfo.color,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  DateFormat.yMMMd().add_Hm().format(job.createdAt),
                  style: const TextStyle(
                    color: _kDarkGray,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (job.errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _kAccentCoral.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _kAccentCoral.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 16,
                      color: _kAccentCoral,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        job.errorMessage!,
                        style: const TextStyle(
                          color: _kAccentCoral,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: _kDarkGray.withOpacity(0.3),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (job.status == QueuedTranscriptionJobStatus.waiting &&
                    onCancel != null)
                  Flexible(
                    child: TextButton.icon(
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Cancel'),
                      onPressed: onCancel,
                      style: TextButton.styleFrom(
                        foregroundColor: _kDarkGray,
                      ),
                    ),
                  )
                else if (job.status == QueuedTranscriptionJobStatus.failed) ...[
                  if (onRetry != null)
                    Flexible(
                      child: TextButton.icon(
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Retry'),
                        onPressed: onRetry,
                        style: TextButton.styleFrom(
                          foregroundColor: _kAccentBlue,
                        ),
                      ),
                    ),
                  if (onCancel != null)
                    Flexible(
                      child: TextButton.icon(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Remove'),
                        onPressed: onCancel,
                        style: TextButton.styleFrom(
                          foregroundColor: _kAccentCoral,
                        ),
                      ),
                    ),
                ],
                if (job.status == QueuedTranscriptionJobStatus.success &&
                    job.noteId != null) ...[
                  if (onViewNote != null)
                    Flexible(
                      child: TextButton.icon(
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: const Text('View Note'),
                        onPressed: onViewNote,
                        style: TextButton.styleFrom(
                          foregroundColor: _kAccentBlue,
                        ),
                      ),
                    ),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _kAccentBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: _kAccentBlue,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Completed',
                            style: TextStyle(
                              color: _kAccentBlue,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatJobLabel(String fileName, DateTime createdAt) {
    // Remove file extension
    final nameWithoutExt = fileName.replaceAll(RegExp(r'\.[^.]+$'), '');
    // If it's a UUID-like name, use recording time instead
    if (nameWithoutExt.startsWith('transcription_') &&
        nameWithoutExt.length > 20) {
      // Format as "Recording from [time]"
      final timeFormat = DateFormat('MMM d, h:mm a');
      return 'Recording from ${timeFormat.format(createdAt)}';
    }
    // Otherwise use filename (cleaned up)
    return nameWithoutExt.replaceAll('_', ' ').replaceAll('-', ' ');
  }

  _StatusInfo _getStatusInfo(QueuedTranscriptionJobStatus status) {
    switch (status) {
      case QueuedTranscriptionJobStatus.waiting:
        return _StatusInfo(
          label: 'Waiting to be processed',
          icon: Icons.schedule,
          color: _kYellow,
        );
      case QueuedTranscriptionJobStatus.processing:
        return _StatusInfo(
          label: 'Processing...',
          icon: Icons.cloud_upload_rounded,
          color: _kAccentBlue,
        );
      case QueuedTranscriptionJobStatus.success:
        return _StatusInfo(
          label: 'Completed',
          icon: Icons.check_circle,
          color: _kAccentBlue,
        );
      case QueuedTranscriptionJobStatus.failed:
        return _StatusInfo(
          label: 'Failed',
          icon: Icons.error_outline,
          color: _kAccentCoral,
        );
    }
  }
}

class _StatusInfo {
  const _StatusInfo({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

