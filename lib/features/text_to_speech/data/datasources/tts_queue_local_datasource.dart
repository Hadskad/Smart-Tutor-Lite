import 'package:hive/hive.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../models/tts_queue_model.dart';

abstract class TtsQueueLocalDataSource {
  Future<void> addToQueue(TtsQueueModel item);
  Future<List<TtsQueueModel>> getPendingItems();
  Future<List<TtsQueueModel>> getAllItems();
  Future<void> markAsProcessing(String id);
  Future<void> markAsCompleted(String id);
  Future<void> markAsFailed(String id, String errorMessage);
  Future<void> removeFromQueue(String id);
  Future<TtsQueueModel?> getItem(String id);
}

@LazySingleton(as: TtsQueueLocalDataSource)
class TtsQueueLocalDataSourceImpl implements TtsQueueLocalDataSource {
  TtsQueueLocalDataSourceImpl(this._hive);

  static const String _boxName = 'tts_queue';

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
  Future<void> addToQueue(TtsQueueModel item) async {
    try {
      final box = await _getBox();
      await box.put(item.id, item.toJson());
    } catch (e) {
      throw CacheFailure(
        message: 'Failed to add TTS job to queue: ${e.toString()}',
      );
    }
  }

  @override
  Future<List<TtsQueueModel>> getPendingItems() async {
    try {
      final box = await _getBox();
      final items = box.values
          .map((data) =>
              TtsQueueModel.fromJson(Map<String, dynamic>.from(data)))
          .where((item) => item.status == 'pending')
          .toList();
      // Sort by createdAt, oldest first
      items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return items;
    } catch (e) {
      throw CacheFailure(
        message: 'Failed to get pending TTS jobs: ${e.toString()}',
      );
    }
  }

  @override
  Future<List<TtsQueueModel>> getAllItems() async {
    try {
      final box = await _getBox();
      final items = box.values
          .map((data) =>
              TtsQueueModel.fromJson(Map<String, dynamic>.from(data)))
          .toList();
      // Sort by createdAt, most recent first
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (e) {
      throw CacheFailure(
        message: 'Failed to get all queued TTS jobs: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> markAsProcessing(String id) async {
    try {
      final box = await _getBox();
      final data = box.get(id);
      if (data != null) {
        final item = TtsQueueModel.fromJson(Map<String, dynamic>.from(data));
        final updated = item.copyWith(status: 'processing');
        await box.put(id, updated.toJson());
      }
    } catch (e) {
      throw CacheFailure(
        message: 'Failed to mark TTS job as processing: ${e.toString()}',
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
        message: 'Failed to mark TTS job as completed: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> markAsFailed(String id, String errorMessage) async {
    try {
      final box = await _getBox();
      final data = box.get(id);
      if (data != null) {
        final item = TtsQueueModel.fromJson(Map<String, dynamic>.from(data));
        final updated = item.copyWith(
          status: 'failed',
          errorMessage: errorMessage,
          retryCount: item.retryCount + 1,
        );
        await box.put(id, updated.toJson());
      }
    } catch (e) {
      throw CacheFailure(
        message: 'Failed to mark TTS job as failed: ${e.toString()}',
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
        message: 'Failed to remove TTS job from queue: ${e.toString()}',
      );
    }
  }

  @override
  Future<TtsQueueModel?> getItem(String id) async {
    try {
      final box = await _getBox();
      final data = box.get(id);
      if (data == null) return null;
      return TtsQueueModel.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      throw CacheFailure(
        message: 'Failed to get queued TTS job: ${e.toString()}',
      );
    }
  }
}

