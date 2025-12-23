import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../native_bridge/performance_bridge.dart';
import '../../domain/entities/transcription.dart';
import '../../domain/entities/transcription_job.dart';
import '../../domain/entities/transcription_job_request.dart';
import '../../domain/entities/transcription_preferences.dart';
import '../../domain/repositories/transcription_preferences_repository.dart';
import '../../domain/repositories/transcription_repository.dart';
import '../../data/datasources/transcription_queue_local_data_source.dart';
import '../../domain/usecases/cancel_transcription_job.dart';
import '../../domain/usecases/create_transcription_job.dart';
import '../../domain/usecases/request_transcription_job_retry.dart';
import '../../domain/usecases/request_note_retry.dart';
import '../../domain/usecases/transcribe_audio.dart' as usecase;
import '../../domain/usecases/watch_transcription_job.dart';
import 'transcription_event.dart';
import 'transcription_state.dart';
import 'queued_transcription_job.dart';

const _kRecordingBitrate = 64000; // bits per second (~64 kbps AAC)
const _kMinRecordingDuration = Duration(seconds: 3);
const _kMinRecordingSizeBytes = 16 * 1024; // 16 KB guard against silence
const _kExtremeRecordingDuration = Duration(hours: 4);
const _kExtremeRecordingSizeBytes = 1024 * 1024 * 1024; // 1 GB
const _kSilenceThresholdDb = -45.0;
const _kSilenceTickTrigger = 6; // 3s at 500ms interval
const _kAmplitudeSampleInterval = Duration(milliseconds: 500);
const _kMaxQueueSize = 10; // Maximum number of queued transcription jobs

enum TranscriptionExecutionMode { online, offline }

/// Represents a queued audio file waiting to be processed
class QueuedAudio {
  const QueuedAudio({
    required this.audioPath,
    required this.duration,
    required this.fileSizeBytes,
    required this.plannedExecutionMode,
    required this.timestamp,
  });

  final String audioPath;
  final Duration duration;
  final int fileSizeBytes;
  final TranscriptionExecutionMode plannedExecutionMode;
  final DateTime timestamp;
}

@lazySingleton
class TranscriptionBloc extends Bloc<TranscriptionEvent, TranscriptionState>
    with WidgetsBindingObserver {
  TranscriptionBloc(
    this._transcribeAudio,
    this._performanceBridge,
    this._transcriptionRepository,
    this._networkInfo,
    this._createTranscriptionJob,
    this._watchTranscriptionJob,
    this._cancelTranscriptionJob,
    this._requestTranscriptionJobRetry,
    this._requestNoteRetry,
    this._preferencesRepository,
    this._queueLocalDataSource,
  ) : super(const TranscriptionInitial()) {
    on<LoadTranscriptions>(_onLoad);
    on<LoadTranscriptionPreferences>(_onLoadPreferences);
    on<ToggleOfflinePreference>(_onToggleOfflinePreference);
    on<ToggleFastWhisperModel>(_onToggleFastWhisperModel);
    on<StartRecording>(_onStartRecording);
    on<StopRecording>(_onStopRecording);
    on<TranscribeAudio>(_onTranscribeAudio);
    on<RecordingMetricsUpdated>(_onRecordingMetricsUpdated);
    on<TranscriptionJobSnapshotReceived>(_onTranscriptionJobSnapshot);
    on<CancelCloudTranscription>(_onCancelCloudTranscription);
    on<RetryCloudTranscription>(_onRetryCloudTranscription);
    on<RetryNoteGeneration>(_onRetryNoteGeneration);
    on<ConfirmOfflineFallback>(_onConfirmOfflineFallback);
    on<RetryCloudFromFallback>(_onRetryCloudFromFallback);
    on<DeleteTranscription>(_onDeleteTranscription);
    on<UpdateTranscription>(_onUpdateTranscription);
    on<FormatTranscriptionNote>(_onFormatTranscriptionNote);
    on<RetryFormatNote>(_onRetryFormatNote);
    on<RetryFailedTranscription>(_onRetryFailedTranscription);
    on<QueueJobAdded>(_onQueueJobAdded);
    on<QueueJobProcessingStarted>(_onQueueJobProcessingStarted);
    on<QueueJobSucceeded>(_onQueueJobSucceeded);
    on<QueueJobFailed>(_onQueueJobFailed);
    on<QueueJobCancelled>(_onQueueJobCancelled);
    on<QueueJobRetried>(_onQueueJobRetried);
    on<LoadQueue>(_onLoadQueue);
    on<ResumeProcessingAfterPause>(_onResumeProcessingAfterPause);

    add(const LoadTranscriptionPreferences());
    add(const LoadQueue());

    // Add lifecycle observer
    WidgetsBinding.instance.addObserver(this);
  }

  final usecase.TranscribeAudio _transcribeAudio;
  final PerformanceBridge _performanceBridge;
  final TranscriptionRepository _transcriptionRepository;
  final NetworkInfo _networkInfo;
  final CreateTranscriptionJob _createTranscriptionJob;
  final WatchTranscriptionJob _watchTranscriptionJob;
  final CancelTranscriptionJob _cancelTranscriptionJob;
  final RequestTranscriptionJobRetry _requestTranscriptionJobRetry;
  final RequestNoteRetry _requestNoteRetry;
  final TranscriptionPreferencesRepository _preferencesRepository;
  final TranscriptionQueueLocalDataSource _queueLocalDataSource;
  final AudioRecorder _recorder = AudioRecorder();
  final Uuid _uuid = const Uuid();
  String? _currentRecordingPath;
  String? _lastRecordedFilePath;
  DateTime? _recordingStartedAt;
  final List<Transcription> _history = <Transcription>[];
  final Queue<QueuedAudio> _processingQueue = Queue<QueuedAudio>();
  Timer? _recordingTicker;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  StreamSubscription<Either<Failure, TranscriptionJob>>? _cloudJobSubscription;
  String? _activeCloudJobId;
  TranscriptionPreferences _preferences = const TranscriptionPreferences();
  TranscriptionExecutionMode _plannedExecutionMode =
      TranscriptionExecutionMode.online;
  bool _isInputTooLow = false;
  int _silenceTicks = 0;
  String? _pendingFallbackAudioPath;
  Duration? _pendingFallbackDuration;
  int? _pendingFallbackSizeBytes;
  String? _lastCloudFailureMessage;
  double? _lastMeasuredSpeedKbps;
  Timer? _speedTestTimer;
  bool _isSpeedTestRunning = false;
  DateTime? _lastSpeedUpdate;
  bool _shouldMonitorSpeed = false; // Track if monitoring should be active

  Future<void> _onLoad(
    LoadTranscriptions event,
    Emitter<TranscriptionState> emit,
  ) async {
    try {
      final result = await _transcriptionRepository.getAllTranscriptions();
      result.fold(
        (failure) => emit(
          TranscriptionError(
            message: failure.message ??
                'Failed to load transcriptions from storage. Please check your connection and try again.',
            history: List.unmodifiable(_history),
            preferences: _preferences,
            queueLength: state.queue.length,
            queue: state.queue,
          ),
        ),
        (transcriptions) {
          _history
            ..clear()
            ..addAll(transcriptions);
          emit(
            TranscriptionInitial(
              history: List.unmodifiable(_history),
              preferences: _preferences,
              queueLength: state.queue.length,
              queue: state.queue,
            ),
          );
        },
      );
    } catch (error) {
      emit(
        TranscriptionError(
          message:
              'Failed to load transcriptions: ${error.toString()}. Please try again.',
          history: List.unmodifiable(_history),
          preferences: _preferences,
          queueLength: state.queue.length,
          queue: state.queue,
        ),
      );
    }
  }

  RecordConfig _buildRecordConfig(TranscriptionExecutionMode mode) {
    if (mode == TranscriptionExecutionMode.offline) {
      return const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 256000,
      );
    }
    return const RecordConfig(
      encoder: AudioEncoder.aacLc,
      sampleRate: 44100,
      numChannels: 1,
      bitRate: _kRecordingBitrate,
    );
  }

  TranscriptionExecutionMode _resolveExecutionMode({
    required bool hasNetwork,
    required ConnectivityResult connectionType,
  }) {
    if (_preferences.alwaysUseOffline || !hasNetwork) {
      return TranscriptionExecutionMode.offline;
    }
    if (!_isStrongConnection(connectionType)) {
      return TranscriptionExecutionMode.offline;
    }
    return TranscriptionExecutionMode.online;
  }

  Future<void> _onLoadPreferences(
    LoadTranscriptionPreferences event,
    Emitter<TranscriptionState> emit,
  ) async {
    _preferences = await _preferencesRepository.loadPreferences();
    _emitSnapshot(emit);
  }

  Future<void> _onLoadQueue(
    LoadQueue event,
    Emitter<TranscriptionState> emit,
  ) async {
    try {
      final savedQueue = await _queueLocalDataSource.loadQueue();

      // Validate and filter queue: check file existence and mark missing files as failed
      final validatedQueue = <QueuedTranscriptionJob>[];
      for (final job in savedQueue) {
        // Skip completed jobs - they should be in history
        if (job.status == QueuedTranscriptionJobStatus.success) {
          continue;
        }

        // Check if file exists
        final file = File(job.audioPath);
        if (await file.exists()) {
          // Reset processing jobs to waiting (they were interrupted)
          if (job.status == QueuedTranscriptionJobStatus.processing) {
            validatedQueue.add(
              job.copyWith(
                status: QueuedTranscriptionJobStatus.waiting,
                updatedAt: DateTime.now(),
              ),
            );
          } else {
            validatedQueue.add(job);
          }
        } else {
          // File missing - mark as failed
          validatedQueue.add(
            job.copyWith(
              status: QueuedTranscriptionJobStatus.failed,
              errorMessage: 'Source audio file missing',
              updatedAt: DateTime.now(),
            ),
          );
        }
      }

      // Update state with loaded queue
      if (validatedQueue.isNotEmpty) {
        _emitStateWithUpdatedQueue(emit, validatedQueue);
        // Save validated queue back
        await _queueLocalDataSource.saveQueue(validatedQueue);

        // Try to process next job if queue has waiting jobs
        await _processNextQueuedJob(emit);
      }
    } catch (e) {
      debugPrint('[Queue] Failed to load queue: $e');
      // Continue with empty queue on error
    }
  }

  Future<void> _onToggleOfflinePreference(
    ToggleOfflinePreference event,
    Emitter<TranscriptionState> emit,
  ) async {
    _preferences = await _preferencesRepository
        .setAlwaysUseOffline(event.alwaysUseOffline);
    _emitSnapshot(emit);
  }

  Future<void> _onToggleFastWhisperModel(
    ToggleFastWhisperModel event,
    Emitter<TranscriptionState> emit,
  ) async {
    _preferences =
        await _preferencesRepository.setUseFastWhisperModel(event.useFastModel);
    _emitSnapshot(emit);
  }

  void _onConfirmOfflineFallback(
    ConfirmOfflineFallback event,
    Emitter<TranscriptionState> emit,
  ) {
    final audioPath = _pendingFallbackAudioPath;
    if (audioPath == null) {
      _emitNotice(
        emit,
        'Original recording is no longer available for offline mode.',
        severity: TranscriptionNoticeSeverity.warning,
      );
      return;
    }
    _plannedExecutionMode = TranscriptionExecutionMode.offline;
    _startOfflineTranscription(audioPath);
  }

  Future<void> _onRetryCloudFromFallback(
    RetryCloudFromFallback event,
    Emitter<TranscriptionState> emit,
  ) async {
    final audioPath = _pendingFallbackAudioPath;
    final duration = _pendingFallbackDuration;
    final size = _pendingFallbackSizeBytes;
    if (audioPath == null || duration == null || size == null) {
      _emitNotice(
        emit,
        'Original recording is no longer available for retry.',
        severity: TranscriptionNoticeSeverity.warning,
      );
      return;
    }
    final hasNetwork = await _networkInfo.isConnected;
    if (!hasNetwork) {
      _emitNotice(
        emit,
        'No internet connection detected. Unable to retry cloud transcription.',
        severity: TranscriptionNoticeSeverity.warning,
      );
      return;
    }
    final started = await _startCloudTranscriptionJob(
      audioPath: audioPath,
      duration: duration,
      fileSizeBytes: size,
      emit: emit,
    );
    if (!started) {
      _promptOfflineFallback(
        emit,
        reason: _lastCloudFailureMessage ??
            'Cloud transcription is still unavailable. Switch to on-device mode?',
      );
    }
  }

  void _emitSnapshot(Emitter<TranscriptionState> emit) {
    final current = state;
    final queueLen = current.queue.length;
    if (current is TranscriptionRecording) {
      emit(
        current.copyWith(
          history: current.history,
          preferences: _preferences,
          queueLength: queueLen,
          queue: current.queue,
        ),
      );
    } else if (current is TranscriptionStopping) {
      emit(
        TranscriptionStopping(
          history: current.history,
          preferences: _preferences,
          queueLength: queueLen,
          queue: current.queue,
        ),
      );
    } else if (current is TranscriptionProcessing) {
      emit(
        TranscriptionProcessing(
          audioPath: current.audioPath,
          history: current.history,
          preferences: _preferences,
          queueLength: queueLen,
          queue: current.queue,
        ),
      );
    } else if (current is TranscriptionSuccess) {
      emit(
        TranscriptionSuccess(
          transcription: current.transcription,
          metrics: current.metrics,
          history: current.history,
          preferences: _preferences,
          queueLength: queueLen,
          queue: current.queue,
        ),
      );
    } else if (current is TranscriptionError) {
      emit(
        TranscriptionError(
          message: current.message,
          history: current.history,
          preferences: _preferences,
          queueLength: queueLen,
          queue: current.queue,
        ),
      );
    } else if (current is CloudTranscriptionState) {
      emit(
        CloudTranscriptionState(
          job: current.job,
          history: current.history,
          preferences: _preferences,
          queueLength: queueLen,
          queue: current.queue,
        ),
      );
    } else if (current is TranscriptionNotice) {
      emit(
        TranscriptionNotice(
          message: current.message,
          severity: current.severity,
          history: current.history,
          preferences: _preferences,
          queueLength: queueLen,
          queue: current.queue,
        ),
      );
    } else {
      emit(
        TranscriptionInitial(
          history: List.unmodifiable(_history),
          preferences: _preferences,
          queueLength: queueLen,
          queue: current.queue,
        ),
      );
    }
  }

  String get _selectedWhisperModel => _preferences.useFastWhisperModel
      ? AppConstants.whisperFastModel
      : AppConstants.whisperDefaultModel;

  bool _isStrongConnection(ConnectivityResult result) {
    // Use measured speed if available and not expired
    if (_lastMeasuredSpeedKbps != null && !isSpeedDataExpired) {
      final isStrong =
          _lastMeasuredSpeedKbps! >= AppConstants.minStrongSpeedKbps;
      debugPrint(
          '[SpeedTest] Using measured speed: ${_lastMeasuredSpeedKbps!.toStringAsFixed(2)} kbps (strong: $isStrong)');
      return isStrong;
    }
    // If minStrongSpeedKbps is 0, any connection is considered strong
    // (user wants online mode regardless of speed)
    if (AppConstants.minStrongSpeedKbps == 0) {
      debugPrint(
          '[SpeedTest] No speed data, but minStrongSpeedKbps=0: treating any connection as strong');
      return true;
    }
    // Fallback to connection type if speed hasn't been measured yet or is expired
    final fallbackReason = _lastMeasuredSpeedKbps == null
        ? 'no speed data'
        : 'speed data expired (last update: ${_lastSpeedUpdate?.toString() ?? "never"})';
    debugPrint(
        '[SpeedTest] Fallback to connection type: $fallbackReason (connection: $result)');
    return result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet;
  }

  bool get isSpeedDataExpired {
    if (_lastSpeedUpdate == null) {
      return true;
    }
    return DateTime.now().difference(_lastSpeedUpdate!) > Duration(minutes: 5);
  }

  void _startSpeedTestMonitoring() {
    _stopSpeedTestMonitoring(); // Ensure no duplicate timers
    if (ApiConstants.speedTestFileUrl.isEmpty) {
      // Skip if test file URL is not configured yet
      debugPrint(
          '[SpeedTest] Monitoring skipped: test file URL not configured');
      return;
    }
    _shouldMonitorSpeed = true;
    _speedTestTimer = Timer.periodic(
      AppConstants.speedTestInterval,
      (_) {
        debugPrint('[SpeedTest] Timer tick: starting speed test');
        _runSpeedTest();
      },
    );
    debugPrint('[SpeedTest] Monitoring started');
    // Run initial test immediately
    _runSpeedTest();
  }

  void _stopSpeedTestMonitoring() {
    _speedTestTimer?.cancel();
    _speedTestTimer = null;
    // Reset flag in case a test is currently running
    _isSpeedTestRunning = false;
    _shouldMonitorSpeed = false;
    debugPrint('[SpeedTest] Monitoring stopped');
  }

  Future<void> _runSpeedTest() async {
    if (ApiConstants.speedTestFileUrl.isEmpty) {
      return;
    }
    // Prevent concurrent speed tests
    if (_isSpeedTestRunning) {
      debugPrint('[SpeedTest] Skipped: test already running');
      return;
    }
    _isSpeedTestRunning = true;
    try {
      final hasNetwork = await _networkInfo.isConnected;
      if (!hasNetwork) {
        debugPrint('[SpeedTest] Skipped: no network connection');
        return;
      }
      // Add timeout wrapper around entire call as defense-in-depth
      // Dio timeout + 2s buffer to ensure future completes even if Dio timeout fails
      final speed = await _networkInfo
          .measureDownloadSpeedKbps(
        testFileUrl: ApiConstants.speedTestFileUrl,
        timeout: AppConstants.speedTestTimeout,
      )
          .timeout(
        AppConstants.speedTestTimeout + const Duration(seconds: 2),
        onTimeout: () {
          debugPrint('[SpeedTest] Request timeout');
          return null;
        },
      );
      if (speed != null) {
        _lastMeasuredSpeedKbps = speed;
        _lastSpeedUpdate = DateTime.now();
        debugPrint(
            '[SpeedTest] Measured speed: ${speed.toStringAsFixed(2)} kbps');
      } else {
        debugPrint(
            '[SpeedTest] Request failed: returned null (keeping last known speed: ${_lastMeasuredSpeedKbps?.toStringAsFixed(2) ?? "none"} kbps)');
      }
      // If speed is null, don't update _lastMeasuredSpeedKbps (keep last known value)
    } catch (e) {
      debugPrint('[SpeedTest] Request error: $e');
      // Ignore errors, keep last known speed
    } finally {
      // Always reset flag, even on early return or error
      _isSpeedTestRunning = false;
    }
  }

  void _setFallbackContext({
    required String audioPath,
    required Duration duration,
    required int fileSizeBytes,
  }) {
    _pendingFallbackAudioPath = audioPath;
    _pendingFallbackDuration = duration;
    _pendingFallbackSizeBytes = fileSizeBytes;
  }

  void _clearFallbackContext() {
    _pendingFallbackAudioPath = null;
    _pendingFallbackDuration = null;
    _pendingFallbackSizeBytes = null;
  }

  void _startOfflineTranscription(String audioPath) {
    add(
      TranscribeAudio(
        audioPath,
        preferLocal: true,
        modelAssetPath: _selectedWhisperModel,
      ),
    );
  }

  void _promptOfflineFallback(
    Emitter<TranscriptionState> emit, {
    String? reason,
  }) {
    final audioPath = _pendingFallbackAudioPath;
    final duration = _pendingFallbackDuration;
    final size = _pendingFallbackSizeBytes;
    if (audioPath == null || duration == null || size == null) {
      emit(
        TranscriptionError(
          message:
              'Original recording is no longer available for offline fallback.',
          history: List.unmodifiable(_history),
          preferences: _preferences,
          queueLength: state.queue.length,
          queue: state.queue,
        ),
      );
      return;
    }
    emit(
      TranscriptionFallbackPrompt(
        audioPath: audioPath,
        duration: duration,
        fileSizeBytes: size,
        reason: reason,
        history: List.unmodifiable(_history),
        preferences: _preferences,
        queueLength: state.queue.length,
        queue: state.queue,
      ),
    );
  }

  Future<void> _onStartRecording(
    StartRecording event,
    Emitter<TranscriptionState> emit,
  ) async {
    // Allow recording even when processing is active (queue will handle it)
    if (await _recorder.isRecording()) {
      return;
    }

    final connectionType = await _networkInfo.connectionType;
    final hasNetwork = connectionType != ConnectivityResult.none;
    _plannedExecutionMode = _resolveExecutionMode(
      hasNetwork: hasNetwork,
      connectionType: connectionType,
    );

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      emit(
        TranscriptionError(
          message: 'Microphone permission denied',
          history: List.unmodifiable(_history),
          preferences: _preferences,
        ),
      );
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final extension =
        _plannedExecutionMode == TranscriptionExecutionMode.offline
            ? 'wav'
            : 'm4a';
    final filePath = p.join(
      tempDir.path,
      'transcription_${_uuid.v4()}.$extension',
    );

    try {
      await _recorder.start(
        _buildRecordConfig(_plannedExecutionMode),
        path: filePath,
      );
      _currentRecordingPath = filePath;
      _lastRecordedFilePath = filePath;
      _recordingStartedAt = DateTime.now();
      _isInputTooLow = false;
      _silenceTicks = 0;
      _startRecordingTicker();
      _startMonitoringInputLevels();
      _startSpeedTestMonitoring();
      emit(
        TranscriptionRecording(
          startedAt: _recordingStartedAt!,
          filePath: _currentRecordingPath,
          estimatedSizeBytes: 0,
          isInputTooLow: false,
          history: List.unmodifiable(_history),
          preferences: _preferences,
          queueLength: state.queue.length,
          queue: state.queue,
        ),
      );
    } catch (error) {
      _stopRecordingTicker();
      _stopMonitoringInputLevels();
      _stopSpeedTestMonitoring();
      emit(
        TranscriptionError(
          message: error.toString(),
          history: List.unmodifiable(_history),
          preferences: _preferences,
          queueLength: state.queue.length,
          queue: state.queue,
        ),
      );
    }
  }

  Future<void> _onStopRecording(
    StopRecording event,
    Emitter<TranscriptionState> emit,
  ) async {
    if (!await _recorder.isRecording()) {
      return;
    }

    // Emit stopping state immediately to show loading indicator
    emit(
      TranscriptionStopping(
        history: List.unmodifiable(_history),
        preferences: _preferences,
        queueLength: state.queue.length,
        queue: state.queue,
      ),
    );

    try {
      final path = await _recorder.stop();
      final audioPath = path ?? _currentRecordingPath;
      if (audioPath == null || !File(audioPath).existsSync()) {
        emit(
          TranscriptionError(
            message:
                'Recording file was not created or is missing. The audio may not have been saved properly. Please try recording again.',
            history: List.unmodifiable(_history),
            preferences: _preferences,
            queueLength: state.queue.length,
            queue: state.queue,
          ),
        );
        return;
      }
      final startedAt = _recordingStartedAt;
      final duration = startedAt != null
          ? DateTime.now().difference(startedAt)
          : Duration.zero;
      final file = File(audioPath);
      final fileSizeBytes = await file.length();

      if (duration < _kMinRecordingDuration) {
        try {
          await file.delete();
        } catch (_) {}
        emit(
          TranscriptionError(
            message:
                'Recording is too short. Please capture at least ${_kMinRecordingDuration.inSeconds} seconds.',
            history: List.unmodifiable(_history),
            preferences: _preferences,
            queueLength: state.queue.length,
            queue: state.queue,
          ),
        );
        return;
      }

      if (fileSizeBytes < _kMinRecordingSizeBytes) {
        try {
          await file.delete();
        } catch (_) {}
        emit(
          TranscriptionError(
            message:
                'We could not detect any audio. Please make sure the microphone is unobstructed.',
            history: List.unmodifiable(_history),
            preferences: _preferences,
            queueLength: state.queue.length,
            queue: state.queue,
          ),
        );
        return;
      }

      final isExtremeDuration = duration > _kExtremeRecordingDuration;
      final isExtremeSize = fileSizeBytes > _kExtremeRecordingSizeBytes;
      if (isExtremeDuration || isExtremeSize) {
        _emitNotice(
          emit,
          'This recording is quite long. Processing may take extra time—keep the app open or come back later.',
          severity: TranscriptionNoticeSeverity.warning,
        );
      }

      _setFallbackContext(
        audioPath: audioPath,
        duration: duration,
        fileSizeBytes: fileSizeBytes,
      );

      // Check if processing is currently active
      final isProcessingActive =
          _activeCloudJobId != null || state is TranscriptionProcessing;

      if (isProcessingActive) {
        // Queue the audio for processing later using new queue system
        // Queue size check is handled in _onQueueJobAdded to avoid duplicate warnings
        add(
          QueueJobAdded(
            audioPath: audioPath,
            duration: duration,
            fileSizeBytes: fileSizeBytes,
            isOnlineMode:
                _plannedExecutionMode == TranscriptionExecutionMode.online,
          ),
        );
        // Notice will be shown by _onQueueJobAdded handler
      } else {
        // Process immediately (not queued)
        final useOnline =
            _plannedExecutionMode == TranscriptionExecutionMode.online;
        var startedCloud = false;
        if (useOnline) {
          final hasNetwork = await _networkInfo.isConnected;
          if (hasNetwork) {
            startedCloud = await _startCloudTranscriptionJob(
              audioPath: audioPath,
              duration: duration,
              fileSizeBytes: fileSizeBytes,
              emit: emit,
            );
          }
        }
        if (!startedCloud) {
          if (_plannedExecutionMode == TranscriptionExecutionMode.offline) {
            _startOfflineTranscription(audioPath);
          } else {
            _promptOfflineFallback(
              emit,
              reason: _lastCloudFailureMessage ??
                  'Cloud transcription is unavailable. Switch to on-device mode to finish faster?',
            );
          }
        }
      }
    } catch (error) {
      emit(
        TranscriptionError(
          message:
              'Failed to stop recording: ${error.toString()}. The recording may have been interrupted.',
          history: List.unmodifiable(_history),
          preferences: _preferences,
          queueLength: state.queue.length,
          queue: state.queue,
        ),
      );
    } finally {
      _stopRecordingTicker();
      _stopMonitoringInputLevels();
      _stopSpeedTestMonitoring();
      _recordingStartedAt = null;
      _currentRecordingPath = null;
    }
  }

  Future<void> _onTranscribeAudio(
    TranscribeAudio event,
    Emitter<TranscriptionState> emit,
  ) async {
    final audioPath = event.audioPath;

    // Check if this is a queued job
    final queuedJob = _findQueuedJobByAudioPath(audioPath);
    final isQueuedJob = queuedJob != null;

    emit(
      TranscriptionProcessing(
        audioPath: audioPath,
        history: List.unmodifiable(_history),
        preferences: _preferences,
        queueLength: state.queue.length,
        queue: state.queue,
      ),
    );

    await _performanceBridge.startSegment('transcription');

    try {
      final result = await _transcribeAudio(
        audioPath,
        preferLocal: event.preferLocal,
        modelAssetPath: event.modelAssetPath ?? _selectedWhisperModel,
      );
      final metrics = await _performanceBridge.endSegment('transcription');
      result.fold(
        (failure) async {
          // Save failed transcription to history
          final failedTranscription = await _createFailedTranscription(
            audioPath: audioPath,
            failureType: 'transcription',
            errorMessage: failure.message ??
                'Audio transcription processing failed. The audio file may be corrupted or the transcription service encountered an error.',
            duration: _pendingFallbackDuration,
            fileSizeBytes: _pendingFallbackSizeBytes,
          );

          if (failedTranscription != null) {
            final saveResult =
                await _transcriptionRepository.updateTranscription(
              failedTranscription,
            );
            saveResult.fold(
              (saveFailure) {
                debugPrint(
                    'Failed to save failed transcription: ${saveFailure.message}');
              },
              (saved) {
                _history.insert(0, saved);
              },
            );
          }

          if (isQueuedJob && queuedJob != null) {
            // Update queued job as failed
            add(
              QueueJobFailed(
                jobId: queuedJob.id,
                errorMessage: failure.message ??
                    'Audio transcription processing failed. The audio file may be corrupted or the transcription service encountered an error.',
              ),
            );
          } else {
            emit(
              TranscriptionError(
                message: failure.message ??
                    'Audio transcription processing failed. The audio file may be corrupted or the transcription service encountered an error.',
                history: List.unmodifiable(_history),
                preferences: _preferences,
                queueLength: state.queue.length,
                queue: state.queue,
              ),
            );
            // Process next queued audio after error
            await _processNextQueuedJob(emit);
          }
        },
        (transcription) {
          _history.insert(0, transcription);

          // Only delete file if note generation succeeded (for non-queued jobs)
          // For queued jobs, deletion is handled by the queue job success handler
          if (!isQueuedJob) {
            _deleteRecordedFile();
          }

          if (isQueuedJob && queuedJob != null) {
            // Update queued job as succeeded
            add(
              QueueJobSucceeded(
                jobId: queuedJob.id,
                noteId: transcription.id,
              ),
            );
          } else {
            emit(
              TranscriptionSuccess(
                transcription: transcription,
                history: List.unmodifiable(_history),
                metrics: metrics,
                preferences: _preferences,
                queueLength: state.queue.length,
                queue: state.queue,
              ),
            );
            // Process next queued audio after success
            _processNextQueuedJob(emit);
          }
        },
      );
    } catch (error) {
      await _performanceBridge.endSegment('transcription');

      // Save failed transcription to history
      final failedTranscription = await _createFailedTranscription(
        audioPath: audioPath,
        failureType: 'transcription',
        errorMessage: 'Unable to process audio: ${error.toString()}',
        duration: _pendingFallbackDuration,
        fileSizeBytes: _pendingFallbackSizeBytes,
      );

      if (failedTranscription != null) {
        final saveResult = await _transcriptionRepository.updateTranscription(
          failedTranscription,
        );
        saveResult.fold(
          (saveFailure) {
            debugPrint(
                'Failed to save failed transcription: ${saveFailure.message}');
          },
          (saved) {
            _history.insert(0, saved);
          },
        );
      }

      if (isQueuedJob && queuedJob != null) {
        // Update queued job as failed
        add(
          QueueJobFailed(
            jobId: queuedJob.id,
            errorMessage: 'Unable to process audio: ${error.toString()}',
          ),
        );
      } else {
        emit(
          TranscriptionError(
            message:
                'Unable to process audio: ${error.toString()}. The audio file may be corrupted, inaccessible, or the transcription service encountered an unexpected error.',
            history: List.unmodifiable(_history),
            preferences: _preferences,
            queueLength: state.queue.length,
            queue: state.queue,
          ),
        );
        // Process next queued audio after error
        await _processNextQueuedJob(emit);
      }
    }
  }

  QueuedTranscriptionJob? _findQueuedJobByAudioPath(String audioPath) {
    try {
      return state.queue.firstWhere(
        (job) => job.audioPath == audioPath,
      );
    } catch (_) {
      return null;
    }
  }

  void _onRecordingMetricsUpdated(
    RecordingMetricsUpdated event,
    Emitter<TranscriptionState> emit,
  ) {
    final currentState = state;
    if (currentState is! TranscriptionRecording) {
      return;
    }
    if (currentState.estimatedSizeBytes == event.estimatedSizeBytes &&
        currentState.isInputTooLow == event.isInputTooLow) {
      return;
    }
    emit(
      currentState.copyWith(
        estimatedSizeBytes: event.estimatedSizeBytes,
        isInputTooLow: event.isInputTooLow,
        history: List.unmodifiable(_history),
        preferences: _preferences,
        queueLength: _processingQueue.length,
      ),
    );
  }

  void _startRecordingTicker() {
    _recordingTicker?.cancel();
    _recordingTicker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _emitRecordingProgress(),
    );
    _emitRecordingProgress();
  }

  void _stopRecordingTicker() {
    _recordingTicker?.cancel();
    _recordingTicker = null;
  }

  Future<bool> _startCloudTranscriptionJob({
    required String audioPath,
    required Duration duration,
    required int fileSizeBytes,
    required Emitter<TranscriptionState> emit,
  }) async {
    final request = TranscriptionJobRequest(
      localFilePath: audioPath,
      duration: duration,
      fileSizeBytes: fileSizeBytes,
      displayName: p.basename(audioPath),
      metadata: {
        'source': 'flutter_app',
        'platform': Platform.operatingSystem,
      },
      mode: TranscriptionJobMode.onlineSoniox,
      userId: _resolveUserId(),
      localAudioPath: p.basename(audioPath),
    );
    _lastCloudFailureMessage = null;
    final result = await _createTranscriptionJob(request);
    return result.fold(
      (failure) {
        _lastCloudFailureMessage = failure.message ??
            'Cloud transcription service is unavailable. Check your internet connection or try offline mode.';
        _emitNotice(
          emit,
          _lastCloudFailureMessage!,
          severity: TranscriptionNoticeSeverity.warning,
        );
        return false;
      },
      (job) {
        _lastCloudFailureMessage = null;
        _activeCloudJobId = job.id;
        _listenToCloudJob(job.id);
        emit(
          CloudTranscriptionState(
            job: job,
            history: List.unmodifiable(_history),
            preferences: _preferences,
            queueLength: state.queue.length,
            queue: state.queue,
          ),
        );
        return true;
      },
    );
  }

  void _listenToCloudJob(String jobId) {
    _cloudJobSubscription?.cancel();
    _cloudJobSubscription = _watchTranscriptionJob(jobId).listen(
      (result) => add(TranscriptionJobSnapshotReceived(result)),
    );
  }

  void _emitRecordingProgress() {
    final startedAt = _recordingStartedAt;
    if (startedAt == null) {
      return;
    }
    final elapsed = DateTime.now().difference(startedAt);
    final estimatedSize =
        ((elapsed.inMilliseconds / 1000.0) * (_kRecordingBitrate / 8)).round();
    add(
      RecordingMetricsUpdated(
        estimatedSizeBytes: estimatedSize,
        isInputTooLow: _isInputTooLow,
      ),
    );
  }

  void _startMonitoringInputLevels() {
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = _recorder
        .onAmplitudeChanged(_kAmplitudeSampleInterval)
        .listen((amplitude) {
      final isSilent = amplitude.current < _kSilenceThresholdDb;
      if (isSilent) {
        _silenceTicks++;
      } else {
        _silenceTicks = 0;
      }
      final shouldWarn = _silenceTicks >= _kSilenceTickTrigger;
      if (shouldWarn != _isInputTooLow) {
        _isInputTooLow = shouldWarn;
        _emitRecordingProgress();
      }
    }, onError: (_) {
      // Ignore amplitude errors, recording can continue without hints.
    });
  }

  void _stopMonitoringInputLevels() {
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    _silenceTicks = 0;
    _isInputTooLow = false;
  }

  Future<void> _finalizeCloudJob(
    TranscriptionJob job,
    Emitter<TranscriptionState> emit,
  ) async {
    _activeCloudJobId = null;
    await _cloudJobSubscription?.cancel();
    _cloudJobSubscription = null;

    // Check if this is a queued job
    final audioPath = _pendingFallbackAudioPath;
    final queuedJob =
        audioPath != null ? _findQueuedJobByAudioPath(audioPath) : null;
    final isQueuedJob = queuedJob != null;

    if (job.status == TranscriptionJobStatus.completed &&
        job.transcriptId != null) {
      final result =
          await _transcriptionRepository.getTranscription(job.transcriptId!);
      await result.fold(
        (failure) async {
          if (isQueuedJob && queuedJob != null) {
            // Update queued job as failed
            add(
              QueueJobFailed(
                jobId: queuedJob.id,
                errorMessage: failure.message ??
                    'Cloud transcription completed but note is unavailable.',
              ),
            );
          } else {
            emit(
              TranscriptionError(
                message: failure.message ??
                    'Cloud transcription completed but note is unavailable.',
                history: List.unmodifiable(_history),
                preferences: _preferences,
                queueLength: state.queue.length,
                queue: state.queue,
              ),
            );
            // Process next queued audio after error
            await _processNextQueuedJob(emit);
          }
        },
        (transcription) async {
          // Check if note generation failed
          if (job.noteStatus == 'error') {
            // Update transcription to mark as failed (note generation failure)
            // ✅ FIX: Use local audio path from fallback context instead of transcription.audioPath
            // The transcription.audioPath from cloud may be incorrect (basename or storage path)
            final correctAudioPath =
                _pendingFallbackAudioPath ?? transcription.audioPath;

            final failedTranscription = Transcription(
              id: transcription.id,
              text: transcription.text,
              audioPath: correctAudioPath,
              duration: transcription.duration,
              timestamp: transcription.timestamp,
              confidence: transcription.confidence,
              metadata: transcription.metadata,
              title: transcription.title,
              structuredNote: transcription.structuredNote,
              isFailed: true,
              failureType: 'note_generation',
              errorMessage: job.noteError ?? 'Note generation failed',
              originalJobId: job.id,
              fileSizeBytes: _pendingFallbackSizeBytes ??
                  transcription.metadata['file_size_bytes'] as int?,
            );

            // Save updated failed transcription
            final updateResult =
                await _transcriptionRepository.updateTranscription(
              failedTranscription,
            );
            await updateResult.fold(
              (failure) async {
                debugPrint(
                    'Failed to update transcription as failed: ${failure.message}');
                // Still add original transcription to history
                _history.insert(0, transcription);
              },
              (updated) async {
                _history.insert(0, updated);
              },
            );

            if (isQueuedJob && queuedJob != null) {
              // Update queued job as failed (note generation failed)
              add(
                QueueJobFailed(
                  jobId: queuedJob.id,
                  errorMessage: job.noteError ?? 'Note generation failed',
                ),
              );
            } else {
              // Don't delete audio file - keep for retry
              // Emit error state instead of success for failed note generation
              emit(
                TranscriptionError(
                  message:
                      'Transcription succeeded but note generation failed. You can retry from Recent Notes.',
                  history: List.unmodifiable(_history),
                  preferences: _preferences,
                  queueLength: state.queue.length,
                  queue: state.queue,
                ),
              );
            }
          } else {
            // Note generation succeeded or not applicable
            _history.insert(0, transcription);
            // ✅ CHECK: Only delete if note generation is complete and successful
            final shouldDeleteFile = job.noteStatus == 'ready';

            if (isQueuedJob && queuedJob != null) {
              // Check if we should delete the file before updating job status
              // Create a temporary job object with success status for policy check
              final tempSuccessJob = queuedJob.copyWith(
                status: QueuedTranscriptionJobStatus.success,
                noteId: transcription.id,
              );
              final shouldDelete = await _cleanupAudioIfNotNeeded(
                job: tempSuccessJob,
                noteStatus: job.noteStatus,
                transcriptionSucceeded: true,
              );

              // Update queued job as succeeded
              add(
                QueueJobSucceeded(
                  jobId: queuedJob.id,
                  noteId: transcription.id,
                ),
              );

              // Delete file using centralized policy
              if (shouldDelete) {
                await _deleteFileForJob(queuedJob.audioPath);
              }
            } else {
              emit(
                TranscriptionSuccess(
                  transcription: transcription,
                  history: List.unmodifiable(_history),
                  metrics: null,
                  preferences: _preferences,
                  queueLength: state.queue.length,
                  queue: state.queue,
                ),
              );
              if (shouldDeleteFile) {
                await _deleteRecordedFile();
              }
            }
          }
          // Process next queued audio after success (handled by event handlers)
          if (!isQueuedJob) {
            await _processNextQueuedJob(emit);
          }
        },
      );
    } else if (job.status == TranscriptionJobStatus.error) {
      _lastCloudFailureMessage = job.errorMessage ??
          'Cloud transcription job failed. The server may be experiencing issues or the audio file may be invalid.';

      if (isQueuedJob && queuedJob != null) {
        // Update queued job as failed
        add(
          QueueJobFailed(
            jobId: queuedJob.id,
            errorMessage: _lastCloudFailureMessage!,
          ),
        );
      } else {
        // Save failed transcription to history
        final audioPath = _pendingFallbackAudioPath;
        if (audioPath != null) {
          final failedTranscription = await _createFailedTranscription(
            audioPath: audioPath,
            failureType: 'transcription',
            errorMessage: _lastCloudFailureMessage!,
            originalJobId: job.id,
            duration: _pendingFallbackDuration,
            fileSizeBytes: _pendingFallbackSizeBytes,
          );

          if (failedTranscription != null) {
            final saveResult =
                await _transcriptionRepository.updateTranscription(
              failedTranscription,
            );
            saveResult.fold(
              (failure) {
                debugPrint(
                    'Failed to save failed transcription: ${failure.message}');
              },
              (saved) {
                _history.insert(0, saved);
              },
            );
          }
        }

        _promptOfflineFallback(
          emit,
          reason: _lastCloudFailureMessage,
        );
        // Process next queued audio after error
        await _processNextQueuedJob(emit);
      }
    }
  }

  Future<void> _onTranscriptionJobSnapshot(
    TranscriptionJobSnapshotReceived event,
    Emitter<TranscriptionState> emit,
  ) async {
    await event.result.fold(
      (failure) async {
        // Clear cloud job state on stream error to unblock queue processing
        _activeCloudJobId = null;
        await _cloudJobSubscription?.cancel();
        _cloudJobSubscription = null;

        _lastCloudFailureMessage = failure.message ??
            'Cloud transcription job failed. The server may be experiencing issues or the audio file may be invalid.';
        _promptOfflineFallback(
          emit,
          reason: _lastCloudFailureMessage,
        );
      },
      (job) async {
        emit(
          CloudTranscriptionState(
            job: job,
            history: List.unmodifiable(_history),
            preferences: _preferences,
            queueLength: state.queue.length,
            queue: state.queue,
          ),
        );

        // Deletion is handled in _finalizeCloudJob for centralized policy
        if (job.isTerminal) {
          await _finalizeCloudJob(job, emit);
        }
      },
    );
  }

  Future<void> _onCancelCloudTranscription(
    CancelCloudTranscription event,
    Emitter<TranscriptionState> emit,
  ) async {
    final jobId = _activeCloudJobId;
    if (jobId == null) {
      return;
    }
    final result = await _cancelTranscriptionJob(jobId, reason: event.reason);
    result.fold(
      (failure) => emit(
        TranscriptionError(
          message: failure.message ??
              'Unable to cancel cloud transcription job. It may have already completed or been cancelled.',
          history: List.unmodifiable(_history),
          preferences: _preferences,
          queueLength: state.queue.length,
          queue: state.queue,
        ),
      ),
      (_) {
        _emitNotice(
          emit,
          'Cloud transcription cancelled.',
        );
        // Process next queued audio after cancellation
        _processNextQueuedAudio(emit);
      },
    );
  }

  Future<void> _onRetryCloudTranscription(
    RetryCloudTranscription event,
    Emitter<TranscriptionState> emit,
  ) async {
    final result = await _requestTranscriptionJobRetry(event.jobId);
    result.fold(
      (failure) => emit(
        TranscriptionError(
          message: failure.message ??
              'Unable to request transcription retry. The job may no longer exist or the service is unavailable.',
          history: List.unmodifiable(_history),
          preferences: _preferences,
          queueLength: state.queue.length,
          queue: state.queue,
        ),
      ),
      (_) => _emitNotice(
        emit,
        'Retry requested. We will attempt to rerun the transcription shortly.',
      ),
    );
  }

  Future<void> _onRetryNoteGeneration(
    RetryNoteGeneration event,
    Emitter<TranscriptionState> emit,
  ) async {
    // ✅ FIX: Find the failed transcription to get audio path and other context
    final failedTranscription = _history.firstWhere(
      (t) => t.originalJobId == event.jobId,
      orElse: () => _history.first, // Fallback (shouldn't happen)
    );

    // Set fallback context so _finalizeCloudJob can use it for retry
    _setFallbackContext(
      audioPath: failedTranscription.audioPath,
      duration: failedTranscription.duration,
      fileSizeBytes: failedTranscription.fileSizeBytes ?? 0,
    );

    final result = await _requestNoteRetry(event.jobId);
    result.fold(
      (failure) => emit(
        TranscriptionError(
          message: failure.message ??
              'Unable to retry note generation. The transcription job may not be available or the service is unavailable.',
          history: List.unmodifiable(_history),
          preferences: _preferences,
          queueLength: state.queue.length,
          queue: state.queue,
        ),
      ),
      (_) {
        // ✅ FIX: Start listening to the job to know when retry completes
        _activeCloudJobId = event.jobId;
        _listenToCloudJob(event.jobId);

        _emitNotice(
          emit,
          'Retrying smart note generation...',
        );
      },
    );
  }

  Future<void> _onRetryFailedTranscription(
    RetryFailedTranscription event,
    Emitter<TranscriptionState> emit,
  ) async {
    final failed = event.transcription;
    final audioPath = failed.audioPath;

    // 1. Check if audio file exists
    final file = File(audioPath);
    if (!await file.exists()) {
      emit(
        TranscriptionError(
          message:
              'Original audio file is no longer available. Please record again.',
          history: List.unmodifiable(_history),
          preferences: _preferences,
          queueLength: state.queue.length,
          queue: state.queue,
        ),
      );
      return;
    }

    // 2. Get duration and file size for retry
    final duration = failed.duration;
    final fileSizeBytes = failed.fileSizeBytes ?? await file.length();

    // 3. Set fallback context for this retry
    _setFallbackContext(
      audioPath: audioPath,
      duration: duration,
      fileSizeBytes: fileSizeBytes,
    );

    // 4. Remove the old failed transcription from history
    _history.removeWhere((t) => t.id == failed.id);

    // 5. Delete the failed transcription from repository
    await _transcriptionRepository.deleteTranscription(failed.id);

    // 6. Check network connectivity and determine execution mode
    final connectionType = await _networkInfo.connectionType;
    final hasNetwork = connectionType != ConnectivityResult.none;
    _plannedExecutionMode = _resolveExecutionMode(
      hasNetwork: hasNetwork,
      connectionType: connectionType,
    );

    // 7. Emit updated state with removed failed transcription
    _emitSnapshot(emit);

    // 8. Route to existing flow based on execution mode
    final useOnline =
        _plannedExecutionMode == TranscriptionExecutionMode.online;

    if (useOnline && hasNetwork) {
      // Retry via cloud transcription (full flow: transcription + note generation)
      final startedCloud = await _startCloudTranscriptionJob(
        audioPath: audioPath,
        duration: duration,
        fileSizeBytes: fileSizeBytes,
        emit: emit,
      );

      if (!startedCloud) {
        // Fallback to offline if cloud fails to start
        _startOfflineTranscription(audioPath);
      }
    } else {
      // Retry via offline transcription
      _startOfflineTranscription(audioPath);
    }
  }

  Future<void> _onDeleteTranscription(
    DeleteTranscription event,
    Emitter<TranscriptionState> emit,
  ) async {
    final result = await _transcriptionRepository.deleteTranscription(event.id);
    await result.fold(
      (failure) async {
        emit(
          TranscriptionError(
            message: failure.message ??
                'Failed to delete transcription from storage. It may have already been deleted or the storage service is unavailable.',
            history: List.unmodifiable(_history),
            preferences: _preferences,
            queueLength: state.queue.length,
            queue: state.queue,
          ),
        );
      },
      (_) async {
        // Remove from local history
        _history.removeWhere((t) => t.id == event.id);
        // Emit success with updated history
        emit(
          TranscriptionInitial(
            history: List.unmodifiable(_history),
            preferences: _preferences,
            queueLength: state.queue.length,
            queue: state.queue,
          ),
        );
      },
    );
  }

  Future<void> _onUpdateTranscription(
    UpdateTranscription event,
    Emitter<TranscriptionState> emit,
  ) async {
    final result =
        await _transcriptionRepository.updateTranscription(event.transcription);
    await result.fold(
      (failure) async {
        emit(
          TranscriptionError(
            message: failure.message ??
                'Failed to update transcription in storage. The transcription may have been deleted or the storage service is unavailable. Please try again.',
            history: List.unmodifiable(_history),
            preferences: _preferences,
            queueLength: state.queue.length,
            queue: state.queue,
          ),
        );
      },
      (updatedTranscription) async {
        // Update in local history
        final index =
            _history.indexWhere((t) => t.id == updatedTranscription.id);
        if (index != -1) {
          _history[index] = updatedTranscription;
        }
        // Emit success with updated history
        emit(
          TranscriptionInitial(
            history: List.unmodifiable(_history),
            preferences: _preferences,
            queueLength: state.queue.length,
            queue: state.queue,
          ),
        );
      },
    );
  }

  Future<void> _onFormatTranscriptionNote(
    FormatTranscriptionNote event,
    Emitter<TranscriptionState> emit,
  ) async {
    try {
      // Check network connectivity
      final hasNetwork = await _networkInfo.isConnected;
      if (!hasNetwork) {
        emit(
          TranscriptionError(
            message: 'Internet connection required to format note',
            history: List.unmodifiable(_history),
            preferences: _preferences,
            queueLength: state.queue.length,
            queue: state.queue,
            formattingTranscriptionId: null,
          ),
        );
        return;
      }

      // Find transcription in history, or fetch from repository if not found
      Transcription? transcription;
      try {
        transcription = _history.firstWhere(
          (t) => t.id == event.id,
        );
      } catch (e) {
        // Transcription not in history, fetch from repository
        final result =
            await _transcriptionRepository.getTranscription(event.id);
        await result.fold(
          (failure) async {
            emit(
              TranscriptionError(
                message: failure.message ??
                    'Transcription not found in storage. It may have been deleted or the ID is invalid.',
                history: List.unmodifiable(_history),
                preferences: _preferences,
                queueLength: state.queue.length,
                queue: state.queue,
                formattingTranscriptionId: null,
              ),
            );
          },
          (fetchedTranscription) async {
            transcription = fetchedTranscription;
            // Add to history if not already there
            if (!_history.any((t) => t.id == fetchedTranscription.id)) {
              _history.insert(0, fetchedTranscription);
            }
          },
        );

        // If we couldn't fetch it, return early
        if (transcription == null) {
          return;
        }
      }

      // Check if transcription has text
      final transcriptionText = transcription!.text;
      if (transcriptionText == null || transcriptionText.trim().isEmpty) {
        emit(
          TranscriptionError(
            message: 'Cannot format note: transcription text is empty',
            history: List.unmodifiable(_history),
            preferences: _preferences,
            queueLength: state.queue.length,
            queue: state.queue,
            formattingTranscriptionId: null,
          ),
        );
        return;
      }

      // Emit state indicating formatting has started
      // Preserve current state type but set formattingTranscriptionId
      if (state is TranscriptionSuccess) {
        emit(
          TranscriptionSuccess(
            transcription: (state as TranscriptionSuccess).transcription,
            history: state.history,
            metrics: (state as TranscriptionSuccess).metrics,
            preferences: state.preferences,
            queueLength: state.queueLength,
            queue: state.queue,
            formattingTranscriptionId: event.id,
          ),
        );
      } else {
        emit(
          TranscriptionInitial(
            history: state.history,
            preferences: state.preferences,
            queueLength: state.queueLength,
            queue: state.queue,
            formattingTranscriptionId: event.id,
          ),
        );
      }

      final result = await _transcriptionRepository.formatNote(event.id);
      await result.fold(
        (failure) async {
          emit(
            TranscriptionError(
              message: failure.message ??
                  'Failed to format transcription note. The service may be unavailable or the transcription may be invalid.',
              history: List.unmodifiable(_history),
              preferences: _preferences,
              queueLength: state.queue.length,
              queue: state.queue,
              formattingTranscriptionId: null,
            ),
          );
        },
        (formattedTranscription) async {
          // Update in local history
          final index =
              _history.indexWhere((t) => t.id == formattedTranscription.id);
          if (index != -1) {
            _history[index] = formattedTranscription;
          } else {
            _history.insert(0, formattedTranscription);
          }
          // Emit success with updated history and clear formatting state
          emit(
            TranscriptionSuccess(
              transcription: formattedTranscription,
              history: List.unmodifiable(_history),
              metrics: null,
              preferences: _preferences,
              queueLength: state.queue.length,
              queue: state.queue,
              formattingTranscriptionId: null,
            ),
          );
        },
      );
    } catch (error) {
      emit(
        TranscriptionError(
          message:
              'An unexpected error occurred while formatting the note: ${error.toString()}. Please try again.',
          history: List.unmodifiable(_history),
          preferences: _preferences,
          queueLength: state.queue.length,
          queue: state.queue,
          formattingTranscriptionId: null,
        ),
      );
    }
  }

  Future<void> _onRetryFormatNote(
    RetryFormatNote event,
    Emitter<TranscriptionState> emit,
  ) async {
    // Reuse the same logic as format note
    await _onFormatTranscriptionNote(
      FormatTranscriptionNote(event.id),
      emit,
    );
  }

  String _resolveUserId() {
    // TODO: integrate with authenticated user profile when available.
    return 'local_user';
  }

  /// Creates a failed Transcription entity for saving to history.
  Future<Transcription?> _createFailedTranscription({
    required String audioPath,
    required String failureType,
    required String errorMessage,
    String? originalJobId,
    Duration? duration,
    int? fileSizeBytes,
  }) async {
    try {
      final file = File(audioPath);
      // Get file size if not provided
      final size =
          fileSizeBytes ?? (await file.exists() ? await file.length() : null);
      // Get duration from fallback context if not provided
      final dur = duration ?? _pendingFallbackDuration ?? Duration.zero;

      return Transcription(
        id: _uuid.v4(),
        text: null, // Failed transcriptions have no text
        audioPath: audioPath,
        duration: dur,
        timestamp: DateTime.now(),
        confidence: 0.0,
        isFailed: true,
        failureType: failureType,
        errorMessage: errorMessage,
        originalJobId: originalJobId,
        fileSizeBytes: size,
      );
    } catch (error) {
      debugPrint('Error creating failed transcription: $error');
      return null;
    }
  }

  Future<void> _deleteRecordedFile() async {
    final path = _lastRecordedFilePath;
    if (path == null) {
      return;
    }
    final file = File(path);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {
        // Best-effort cleanup.
      }
    }
    _lastRecordedFilePath = null;
    _clearFallbackContext();
  }

  void _emitNotice(
    Emitter<TranscriptionState> emit,
    String message, {
    TranscriptionNoticeSeverity severity = TranscriptionNoticeSeverity.info,
  }) {
    emit(
      TranscriptionNotice(
        message: message,
        severity: severity,
        history: List.unmodifiable(_history),
        preferences: _preferences,
        queueLength: state.queue.length,
        queue: state.queue,
      ),
    );
  }

  Future<void> _processNextQueuedJob(Emitter<TranscriptionState> emit) async {
    // Check if processing is already active
    final isProcessingActive =
        _activeCloudJobId != null || state is TranscriptionProcessing;
    if (isProcessingActive) {
      return;
    }

    // Find first waiting job
    final currentQueue = state.queue;
    QueuedTranscriptionJob waitingJob;
    try {
      waitingJob = currentQueue.firstWhere(
        (job) => job.status == QueuedTranscriptionJobStatus.waiting,
      );
    } catch (_) {
      // No waiting jobs found
      return;
    }

    // Check if file exists before processing
    final audioFile = File(waitingJob.audioPath);
    if (!await audioFile.exists()) {
      // File missing - mark as failed and remove from queue
      // Per requirement: mark failed with errorMessage "Source audio missing", then remove automatically
      final currentQueue = List<QueuedTranscriptionJob>.from(state.queue);
      final jobIndex = currentQueue.indexWhere((j) => j.id == waitingJob.id);
      if (jobIndex != -1) {
        // Remove the job from queue automatically (file doesn't exist, can't process)
        // Note: We remove it directly since it can't be processed; the error is logged
        final updatedQueue = List<QueuedTranscriptionJob>.from(currentQueue)
          ..removeAt(jobIndex);
        _emitStateWithUpdatedQueue(emit, updatedQueue);
        await _saveQueue(updatedQueue);
        debugPrint(
            '[Queue] Removed job ${waitingJob.id} - source audio missing (error: "Source audio missing")');
      }
      return;
    }

    // Get file metadata - use stored values if available, otherwise read from file
    final fileSizeBytes = waitingJob.fileSizeBytes ?? await audioFile.length();
    final duration = waitingJob.duration ?? const Duration(seconds: 0);

    // Mark job as processing - update synchronously to avoid race condition
    final updatedQueue = List<QueuedTranscriptionJob>.from(state.queue);
    final jobIndex = updatedQueue.indexWhere((j) => j.id == waitingJob.id);
    if (jobIndex != -1) {
      updatedQueue[jobIndex] = waitingJob.copyWith(
        status: QueuedTranscriptionJobStatus.processing,
        updatedAt: DateTime.now(),
      );
      _emitStateWithUpdatedQueue(emit, updatedQueue);
      await _saveQueue(updatedQueue);
    }

    // Set fallback context
    _setFallbackContext(
      audioPath: waitingJob.audioPath,
      duration: duration,
      fileSizeBytes: fileSizeBytes,
    );

    // Process based on mode
    final useOnline = waitingJob.isOnlineMode ?? true;
    if (useOnline) {
      final hasNetwork = await _networkInfo.isConnected;
      if (hasNetwork) {
        // Try cloud transcription
        // We need duration - let's get it from file metadata or estimate
        // For now, use a reasonable default or try to extract from file
        final startedCloud = await _startCloudTranscriptionJob(
          audioPath: waitingJob.audioPath,
          duration: duration,
          fileSizeBytes: fileSizeBytes,
          emit: emit,
        );

        if (!startedCloud) {
          // Cloud failed - mark job as failed
          add(
            QueueJobFailed(
              jobId: waitingJob.id,
              errorMessage: _lastCloudFailureMessage ??
                  'Cloud transcription service is unavailable. Check your internet connection or try offline mode.',
            ),
          );
        }
        // If started, the cloud job will eventually call _onTranscriptionJobSnapshot
        // which will handle success/failure
      } else {
        // No network - fallback to offline
        _startOfflineTranscriptionForJob(waitingJob.id, waitingJob.audioPath);
      }
    } else {
      // Offline mode
      _startOfflineTranscriptionForJob(waitingJob.id, waitingJob.audioPath);
    }
  }

  void _startOfflineTranscriptionForJob(String jobId, String audioPath) {
    // Start offline transcription for the queued job
    _startOfflineTranscription(audioPath);
  }

  // Legacy method for backward compatibility - will be updated to use new queue
  Future<void> _processNextQueuedAudio(Emitter<TranscriptionState> emit) async {
    // This method is kept for backward compatibility
    // New code should use _processNextQueuedJob
    await _processNextQueuedJob(emit);
  }

  // Helper method to save queue to local storage
  Future<void> _saveQueue(List<QueuedTranscriptionJob> queue) async {
    try {
      await _queueLocalDataSource.saveQueue(queue);
    } catch (e) {
      debugPrint('[Queue] Failed to save queue: $e');
      // Best-effort save - don't throw
    }
  }

  // Helper method to update queue in current state
  void _emitStateWithUpdatedQueue(
    Emitter<TranscriptionState> emit,
    List<QueuedTranscriptionJob> updatedQueue,
  ) {
    final current = state;
    final queueLen = updatedQueue.length;
    if (current is TranscriptionRecording) {
      emit(
        current.copyWith(
          history: current.history,
          preferences: _preferences,
          queueLength: queueLen,
          queue: updatedQueue,
        ),
      );
    } else if (current is TranscriptionStopping) {
      emit(
        TranscriptionStopping(
          history: current.history,
          preferences: _preferences,
          queueLength: queueLen,
          queue: updatedQueue,
        ),
      );
    } else if (current is TranscriptionProcessing) {
      emit(
        TranscriptionProcessing(
          audioPath: current.audioPath,
          history: current.history,
          preferences: _preferences,
          queueLength: queueLen,
          queue: updatedQueue,
        ),
      );
    } else if (current is TranscriptionSuccess) {
      emit(
        TranscriptionSuccess(
          transcription: current.transcription,
          metrics: current.metrics,
          history: current.history,
          preferences: _preferences,
          queueLength: queueLen,
          queue: updatedQueue,
        ),
      );
    } else if (current is TranscriptionError) {
      emit(
        TranscriptionError(
          message: current.message,
          history: current.history,
          preferences: _preferences,
          queueLength: queueLen,
          queue: updatedQueue,
        ),
      );
    } else if (current is CloudTranscriptionState) {
      emit(
        CloudTranscriptionState(
          job: current.job,
          history: current.history,
          preferences: _preferences,
          queueLength: queueLen,
          queue: updatedQueue,
        ),
      );
    } else if (current is TranscriptionNotice) {
      emit(
        TranscriptionNotice(
          message: current.message,
          severity: current.severity,
          history: current.history,
          preferences: _preferences,
          queueLength: queueLen,
          queue: updatedQueue,
        ),
      );
    } else if (current is TranscriptionFallbackPrompt) {
      emit(
        TranscriptionFallbackPrompt(
          audioPath: current.audioPath,
          duration: current.duration,
          fileSizeBytes: current.fileSizeBytes,
          reason: current.reason,
          history: current.history,
          preferences: _preferences,
          queueLength: queueLen,
          queue: updatedQueue,
        ),
      );
    } else {
      emit(
        TranscriptionInitial(
          history: List.unmodifiable(_history),
          preferences: _preferences,
          queueLength: queueLen,
          queue: updatedQueue,
        ),
      );
    }
  }

  Future<void> _onQueueJobAdded(
    QueueJobAdded event,
    Emitter<TranscriptionState> emit,
  ) async {
    final currentQueue = List<QueuedTranscriptionJob>.from(state.queue);

    // Enforce max queue size - prevent adding if queue is full
    if (currentQueue.length >= _kMaxQueueSize) {
      _emitNotice(
        emit,
        'You have $_kMaxQueueSize pending transcriptions. Please wait or cancel some items.',
        severity: TranscriptionNoticeSeverity.warning,
      );
      // Delete the audio file since we can't queue it
      try {
        final file = File(event.audioPath);
        if (await file.exists()) {
          await file.delete();
          debugPrint(
              '[Queue] Deleted audio file that exceeded queue limit: ${event.audioPath}');
        }
      } catch (e) {
        debugPrint('[Queue] Failed to delete audio file: $e');
      }
      return;
    }

    // Create new job
    final job = QueuedTranscriptionJob(
      id: _uuid.v4(),
      audioPath: event.audioPath,
      status: QueuedTranscriptionJobStatus.waiting,
      createdAt: DateTime.now(),
      isOnlineMode: event.isOnlineMode,
      duration: event.duration,
      fileSizeBytes: event.fileSizeBytes,
    );

    // Add to queue
    final updatedQueue = [...currentQueue, job];
    _emitStateWithUpdatedQueue(emit, updatedQueue);
    await _saveQueue(updatedQueue);

    // Show success notice with queue count
    _emitNotice(
      emit,
      'Recording saved. ${updatedQueue.length} audio(s) in queue.',
      severity: TranscriptionNoticeSeverity.info,
    );

    // Try to process if no active processing
    await _processNextQueuedJob(emit);
  }

  Future<void> _onQueueJobProcessingStarted(
    QueueJobProcessingStarted event,
    Emitter<TranscriptionState> emit,
  ) async {
    final currentQueue = List<QueuedTranscriptionJob>.from(state.queue);
    final jobIndex = currentQueue.indexWhere((j) => j.id == event.jobId);
    if (jobIndex == -1) return;

    final job = currentQueue[jobIndex];
    final updatedJob = job.copyWith(
      status: QueuedTranscriptionJobStatus.processing,
      updatedAt: DateTime.now(),
    );

    final updatedQueue = List<QueuedTranscriptionJob>.from(currentQueue);
    updatedQueue[jobIndex] = updatedJob;
    _emitStateWithUpdatedQueue(emit, updatedQueue);
    await _saveQueue(updatedQueue);
  }

  Future<void> _onQueueJobSucceeded(
    QueueJobSucceeded event,
    Emitter<TranscriptionState> emit,
  ) async {
    final currentQueue = List<QueuedTranscriptionJob>.from(state.queue);
    final jobIndex = currentQueue.indexWhere((j) => j.id == event.jobId);
    if (jobIndex == -1) return;

    final job = currentQueue[jobIndex];
    final updatedJob = job.copyWith(
      status: QueuedTranscriptionJobStatus.success,
      noteId: event.noteId,
      updatedAt: DateTime.now(),
    );

    final updatedQueue = List<QueuedTranscriptionJob>.from(currentQueue);
    updatedQueue[jobIndex] = updatedJob;
    _emitStateWithUpdatedQueue(emit, updatedQueue);
    await _saveQueue(updatedQueue);

    // Delete audio file if not needed (using centralized policy)
    // For offline mode: verify note is safely stored before deleting
    // For online mode: deletion is handled in _finalizeCloudJob when noteStatus == 'ready'
    bool transcriptionSucceeded = true;

    // For offline mode, verify the transcription exists in repository before deleting
    if (updatedJob.isOnlineMode == false && event.noteId != null) {
      final verifyResult =
          await _transcriptionRepository.getTranscription(event.noteId);
      transcriptionSucceeded = verifyResult.fold(
        (failure) {
          debugPrint(
              '[Queue] Failed to verify transcription storage: ${failure.message}');
          return false;
        },
        (transcription) => transcription != null,
      );
    }

    final shouldDelete = await _cleanupAudioIfNotNeeded(
      job: updatedJob,
      noteStatus: null, // For offline mode, we don't have noteStatus yet
      transcriptionSucceeded: transcriptionSucceeded,
    );
    if (shouldDelete) {
      await _deleteFileForJob(job.audioPath);
    }

    // Clear fallback context after processing to prevent stale data
    _clearFallbackContext();

    // Process next job
    await _processNextQueuedJob(emit);
  }

  /// Encapsulates the decision logic for when to delete audio files after successful processing.
  /// This policy can evolve later without affecting call sites.
  ///
  /// Returns true if the audio file should be deleted, false otherwise.
  ///
  /// Deletion criteria:
  /// - For online mode: delete only when note generation is complete (noteStatus == 'ready')
  /// - For offline mode: delete when transcription succeeds (note is safely stored)
  /// - Audio files for waiting/failed jobs are never deleted (preserved for retry)
  Future<bool> _cleanupAudioIfNotNeeded({
    required QueuedTranscriptionJob job,
    String? noteStatus,
    bool transcriptionSucceeded = true,
  }) async {
    // Never delete files for waiting or failed jobs
    if (job.status == QueuedTranscriptionJobStatus.waiting ||
        job.status == QueuedTranscriptionJobStatus.failed) {
      return false;
    }

    // Only delete for successful jobs
    if (job.status != QueuedTranscriptionJobStatus.success) {
      return false;
    }

    // For online mode: delete only when note generation is complete
    if (job.isOnlineMode == true) {
      return noteStatus == 'ready';
    }

    // For offline mode: delete when transcription succeeds
    // (transcription success means note is safely stored)
    if (job.isOnlineMode == false) {
      return transcriptionSucceeded;
    }

    // Default: don't delete if we're unsure
    return false;
  }

  Future<void> _deleteFileForJob(String audioPath) async {
    final file = File(audioPath);
    if (await file.exists()) {
      try {
        await file.delete();
        debugPrint('[Queue] Deleted audio file for successful job: $audioPath');
      } catch (e) {
        debugPrint('[Queue] Failed to delete audio file: $e');
        // Best-effort cleanup - don't fail the job
      }
    }
  }

  Future<void> _onQueueJobFailed(
    QueueJobFailed event,
    Emitter<TranscriptionState> emit,
  ) async {
    final currentQueue = List<QueuedTranscriptionJob>.from(state.queue);
    final jobIndex = currentQueue.indexWhere((j) => j.id == event.jobId);
    if (jobIndex == -1) return;

    final job = currentQueue[jobIndex];
    final updatedJob = job.copyWith(
      status: QueuedTranscriptionJobStatus.failed,
      errorMessage: event.errorMessage,
      updatedAt: DateTime.now(),
    );

    final updatedQueue = List<QueuedTranscriptionJob>.from(currentQueue);
    updatedQueue[jobIndex] = updatedJob;
    _emitStateWithUpdatedQueue(emit, updatedQueue);
    await _saveQueue(updatedQueue);

    // Clear fallback context after processing to prevent stale data
    _clearFallbackContext();

    // Process next job
    await _processNextQueuedJob(emit);
  }

  Future<void> _onQueueJobCancelled(
    QueueJobCancelled event,
    Emitter<TranscriptionState> emit,
  ) async {
    final currentQueue = List<QueuedTranscriptionJob>.from(state.queue);
    final jobIndex = currentQueue.indexWhere((j) => j.id == event.jobId);
    if (jobIndex == -1) return;

    final job = currentQueue[jobIndex];
    // Only allow cancellation of waiting or failed jobs
    if (job.status != QueuedTranscriptionJobStatus.waiting &&
        job.status != QueuedTranscriptionJobStatus.failed) {
      return;
    }

    // Delete audio file for cancelled job to avoid orphaned temp files
    try {
      final file = File(job.audioPath);
      if (await file.exists()) {
        await file.delete();
        debugPrint(
            '[Queue] Deleted audio file for cancelled job: ${job.audioPath}');
      }
    } catch (e) {
      debugPrint('[Queue] Failed to delete audio file for cancelled job: $e');
      // Best-effort cleanup - continue with queue removal
    }

    // Remove from queue
    final updatedQueue = List<QueuedTranscriptionJob>.from(currentQueue)
      ..removeAt(jobIndex);
    _emitStateWithUpdatedQueue(emit, updatedQueue);
    await _saveQueue(updatedQueue);
  }

  Future<void> _onQueueJobRetried(
    QueueJobRetried event,
    Emitter<TranscriptionState> emit,
  ) async {
    final currentQueue = List<QueuedTranscriptionJob>.from(state.queue);
    final jobIndex = currentQueue.indexWhere((j) => j.id == event.jobId);
    if (jobIndex == -1) return;

    final job = currentQueue[jobIndex];
    // Only allow retry of failed jobs
    if (job.status != QueuedTranscriptionJobStatus.failed) {
      return;
    }

    // Reset job to waiting status
    final updatedJob = job.copyWith(
      status: QueuedTranscriptionJobStatus.waiting,
      errorMessage: null,
      updatedAt: DateTime.now(),
    );

    final updatedQueue = List<QueuedTranscriptionJob>.from(currentQueue);
    updatedQueue[jobIndex] = updatedJob;
    _emitStateWithUpdatedQueue(emit, updatedQueue);
    await _saveQueue(updatedQueue);

    // Try to process
    await _processNextQueuedJob(emit);
  }

  Future<void> _onResumeProcessingAfterPause(
    ResumeProcessingAfterPause event,
    Emitter<TranscriptionState> emit,
  ) async {
    debugPrint('[Queue] Resuming processing after app pause');

    final currentQueue = state.queue;
    final processingJobs = currentQueue
        .where(
          (job) => job.status == QueuedTranscriptionJobStatus.processing,
        )
        .toList();

    if (processingJobs.isEmpty) {
      // No processing jobs to reset, just check for waiting jobs
      final hasWaitingJobs = currentQueue.any(
        (job) => job.status == QueuedTranscriptionJobStatus.waiting,
      );

      if (hasWaitingJobs) {
        debugPrint('[Queue] Resuming - processing waiting jobs');
        await _processNextQueuedJob(emit);
      }
      return;
    }

    // Reset stuck processing jobs to waiting
    debugPrint(
        '[Queue] Resetting ${processingJobs.length} stuck processing jobs to waiting');

    final updatedQueue = List<QueuedTranscriptionJob>.from(currentQueue);
    final now = DateTime.now();

    for (final job in processingJobs) {
      final jobIndex = updatedQueue.indexWhere((j) => j.id == job.id);
      if (jobIndex != -1) {
        updatedQueue[jobIndex] = job.copyWith(
          status: QueuedTranscriptionJobStatus.waiting,
          updatedAt: now,
        );
        debugPrint('[Queue] Reset job ${job.id} from processing to waiting');
      }
    }

    // Update state and save
    _emitStateWithUpdatedQueue(emit, updatedQueue);
    await _saveQueue(updatedQueue);

    // Resume processing
    await _processNextQueuedJob(emit);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      // Stop speed tests when app goes to background
      debugPrint('[SpeedTest] App paused: stopping monitoring');
      _stopSpeedTestMonitoring();

      // Handle transcription jobs - save queue state
      _handleAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      // Resume speed tests if we should be monitoring (recording is active)
      debugPrint('[SpeedTest] App resumed: shouldMonitor=$_shouldMonitorSpeed');
      if (_shouldMonitorSpeed) {
        debugPrint('[SpeedTest] Resuming monitoring');
        _startSpeedTestMonitoring();
      }

      // Resume transcription jobs
      _handleAppResumed();
    }
  }

  void _handleAppPaused() {
    // Save queue state before pausing to prevent data loss
    try {
      _saveQueue(state.queue);
      debugPrint(
          '[Queue] App paused - queue state saved (${state.queue.length} jobs)');
    } catch (e) {
      debugPrint('[Queue] Failed to save queue on pause: $e');
    }
  }

  void _handleAppResumed() {
    // Clear potentially stale cloud job state
    // Cloud job subscription may be stale after app pause
    if (_activeCloudJobId != null) {
      debugPrint(
          '[Queue] App resumed - clearing stale cloud job: $_activeCloudJobId');
      _activeCloudJobId = null;
      _cloudJobSubscription?.cancel();
      _cloudJobSubscription = null;
    }

    // Check for stuck processing jobs and trigger resume event
    final currentQueue = state.queue;
    final processingJobs = currentQueue
        .where(
          (job) => job.status == QueuedTranscriptionJobStatus.processing,
        )
        .toList();

    final hasWaitingJobs = currentQueue.any(
      (job) => job.status == QueuedTranscriptionJobStatus.waiting,
    );

    if (processingJobs.isNotEmpty || hasWaitingJobs) {
      debugPrint(
          '[Queue] App resumed - found ${processingJobs.length} processing jobs and ${hasWaitingJobs ? "waiting" : "no waiting"} jobs');
      // Trigger resume event to reset stuck jobs and continue processing
      add(const ResumeProcessingAfterPause());
    }
  }

  @override
  Future<void> close() async {
    _stopRecordingTicker();
    _stopMonitoringInputLevels();
    _stopSpeedTestMonitoring();
    await _cloudJobSubscription?.cancel();
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    await _recorder.dispose();
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    return super.close();
  }
}
