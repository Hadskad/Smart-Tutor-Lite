import 'package:injectable/injectable.dart';
import 'package:logger/logger.dart';

@lazySingleton
class AppLogger {
  AppLogger(this._logger);

  final Logger _logger;

  void info(String message, [dynamic data]) {
    if (data != null) {
      _logger.i('$message | payload: $data');
    } else {
      _logger.i(message);
    }
  }

  void warning(String message, [dynamic data]) {
    if (data != null) {
      _logger.w('$message | payload: $data');
    } else {
      _logger.w(message);
    }
  }

  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }
}
