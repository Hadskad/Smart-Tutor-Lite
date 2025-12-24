import 'package:hive/hive.dart';

import '../../../../core/errors/failures.dart';
import '../models/flashcard_model.dart';
import '../models/study_session_model.dart';

import 'package:injectable/injectable.dart';

abstract class FlashcardLocalDataSource {
  Future<List<FlashcardModel>> getAllFlashcards();
  Future<List<FlashcardModel>> getFlashcardsBySource({
    required String sourceId,
    required String sourceType,
  });
  Future<FlashcardModel> getFlashcard(String id);
  Future<void> saveFlashcard(FlashcardModel flashcard);
  Future<void> saveFlashcards(List<FlashcardModel> flashcards);
  Future<void> deleteFlashcard(String id);
  Future<void> deleteFlashcards(List<String> ids);

  // Study Session methods
  Future<void> saveStudySession(StudySessionModel session);
  Future<StudySessionModel?> getStudySession(String id);
  Future<List<StudySessionModel>> getAllStudySessions();
  Future<void> deleteStudySession(String id);
}

@LazySingleton(as: FlashcardLocalDataSource)
class FlashcardLocalDataSourceImpl implements FlashcardLocalDataSource {
  FlashcardLocalDataSourceImpl(this.hive);

  static const String _flashcardsBoxName = 'flashcards';
  static const String _sessionsBoxName = 'study_sessions';

  final HiveInterface hive;

  Box<Map>? _flashcardsBox;
  Box<Map>? _sessionsBox;

  Future<Box<Map>> _getFlashcardsBox() async {
    _flashcardsBox ??= await hive.openBox<Map>(_flashcardsBoxName);
    return _flashcardsBox!;
  }

  Future<Box<Map>> _getSessionsBox() async {
    _sessionsBox ??= await hive.openBox<Map>(_sessionsBoxName);
    return _sessionsBox!;
  }

  /// Recursively converts Map<dynamic, dynamic> to Map<String, dynamic>
  Map<String, dynamic> _convertMap(dynamic data) {
    if (data == null) {
      throw CacheFailure(message: 'Data is null');
    }
    
    if (data is! Map) {
      throw CacheFailure(message: 'Data is not a Map: ${data.runtimeType}');
    }

    final result = <String, dynamic>{};
    for (final entry in data.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      
      if (value == null) {
        result[key] = null;
      } else if (value is Map) {
        // Recursively convert nested maps
        result[key] = _convertMap(value);
      } else if (value is List) {
        // Convert lists, handling nested maps in lists
        result[key] = value.map((item) {
          if (item is Map) {
            return _convertMap(item);
          }
          return item;
        }).toList();
      } else {
        result[key] = value;
      }
    }
    return result;
  }

  @override
  Future<List<FlashcardModel>> getAllFlashcards() async {
    try {
      final box = await _getFlashcardsBox();
      if (box.isEmpty) {
        return [];
      }
      final flashcards = box.values
          .map((data) => FlashcardModel.fromJson(_convertMap(data)))
          .toList();
      return flashcards;
    } catch (e) {
      throw CacheFailure(message: 'Failed to get flashcards: ${e.toString()}');
    }
  }

  @override
  Future<List<FlashcardModel>> getFlashcardsBySource({
    required String sourceId,
    required String sourceType,
  }) async {
    try {
      final allFlashcards = await getAllFlashcards();
      return allFlashcards
          .where((fc) => fc.sourceId == sourceId && fc.sourceType == sourceType)
          .toList();
    } catch (e) {
      throw CacheFailure(
          message: 'Failed to get flashcards by source: ${e.toString()}');
    }
  }

  @override
  Future<FlashcardModel> getFlashcard(String id) async {
    try {
      final box = await _getFlashcardsBox();
      final data = box.get(id);
      if (data == null) {
        throw CacheFailure(message: 'Flashcard not found: $id');
      }
      return FlashcardModel.fromJson(_convertMap(data));
    } catch (e) {
      if (e is CacheFailure) rethrow;
      throw CacheFailure(message: 'Failed to get flashcard: ${e.toString()}');
    }
  }

  @override
  Future<void> saveFlashcard(FlashcardModel flashcard) async {
    try {
      final box = await _getFlashcardsBox();
      await box.put(flashcard.id, flashcard.toJson());
    } catch (e) {
      throw CacheFailure(message: 'Failed to save flashcard: ${e.toString()}');
    }
  }

  @override
  Future<void> saveFlashcards(List<FlashcardModel> flashcards) async {
    try {
      final box = await _getFlashcardsBox();
      final Map<String, Map> data = {};
      for (final flashcard in flashcards) {
        data[flashcard.id] = flashcard.toJson();
      }
      await box.putAll(data);
    } catch (e) {
      throw CacheFailure(message: 'Failed to save flashcards: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteFlashcard(String id) async {
    try {
      final box = await _getFlashcardsBox();
      await box.delete(id);
    } catch (e) {
      throw CacheFailure(
          message: 'Failed to delete flashcard: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteFlashcards(List<String> ids) async {
    try {
      final box = await _getFlashcardsBox();
      await box.deleteAll(ids);
    } catch (e) {
      throw CacheFailure(
          message: 'Failed to delete flashcards: ${e.toString()}');
    }
  }

  @override
  Future<void> saveStudySession(StudySessionModel session) async {
    try {
      final box = await _getSessionsBox();
      await box.put(session.id, session.toJson());
    } catch (e) {
      throw CacheFailure(
          message: 'Failed to save study session: ${e.toString()}');
    }
  }

  @override
  Future<StudySessionModel?> getStudySession(String id) async {
    try {
      final box = await _getSessionsBox();
      final data = box.get(id);
      if (data == null) return null;
      return StudySessionModel.fromJson(_convertMap(data));
    } catch (e) {
      throw CacheFailure(
          message: 'Failed to get study session: ${e.toString()}');
    }
  }

  @override
  Future<List<StudySessionModel>> getAllStudySessions() async {
    try {
      final box = await _getSessionsBox();
      if (box.isEmpty) {
        return [];
      }
      final sessions = box.values
          .map((data) => StudySessionModel.fromJson(_convertMap(data)))
          .toList();
      // Sort by start time, most recent first
      sessions.sort((a, b) {
        if (a.startTime == null) return 1;
        if (b.startTime == null) return -1;
        return b.startTime!.compareTo(a.startTime!);
      });
      return sessions;
    } catch (e) {
      throw CacheFailure(
          message: 'Failed to get study sessions: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteStudySession(String id) async {
    try {
      final box = await _getSessionsBox();
      await box.delete(id);
    } catch (e) {
      throw CacheFailure(
          message: 'Failed to delete study session: ${e.toString()}');
    }
  }
}
