import 'package:battery_plus/battery_plus.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class PerformanceMonitor {
  PerformanceMonitor(this._battery);

  final Battery _battery;
  final Map<String, Stopwatch> _segments = {};

  void startSegment(String name) {
    final stopwatch = Stopwatch()..start();
    _segments[name] = stopwatch;
  }

  Future<PerformanceReport> endSegment(String name) async {
    final stopwatch = _segments.remove(name);
    if (stopwatch == null) {
      throw StateError('Segment $name was not started');
    }
    stopwatch.stop();
    final batteryLevel = await _battery.batteryLevel;
    return PerformanceReport(
      name: name,
      duration: stopwatch.elapsed,
      batteryLevel: batteryLevel,
    );
  }
}

class PerformanceReport {
  PerformanceReport({
    required this.name,
    required this.duration,
    required this.batteryLevel,
  });

  final String name;
  final Duration duration;
  final int batteryLevel;
}
