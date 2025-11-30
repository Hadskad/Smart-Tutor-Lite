import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:injectable/injectable.dart';

abstract class NetworkInfo {
  Future<bool> get isConnected;
  Stream<bool> get onStatusChange;
}

@LazySingleton(as: NetworkInfo)
class NetworkInfoImpl implements NetworkInfo {
  NetworkInfoImpl(this._connectivity);

  final Connectivity _connectivity;

  @override
  Future<bool> get isConnected async {
    final result = await _connectivity.checkConnectivity();
    return _hasConnection(result);
  }

  @override
  Stream<bool> get onStatusChange =>
      _connectivity.onConnectivityChanged.map(_hasConnection);

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
