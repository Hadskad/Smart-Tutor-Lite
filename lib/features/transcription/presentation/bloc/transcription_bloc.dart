import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../native_bridge/performance_bridge.dart';
import '../../domain/entities/transcription.dart';
import '../../domain/entities/transcription_job.dart';
import '../../domain/entities/transcription_job_request.dart';
import '../../domain/repositories/transcription_repository.dart';
import '../../domain/usecases/cancel_transcription_job.dart';
import '../../domain/usecases/create_transcription_job.dart';
import '../../domain/usecases/request_transcription_job_retry.dart';
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

@injectable
class TranscriptionBloc extends Bloc<TranscriptionEvent, TranscriptionState> {
  TranscriptionBloc(
    this._transcribeAudio,
    this._performanceBridge,
    this._transcriptionRepository,
    this._networkInfo,
    this._createTranscriptionJob,
    this._watchTranscriptionJob,
    this._cancelTranscriptionJob,
    this._requestTranscriptionJobRetry,
  ) : super(const TranscriptionInitial()) {
    on<LoadTranscriptions>(_onLoad);
    on<StartRecording>(_onStartRecording);
    on<StopRecording>(_onStopRecording);
    on<TranscribeAudio>(_onTranscribeAudio);
    on<RecordingMetricsUpdated>(_onRecordingMetricsUpdated);
    on<TranscriptionJobSnapshotReceived>(_onTranscriptionJobSnapshot);
    on<CancelCloudTranscription>(_onCancelCloudTranscription);
    on<RetryCloudTranscription>(_onRetryCloudTranscription);
  }

  final usecase.TranscribeAudio _transcribeAudio;
  final PerformanceBridge _performanceBridge;
  final TranscriptionRepository _transcriptionRepository;
  final NetworkInfo _networkInfo;
  final CreateTranscriptionJob _createTranscriptionJob;
  final WatchTranscriptionJob _watchTranscriptionJob;
  final CancelTranscriptionJob _cancelTranscriptionJob;
  final RequestTranscriptionJobRetry _requestTranscriptionJobRetry;
  final AudioRecorder _recorder = AudioRecorder();
  final Uuid _uuid = const Uuid();
  String? _currentRecordingPath;
  String? _lastRecordedFilePath;
  DateTime? _recordingStartedAt;
  final List<Transcription> _history = <Transcription>[];
  Timer? _recordingTicker;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  StreamSubscription<Either<Failure, TranscriptionJob>>?
      _cloudJobSubscription;
  String? _activeCloudJobId;
  bool _isInputTooLow = false;
  int _silenceTicks = 0;

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
          ),
        ),
        (transcriptions) {
          _history
            ..clear()
            ..addAll(transcriptions);
          emit(
            TranscriptionInitial(
              history: List.unmodifiable(_history),
            ),
          );
        },
      );
    } catch (error) {
      emit(
        TranscriptionError(
          message: 'Failed to load transcriptions',
          history: List.unmodifiable(_history),
        ),
      );
    }
  }

  Future<void> _onStartRecording(
    StartRecording event,
    Emitter<TranscriptionState> emit,
  ) async {
    if (_activeCloudJobId != null) {
      emit(
        TranscriptionNotice(
          message: 'Cloud transcription still running. Please wait or cancel it before recording again.',
          severity: TranscriptionNoticeSeverity.warning,
          history: List.unmodifiable(_history),
        ),
      );
      return;
    }
    if (await _recorder.isRecording()) {
      return;
    }

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      emit(
        TranscriptionError(
          message: 'Microphone permission denied',
          history: List.unmodifiable(_history),
        ),
      );
      return;
    }

    final tempDir = await getTemporaryDirectory();
    final filePath = p.join(
      tempDir.path,
      'transcription_${_uuid.v4()}.m4a',
    );

    try {
      await _recorder.start(
        RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 44100,
          numChannels: 1,
          bitRate: _kRecordingBitrate,
        ),
        path: filePath,
      );
      _currentRecordingPath = filePath;
      _lastRecordedFilePath = filePath;
      _recordingStartedAt = DateTime.now();
      _isInputTooLow = false;
      _silenceTicks = 0;
      _startRecordingTicker();
      _startMonitoringInputLevels();
      emit(
        TranscriptionRecording(
          startedAt: _recordingStartedAt!,
          filePath: _currentRecordingPath,
          estimatedSizeBytes: 0,
          isInputTooLow: false,
          history: List.unmodifiable(_history),
        ),
      );
    } catch (error) {
      _stopRecordingTicker();
      _stopMonitoringInputLevels();
      emit(
        TranscriptionError(
          message: error.toString(),
          history: List.unmodifiable(_history),
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
          ),
        );
        return;
      }
      final startedAt = _recordingStartedAt;
      final duration =
          startedAt != null ? DateTime.now().difference(startedAt) : Duration.zero;
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

      final hasNetwork = await _networkInfo.isConnected;
      var startedCloud = false;
      if (hasNetwork) {
        startedCloud = await _startCloudTranscriptionJob(
          audioPath: audioPath,
          duration: duration,
          fileSizeBytes: fileSizeBytes,
          emit: emit,
        );
      }
      if (!startedCloud) {
        add(TranscribeAudio(audioPath));
      }
    } catch (error) {
      emit(
        TranscriptionError(
          message: 'Failed to stop recording',
          history: List.unmodifiable(_history),
        ),
      );
    } finally {
      _stopRecordingTicker();
      _stopMonitoringInputLevels();
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
      ),
    );

    await _performanceBridge.startSegment('transcription');

    try {
      final hasNetwork = await _networkInfo.isConnected;
      if (!hasNetwork) {
        _emitNotice(
          emit,
          'No internet connection detected. Using on-device transcription.',
          severity: TranscriptionNoticeSeverity.warning,
        );
      }
      final result = await _transcribeAudio(audioPath);
      final metrics = await _performanceBridge.endSegment('transcription');
      result.fold(
        (failure) => emit(
          TranscriptionError(
            message: failure.message ?? 'Transcription failed',
            history: List.unmodifiable(_history),
          ),
        ),
        (transcription) {
          _history.insert(0, transcription);
          _lastRecordedFilePath = null;
          emit(
            TranscriptionSuccess(
              transcription: transcription,
              history: List.unmodifiable(_history),
              metrics: metrics,
            ),
          );
        },
      );
    } catch (error) {
      await _performanceBridge.endSegment('transcription');
      emit(
        TranscriptionError(
          message: 'Unable to process audio',
          history: List.unmodifiable(_history),
        ),
      );
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
    final result = await _createTranscriptionJob(request);
    return result.fold(
      (failure) {
        _emitNotice(
          emit,
          failure.message ??
              'Cloud transcription is unavailable. Falling back to on-device mode.',
          severity: TranscriptionNoticeSeverity.warning,
        );
        return false;
      },
      (job) {
        _activeCloudJobId = job.id;
        _listenToCloudJob(job.id);
        emit(
          CloudTranscriptionState(
            job: job,
            history: List.unmodifiable(_history),
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
    if (job.status == TranscriptionJobStatus.done &&
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
            ),
          );
        },
        (transcription) async {
          _history.insert(0, transcription);
          emit(
            TranscriptionSuccess(
              transcription: transcription,
              history: List.unmodifiable(_history),
              metrics: null,
            ),
          );
          await _deleteRecordedFile();
        },
      );
    } else if (job.status == TranscriptionJobStatus.error) {
      emit(
        TranscriptionError(
          message: job.errorMessage ?? 'Cloud transcription failed.',
          history: List.unmodifiable(_history),
        ),
      );
    }
  }

  Future<void> _onTranscriptionJobSnapshot(
    TranscriptionJobSnapshotReceived event,
    Emitter<TranscriptionState> emit,
  ) async {
    await event.result.fold(
      (failure) async {
        emit(
          TranscriptionError(
            message: failure.message ?? 'Cloud transcription failed',
            history: List.unmodifiable(_history),
          ),
        );
      },
      (job) async {
        emit(
          CloudTranscriptionState(
            job: job,
            history: List.unmodifiable(_history),
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
        ),
      ),
      (_) => _emitNotice(
        emit,
        'Cloud transcription cancelled.',
      ),
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
        ),
      ),
      (_) => _emitNotice(
        emit,
        'Retry requested. We will attempt to rerun the transcription shortly.',
      ),
    );
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
      ),
    );
  }

  @override
  Future<void> close() async {
    _stopRecordingTicker();
    _stopMonitoringInputLevels();
    await _cloudJobSubscription?.cancel();
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    await _recorder.dispose();
    return super.close();
  }
}
