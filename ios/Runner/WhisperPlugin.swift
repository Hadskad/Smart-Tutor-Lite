import Flutter
import Foundation

final class WhisperPlugin: NSObject, FlutterPlugin {
  private static let channelName = "smart_tutor_lite/whisper"

  private var methodChannel: FlutterMethodChannel?
  private var contextPointer: UnsafeMutableRawPointer?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )
    let instance = WhisperPlugin()
    channel.setMethodCallHandler(instance.handle)
    instance.methodChannel = channel
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initModel":
      guard let args = call.arguments as? [String: Any],
            let modelPath = args["modelPath"] as? String,
            !modelPath.isEmpty
      else {
        result(FlutterError(code: "invalid_args", message: "modelPath required", details: nil))
        return
      }
      initializeModel(at: modelPath, result: result)

    case "transcribe":
      guard let args = call.arguments as? [String: Any],
            let audioPath = args["audioPath"] as? String,
            !audioPath.isEmpty
      else {
        result(FlutterError(code: "invalid_args", message: "audioPath required", details: nil))
        return
      }
      transcribeAudio(at: audioPath, result: result)

    case "free":
      releaseContext()
      result(nil)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func initializeModel(at path: String, result: FlutterResult) {
    releaseContext()
    guard let context = whisper_init(path.cString(using: .utf8)) else {
      result(FlutterError(code: "init_failed", message: "Unable to init whisper model", details: nil))
      return
    }
    contextPointer = UnsafeMutableRawPointer(context)
    result(true)
  }

  private func transcribeAudio(at path: String, result: FlutterResult) {
    guard let context = contextPointer?.assumingMemoryBound(to: WhisperContext.self) else {
      result(FlutterError(code: "not_initialized", message: "Call initModel first", details: nil))
      return
    }
    do {
      let samples = try loadPcmSamples(from: URL(fileURLWithPath: path))
      let pointer = samples.withUnsafeBufferPointer { buffer -> UnsafeMutablePointer<Int16> in
        let destination = UnsafeMutablePointer<Int16>.allocate(capacity: buffer.count)
        destination.initialize(from: buffer.baseAddress!, count: buffer.count)
        return destination
      }
      defer { pointer.deallocate() }
      guard let textPointer = whisper_process(context, pointer, Int32(samples.count)) else {
        result("")
        return
      }
      let transcript = String(cString: textPointer)
      free(textPointer)
      result(transcript)
    } catch {
      result(FlutterError(code: "wav_error", message: error.localizedDescription, details: nil))
    }
  }

  private func releaseContext() {
    if let context = contextPointer?.assumingMemoryBound(to: WhisperContext.self) {
      whisper_free(context)
    }
    contextPointer = nil
  }

  private func loadPcmSamples(from url: URL) throws -> [Int16] {
    let data = try Data(contentsOf: url)
    guard data.count > 44 else {
      throw NSError(domain: "whisper", code: -1, userInfo: [NSLocalizedDescriptionKey: "WAV header missing"])
    }
    let riff = String(data: data.subdata(in: 0..<4), encoding: .ascii)
    guard riff == "RIFF" else {
      throw NSError(domain: "whisper", code: -2, userInfo: [NSLocalizedDescriptionKey: "Only WAV supported"])
    }
    let sampleRate = data[data.startIndex.advanced(by: 24)..<data.startIndex.advanced(by: 28)].withUnsafeBytes {
      $0.load(as: UInt32.self)
    }
    guard sampleRate == 16_000 else {
      throw NSError(domain: "whisper", code: -3, userInfo: [NSLocalizedDescriptionKey: "Expected 16kHz WAV"])
    }
    let pcmStart = 44
    var samples: [Int16] = []
    samples.reserveCapacity((data.count - pcmStart) / MemoryLayout<Int16>.size)
    var index = pcmStart
    while index + 1 < data.count {
      let value = data[index..<index + 2].withUnsafeBytes { $0.load(as: Int16.self) }
      samples.append(value)
      index += 2
    }
    return samples
  }
}

