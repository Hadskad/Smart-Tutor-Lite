import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WhisperModelInfo {
  const WhisperModelInfo({
    required this.assetPath,
    required this.filePath,
    required this.checksum,
  });

  final String assetPath;
  final String filePath;
  final String checksum;
}

@lazySingleton
class WhisperModelManager {
  WhisperModelManager(this._sharedPreferences);

  final SharedPreferences _sharedPreferences;
  static const _checksumKeyPrefix = 'whisper_model_checksum_';

  Future<WhisperModelInfo> ensureModel(String assetPath) async {
    final byteData = await rootBundle.load(assetPath);
    final checksum =
        sha256.convert(byteData.buffer.asUint8List()).toString();
    final directory = await getApplicationSupportDirectory();
    final fileName = p.basename(assetPath);
    final file = File(p.join(directory.path, fileName));
    final storedChecksum = _sharedPreferences.getString(
      _checksumKey(fileName),
    );

    final bytes = byteData.buffer.asUint8List();
    final needsCopy = !await file.exists() || storedChecksum != checksum;
    if (needsCopy) {
      await file.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      await _sharedPreferences.setString(_checksumKey(fileName), checksum);
    } else {
      // Opportunistic on-device verification in case file is corrupted.
      final existingBytes = await file.readAsBytes();
      final existingChecksum = sha256.convert(existingBytes).toString();
      if (existingChecksum != checksum) {
        await file.writeAsBytes(bytes, flush: true);
        await _sharedPreferences.setString(_checksumKey(fileName), checksum);
      }
    }

    return WhisperModelInfo(
      assetPath: assetPath,
      filePath: file.path,
      checksum: checksum,
    );
  }

  Future<void> preloadDefaultModels(List<String> assetPaths) async {
    for (final asset in assetPaths) {
      await ensureModel(asset);
    }
  }

  String _checksumKey(String fileName) => '$_checksumKeyPrefix$fileName';
}


