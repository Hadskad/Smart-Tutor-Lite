import 'package:flutter_test/flutter_test.dart';
import 'package:smart_tutor_lite/features/transcription/presentation/bloc/queued_transcription_job.dart';

void main() {
  group('QueuedTranscriptionJob', () {
    test('creates job with all required fields', () {
      final job = QueuedTranscriptionJob(
        id: 'test-id',
        audioPath: '/path/to/audio.m4a',
        status: QueuedTranscriptionJobStatus.waiting,
        createdAt: DateTime(2024, 1, 1),
      );

      expect(job.id, 'test-id');
      expect(job.audioPath, '/path/to/audio.m4a');
      expect(job.status, QueuedTranscriptionJobStatus.waiting);
      expect(job.createdAt, DateTime(2024, 1, 1));
    });

    test('copyWith updates fields correctly', () {
      final original = QueuedTranscriptionJob(
        id: 'test-id',
        audioPath: '/path/to/audio.m4a',
        status: QueuedTranscriptionJobStatus.waiting,
        createdAt: DateTime(2024, 1, 1),
        errorMessage: null,
      );

      final updated = original.copyWith(
        status: QueuedTranscriptionJobStatus.processing,
        updatedAt: DateTime(2024, 1, 2),
      );

      expect(updated.id, 'test-id');
      expect(updated.status, QueuedTranscriptionJobStatus.processing);
      expect(updated.updatedAt, DateTime(2024, 1, 2));
      expect(updated.errorMessage, isNull);
    });

    test('equality works correctly', () {
      final job1 = QueuedTranscriptionJob(
        id: 'test-id',
        audioPath: '/path/to/audio.m4a',
        status: QueuedTranscriptionJobStatus.waiting,
        createdAt: DateTime(2024, 1, 1),
      );

      final job2 = QueuedTranscriptionJob(
        id: 'test-id',
        audioPath: '/path/to/audio.m4a',
        status: QueuedTranscriptionJobStatus.waiting,
        createdAt: DateTime(2024, 1, 1),
      );

      expect(job1, equals(job2));
    });

    test('handles optional fields', () {
      final job = QueuedTranscriptionJob(
        id: 'test-id',
        audioPath: '/path/to/audio.m4a',
        status: QueuedTranscriptionJobStatus.failed,
        createdAt: DateTime(2024, 1, 1),
        errorMessage: 'Test error',
        noteId: 'note-123',
        isOnlineMode: true,
        duration: const Duration(seconds: 30),
        fileSizeBytes: 100000,
      );

      expect(job.errorMessage, 'Test error');
      expect(job.noteId, 'note-123');
      expect(job.isOnlineMode, true);
      expect(job.duration, const Duration(seconds: 30));
      expect(job.fileSizeBytes, 100000);
    });
  });

  group('QueuedTranscriptionJobStatus', () {
    test('has all required status values', () {
      expect(QueuedTranscriptionJobStatus.values.length, 4);
      expect(QueuedTranscriptionJobStatus.values,
          contains(QueuedTranscriptionJobStatus.waiting));
      expect(QueuedTranscriptionJobStatus.values,
          contains(QueuedTranscriptionJobStatus.processing));
      expect(QueuedTranscriptionJobStatus.values,
          contains(QueuedTranscriptionJobStatus.success));
      expect(QueuedTranscriptionJobStatus.values,
          contains(QueuedTranscriptionJobStatus.failed));
    });
  });
}

