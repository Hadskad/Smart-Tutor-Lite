import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Represents the lifecycle state of an audio file.
enum AudioFileState {
  /// File is currently being recorded.
  recording,

  /// Recording complete, waiting to be processed.
  pendingProcess,

  /// File is currently being processed (transcription/upload).
  processing,

  /// Processing complete, file can be safely deleted.
  readyForCleanup,

  /// Processing failed, file retained for potential retry.
  retainedForRetry,
}

/// Metadata about a managed audio file.
class ManagedAudioFile {
  const ManagedAudioFile({
    required this.path,
    required this.state,
    required this.createdAt,
    this.jobId,
    this.noteId,
    this.lastStateChange,
    this.retryCount = 0,
  });

  final String path;
  final AudioFileState state;
  final DateTime createdAt;
  final String? jobId;
  final String? noteId;
  final DateTime? lastStateChange;
  final int retryCount;

  ManagedAudioFile copyWith({
    String? path,
    AudioFileState? state,
    DateTime? createdAt,
    String? jobId,
    String? noteId,
    DateTime? lastStateChange,
    int? retryCount,
  }) {
    return ManagedAudioFile(
      path: path ?? this.path,
      state: state ?? this.state,
      createdAt: createdAt ?? this.createdAt,
      jobId: jobId ?? this.jobId,
      noteId: noteId ?? this.noteId,
      lastStateChange: lastStateChange ?? this.lastStateChange,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'state': state.name,
        'createdAt': createdAt.toIso8601String(),
        'jobId': jobId,
        'noteId': noteId,
        'lastStateChange': lastStateChange?.toIso8601String(),
        'retryCount': retryCount,
      };

  factory ManagedAudioFile.fromJson(Map<String, dynamic> json) {
    return ManagedAudioFile(
      path: json['path'] as String,
      state: AudioFileState.values.firstWhere(
        (e) => e.name == json['state'],
        orElse: () => AudioFileState.pendingProcess,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      jobId: json['jobId'] as String?,
      noteId: json['noteId'] as String?,
      lastStateChange: json['lastStateChange'] != null
          ? DateTime.parse(json['lastStateChange'] as String)
          : null,
      retryCount: json['retryCount'] as int? ?? 0,
    );
  }
}

/// Centralized manager for audio file lifecycle.
///
/// Ensures audio files are only deleted when:
/// - Note generation is complete (`noteStatus == 'ready'`)
/// - User explicitly deletes the note
/// - File is orphaned for more than 24 hours
@lazySingleton
class AudioFileManager {
  AudioFileManager(this._prefs);

  final SharedPreferences _prefs;
  static const _storageKey = 'managed_audio_files';
  static const _orphanThresholdHours = 24;

  final Map<String, ManagedAudioFile> _managedFiles = {};
  bool _initialized = false;

  /// Initialize the manager and load persisted state.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final jsonString = _prefs.getString(_storageKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        for (final json in jsonList) {
          final file = ManagedAudioFile.fromJson(json as Map<String, dynamic>);
          _managedFiles[file.path] = file;
        }
      }
      _initialized = true;
      debugPrint(
          '[AudioFileManager] Initialized with ${_managedFiles.length} managed files');
    } catch (e) {
      debugPrint('[AudioFileManager] Failed to load state: $e');
      _initialized = true;
    }
  }

  /// Register a new audio file being recorded.
  Future<void> registerRecording(String path) async {
    await initialize();
    final now = DateTime.now();
    _managedFiles[path] = ManagedAudioFile(
      path: path,
      state: AudioFileState.recording,
      createdAt: now,
      lastStateChange: now,
    );
    await _persist();
    debugPrint('[AudioFileManager] Registered recording: $path');
  }

  /// Mark recording as complete and pending processing.
  Future<void> markPendingProcess(String path, {String? jobId}) async {
    await initialize();
    final existing = _managedFiles[path];
    if (existing == null) {
      // Auto-register if not tracked
      _managedFiles[path] = ManagedAudioFile(
        path: path,
        state: AudioFileState.pendingProcess,
        createdAt: DateTime.now(),
        jobId: jobId,
        lastStateChange: DateTime.now(),
      );
    } else {
      _managedFiles[path] = existing.copyWith(
        state: AudioFileState.pendingProcess,
        jobId: jobId,
        lastStateChange: DateTime.now(),
      );
    }
    await _persist();
    debugPrint('[AudioFileManager] Marked pending process: $path');
  }

  /// Mark file as currently being processed.
  Future<void> markProcessing(String path, {String? jobId}) async {
    await initialize();
    final existing = _managedFiles[path];
    if (existing != null) {
      _managedFiles[path] = existing.copyWith(
        state: AudioFileState.processing,
        jobId: jobId ?? existing.jobId,
        lastStateChange: DateTime.now(),
      );
      await _persist();
      debugPrint('[AudioFileManager] Marked processing: $path');
    }
  }

  /// Mark file as ready for cleanup (note generation complete).
  Future<void> markReadyForCleanup(String path, {String? noteId}) async {
    await initialize();
    final existing = _managedFiles[path];
    if (existing != null) {
      _managedFiles[path] = existing.copyWith(
        state: AudioFileState.readyForCleanup,
        noteId: noteId ?? existing.noteId,
        lastStateChange: DateTime.now(),
      );
      await _persist();
      debugPrint('[AudioFileManager] Marked ready for cleanup: $path');
    }
  }

  /// Mark file as retained for retry (processing failed).
  Future<void> markRetainedForRetry(String path, {int? incrementRetry}) async {
    await initialize();
    final existing = _managedFiles[path];
    if (existing != null) {
      _managedFiles[path] = existing.copyWith(
        state: AudioFileState.retainedForRetry,
        lastStateChange: DateTime.now(),
        retryCount: incrementRetry != null
            ? existing.retryCount + 1
            : existing.retryCount,
      );
      await _persist();
      debugPrint(
          '[AudioFileManager] Marked retained for retry: $path (count: ${_managedFiles[path]!.retryCount})');
    }
  }

  /// Check if file can be safely deleted.
  bool canDelete(String path) {
    final file = _managedFiles[path];
    if (file == null) return true; // Untracked files can be deleted

    switch (file.state) {
      case AudioFileState.readyForCleanup:
        return true;
      case AudioFileState.recording:
      case AudioFileState.pendingProcess:
      case AudioFileState.processing:
      case AudioFileState.retainedForRetry:
        return false;
    }
  }

  /// Delete file if allowed by lifecycle policy.
  Future<bool> deleteIfAllowed(String path) async {
    await initialize();

    if (!canDelete(path)) {
      debugPrint('[AudioFileManager] Delete not allowed for: $path');
      return false;
    }

    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        debugPrint('[AudioFileManager] Deleted file: $path');
      }
      _managedFiles.remove(path);
      await _persist();
      return true;
    } catch (e) {
      debugPrint('[AudioFileManager] Failed to delete file: $e');
      return false;
    }
  }

  /// Force delete a file (user explicitly deleted note).
  Future<void> forceDelete(String path) async {
    await initialize();
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        debugPrint('[AudioFileManager] Force deleted file: $path');
      }
    } catch (e) {
      debugPrint('[AudioFileManager] Failed to force delete: $e');
    }
    _managedFiles.remove(path);
    await _persist();
  }

  /// Get the state of a managed file.
  AudioFileState? getState(String path) {
    return _managedFiles[path]?.state;
  }

  /// Get managed file info.
  ManagedAudioFile? getFile(String path) {
    return _managedFiles[path];
  }

  /// Clean up orphaned files older than threshold.
  Future<int> cleanupOrphanedFiles() async {
    await initialize();
    final now = DateTime.now();
    final threshold = Duration(hours: _orphanThresholdHours);
    final toRemove = <String>[];
    int cleanedCount = 0;

    for (final entry in _managedFiles.entries) {
      final file = entry.value;
      final age = now.difference(file.createdAt);

      // Check if file is orphaned (old and in a stale state)
      if (age > threshold) {
        final isStale = file.state == AudioFileState.pendingProcess ||
            file.state == AudioFileState.recording ||
            file.state == AudioFileState.readyForCleanup;

        if (isStale) {
          try {
            final diskFile = File(entry.key);
            if (await diskFile.exists()) {
              await diskFile.delete();
              cleanedCount++;
              debugPrint(
                  '[AudioFileManager] Cleaned orphaned file: ${entry.key}');
            }
          } catch (e) {
            debugPrint('[AudioFileManager] Failed to clean orphaned file: $e');
          }
          toRemove.add(entry.key);
        }
      }
    }

    for (final path in toRemove) {
      _managedFiles.remove(path);
    }

    if (toRemove.isNotEmpty) {
      await _persist();
    }

    debugPrint('[AudioFileManager] Cleaned $cleanedCount orphaned files');
    return cleanedCount;
  }

  /// Clean up temp directory of untracked audio files.
  Future<int> cleanupUntrackedTempFiles() async {
    await initialize();
    int cleanedCount = 0;

    try {
      final tempDir = await getTemporaryDirectory();
      final files = tempDir.listSync();
      final now = DateTime.now();
      final threshold = Duration(hours: _orphanThresholdHours);

      for (final entity in files) {
        if (entity is File) {
          final name = entity.path.split('/').last;
          // Check if it's a transcription audio file
          if (name.startsWith('transcription_') &&
              (name.endsWith('.m4a') || name.endsWith('.wav'))) {
            // Check if it's tracked
            if (!_managedFiles.containsKey(entity.path)) {
              // Check file age
              final stat = await entity.stat();
              final age = now.difference(stat.modified);
              if (age > threshold) {
                try {
                  await entity.delete();
                  cleanedCount++;
                  debugPrint(
                      '[AudioFileManager] Cleaned untracked temp file: ${entity.path}');
                } catch (e) {
                  debugPrint(
                      '[AudioFileManager] Failed to clean untracked file: $e');
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[AudioFileManager] Failed to cleanup temp files: $e');
    }

    debugPrint(
        '[AudioFileManager] Cleaned $cleanedCount untracked temp files');
    return cleanedCount;
  }

  /// Run full cleanup (orphaned + untracked).
  Future<int> runFullCleanup() async {
    final orphaned = await cleanupOrphanedFiles();
    final untracked = await cleanupUntrackedTempFiles();
    return orphaned + untracked;
  }

  /// Unregister a file (remove from tracking without deleting).
  Future<void> unregister(String path) async {
    await initialize();
    _managedFiles.remove(path);
    await _persist();
    debugPrint('[AudioFileManager] Unregistered file: $path');
  }

  Future<void> _persist() async {
    try {
      final jsonList =
          _managedFiles.values.map((f) => f.toJson()).toList();
      await _prefs.setString(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('[AudioFileManager] Failed to persist state: $e');
    }
  }
}

