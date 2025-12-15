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
import '../../domain/usecases/cancel_transcription_job.dart';
import '../../domain/usecases/create_transcription_job.dart';
import '../../domain/usecases/request_transcription_job_retry.dart';
import '../../domain/usecases/request_note_retry.dart';
import '../../domain/usecases/transcribe_audio.dart' as usecase;
import '../../domain/usecases/watch_transcription_job.dart';
import 'transcription_event.dart';
import 'transcription_state.dart';

const _kRecordingBitrate = 64000; // bits per second (~64 kbps AAC)
const _kMinRecordingDuration = Duration(seconds: 3);
const _kMinRecordingSizeBytes = 16 * 1024; // 16 KB guard against silence
const _kExtremeRecordingDuration = Duration(hours: 4);
const _kExtremeRecordingSizeBytes = 1024 * 1024 * 1024; // 1 GB
const _kSilenceThresholdDb = -45.0;
const _kSilenceTickTrigger = 6; // 3s at 500ms interval
const _kAmplitudeSampleInterval = Duration(milliseconds: 500);

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

@injectable
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

    add(const LoadTranscriptionPreferences());

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
            message: failure.message ?? 'Failed to load transcriptions',
            history: List.unmodifiable(_history),
            preferences: _preferences,
            queueLength: _processingQueue.length,
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
              queueLength: _processingQueue.length,
            ),
          );
        },
      );
    } catch (error) {
      emit(
        TranscriptionError(
          message: 'Failed to load transcriptions',
          history: List.unmodifiable(_history),
          preferences: _preferences,
          queueLength: _processingQueue.length,
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
    final queueLen = _processingQueue.length;
    if (current is TranscriptionRecording) {
      emit(
        current.copyWith(
          history: current.history,
          preferences: _preferences,
          queueLength: queueLen,
        ),
      );
    } else if (current is TranscriptionProcessing) {
      emit(
        TranscriptionProcessing(
          audioPath: current.audioPath,
          history: current.history,
          preferences: _preferences,
          queueLength: queueLen,
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
        ),
      );
    } else if (current is TranscriptionError) {
      emit(
        TranscriptionError(
          message: current.message,
          history: current.history,
          preferences: _preferences,
          queueLength: queueLen,
        ),
      );
    } else if (current is CloudTranscriptionState) {
      emit(
        CloudTranscriptionState(
          job: current.job,
          history: current.history,
          preferences: _preferences,
          queueLength: queueLen,
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
        ),
      );
    } else {
      emit(
        TranscriptionInitial(
          history: List.unmodifiable(_history),
          preferences: _preferences,
          queueLength: queueLen,
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
          queueLength: _processingQueue.length,
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
        queueLength: _processingQueue.length,
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
          queueLength: _processingQueue.length,
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
          queueLength: _processingQueue.length,
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

    try {
      final path = await _recorder.stop();
      final audioPath = path ?? _currentRecordingPath;
      if (audioPath == null || !File(audioPath).existsSync()) {
        emit(
          TranscriptionError(
            message: 'Recording failed. Please try again.',
            history: List.unmodifiable(_history),
            preferences: _preferences,
            queueLength: _processingQueue.length,
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
            queueLength: _processingQueue.length,
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
            queueLength: _processingQueue.length,
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
        // Queue the audio for processing later
        final queuedAudio = QueuedAudio(
          audioPath: audioPath,
          duration: duration,
          fileSizeBytes: fileSizeBytes,
          plannedExecutionMode: _plannedExecutionMode,
          timestamp: DateTime.now(),
        );
        _processingQueue.add(queuedAudio);

        _emitNotice(
          emit,
          'Recording saved. ${_processingQueue.length} audio(s) in queue.',
          severity: TranscriptionNoticeSeverity.info,
        );
      } else {
        // Process immediately
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
          message: 'Failed to stop recording',
          history: List.unmodifiable(_history),
          preferences: _preferences,
          queueLength: _processingQueue.length,
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
    emit(
      TranscriptionProcessing(
        audioPath: audioPath,
        history: List.unmodifiable(_history),
        preferences: _preferences,
        queueLength: _processingQueue.length,
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
        (failure) {
          emit(
            TranscriptionError(
              message: failure.message ?? 'Transcription failed',
              history: List.unmodifiable(_history),
              preferences: _preferences,
              queueLength: _processingQueue.length,
            ),
          );
          // Process next queued audio after error
          _processNextQueuedAudio(emit);
        },
        (transcription) {
          _history.insert(0, transcription);
          _deleteRecordedFile();
          emit(
            TranscriptionSuccess(
              transcription: transcription,
              history: List.unmodifiable(_history),
              metrics: metrics,
              preferences: _preferences,
              queueLength: _processingQueue.length,
            ),
          );
          // Process next queued audio after success
          _processNextQueuedAudio(emit);
        },
      );
    } catch (error) {
      await _performanceBridge.endSegment('transcription');
      emit(
        TranscriptionError(
          message: 'Unable to process audio',
          history: List.unmodifiable(_history),
          preferences: _preferences,
          queueLength: _processingQueue.length,
        ),
      );
      // Process next queued audio after error
      _processNextQueuedAudio(emit);
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
        _lastCloudFailureMessage =
            failure.message ?? 'Cloud transcription is unavailable.';
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
            queueLength: _processingQueue.length,
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
    if (job.status == TranscriptionJobStatus.completed &&
        job.transcriptId != null) {
      final result =
          await _transcriptionRepository.getTranscription(job.transcriptId!);
      await result.fold(
        (failure) async {
          emit(
            TranscriptionError(
              message: failure.message ??
                  'Cloud transcription completed but note is unavailable.',
              history: List.unmodifiable(_history),
              preferences: _preferences,
              queueLength: _processingQueue.length,
            ),
          );
          // Process next queued audio after error
          await _processNextQueuedAudio(emit);
        },
        (transcription) async {
          _history.insert(0, transcription);
          emit(
            TranscriptionSuccess(
              transcription: transcription,
              history: List.unmodifiable(_history),
              metrics: null,
              preferences: _preferences,
              queueLength: _processingQueue.length,
            ),
          );
          await _deleteRecordedFile();
          // Process next queued audio after success
          await _processNextQueuedAudio(emit);
        },
      );
    } else if (job.status == TranscriptionJobStatus.error) {
      _lastCloudFailureMessage =
          job.errorMessage ?? 'Cloud transcription failed.';
      _promptOfflineFallback(
        emit,
        reason: _lastCloudFailureMessage,
      );
      // Process next queued audio after error
      await _processNextQueuedAudio(emit);
    }
  }

  Future<void> _onTranscriptionJobSnapshot(
    TranscriptionJobSnapshotReceived event,
    Emitter<TranscriptionState> emit,
  ) async {
    await event.result.fold(
      (failure) async {
        _lastCloudFailureMessage =
            failure.message ?? 'Cloud transcription failed.';
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
            queueLength: _processingQueue.length,
          ),
        );
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
          message: failure.message ?? 'Unable to cancel cloud transcription',
          history: List.unmodifiable(_history),
          preferences: _preferences,
          queueLength: _processingQueue.length,
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
          message: failure.message ?? 'Unable to request retry',
          history: List.unmodifiable(_history),
          preferences: _preferences,
          queueLength: _processingQueue.length,
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
    final result = await _requestNoteRetry(event.jobId);
    result.fold(
      (failure) => emit(
        TranscriptionError(
          message: failure.message ?? 'Unable to retry note generation',
          history: List.unmodifiable(_history),
          preferences: _preferences,
          queueLength: _processingQueue.length,
        ),
      ),
      (_) => _emitNotice(
        emit,
        'Retrying smart note generation...',
      ),
    );
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
            message: failure.message ?? 'Failed to delete transcription',
            history: List.unmodifiable(_history),
            preferences: _preferences,
            queueLength: _processingQueue.length,
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
            queueLength: _processingQueue.length,
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
            message: failure.message ?? 'Failed to update transcription',
            history: List.unmodifiable(_history),
            preferences: _preferences,
            queueLength: _processingQueue.length,
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
            queueLength: _processingQueue.length,
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
            queueLength: _processingQueue.length,
          ),
        );
        return;
      }

      // Find transcription in history
      final transcription = _history.firstWhere(
        (t) => t.id == event.id,
        orElse: () => throw Exception('Transcription not found'),
      );

      // Check if transcription has text
      if (transcription.text.trim().isEmpty) {
        emit(
          TranscriptionError(
            message: 'Cannot format note: transcription text is empty',
            history: List.unmodifiable(_history),
            preferences: _preferences,
            queueLength: _processingQueue.length,
          ),
        );
        return;
      }

      // Note: We don't emit TranscriptionProcessing state here because:
      // 1. It requires audioPath which we don't have in this context
      // 2. The UI already shows a loading indicator based on _isFormatting
      // 3. Formatting is quick (just an API call) unlike audio processing

      final result = await _transcriptionRepository.formatNote(event.id);
      await result.fold(
        (failure) async {
          emit(
            TranscriptionError(
              message: failure.message ?? 'Failed to format note',
              history: List.unmodifiable(_history),
              preferences: _preferences,
              queueLength: _processingQueue.length,
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
          // Emit success with updated history
          emit(
            TranscriptionSuccess(
              transcription: formattedTranscription,
              history: List.unmodifiable(_history),
              metrics: null,
              preferences: _preferences,
              queueLength: _processingQueue.length,
            ),
          );
        },
      );
    } catch (error) {
      emit(
        TranscriptionError(
          message: error.toString(),
          history: List.unmodifiable(_history),
          preferences: _preferences,
          queueLength: _processingQueue.length,
        ),
      );
    }
  }

  String _resolveUserId() {
    // TODO: integrate with authenticated user profile when available.
    return 'local_user';
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
        queueLength: _processingQueue.length,
      ),
    );
  }

  Future<void> _processNextQueuedAudio(Emitter<TranscriptionState> emit) async {
    // Only process if queue has items and no processing is currently active
    if (_processingQueue.isEmpty) {
      return;
    }

    final isProcessingActive =
        _activeCloudJobId != null || state is TranscriptionProcessing;
    if (isProcessingActive) {
      return;
    }

    // Dequeue the next audio file
    final queuedAudio = _processingQueue.removeFirst();

    debugPrint(
        '[Queue] Processing next audio. ${_processingQueue.length} remaining in queue.');

    // Set fallback context for the queued audio
    _setFallbackContext(
      audioPath: queuedAudio.audioPath,
      duration: queuedAudio.duration,
      fileSizeBytes: queuedAudio.fileSizeBytes,
    );

    // Process based on the planned execution mode
    if (queuedAudio.plannedExecutionMode == TranscriptionExecutionMode.online) {
      final hasNetwork = await _networkInfo.isConnected;
      if (hasNetwork) {
        final startedCloud = await _startCloudTranscriptionJob(
          audioPath: queuedAudio.audioPath,
          duration: queuedAudio.duration,
          fileSizeBytes: queuedAudio.fileSizeBytes,
          emit: emit,
        );

        if (!startedCloud) {
          // Fallback to offline if cloud fails
          _promptOfflineFallback(
            emit,
            reason: _lastCloudFailureMessage ??
                'Cloud transcription is unavailable. Switch to on-device mode?',
          );
        }
      } else {
        // No network, fallback to offline
        _startOfflineTranscription(queuedAudio.audioPath);
      }
    } else {
      // Offline mode
      _startOfflineTranscription(queuedAudio.audioPath);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      // Stop speed tests when app goes to background
      debugPrint('[SpeedTest] App paused: stopping monitoring');
      _stopSpeedTestMonitoring();
    } else if (state == AppLifecycleState.resumed) {
      // Resume speed tests if we should be monitoring (recording is active)
      debugPrint('[SpeedTest] App resumed: shouldMonitor=$_shouldMonitorSpeed');
      if (_shouldMonitorSpeed) {
        debugPrint('[SpeedTest] Resuming monitoring');
        _startSpeedTestMonitoring();
      }
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
