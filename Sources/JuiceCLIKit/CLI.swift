import Foundation
import JuiceCore
import JuiceStore

public enum CLI {
  public static let usage = """
    usage: logijuice <command>
      status [--json]                              battery for each known device
      devices                                      device IDs, names and kinds
      debug capture [--seconds N] [--out FILE] [--probe]
                                                   record raw HID++ frames (troubleshooting)
    """

  public static func run(_ args: [String], snapshotURL: URL, now: Date = Date(),
                         out: (String) -> Void, err: (String) -> Void) -> Int32 {
    guard let command = args.first else {
      out(usage)
      return 0
    }
    switch command {
    case "-h", "--help", "help":
      out(usage)
      return 0
    case "status", "devices":
      guard let snapshot = SnapshotStore(url: snapshotURL).read(), snapshot.schema <= Snapshot.currentSchema else {
        err("No data yet. Is LogiJuice running?")
        return 1
      }
      if command == "status" {
        if args.contains("--json") {
          let data = (try? JuiceJSON.prettyEncoder.encode(snapshot)) ?? Data()
          out(String(decoding: data, as: UTF8.self))
          return 0
        }
        if snapshot.devices.isEmpty {
          out("No devices seen yet.")
          return 0
        }
        snapshot.devices.forEach { out(Format.statusLine($0, now: now)) }
      } else {
        snapshot.devices.forEach {
          out("\($0.id.rawValue)\t\($0.displayName)\t\($0.kind.rawValue)\t\(Format.seen($0.lastSeen, now: now))")
        }
      }
      return 0
    default:
      err("unknown command: \(command)\n\(usage)")
      return 64
    }
  }
}
