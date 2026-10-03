import Foundation

/// One HID++ report: short (0x10, 7 B), long (0x11, 20 B) or very long (0x12, 64 B).
/// For HID++ 1.0 frames `featureIndex` is the sub-ID and `functionAndSoftwareID` the address.
public struct HIDPPFrame: Hashable, Sendable {
  public var reportID: UInt8
  public var deviceIndex: UInt8
  public var featureIndex: UInt8
  public var functionAndSoftwareID: UInt8
  public var params: [UInt8]

  public init(reportID: UInt8, deviceIndex: UInt8, featureIndex: UInt8, functionAndSoftwareID: UInt8,
              params: [UInt8]) {
    self.reportID = reportID
    self.deviceIndex = deviceIndex
    self.featureIndex = featureIndex
    self.functionAndSoftwareID = functionAndSoftwareID
    let count = (Self.length(forReportID: reportID) ?? 20) - 4
    self.params = Array((params + Array(repeating: 0, count: count)).prefix(count))
  }

  public init?(bytes: [UInt8]) {
    guard let first = bytes.first, let length = Self.length(forReportID: first), bytes.count >= length else {
      return nil
    }
    self.init(reportID: bytes[0], deviceIndex: bytes[1], featureIndex: bytes[2],
              functionAndSoftwareID: bytes[3], params: Array(bytes[4..<length]))
  }

  public static func length(forReportID id: UInt8) -> Int? {
    switch id {
    case 0x10: return 7
    case 0x11: return 20
    case 0x12: return 64
    default: return nil
    }
  }

  public static func request(device: UInt8, featureIndex: UInt8, function: UInt8, softwareID: UInt8,
                             params: [UInt8]) -> HIDPPFrame {
    HIDPPFrame(reportID: 0x11, deviceIndex: device, featureIndex: featureIndex,
               functionAndSoftwareID: (function << 4) | (softwareID & 0x0F), params: params)
  }

  public var bytes: [UInt8] { [reportID, deviceIndex, featureIndex, functionAndSoftwareID] + params }
  public var function: UInt8 { functionAndSoftwareID >> 4 }
  public var softwareID: UInt8 { functionAndSoftwareID & 0x0F }

  /// HID++ 2.0 error (0xFF) or HID++ 1.0 error (0x8F). Both carry: byte3 = original feature index,
  /// params[0] = original function|swID, params[1] = error code.
  public var isError: Bool { featureIndex == 0xFF || featureIndex == 0x8F }

  /// HID++ 1.0 receiver notifications such as 0x41 device connection.
  public var isNotification: Bool { reportID == 0x10 && (0x40...0x7F).contains(featureIndex) }
}
