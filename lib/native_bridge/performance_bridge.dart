import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';

const _channelName = 'smart_tutor_lite/performance';

class PerformanceMetrics {
  PerformanceMetrics({
    required this.durationMs,
    required this.batteryLevel,
    this.cpuUsage = 0,
    this.memoryUsageMb = 0,
    this.notes,
  });

  final int durationMs;
  final int batteryLevel;
  final double cpuUsage;
  final double memoryUsageMb;
  final String? notes;
}

@lazySingleton
class PerformanceBridge {
  PerformanceBridge() : _channel = const MethodChannel(_channelName);

  final MethodChannel _channel;

  Future<void> startSegment(String id) async {
    try {
      await _channel.invokeMethod('startSegment', {'id': id});
    } catch (error, stackTrace) {
      debugPrint('PerformanceBridge.startSegment failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<PerformanceMetrics> endSegment(String id) async {
    try {
      final result = await _channel
          .invokeMapMethod<String, dynamic>('endSegment', {'id': id});
      if (result == null) throw const FormatException('Missing metrics');
      return PerformanceMetrics(
        durationMs: (result['durationMs'] as num?)?.toInt() ?? 0,
        batteryLevel: (result['batteryLevel'] as num?)?.toInt() ?? 0,
        cpuUsage: (result['cpuUsage'] as num?)?.toDouble() ?? 0,
        memoryUsageMb: (result['memoryUsageMb'] as num?)?.toDouble() ?? 0,
        notes: result['notes'] as String?,
      );
    } catch (error, stackTrace) {
      debugPrint('PerformanceBridge.endSegment failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return PerformanceMetrics(
        durationMs: 0,
        batteryLevel: -1,
        notes: 'native_bridge_unavailable',
      );
    }
  }
}
