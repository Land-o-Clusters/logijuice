import Foundation
import JuiceHID

/// `logijuice debug capture [--seconds N] [--out FILE] [--probe]` — records raw HID++ frames (spec §3).
public enum DebugCapture {
  struct Frame: Codable {
    var t: Double
    var dir: String
    var hex: String
  }

  struct Capture: Codable {
    var capturedAt: Date
    var frames: [Frame]
  }

  final class Log: @unchecked Sendable {
    private let lock = NSLock()
    private let start = Date()
    private(set) var frames: [Frame] = []

    func add(_ dir: String, _ bytes: [UInt8]) {
      let frame = Frame(t: Date().timeIntervalSince(start), dir: dir,
                        hex: bytes.map { String(format: "%02X", $0) }.joined(separator: " "))
      lock.withLock { frames.append(frame) }
      print("\(dir) \(frame.hex)")
    }

    var snapshot: [Frame] { lock.withLock { frames } }
  }

  final class RecordingChannel: ReportChannel, @unchecked Sendable {
    let inner: ReportChannel
    let log: Log

    init(inner: ReportChannel, log: Log) {
      self.inner = inner
      self.log = log
    }

    func send(_ bytes: [UInt8]) throws {
      log.add("out", bytes)
      try inner.send(bytes)
    }

    func setReportHandler(_ handler: @escaping @Sendable ([UInt8]) -> Void) {
      let log = self.log
      inner.setReportHandler { bytes in
        log.add("in", bytes)
        handler(bytes)
      }
    }
  }

  public static func run(arguments: [String]) -> Int32 {
    func value(_ flag: String) -> String? {
      guard let i = arguments.firstIndex(of: flag), i + 1 < arguments.count else { return nil }
      return arguments[i + 1]
    }
    let seconds = Double(value("--seconds") ?? "30") ?? 30
    let out = URL(fileURLWithPath: value("--out") ?? "logijuice-capture.json")
    let probe = arguments.contains("--probe")
    let log = Log()
    let monitor = ReceiverMonitor()
    var keepAlive: [AnyObject] = []

    monitor.onArrive = { channel in
      let recorder = RecordingChannel(inner: channel, log: log)
      keepAlive.append(recorder)
      if probe {
        let broker = RequestBroker(channel: recorder)
        broker.start()
        let session = ReceiverSession(broker: broker)
        Task {
          for slot in UInt8(1)...6 {
            if let info = await session.identify(slot: slot) {
              print("slot \(slot): \(info.info.name) \(info.info.kind) \(info.info.id) \(info.battery)")
              print("battery:", String(describing: await session.readBattery(info)))
            }
          }
        }
        keepAlive.append(broker)
      } else {
        recorder.setReportHandler { _ in }
      }
    }
    monitor.onDepart = { print("receiver departed") }
    monitor.start()
    print("Capturing for \(Int(seconds)) s… (Ctrl-C to abort)")
    RunLoop.main.run(until: Date().addingTimeInterval(seconds))

    do {
      try FileManager.default.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      encoder.dateEncodingStrategy = .iso8601
      try encoder.encode(Capture(capturedAt: Date(), frames: log.snapshot)).write(to: out)
      print("Wrote \(log.snapshot.count) frames to \(out.path)")
      return 0
    } catch {
      FileHandle.standardError.write(Data("Could not write capture: \(error)\n".utf8))
      return 1
    }
  }
}
