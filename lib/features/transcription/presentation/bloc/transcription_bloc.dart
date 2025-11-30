import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import '../../../../native_bridge/performance_bridge.dart';
import '../../domain/entities/transcription.dart';
import '../../domain/repositories/transcription_repository.dart';
import '../../domain/usecases/transcribe_audio.dart' as usecase;
import 'transcription_event.dart';
import 'transcription_state.dart';

@injectable
class TranscriptionBloc extends Bloc<TranscriptionEvent, TranscriptionState> {
  TranscriptionBloc(
    this._transcribeAudio,
    this._performanceBridge,
    this._transcriptionRepository,
  ) : super(const TranscriptionInitial()) {
    on<LoadTranscriptions>(_onLoad);
    on<StartRecording>(_onStartRecording);
    on<StopRecording>(_onStopRecording);
    on<TranscribeAudio>(_onTranscribeAudio);
  }

  final usecase.TranscribeAudio _transcribeAudio;
  final PerformanceBridge _performanceBridge;
  final TranscriptionRepository _transcriptionRepository;
  final AudioRecorder _recorder = AudioRecorder();
  final Uuid _uuid = const Uuid();
  String? _currentRecordingPath;
  DateTime? _recordingStartedAt;
  final List<Transcription> _history = <Transcription>[];

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
      'transcription_${_uuid.v4()}.wav',
    );

    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 128000,
        ),
        path: filePath,
      );
      _currentRecordingPath = filePath;
      _recordingStartedAt = DateTime.now();
      emit(
        TranscriptionRecording(
          startedAt: _recordingStartedAt!,
          filePath: _currentRecordingPath,
          history: List.unmodifiable(_history),
        ),
      );
    } catch (error) {
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
      add(TranscribeAudio(audioPath));
    } catch (error) {
      emit(
        TranscriptionError(
          message: 'Failed to stop recording',
          history: List.unmodifiable(_history),
        ),
      );
    } finally {
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

  @override
  Future<void> close() async {
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
    await _recorder.dispose();
    return super.close();
  }
}
