import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/network/network_info.dart';
import '../../domain/entities/tts_job.dart';
import '../../domain/repositories/tts_repository.dart';
import '../../domain/usecases/convert_pdf_to_audio.dart';
import '../../domain/usecases/convert_text_to_audio.dart';
import '../../utils/tts_error_mapper.dart';
import 'tts_event.dart';
import 'tts_state.dart';

@lazySingleton
class TtsBloc extends Bloc<TtsEvent, TtsState> {
  TtsBloc(
    this._convertPdfToAudio,
    this._convertTextToAudio,
    this._repository,
    this._networkInfo,
  ) : super(const TtsInitial()) {
    on<ConvertPdfToAudioEvent>(_onConvertPdfToAudio);
    on<ConvertTextToAudioEvent>(_onConvertTextToAudio);
    on<LoadTtsJobsEvent>(_onLoadTtsJobs);
    on<PlayAudioEvent>(_onPlayAudio);
    on<PauseAudioEvent>(_onPauseAudio);
    on<StopAudioEvent>(_onStopAudio);
    on<DeleteTtsJobEvent>(_onDeleteTtsJob);
    on<ProcessQueuedJobsEvent>(_onProcessQueuedJobs);
    on<_UpdatePlayingStateEvent>(_onUpdatePlayingState);
    on<StartPollingEvent>(_onStartPolling);
    on<StopPollingEvent>(_onStopPolling);
    on<JobStatusUpdatedEvent>(_onJobStatusUpdated);
    on<RetryTtsJobEvent>(_onRetryTtsJob);

    // Listen to connectivity changes to auto-process queued jobs
    _connectivitySubscription = _networkInfo.onStatusChange.listen(
      _onConnectivityChanged,
    );
  }

  final ConvertPdfToAudio _convertPdfToAudio;
  final ConvertTextToAudio _convertTextToAudio;
  final TtsRepository _repository;
  final NetworkInfo _networkInfo;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<TtsJob> _jobs = <TtsJob>[];
  String? _currentAudioUrl;
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<bool>? _connectivitySubscription;
  bool _isClosed = false;
  bool _wasOffline = false;

  /// Timer for polling processing jobs
  Timer? _pollingTimer;

  /// Polling interval in seconds
  static const int _pollingIntervalSeconds = 5;

  @override
  Future<void> close() {
    _isClosed = true;
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _playerStateSubscription?.cancel();
    _playerStateSubscription = null;
    _audioPlayer.dispose();
    return super.close();
  }

  /// Handles connectivity changes to auto-process queued jobs
  void _onConnectivityChanged(bool isConnected) {
    if (_isClosed) return;

    if (isConnected && _wasOffline) {
      // Network returned after being offline - process queued jobs
      add(const ProcessQueuedJobsEvent());
    }

    _wasOffline = !isConnected;
  }

  Future<void> _onConvertPdfToAudio(
    ConvertPdfToAudioEvent event,
    Emitter<TtsState> emit,
  ) async {
    if (_isClosed) return; // Guard against operations after bloc is closed

    // Emit processing state with estimated time
    // PDF conversion typically takes 1-3 minutes depending on size
    emit(TtsProcessing(
      jobs: List.unmodifiable(_jobs),
      statusMessage: 'Extracting text from PDF...',
      estimatedSeconds: 120, // Estimate ~2 minutes for PDF processing
    ));

    final result = await _convertPdfToAudio(
      pdfUrl: event.pdfUrl,
      voice: event.voice,
    );

    result.fold(
      (failure) {
        if (_isClosed) return; // Guard against emits after bloc is closed

        final rawMessage = failure.message ?? 'Failed to convert PDF to audio';
        // Check if request was queued
        if (rawMessage.contains('queued') || rawMessage.contains('Queued')) {
          emit(
            TtsQueued(
              message: rawMessage,
              jobs: List.unmodifiable(_jobs),
            ),
          );
        } else {
          emit(
            TtsError(
              message: TtsErrorMapper.toFriendlyMessage(rawMessage),
              jobs: List.unmodifiable(_jobs),
            ),
          );
        }
      },
      (job) {
        if (_isClosed) return; // Guard against emits after bloc is closed

        _jobs.insert(0, job);
        emit(
          TtsSuccess(
            job: job,
            jobs: List.unmodifiable(_jobs),
          ),
        );

        // Start polling if job is still processing
        if (job.status == 'processing') {
          add(const StartPollingEvent());
        }
      },
    );
  }

  Future<void> _onConvertTextToAudio(
    ConvertTextToAudioEvent event,
    Emitter<TtsState> emit,
  ) async {
    if (_isClosed) return; // Guard against operations after bloc is closed

    // Calculate estimated time based on text length
    // Approximately 150 words per minute speaking rate
    // Average word is ~5 characters, so ~750 chars/minute
    // Processing overhead adds ~30 seconds for short texts, more for longer
    final textLength = event.text.length;
    final estimatedMinutes = (textLength / 750).ceil();
    final processingOverhead = textLength > 100000 ? 60 : 30; // Longer for batch processing
    final estimatedSeconds = (estimatedMinutes * 60) + processingOverhead;

    emit(TtsProcessing(
      jobs: List.unmodifiable(_jobs),
      statusMessage: 'Generating audio...',
      estimatedSeconds: estimatedSeconds.clamp(30, 600), // Between 30s and 10min
    ));

    final result = await _convertTextToAudio(
      text: event.text,
      voice: event.voice,
    );

    result.fold(
      (failure) {
        if (_isClosed) return; // Guard against emits after bloc is closed

        final rawMessage = failure.message ?? 'Failed to convert text to audio';
        // Check if request was queued
        if (rawMessage.contains('queued') || rawMessage.contains('Queued')) {
          emit(
            TtsQueued(
              message: rawMessage,
              jobs: List.unmodifiable(_jobs),
            ),
          );
        } else {
          emit(
            TtsError(
              message: TtsErrorMapper.toFriendlyMessage(rawMessage),
              jobs: List.unmodifiable(_jobs),
            ),
          );
        }
      },
      (job) {
        if (_isClosed) return; // Guard against emits after bloc is closed

        _jobs.insert(0, job);
        emit(
          TtsSuccess(
            job: job,
            jobs: List.unmodifiable(_jobs),
          ),
        );

        // Start polling if job is still processing
        if (job.status == 'processing') {
          add(const StartPollingEvent());
        }
      },
    );
  }

  Future<void> _onLoadTtsJobs(
    LoadTtsJobsEvent event,
    Emitter<TtsState> emit,
  ) async {
    if (_isClosed) return; // Guard against operations after bloc is closed

    final result = await _repository.getAllTtsJobs();

    result.fold(
      (failure) {
        if (_isClosed) return; // Guard against emits after bloc is closed
        emit(
          TtsError(
            message: failure.message ?? 'Failed to load TTS jobs',
            jobs: List.unmodifiable(_jobs),
          ),
        );
      },
      (jobs) {
        if (_isClosed) return; // Guard against emits after bloc is closed
        _jobs.clear();
        _jobs.addAll(jobs);
        emit(TtsInitial(jobs: List.unmodifiable(_jobs)));

        // Start polling if there are any processing jobs
        final hasProcessingJobs = _jobs.any((j) => j.status == 'processing');
        if (hasProcessingJobs) {
          add(const StartPollingEvent());
        }
      },
    );
  }

  Future<void> _onPlayAudio(
    PlayAudioEvent event,
    Emitter<TtsState> emit,
  ) async {
    if (_isClosed) return; // Guard against operations after bloc is closed

    try {
      if (_currentAudioUrl != event.audioUrl) {
        await _audioPlayer.stop();
        await _audioPlayer.play(UrlSource(event.audioUrl));
        _currentAudioUrl = event.audioUrl;
      } else {
        await _audioPlayer.resume();
      }

      _playerStateSubscription?.cancel();
      _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen(
        (state) {
          if (_isClosed) return; // Guard against emits after bloc is closed

          if (state == PlayerState.playing) {
            add(const _UpdatePlayingStateEvent(isPlaying: true));
          } else if (state == PlayerState.paused) {
            add(const _UpdatePlayingStateEvent(isPlaying: false));
          } else if (state == PlayerState.completed) {
            add(const _UpdatePlayingStateEvent(isPlaying: false));
          }
        },
      );

      if (!_isClosed) {
        emit(
          TtsPlaying(
            currentAudioUrl: event.audioUrl,
            isPlaying: true,
            jobs: List.unmodifiable(_jobs),
          ),
        );
      }
    } catch (error) {
      if (!_isClosed) {
        emit(
          TtsError(
            message: 'Failed to play audio: $error',
            jobs: List.unmodifiable(_jobs),
          ),
        );
      }
    }
  }

  Future<void> _onPauseAudio(
    PauseAudioEvent event,
    Emitter<TtsState> emit,
  ) async {
    if (_isClosed) return; // Guard against operations after bloc is closed

    try {
      await _audioPlayer.pause();
      if (!_isClosed && state is TtsPlaying) {
        emit(
          TtsPlaying(
            currentAudioUrl: (state as TtsPlaying).currentAudioUrl,
            isPlaying: false,
            jobs: List.unmodifiable(_jobs),
          ),
        );
      }
    } catch (error) {
      if (!_isClosed) {
        emit(
          TtsError(
            message: 'Failed to pause audio: $error',
            jobs: List.unmodifiable(_jobs),
          ),
        );
      }
    }
  }

  Future<void> _onStopAudio(
    StopAudioEvent event,
    Emitter<TtsState> emit,
  ) async {
    if (_isClosed) return; // Guard against operations after bloc is closed

    try {
      await _audioPlayer.stop();
      _currentAudioUrl = null;
      _playerStateSubscription?.cancel();
      _playerStateSubscription = null;

      if (!_isClosed) {
        emit(TtsInitial(jobs: List.unmodifiable(_jobs)));
      }
    } catch (error) {
      if (!_isClosed) {
        emit(
          TtsError(
            message: 'Failed to stop audio: $error',
            jobs: List.unmodifiable(_jobs),
          ),
        );
      }
    }
  }

  Future<void> _onDeleteTtsJob(
    DeleteTtsJobEvent event,
    Emitter<TtsState> emit,
  ) async {
    if (_isClosed) return; // Guard against operations after bloc is closed

    final result = await _repository.deleteTtsJob(event.jobId);

    result.fold(
      (failure) {
        if (_isClosed) return; // Guard against emits after bloc is closed
        emit(
          TtsError(
            message: failure.message ?? 'Failed to delete TTS job',
            jobs: List.unmodifiable(_jobs),
          ),
        );
      },
      (_) {
        if (_isClosed) return; // Guard against emits after bloc is closed
        _jobs.removeWhere((j) => j.id == event.jobId);
        emit(TtsInitial(jobs: List.unmodifiable(_jobs)));
      },
    );
  }

  Future<void> _onProcessQueuedJobs(
    ProcessQueuedJobsEvent event,
    Emitter<TtsState> emit,
  ) async {
    if (_isClosed) return; // Guard against operations after bloc is closed

    emit(TtsProcessing(jobs: List.unmodifiable(_jobs)));

    try {
      await _repository.processQueuedTtsJobs();
      // Reload jobs to show newly processed ones
      if (!_isClosed) {
        add(const LoadTtsJobsEvent());
      }
    } catch (error) {
      if (!_isClosed) {
        emit(
          TtsError(
            message: 'Failed to process queued jobs: $error',
            jobs: List.unmodifiable(_jobs),
          ),
        );
      }
    }
  }

  void _onUpdatePlayingState(
    _UpdatePlayingStateEvent event,
    Emitter<TtsState> emit,
  ) {
    if (_isClosed) return; // Guard against emits after bloc is closed

    if (state is TtsPlaying) {
      final currentState = state as TtsPlaying;
      emit(
        TtsPlaying(
          currentAudioUrl: currentState.currentAudioUrl,
          isPlaying: event.isPlaying,
          jobs: List.unmodifiable(_jobs),
        ),
      );
    }
  }

  /// Starts polling for processing job status updates
  void _onStartPolling(
    StartPollingEvent event,
    Emitter<TtsState> emit,
  ) {
    if (_isClosed) return;

    // Don't start if already polling
    if (_pollingTimer != null && _pollingTimer!.isActive) return;

    // Check if there are any processing jobs
    final hasProcessingJobs = _jobs.any((j) => j.status == 'processing');
    if (!hasProcessingJobs) return;

    _pollingTimer = Timer.periodic(
      Duration(seconds: _pollingIntervalSeconds),
      (_) => _pollProcessingJobs(),
    );
  }

  /// Stops polling for job status updates
  void _onStopPolling(
    StopPollingEvent event,
    Emitter<TtsState> emit,
  ) {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Polls the server for status updates on processing jobs
  Future<void> _pollProcessingJobs() async {
    if (_isClosed) {
      _pollingTimer?.cancel();
      return;
    }

    final processingJobs = _jobs.where((j) => j.status == 'processing').toList();

    // No processing jobs, stop polling
    if (processingJobs.isEmpty) {
      add(const StopPollingEvent());
      return;
    }

    // Poll each processing job
    for (final job in processingJobs) {
      final result = await _repository.getTtsJob(job.id);
      result.fold(
        (failure) {
          // Silently ignore poll failures - will retry on next interval
        },
        (updatedJob) {
          if (updatedJob.status != job.status) {
            // Status changed, trigger update
            add(JobStatusUpdatedEvent(job.id));
          }
        },
      );
    }
  }

  /// Handles job status updates from polling
  Future<void> _onJobStatusUpdated(
    JobStatusUpdatedEvent event,
    Emitter<TtsState> emit,
  ) async {
    if (_isClosed) return;

    final result = await _repository.getTtsJob(event.jobId);

    result.fold(
      (failure) {
        // Ignore - job may have been deleted
      },
      (updatedJob) {
        if (_isClosed) return;

        // Find and update the job in our list
        final index = _jobs.indexWhere((j) => j.id == event.jobId);
        if (index >= 0) {
          _jobs[index] = updatedJob;

          // If job completed or failed, emit success/error notification
          if (updatedJob.status == 'completed') {
            emit(
              TtsSuccess(
                job: updatedJob,
                jobs: List.unmodifiable(_jobs),
              ),
            );

            // Check if we should stop polling
            final hasProcessingJobs = _jobs.any((j) => j.status == 'processing');
            if (!hasProcessingJobs) {
              add(const StopPollingEvent());
            }
          } else if (updatedJob.status == 'failed') {
            emit(
              TtsError(
                message: updatedJob.errorMessage ?? 'Conversion failed',
                jobs: List.unmodifiable(_jobs),
              ),
            );

            // Check if we should stop polling
            final hasProcessingJobs = _jobs.any((j) => j.status == 'processing');
            if (!hasProcessingJobs) {
              add(const StopPollingEvent());
            }
          } else {
            // Still processing, just update the list
            emit(TtsInitial(jobs: List.unmodifiable(_jobs)));
          }
        }
      },
    );
  }

  /// Retries a failed TTS job
  Future<void> _onRetryTtsJob(
    RetryTtsJobEvent event,
    Emitter<TtsState> emit,
  ) async {
    if (_isClosed) return;

    // Find the failed job
    final jobIndex = _jobs.indexWhere((j) => j.id == event.jobId);
    if (jobIndex < 0) {
      emit(
        TtsError(
          message: 'Job not found',
          jobs: List.unmodifiable(_jobs),
        ),
      );
      return;
    }

    final failedJob = _jobs[jobIndex];
    if (failedJob.status != 'failed') {
      emit(
        TtsError(
          message: 'Can only retry failed jobs',
          jobs: List.unmodifiable(_jobs),
        ),
      );
      return;
    }

    // Determine source type and retry
    if (failedJob.sourceType == 'pdf') {
      // Re-convert PDF (sourceId contains the PDF URL)
      add(ConvertPdfToAudioEvent(
        pdfUrl: failedJob.sourceId,
        voice: failedJob.voice ?? 'en-US-Neural2-D',
      ));
    } else if (failedJob.sourceType == 'text') {
      // Re-convert text (sourceId contains the text content)
      add(ConvertTextToAudioEvent(
        text: failedJob.sourceId,
        voice: failedJob.voice ?? 'en-US-Neural2-D',
      ));
    } else {
      emit(
        TtsError(
          message: 'Unknown source type: ${failedJob.sourceType}',
          jobs: List.unmodifiable(_jobs),
        ),
      );
    }

    // Remove the old failed job from the list
    _jobs.removeAt(jobIndex);
    await _repository.deleteTtsJob(event.jobId);
  }
}

// Internal event for updating playing state
class _UpdatePlayingStateEvent extends TtsEvent {
  const _UpdatePlayingStateEvent({required this.isPlaying});

  final bool isPlaying;

  @override
  List<Object?> get props => [isPlaying];
}
