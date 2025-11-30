import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:injectable/injectable.dart';

import 'whisper_ffi.dart';

@lazySingleton
class WhisperLifecycleObserver with WidgetsBindingObserver {
  WhisperLifecycleObserver(this._whisperFfi);

  final WhisperFfi _whisperFfi;
  bool _isRegistered = false;

  void start() {
    if (_isRegistered) {
      return;
    }
    WidgetsBinding.instance.addObserver(this);
    _isRegistered = true;
  }

  void stop() {
    if (!_isRegistered) {
      return;
    }
    WidgetsBinding.instance.removeObserver(this);
    _isRegistered = false;
    _disposeAsync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      _disposeAsync();
    }
  }

  void _disposeAsync() {
    scheduleMicrotask(() => _whisperFfi.dispose());
  }
}
