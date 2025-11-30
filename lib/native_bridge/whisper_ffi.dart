import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/constants/app_constants.dart';

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

@lazySingleton
class WhisperFfi {
  WhisperFfi();

  ffi.DynamicLibrary? _library;
  ffi.Pointer<ffi.Void>? _context;
  String? _modelPath;

  late final _WhisperInit _init;
  late final _WhisperProcess _process;
  late final _WhisperFree _free;
  bool _symbolsLoaded = false;

  Future<void> ensureInitialized({String? modelAssetPath}) async {
    _library ??= _openLibrary();
    _lookupFunctions();
    _modelPath ??= await _materializeModel(
      modelAssetPath ?? AppConstants.whisperDefaultModel,
    );
    if (_context == null) {
      final modelPathPointer = _modelPath!.toNativeUtf8();
      _context = _init(modelPathPointer);
      malloc.free(modelPathPointer);
      if (_context == ffi.nullptr) {
        throw StateError('Failed to initialize Whisper model');
      }
    }
  }

  Future<String> transcribeFile(String audioPath) async {
    await ensureInitialized();
    final buffer = await _loadPcmSamples(audioPath);
    try {
      final resultPointer =
          _process(_context!, buffer.pointer, buffer.sampleCount);
      final result = resultPointer.toDartString();
      malloc.free(resultPointer);
      return result;
    } finally {
      buffer.dispose();
    }
  }

  Future<void> dispose() async {
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

  Future<_AudioBuffer> _loadPcmSamples(String audioPath) async {
    final file = File(audioPath);
    if (!file.existsSync()) {
      throw ArgumentError('Audio file not found at $audioPath');
    }
    final bytes = await file.readAsBytes();
    final wav = _ensureWavFormat(bytes);
    final pcmBytes = wav.sublist(44); // skip header
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
      throw UnsupportedError('Invalid WAV file');
    }
    final header = String.fromCharCodes(data.sublist(0, 4));
    if (header != 'RIFF') {
      throw UnsupportedError('Only WAV audio is supported locally');
    }
    final sampleRateData = ByteData.view(
      data.buffer,
      data.offsetInBytes + 24,
      4,
    );
    final sampleRate = sampleRateData.getUint32(0, Endian.little);
    if (sampleRate != 16000) {
      throw UnsupportedError('Audio must be 16kHz. Found $sampleRate Hz');
    }
    return data;
  }

  Future<String> _materializeModel(String assetPath) async {
    final byteData = await rootBundle.load(assetPath);
    final tempDir = await getTemporaryDirectory();
    final fileName = p.basename(assetPath);
    final file = File(p.join(tempDir.path, fileName));
    if (!await file.exists()) {
      await file.create(recursive: true);
      await file.writeAsBytes(byteData.buffer.asUint8List());
    }
    return file.path;
  }

  void _lookupFunctions() {
    if (_symbolsLoaded) {
      return;
    }
    _init = _library!.lookupFunction<_WhisperInitNative, _WhisperInit>(
      'whisper_init',
    );
    _process = _library!.lookupFunction<_WhisperProcessNative, _WhisperProcess>(
      'whisper_process',
    );
    _free = _library!.lookupFunction<_WhisperFreeNative, _WhisperFree>(
      'whisper_free',
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
      throw StateError(
        'Unable to load Whisper native library. Last error: $lastError',
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
