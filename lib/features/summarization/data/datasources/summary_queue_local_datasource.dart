import 'package:hive/hive.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failures.dart';
import '../models/summary_queue_model.dart';

abstract class SummaryQueueLocalDataSource {
  Future<void> addToQueue(SummaryQueueModel item);
  Future<List<SummaryQueueModel>> getPendingItems();
  Future<List<SummaryQueueModel>> getAllItems();
  Future<void> markAsProcessing(String id);
  Future<void> markAsCompleted(String id);
  Future<void> markAsFailed(String id, String errorMessage);
  Future<void> removeFromQueue(String id);
  Future<SummaryQueueModel?> getItem(String id);
}

@LazySingleton(as: SummaryQueueLocalDataSource)
class SummaryQueueLocalDataSourceImpl implements SummaryQueueLocalDataSource {
  SummaryQueueLocalDataSourceImpl(this._hive);

  static const String _boxName = 'summary_queue';

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
  Future<void> addToQueue(SummaryQueueModel item) async {
    try {
      final box = await _getBox();
      await box.put(item.id, item.toJson());
    } catch (e) {
      throw CacheFailure(
        message: 'Failed to add summary to queue: ${e.toString()}',
      );
    }
  }

  @override
  Future<List<SummaryQueueModel>> getPendingItems() async {
    try {
      final box = await _getBox();
      final items = box.values
          .map((data) =>
              SummaryQueueModel.fromJson(Map<String, dynamic>.from(data)))
          .where((item) => item.status == 'pending')
          .toList();
      // Sort by createdAt, oldest first
      items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return items;
    } catch (e) {
      throw CacheFailure(
        message: 'Failed to get pending summaries: ${e.toString()}',
      );
    }
  }

  @override
  Future<List<SummaryQueueModel>> getAllItems() async {
    try {
      final box = await _getBox();
      final items = box.values
          .map((data) =>
              SummaryQueueModel.fromJson(Map<String, dynamic>.from(data)))
          .toList();
      // Sort by createdAt, most recent first
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (e) {
      throw CacheFailure(
        message: 'Failed to get all queued summaries: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> markAsProcessing(String id) async {
    try {
      final box = await _getBox();
      final data = box.get(id);
      if (data != null) {
        final item = SummaryQueueModel.fromJson(
          Map<String, dynamic>.from(data),
        );
        final updated = item.copyWith(status: 'processing');
        await box.put(id, updated.toJson());
      }
    } catch (e) {
      throw CacheFailure(
        message: 'Failed to mark summary as processing: ${e.toString()}',
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
        message: 'Failed to mark summary as completed: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> markAsFailed(String id, String errorMessage) async {
    try {
      final box = await _getBox();
      final data = box.get(id);
      if (data != null) {
        final item = SummaryQueueModel.fromJson(
          Map<String, dynamic>.from(data),
        );
        final updated = item.copyWith(
          status: 'failed',
          errorMessage: errorMessage,
          retryCount: item.retryCount + 1,
        );
        await box.put(id, updated.toJson());
      }
    } catch (e) {
      throw CacheFailure(
        message: 'Failed to mark summary as failed: ${e.toString()}',
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
        message: 'Failed to remove summary from queue: ${e.toString()}',
      );
    }
  }

  @override
  Future<SummaryQueueModel?> getItem(String id) async {
    try {
      final box = await _getBox();
      final data = box.get(id);
      if (data == null) return null;
      return SummaryQueueModel.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      throw CacheFailure(
        message: 'Failed to get queued summary: ${e.toString()}',
      );
    }
  }
}
