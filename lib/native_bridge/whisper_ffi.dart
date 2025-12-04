import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:injectable/injectable.dart';

import '../core/constants/app_constants.dart';
import 'whisper_model_manager.dart';

typedef _WhisperInitNative = ffi.Pointer<ffi.Void> Function(
  ffi.Pointer<Utf8>,
);
typedef _WhisperProcessNative = ffi.Pointer<Utf8> Function(
  ffi.Pointer<ffi.Void>,
  ffi.Pointer<ffi.Int16>,
  ffi.Int32,
);
typedef _WhisperFreeNative = ffi.Void Function(ffi.Pointer<ffi.Void>);

typedef _WhisperInit = ffi.Pointer<ffi.Void> Function(
  ffi.Pointer<Utf8>,
);
typedef _WhisperProcess = ffi.Pointer<Utf8> Function(
  ffi.Pointer<ffi.Void>,
  ffi.Pointer<ffi.Int16>,
  int,
);
typedef _WhisperFree = void Function(ffi.Pointer<ffi.Void>);

enum WhisperErrorType { init, runtime, noSpeech }

class WhisperException implements Exception {
  WhisperException(this.message, this.type);

  final String message;
  final WhisperErrorType type;

  @override
  String toString() => 'WhisperException(type: $type, message: $message)';
}

@lazySingleton
class WhisperFfi {
  WhisperFfi(this._modelManager);

  final WhisperModelManager _modelManager;

  Isolate? _worker;
  SendPort? _workerSendPort;
  Completer<void>? _initializing;
  String? _currentModelAsset;

  Future<void> ensureInitialized({String? modelAssetPath}) async {
    final desiredModel = modelAssetPath ?? AppConstants.whisperDefaultModel;
    if (_workerSendPort != null && _currentModelAsset == desiredModel) {
      return;
    }
    if (_workerSendPort != null) {
      await dispose();
    }
    if (_initializing != null) {
      await _initializing!.future;
      _initializing = null;
    }

    final completer = Completer<void>();
    _initializing = completer;

    final modelInfo = await _modelManager.ensureModel(desiredModel);
    final handshakePort = ReceivePort();

    _worker = await Isolate.spawn<_WhisperWorkerBootstrap>(
      _whisperWorkerEntryPoint,
      _WhisperWorkerBootstrap(
        modelPath: modelInfo.filePath,
        handshakePort: handshakePort.sendPort,
      ),
      debugName: 'whisper_worker',
    );

    final handshake = await handshakePort.first;
    if (handshake is Map && handshake['status'] == 'ok') {
      _workerSendPort = handshake['sendPort'] as SendPort?;
      _currentModelAsset = desiredModel;
      completer.complete();
    } else {
      final errorMessage = handshake is Map ? handshake['message'] : 'Unknown';
      final exception = WhisperException(
        'Failed to initialize Whisper isolate: $errorMessage',
        WhisperErrorType.init,
      );
      completer.completeError(exception);
      await dispose();
      throw exception;
    }
  }

  Future<String> transcribeFile(
    String audioPath, {
    String? modelAssetPath,
  }) async {
    await ensureInitialized(modelAssetPath: modelAssetPath);
    final responsePort = ReceivePort();
    _workerSendPort!.send({
      'type': 'transcribe',
      'audioPath': audioPath,
      'replyPort': responsePort.sendPort,
    });
    final response = await responsePort.first as Map;
    final status = response['status'] as String?;
    if (status == 'ok') {
      return (response['text'] as String).trim();
    }
    final errorMessage =
        response['message'] as String? ?? 'Unknown Whisper error';
    final errorTypeString = response['errorType'] as String? ?? 'runtime';
    throw WhisperException(
      errorMessage,
      _parseErrorType(errorTypeString),
    );
  }

  Future<void> dispose() async {
    if (_workerSendPort != null) {
      final responsePort = ReceivePort();
      _workerSendPort!.send({
        'type': 'dispose',
        'replyPort': responsePort.sendPort,
      });
      await responsePort.first;
      _workerSendPort = null;
    }
    _worker?.kill(priority: Isolate.immediate);
    _worker = null;
    _initializing = null;
    _currentModelAsset = null;
  }

  WhisperErrorType _parseErrorType(String raw) {
    switch (raw) {
      case 'init':
        return WhisperErrorType.init;
      case 'noSpeech':
        return WhisperErrorType.noSpeech;
      default:
        return WhisperErrorType.runtime;
    }
  }
}

class _WhisperWorkerBootstrap {
  const _WhisperWorkerBootstrap({
    required this.modelPath,
    required this.handshakePort,
  });

  final String modelPath;
  final SendPort handshakePort;
}

@pragma('vm:entry-point')
void _whisperWorkerEntryPoint(_WhisperWorkerBootstrap bootstrap) async {
  final commandPort = ReceivePort();
  final native = _WhisperNativeHandle();

  try {
    native.initialize(bootstrap.modelPath);
    bootstrap.handshakePort.send({
      'status': 'ok',
      'sendPort': commandPort.sendPort,
    });
  } catch (error) {
    bootstrap.handshakePort.send({
      'status': 'error',
      'message': error.toString(),
    });
    commandPort.close();
    return;
  }

  await for (final dynamic message in commandPort) {
    if (message is! Map) {
      continue;
    }
    final replyPort = message['replyPort'] as SendPort?;
    if (replyPort == null) {
      continue;
    }
    final type = message['type'] as String?;

    if (type == 'dispose') {
      native.dispose();
      replyPort.send({'status': 'ok'});
      break;
    } else if (type == 'transcribe') {
      final audioPath = message['audioPath'] as String?;
      if (audioPath == null) {
        replyPort.send({
          'status': 'error',
          'message': 'Audio path missing',
          'errorType': 'runtime',
        });
        continue;
      }
      try {
        final text = native.transcribe(audioPath);
        replyPort.send({'status': 'ok', 'text': text});
      } on WhisperException catch (error) {
        replyPort.send({
          'status': 'error',
          'message': error.message,
          'errorType': _errorTypeToString(error.type),
        });
      } catch (error) {
        replyPort.send({
          'status': 'error',
          'message': error.toString(),
          'errorType': 'runtime',
        });
      }
    }
  }

  commandPort.close();
}

String _errorTypeToString(WhisperErrorType type) {
  switch (type) {
    case WhisperErrorType.init:
      return 'init';
    case WhisperErrorType.noSpeech:
      return 'noSpeech';
    case WhisperErrorType.runtime:
      return 'runtime';
  }
}

class _WhisperNativeHandle {
  ffi.DynamicLibrary? _library;
  ffi.Pointer<ffi.Void>? _context;
  late final _WhisperInit _init;
  late final _WhisperProcess _process;
  late final _WhisperFree _free;
  bool _symbolsLoaded = false;

  void initialize(String modelPath) {
    _library ??= _openLibrary();
    _lookupFunctions();
    final modelPathPointer = modelPath.toNativeUtf8();
    _context = _init(modelPathPointer);
    malloc.free(modelPathPointer);
    if (_context == ffi.nullptr) {
      throw WhisperException(
        'Failed to initialize whisper.cpp model',
        WhisperErrorType.init,
      );
    }
  }

  String transcribe(String audioPath) {
    if (_context == null) {
      throw WhisperException(
        'Whisper context not initialized',
        WhisperErrorType.init,
      );
    }
    final buffer = _loadPcmSamples(audioPath);
    try {
      final resultPointer =
          _process(_context!, buffer.pointer, buffer.sampleCount);
      final result =
          resultPointer.cast<Utf8>().toDartString().trim();
      malloc.free(resultPointer);
      if (result.isEmpty) {
        throw WhisperException(
          'No speech detected in the recording.',
          WhisperErrorType.noSpeech,
        );
      }
      return result;
    } finally {
      buffer.dispose();
    }
  }

  void dispose() {
    if (_context != null) {
      _free(_context!);
      _context = null;
    }
  }

  _AudioBuffer _allocateAudioBuffer(Int16List samples) {
    final pointer = calloc<ffi.Int16>(samples.length);
    for (var i = 0; i < samples.length; i++) {
      pointer[i] = samples[i];
    }
    return _AudioBuffer(pointer, samples.length);
  }

  _AudioBuffer _loadPcmSamples(String audioPath) {
    final file = File(audioPath);
    if (!file.existsSync()) {
      throw WhisperException(
        'Audio file not found: $audioPath',
        WhisperErrorType.runtime,
      );
    }
    final bytes = file.readAsBytesSync();
    final wav = _ensureWavFormat(bytes);
    final pcmBytes = wav.sublist(44);
    final byteData = ByteData.view(
      pcmBytes.buffer,
      pcmBytes.offsetInBytes,
      pcmBytes.lengthInBytes,
    );
    final sampleCount = byteData.lengthInBytes ~/ 2;
    final samples = Int16List(sampleCount);
    for (var i = 0; i < sampleCount; i++) {
      samples[i] = byteData.getInt16(i * 2, Endian.little);
    }
    return _allocateAudioBuffer(samples);
  }

  Uint8List _ensureWavFormat(Uint8List data) {
    if (data.length < 44) {
      throw WhisperException(
        'Invalid WAV file',
        WhisperErrorType.runtime,
      );
    }
    final header = String.fromCharCodes(data.sublist(0, 4));
    if (header != 'RIFF') {
      throw WhisperException(
        'Only 16-bit PCM WAV audio is supported offline.',
        WhisperErrorType.runtime,
      );
    }
    final sampleRateData = ByteData.view(
      data.buffer,
      data.offsetInBytes + 24,
      4,
    );
    final sampleRate = sampleRateData.getUint32(0, Endian.little);
    if (sampleRate != 16000) {
      throw WhisperException(
        'Audio must be recorded at 16kHz for offline transcription. Found $sampleRate Hz.',
        WhisperErrorType.runtime,
      );
    }
    return data;
  }

  void _lookupFunctions() {
    if (_symbolsLoaded) {
      return;
    }
    final initSymbol = Platform.isAndroid ? 'whisper_wrapper_init' : 'whisper_init';
    final processSymbol =
        Platform.isAndroid ? 'whisper_wrapper_process' : 'whisper_process';
    final freeSymbol = Platform.isAndroid ? 'whisper_wrapper_free' : 'whisper_free';

    _init = _library!.lookupFunction<_WhisperInitNative, _WhisperInit>(
      initSymbol,
    );
    _process = _library!.lookupFunction<_WhisperProcessNative, _WhisperProcess>(
      processSymbol,
    );
    _free = _library!.lookupFunction<_WhisperFreeNative, _WhisperFree>(
      freeSymbol,
    );
    _symbolsLoaded = true;
  }

  ffi.DynamicLibrary _openLibrary() {
    if (Platform.isAndroid) {
      final candidates = ['libwhisper.so', 'libwhisper_jni.so'];
      Object? lastError;
      for (final name in candidates) {
        try {
          return ffi.DynamicLibrary.open(name);
        } catch (error) {
          lastError = error;
        }
      }
      throw WhisperException(
        'Unable to load Whisper native library. Last error: $lastError',
        WhisperErrorType.init,
      );
    }
    if (Platform.isIOS) {
      return ffi.DynamicLibrary.process();
    }
    if (Platform.isMacOS) {
      return ffi.DynamicLibrary.open('libwhisper.dylib');
    }
    if (Platform.isWindows) {
      return ffi.DynamicLibrary.open('whisper.dll');
    }
    return ffi.DynamicLibrary.process();
  }
}

class _AudioBuffer {
  _AudioBuffer(this.pointer, this.sampleCount);

  final ffi.Pointer<ffi.Int16> pointer;
  final int sampleCount;

  void dispose() {
    calloc.free(pointer);
  }
}

