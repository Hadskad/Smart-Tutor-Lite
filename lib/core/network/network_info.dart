import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

abstract class NetworkInfo {
  Future<bool> get isConnected;
  Stream<bool> get onStatusChange;
  Stream<List<ConnectivityResult>> get onConnectivityChanged;
  Future<ConnectivityResult> get connectionType;
  Future<double?> measureDownloadSpeedKbps({
    required String testFileUrl,
    Duration timeout = const Duration(seconds: 10),
  });
}

@LazySingleton(as: NetworkInfo)
class NetworkInfoImpl implements NetworkInfo {
  NetworkInfoImpl(this._connectivity, this._dio);

  final Connectivity _connectivity;
  final Dio _dio;

  @override
  Future<bool> get isConnected async {
    final result = await _connectivity.checkConnectivity();
    return _hasConnection(result);
  }

  @override
  Stream<bool> get onStatusChange =>
      _connectivity.onConnectivityChanged.map(_hasConnection);

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged.map(_normalizeResults);

  @override
  Future<ConnectivityResult> get connectionType async {
    final result = await _connectivity.checkConnectivity();
    final normalized = _normalizeResults(result);
    if (normalized.isEmpty) {
      return ConnectivityResult.none;
    }
    return normalized.first;
  }

  @override
  Future<double?> measureDownloadSpeedKbps({
    required String testFileUrl,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final stopwatch = Stopwatch()..start();

      final response = await _dio
          .get(
            testFileUrl,
            options: Options(
              responseType: ResponseType.bytes,
              receiveTimeout: timeout,
            ),
          )
          .timeout(timeout);

      stopwatch.stop();

      if (response.data is! List<int>) {
        return null;
      }

      final bytes = response.data as List<int>;
      final bytesDownloaded = bytes.length;
      final timeSeconds = stopwatch.elapsedMilliseconds / 1000.0;

      if (timeSeconds <= 0 || bytesDownloaded == 0) {
        return null;
      }

      // Convert to kbps: (bytes * 8) / (time in seconds) / 1000
      final kbps = (bytesDownloaded * 8) / timeSeconds / 1000;
      return kbps;
    } catch (e) {
      // Network error, timeout, or other issue - return null
      return null;
    }
  }

  bool _hasConnection(Object result) {
    final normalized = _normalizeResults(result);
    return normalized.any((status) => status != ConnectivityResult.none);
  }

  List<ConnectivityResult> _normalizeResults(Object result) {
    if (result is List<ConnectivityResult>) {
      return result;
    }
    if (result is ConnectivityResult) {
      return [result];
    }
    return const <ConnectivityResult>[];
  }
}
