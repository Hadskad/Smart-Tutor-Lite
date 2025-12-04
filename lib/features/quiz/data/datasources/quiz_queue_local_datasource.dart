import 'package:hive/hive.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../models/quiz_queue_model.dart';

abstract class QuizQueueLocalDataSource {
  Future<void> addToQueue(QuizQueueModel item);
  Future<List<QuizQueueModel>> getPendingItems();
  Future<List<QuizQueueModel>> getAllItems();
  Future<void> markAsProcessing(String id);
  Future<void> markAsCompleted(String id);
  Future<void> markAsFailed(String id, String errorMessage);
  Future<void> removeFromQueue(String id);
  Future<QuizQueueModel?> getItem(String id);
}

@LazySingleton(as: QuizQueueLocalDataSource)
class QuizQueueLocalDataSourceImpl implements QuizQueueLocalDataSource {
  QuizQueueLocalDataSourceImpl(this._hive);

  static const String _boxName = 'quiz_queue';

  final HiveInterface _hive;
  Box<Map>? _box;

  Future<Box<Map>> _getBox() async {
    if (_box?.isOpen ?? false) {
      return _box!;
    }
    _box = await _hive.openBox<Map>(_boxName);
    return _box!;
  }

  @override
  Future<void> addToQueue(QuizQueueModel item) async {
    try {
      final box = await _getBox();
      await box.put(item.id, item.toJson());
    } catch (e) {
      throw CacheFailure(
        message: 'Failed to add quiz to queue: ${e.toString()}',
      );
    }
  }

  @override
  Future<List<QuizQueueModel>> getPendingItems() async {
    try {
      final box = await _getBox();
      final items = box.values
          .map((data) =>
              QuizQueueModel.fromJson(Map<String, dynamic>.from(data)))
          .where((item) => item.status == 'pending')
          .toList();
      // Sort by createdAt, oldest first
      items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return items;
    } catch (e) {
      throw CacheFailure(
        message: 'Failed to get pending quizzes: ${e.toString()}',
      );
    }
  }

  @override
  Future<List<QuizQueueModel>> getAllItems() async {
    try {
      final box = await _getBox();
      final items = box.values
          .map((data) =>
              QuizQueueModel.fromJson(Map<String, dynamic>.from(data)))
          .toList();
      // Sort by createdAt, most recent first
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (e) {
      throw CacheFailure(
        message: 'Failed to get all queued quizzes: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> markAsProcessing(String id) async {
    try {
      final box = await _getBox();
      final data = box.get(id);
      if (data != null) {
        final item = QuizQueueModel.fromJson(Map<String, dynamic>.from(data));
        final updated = item.copyWith(status: 'processing');
        await box.put(id, updated.toJson());
      }
    } catch (e) {
      throw CacheFailure(
        message: 'Failed to mark quiz as processing: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> markAsCompleted(String id) async {
    try {
      final box = await _getBox();
      await box.delete(id); // Remove from queue when completed
    } catch (e) {
      throw CacheFailure(
        message: 'Failed to mark quiz as completed: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> markAsFailed(String id, String errorMessage) async {
    try {
      final box = await _getBox();
      final data = box.get(id);
      if (data != null) {
        final item = QuizQueueModel.fromJson(Map<String, dynamic>.from(data));
        final updated = item.copyWith(
          status: 'failed',
          errorMessage: errorMessage,
          retryCount: item.retryCount + 1,
        );
        await box.put(id, updated.toJson());
      }
    } catch (e) {
      throw CacheFailure(
        message: 'Failed to mark quiz as failed: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> removeFromQueue(String id) async {
    try {
      final box = await _getBox();
      await box.delete(id);
    } catch (e) {
      throw CacheFailure(
        message: 'Failed to remove quiz from queue: ${e.toString()}',
      );
    }
  }

  @override
  Future<QuizQueueModel?> getItem(String id) async {
    try {
      final box = await _getBox();
      final data = box.get(id);
      if (data == null) return null;
      return QuizQueueModel.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      throw CacheFailure(
        message: 'Failed to get queued quiz: ${e.toString()}',
      );
    }
  }
}

