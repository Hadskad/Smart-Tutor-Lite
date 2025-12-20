import 'dart:convert';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../presentation/bloc/queued_transcription_job.dart';

abstract class TranscriptionQueueLocalDataSource {
  Future<List<QueuedTranscriptionJob>> loadQueue();
  Future<void> saveQueue(List<QueuedTranscriptionJob> queue);
}

@LazySingleton(as: TranscriptionQueueLocalDataSource)
class TranscriptionQueueLocalDataSourceImpl
    implements TranscriptionQueueLocalDataSource {
  TranscriptionQueueLocalDataSourceImpl(this._prefs);

  final SharedPreferences _prefs;
  static const _keyQueue = 'transcription_queue';

  @override
  Future<List<QueuedTranscriptionJob>> loadQueue() async {
    final jsonString = _prefs.getString(_keyQueue);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map((json) => _QueuedTranscriptionJobSerializer.fromJson(json))
          .toList();
    } catch (e) {
      // If deserialization fails, return empty queue
      return [];
    }
  }

  @override
  Future<void> saveQueue(List<QueuedTranscriptionJob> queue) async {
    try {
      final jsonList = queue.map((job) => _QueuedTranscriptionJobSerializer.toJson(job)).toList();
      final jsonString = jsonEncode(jsonList);
      await _prefs.setString(_keyQueue, jsonString);
    } catch (e) {
      // Best-effort save - don't throw
    }
  }
}

/// Helper class for serializing/deserializing QueuedTranscriptionJob
class _QueuedTranscriptionJobSerializer {
  static Map<String, dynamic> toJson(QueuedTranscriptionJob job) {
    return {
      'id': job.id,
      'audioPath': job.audioPath,
      'status': job.status.name,
      'errorMessage': job.errorMessage,
      'createdAt': job.createdAt.toIso8601String(),
      'updatedAt': job.updatedAt?.toIso8601String(),
      'noteId': job.noteId,
      'isOnlineMode': job.isOnlineMode,
      'duration': job.duration?.inMilliseconds,
      'fileSizeBytes': job.fileSizeBytes,
    };
  }

  static QueuedTranscriptionJob fromJson(Map<String, dynamic> json) {
    return QueuedTranscriptionJob(
      id: json['id'] as String,
      audioPath: json['audioPath'] as String,
      status: QueuedTranscriptionJobStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => QueuedTranscriptionJobStatus.waiting,
      ),
      errorMessage: json['errorMessage'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      noteId: json['noteId'] as String?,
      isOnlineMode: json['isOnlineMode'] as bool?,
      duration: json['duration'] != null
          ? Duration(milliseconds: json['duration'] as int)
          : null,
      fileSizeBytes: json['fileSizeBytes'] as int?,
    );
  }
}

