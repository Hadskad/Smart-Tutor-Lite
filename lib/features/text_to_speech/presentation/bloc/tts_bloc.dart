import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/tts_job.dart';
import '../../domain/repositories/tts_repository.dart';
import '../../domain/usecases/convert_pdf_to_audio.dart';
import '../../domain/usecases/convert_text_to_audio.dart';
import 'tts_event.dart';
import 'tts_state.dart';

@injectable
class TtsBloc extends Bloc<TtsEvent, TtsState> {
  TtsBloc(
    this._convertPdfToAudio,
    this._convertTextToAudio,
    this._repository,
  ) : super(const TtsInitial()) {
    on<ConvertPdfToAudioEvent>(_onConvertPdfToAudio);
    on<ConvertTextToAudioEvent>(_onConvertTextToAudio);
    on<LoadTtsJobsEvent>(_onLoadTtsJobs);
    on<PlayAudioEvent>(_onPlayAudio);
    on<PauseAudioEvent>(_onPauseAudio);
    on<StopAudioEvent>(_onStopAudio);
    on<DeleteTtsJobEvent>(_onDeleteTtsJob);
    on<_UpdatePlayingStateEvent>(_onUpdatePlayingState);
  }

  final ConvertPdfToAudio _convertPdfToAudio;
  final ConvertTextToAudio _convertTextToAudio;
  final TtsRepository _repository;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<TtsJob> _jobs = <TtsJob>[];
  String? _currentAudioUrl;
  StreamSubscription<PlayerState>? _playerStateSubscription;

  @override
  Future<void> close() {
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    return super.close();
  }

  Future<void> _onConvertPdfToAudio(
    ConvertPdfToAudioEvent event,
    Emitter<TtsState> emit,
  ) async {
    emit(TtsProcessing(jobs: List.unmodifiable(_jobs)));

    final result = await _convertPdfToAudio(
      pdfUrl: event.pdfUrl,
      voice: event.voice,
    );

    result.fold(
      (failure) {
        final message = failure.message ?? 'Failed to convert PDF to audio';
        // Check if request was queued
        if (message.contains('queued') || message.contains('Queued')) {
          emit(
            TtsQueued(
              message: message,
              jobs: List.unmodifiable(_jobs),
            ),
          );
        } else {
          emit(
            TtsError(
              message: message,
              jobs: List.unmodifiable(_jobs),
            ),
          );
        }
      },
      (job) {
        _jobs.insert(0, job);
        emit(
          TtsSuccess(
            job: job,
            jobs: List.unmodifiable(_jobs),
          ),
        );
      },
    );
  }

  Future<void> _onConvertTextToAudio(
    ConvertTextToAudioEvent event,
    Emitter<TtsState> emit,
  ) async {
    emit(TtsProcessing(jobs: List.unmodifiable(_jobs)));

    final result = await _convertTextToAudio(
      text: event.text,
      voice: event.voice,
    );

    result.fold(
      (failure) {
        final message = failure.message ?? 'Failed to convert text to audio';
        // Check if request was queued
        if (message.contains('queued') || message.contains('Queued')) {
          emit(
            TtsQueued(
              message: message,
              jobs: List.unmodifiable(_jobs),
            ),
          );
        } else {
          emit(
            TtsError(
              message: message,
              jobs: List.unmodifiable(_jobs),
            ),
          );
        }
      },
      (job) {
        _jobs.insert(0, job);
        emit(
          TtsSuccess(
            job: job,
            jobs: List.unmodifiable(_jobs),
          ),
        );
      },
    );
  }

  Future<void> _onLoadTtsJobs(
    LoadTtsJobsEvent event,
    Emitter<TtsState> emit,
  ) async {
    final result = await _repository.getAllTtsJobs();

    result.fold(
      (failure) => emit(
        TtsError(
          message: failure.message ?? 'Failed to load TTS jobs',
          jobs: List.unmodifiable(_jobs),
        ),
      ),
      (jobs) {
        _jobs.clear();
        _jobs.addAll(jobs);
        emit(TtsInitial(jobs: List.unmodifiable(_jobs)));
      },
    );
  }

  Future<void> _onPlayAudio(
    PlayAudioEvent event,
    Emitter<TtsState> emit,
  ) async {
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
          if (state == PlayerState.playing) {
            add(const _UpdatePlayingStateEvent(isPlaying: true));
          } else if (state == PlayerState.paused) {
            add(const _UpdatePlayingStateEvent(isPlaying: false));
          } else if (state == PlayerState.completed) {
            add(const _UpdatePlayingStateEvent(isPlaying: false));
          }
        },
      );

      emit(
        TtsPlaying(
          currentAudioUrl: event.audioUrl,
          isPlaying: true,
          jobs: List.unmodifiable(_jobs),
        ),
      );
    } catch (error) {
      emit(
        TtsError(
          message: 'Failed to play audio: $error',
          jobs: List.unmodifiable(_jobs),
        ),
      );
    }
  }

  Future<void> _onPauseAudio(
    PauseAudioEvent event,
    Emitter<TtsState> emit,
  ) async {
    try {
      await _audioPlayer.pause();
      if (state is TtsPlaying) {
        emit(
          TtsPlaying(
            currentAudioUrl: (state as TtsPlaying).currentAudioUrl,
            isPlaying: false,
            jobs: List.unmodifiable(_jobs),
          ),
        );
      }
    } catch (error) {
      emit(
        TtsError(
          message: 'Failed to pause audio: $error',
          jobs: List.unmodifiable(_jobs),
        ),
      );
    }
  }

  Future<void> _onStopAudio(
    StopAudioEvent event,
    Emitter<TtsState> emit,
  ) async {
    try {
      await _audioPlayer.stop();
      _currentAudioUrl = null;
      _playerStateSubscription?.cancel();
      emit(TtsInitial(jobs: List.unmodifiable(_jobs)));
    } catch (error) {
      emit(
        TtsError(
          message: 'Failed to stop audio: $error',
          jobs: List.unmodifiable(_jobs),
        ),
      );
    }
  }

  Future<void> _onDeleteTtsJob(
    DeleteTtsJobEvent event,
    Emitter<TtsState> emit,
  ) async {
    final result = await _repository.deleteTtsJob(event.jobId);

    result.fold(
      (failure) => emit(
        TtsError(
          message: failure.message ?? 'Failed to delete TTS job',
          jobs: List.unmodifiable(_jobs),
        ),
      ),
      (_) {
        _jobs.removeWhere((j) => j.id == event.jobId);
        emit(TtsInitial(jobs: List.unmodifiable(_jobs)));
      },
    );
  }

  void _onUpdatePlayingState(
    _UpdatePlayingStateEvent event,
    Emitter<TtsState> emit,
  ) {
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
}

// Internal event for updating playing state
class _UpdatePlayingStateEvent extends TtsEvent {
  const _UpdatePlayingStateEvent({required this.isPlaying});

  final bool isPlaying;

  @override
  List<Object?> get props => [isPlaying];
}

