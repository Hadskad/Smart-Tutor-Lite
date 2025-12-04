import 'dart:async';

import 'package:injectable/injectable.dart';

import '../../features/quiz/domain/repositories/quiz_repository.dart';
import '../../features/summarization/domain/repositories/summary_repository.dart';
import '../../features/text_to_speech/domain/repositories/tts_repository.dart';
import '../network/network_info.dart';
import '../utils/logger.dart';

/// Service responsible for processing queued AI tasks when network is available
@LazySingleton()
class QueueSyncService {
  QueueSyncService(
    this._networkInfo,
    this._summaryRepository,
    this._quizRepository,
    this._ttsRepository,
    this._logger,
  );

  final NetworkInfo _networkInfo;
  final SummaryRepository _summaryRepository;
  final QuizRepository _quizRepository;
  final TtsRepository _ttsRepository;
  final AppLogger _logger;

  StreamSubscription<bool>? _networkSubscription;
  bool _isProcessing = false;

  /// Start listening for network changes and process queues when online
  void start() {
    _networkSubscription?.cancel();
    _networkSubscription = _networkInfo.onStatusChange.listen(
      (isConnected) {
        if (isConnected && !_isProcessing) {
          _processAllQueues();
        }
      },
    );

    // Also check immediately if already online
    _networkInfo.isConnected.then((isConnected) {
      if (isConnected && !_isProcessing) {
        _processAllQueues();
      }
    });
  }

  /// Stop listening for network changes
  void stop() {
    _networkSubscription?.cancel();
    _networkSubscription = null;
  }

  /// Manually trigger queue processing
  Future<void> processAllQueues() async {
    await _processAllQueues();
  }

  Future<void> _processAllQueues() async {
    if (_isProcessing) {
      return; // Already processing
    }

    final isConnected = await _networkInfo.isConnected;
    if (!isConnected) {
      return; // Not online
    }

    _isProcessing = true;

    try {
      _logger.info('Starting queue processing...');

      // Process all queues in parallel
      await Future.wait([
        _summaryRepository.processQueuedSummaries(),
        _quizRepository.processQueuedQuizzes(),
        _ttsRepository.processQueuedTtsJobs(),
      ]);

      _logger.info('Queue processing completed');
    } catch (error) {
      _logger.error('Error processing queues: $error');
    } finally {
      _isProcessing = false;
    }
  }

  /// Dispose resources
  void dispose() {
    stop();
  }
}

