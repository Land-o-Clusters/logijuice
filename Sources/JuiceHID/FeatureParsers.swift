import Foundation
import JuiceCore

public enum FeatureID: UInt16, Sendable {
  case root = 0x0000
  case deviceInformation = 0x0003
  case deviceNameType = 0x0005
  case batteryStatus = 0x1000
  case batteryVoltage = 0x1001
  case unifiedBattery = 0x1004
}

public struct BatteryReport: Hashable, Sendable {
  public var level: BatteryLevel
  public var charging: Bool

  public init(level: BatteryLevel, charging: Bool) {
    self.level = level
    self.charging = charging
  }
}

public struct DeviceInformation: Hashable, Sendable {
  public var unitID: String?
  public var serialSupported: Bool
}

public struct ConnectionNotice: Hashable, Sendable {
  public var slot: UInt8
  public var linkUp: Bool
  public var wpid: UInt16
}

public enum FeatureParsers {
  /// Root getFeature reply: [index, type, version]. Index 0 means "not supported".
  public static func featureIndex(fromGetFeature p: [UInt8]) -> UInt8? {
    guard let index = p.first, index != 0 else { return nil }
    return index
  }

  /// 0x1004 getCapabilities: [supported level mask, flags]; flags bit 0x02 = state of charge (%).
  public static func unifiedBatteryPercentSupported(_ p: [UInt8]) -> Bool {
    p.count >= 2 && p[1] & 0x02 != 0
  }

  /// 0x1004 getStatus / battery event: [state of charge, level mask, charging status, external power].
  public static func unifiedBatteryStatus(_ p: [UInt8], percentSupported: Bool) -> BatteryReport? {
    guard p.count >= 3 else { return nil }
    let soc = Int(p[0])
    let mask = p[1]
    let status = p[2]
    let word: LevelWord? =
      mask & 0x08 != 0 ? .full : mask & 0x04 != 0 ? .good : mask & 0x02 != 0 ? .low : mask & 0x01 != 0 ? .critical : nil
    let level: BatteryLevel
    if percentSupported, (1...100).contains(soc) {
      level = .percent(soc)
    } else if let word {
      level = .word(word)
    } else {
      return nil
    }
    return BatteryReport(level: level, charging: status == 1 || status == 2)
  }

  /// 0x1000 getBatteryLevelStatus / event: [discharge %, next level %, status].
  /// Status 0 discharging, 1 recharging, 2 almost full, 3 full, 4 slow recharge, 5+ battery error.
  public static func batteryStatus(_ p: [UInt8]) -> BatteryReport? {
    guard p.count >= 3, p[2] <= 4 else { return nil }
    let status = p[2]
    if status == 3 { return BatteryReport(level: .percent(100), charging: false) }
    let percent = Int(p[0])
    guard (1...100).contains(percent) else { return nil }
    return BatteryReport(level: .percent(percent), charging: [1, 2, 4].contains(status))
  }

  /// Typical single-cell Li-ion discharge curve (mV → %), as used by Solaar for 0x1001 devices. Untested on hardware.
  static let voltageCurve: [(mv: Int, percent: Int)] = [
    (4186, 100), (4067, 90), (3989, 80), (3922, 70), (3859, 60), (3811, 50), (3778, 40), (3751, 30),
    (3717, 20), (3671, 10), (3646, 5), (3579, 2), (3500, 0),
  ]

  public static func percent(fromMillivolts mv: Int) -> Int {
    guard let top = voltageCurve.first, let bottom = voltageCurve.last else { return 0 }
    if mv >= top.mv { return 100 }
    if mv <= bottom.mv { return 0 }
    for (hi, lo) in zip(voltageCurve, voltageCurve.dropFirst()) where mv <= hi.mv && mv >= lo.mv {
      let t = Double(mv - lo.mv) / Double(hi.mv - lo.mv)
      return Int((Double(lo.percent) + t * Double(hi.percent - lo.percent)).rounded())
    }
    return 0
  }

  /// 0x1001 getBatteryInfo / event: [voltage hi, voltage lo, flags]; flags bit 0x80 = charging.
  public static func batteryVoltage(_ p: [UInt8]) -> BatteryReport? {
    guard p.count >= 3 else { return nil }
    let mv = Int(p[0]) << 8 | Int(p[1])
    guard (3000...4500).contains(mv) else { return nil }
    return BatteryReport(level: .percent(percent(fromMillivolts: mv)), charging: p[2] & 0x80 != 0)
  }

  /// 0x0005 getDeviceName chunk: ASCII bytes, stop at NUL or `remaining`.
  public static func nameChunk(_ p: [UInt8], remaining: Int) -> String {
    let bytes = p.prefix(max(0, remaining)).prefix { $0 != 0 }
    return String(decoding: bytes, as: UTF8.self)
  }

  /// 0x0003 getDeviceInfo: [entityCount, unitID×4, transport×2, modelID×6, extendedModelID, capabilities].
  public static func deviceInformation(_ p: [UInt8]) -> DeviceInformation? {
    guard p.count >= 15 else { return nil }
    let unit = p[1...4]
    let unitID = unit.allSatisfy({ $0 == 0 }) ? nil : unit.map { String(format: "%02X", $0) }.joined()
    return DeviceInformation(unitID: unitID, serialSupported: p[14] & 0x01 != 0)
  }

  /// 0x0003 getSerialNumber: 12 ASCII characters.
  public static func serialNumber(_ p: [UInt8]) -> String? {
    let text = String(decoding: p.prefix(12).prefix { $0 != 0 }, as: UTF8.self)
      .trimmingCharacters(in: .whitespaces)
    return text.isEmpty ? nil : text
  }

  /// HID++ 1.0 device connection notification: [0x10, slot, 0x41, protocol, flags, wpidLo, wpidHi].
  /// flags bit 0x40 set = link NOT established.
  public static func connectionNotice(_ f: HIDPPFrame) -> ConnectionNotice? {
    guard f.reportID == 0x10, f.featureIndex == 0x41, (1...6).contains(f.deviceIndex), f.params.count >= 3 else {
      return nil
    }
    return ConnectionNotice(slot: f.deviceIndex, linkUp: f.params[0] & 0x40 == 0,
                            wpid: UInt16(f.params[2]) << 8 | UInt16(f.params[1]))
  }
}
