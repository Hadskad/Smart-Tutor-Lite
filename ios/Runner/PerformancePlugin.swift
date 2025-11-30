import Flutter
import Foundation
import MachO
import UIKit

final class PerformancePlugin: NSObject, FlutterPlugin {
  private var channel: FlutterMethodChannel?
  private var segments: [String: Segment] = [:]

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "smart_tutor_lite/performance",
      binaryMessenger: registrar.messenger()
    )
    let instance = PerformancePlugin()
    channel.setMethodCallHandler(instance.handle)
    instance.channel = channel
    UIDevice.current.isBatteryMonitoringEnabled = true
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "startSegment":
      guard
        let args = call.arguments as? [String: Any],
        let id = args["id"] as? String,
        !id.isEmpty
      else {
        result(FlutterError(code: "invalid_args", message: "Segment id required", details: nil))
        return
      }
      segments[id] = Segment(
        startTime: DispatchTime.now().uptimeNanoseconds,
        cpuTime: processCpuTimeSeconds(),
        batteryLevel: currentBatteryLevel(),
        systemCpu: systemCpuSample()
      )
      result(nil)

    case "endSegment":
      guard
        let args = call.arguments as? [String: Any],
        let id = args["id"] as? String,
        !id.isEmpty
      else {
        result(FlutterError(code: "invalid_args", message: "Segment id required", details: nil))
        return
      }

      guard let segment = segments.removeValue(forKey: id) else {
        result(FlutterError(code: "segment_missing", message: "Segment \(id) was not started", details: nil))
        return
      }

      let durationMs = max(
        Double(DispatchTime.now().uptimeNanoseconds - segment.startTime) / 1_000_000.0,
        0
      )
      let batteryLevel = currentBatteryLevel()
      let cpuDelta = max(processCpuTimeSeconds() - segment.cpuTime, 0)
      let cpuUsage = durationMs > 0
        ? min((cpuDelta / (durationMs / 1000.0)) * 100.0 / Double(ProcessInfo.processInfo.activeProcessorCount), 100.0)
        : 0.0
      let systemCpuUsage = systemCpuSample().flatMap { endSample in
        segment.systemCpu.flatMap { $0.deltaPercentage(to: endSample) }
      }
      let memoryUsage = memoryUsageMb()

      var response: [String: Any] = [
        "durationMs": Int(durationMs.rounded()),
        "batteryLevel": batteryLevel,
        "cpuUsage": cpuUsage,
        "memoryUsageMb": memoryUsage,
      ]

      var notes: [String] = []
      let batteryDelta = batteryDeltaString(start: segment.batteryLevel, end: batteryLevel)
      if let batteryDelta = batteryDelta {
        notes.append(batteryDelta)
      }
      if let systemCpuUsage = systemCpuUsage {
        notes.append(String(format: "systemCpu=%.2f", systemCpuUsage))
      }
      if !notes.isEmpty {
        response["notes"] = notes.joined(separator: "; ")
      }

      result(response)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func currentBatteryLevel() -> Int {
    let level = UIDevice.current.batteryLevel
    if level < 0 {
      return -1
    }
    return Int((level * 100).rounded())
  }

  private func batteryDeltaString(start: Int, end: Int) -> String? {
    guard start >= 0, end >= 0 else { return nil }
    let delta = end - start
    return delta == 0 ? nil : "batteryDelta=\(delta)"
  }

  private func processCpuTimeSeconds() -> TimeInterval {
    var info = task_thread_times_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: info) / MemoryLayout<Int32>.size)
    let result = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        task_info(mach_task_self_, task_flavor_t(TASK_THREAD_TIMES_INFO), $0, &count)
      }
    }
    guard result == KERN_SUCCESS else { return 0 }
    let user = TimeInterval(info.user_time.seconds) + TimeInterval(info.user_time.microseconds) / 1_000_000
    let system = TimeInterval(info.system_time.seconds) + TimeInterval(info.system_time.microseconds) / 1_000_000
    return user + system
  }

  private func memoryUsageMb() -> Double {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: info) / MemoryLayout<Int32>.size)
    let result = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
      }
    }
    guard result == KERN_SUCCESS else { return 0 }
    return Double(info.phys_footprint) / 1_048_576.0
  }

  private func systemCpuSample() -> CpuSample? {
    var size = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
    var cpuInfo = host_cpu_load_info_data_t()
    let result = withUnsafeMutablePointer(to: &cpuInfo) {
      $0.withMemoryRebound(to: integer_t.self, capacity: Int(size)) {
        host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
      }
    }
    guard result == KERN_SUCCESS else { return nil }
    return CpuSample(
      user: Double(cpuInfo.cpu_ticks.0),
      nice: Double(cpuInfo.cpu_ticks.1),
      system: Double(cpuInfo.cpu_ticks.2),
      idle: Double(cpuInfo.cpu_ticks.3)
    )
  }

  private struct Segment {
    let startTime: UInt64
    let cpuTime: TimeInterval
    let batteryLevel: Int
    let systemCpu: CpuSample?
  }

  private struct CpuSample {
    let user: Double
    let nice: Double
    let system: Double
    let idle: Double

    var total: Double { user + nice + system + idle }

    func deltaPercentage(to other: CpuSample) -> Double? {
      let totalDelta = other.total - total
      if totalDelta <= 0 { return nil }
      let idleDelta = other.idle - idle
      let used = totalDelta - idleDelta
      return max(min((used / totalDelta) * 100.0, 100.0), 0.0)
    }
  }
}

