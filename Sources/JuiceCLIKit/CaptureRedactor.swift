import Foundation
import JuiceHID

/// Removes device serial numbers and unit IDs from a capture before it is written, so a capture can be attached to a
/// public issue. Two passes:
/// 1. Structural. A `--probe` capture holds our own root getFeature(0x0003) request and its reply, which give the
///    Device Information feature index per device. Every reply on that index is redacted, whoever asked
///    (Options+ asks too): unit ID bytes in fn0 replies, the serial in fn2 replies.
/// 2. Content. The identifiers found in pass 1, plus the ones logijuice already knows, are swept from every frame.
public enum CaptureRedactor {
  public struct RawFrame: Equatable, Sendable {
    public var dir: String
    public var bytes: [UInt8]
    public init(dir: String, bytes: [UInt8]) {
      self.dir = dir
      self.bytes = bytes
    }
  }

  static let fill: UInt8 = 0x2A  // "*"
  static let deviceInformation: UInt16 = 0x0003

  public static func redact(_ frames: [RawFrame], knownIDs: [String]) -> [RawFrame] {
    var out = frames
    var infoIndex: [UInt8: UInt8] = [:]  // device index → 0x0003 feature index
    var asked: [UInt8: UInt16] = [:]  // device index → feature in our pending getFeature request
    var found: [[UInt8]] = []

    for i in out.indices {
      let b = out[i].bytes
      guard b.count >= 7, b[0] == 0x10 || b[0] == 0x11 else { continue }
      let device = b[1], featureIndex = b[2], function = b[3] >> 4, softwareID = b[3] & 0x0F
      if featureIndex == 0, function == 0, softwareID == RequestBroker.defaultSoftwareID {
        if out[i].dir == "out" {
          asked[device] = UInt16(b[4]) << 8 | UInt16(b[5])
        } else {
          if asked[device] == deviceInformation, b[4] != 0 { infoIndex[device] = b[4] }
          asked[device] = nil
        }
        continue
      }
      guard out[i].dir == "in", b[0] == 0x11, b.count >= 16, infoIndex[device] == featureIndex else { continue }
      if function == 0 {  // [entities, unitID×4, …]
        found.append(Array(b[5...8]))
        for k in 5...8 { out[i].bytes[k] = 0 }
      } else if function == 2 {  // 12 ASCII characters
        found.append(Array(b[4..<16].prefix { $0 != 0 }))
        for k in 4..<16 { out[i].bytes[k] = fill }
      }
    }

    var needles = found
    for id in knownIDs {
      if id.hasPrefix("sn:") { needles.append(Array(id.dropFirst(3).utf8)) }
      if id.hasPrefix("unit:"), let bytes = hexBytes(String(id.dropFirst(5))) { needles.append(bytes) }
    }
    needles = needles.filter { $0.count >= 4 && !$0.allSatisfy { $0 == 0 || $0 == fill } }
    for i in out.indices {
      for needle in needles {
        while let r = out[i].bytes.firstRange(of: needle) {
          out[i].bytes.replaceSubrange(r, with: [UInt8](repeating: fill, count: needle.count))
        }
      }
    }
    return out
  }

  /// For text output: keeps the kind of ID, drops the identifying part.
  public static func redactID(_ id: String) -> String {
    for prefix in ["sn:", "unit:"] where id.hasPrefix(prefix) { return prefix + "<redacted>" }
    return id
  }

  static func hexBytes(_ hex: String) -> [UInt8]? {
    let chars = Array(hex)
    guard chars.count % 2 == 0, !chars.isEmpty else { return nil }
    return stride(from: 0, to: chars.count, by: 2).compactMap { UInt8(String(chars[$0...$0 + 1]), radix: 16) }
  }
}
