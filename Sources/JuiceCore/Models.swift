import Foundation

/// Stable identity of one physical device across receivers, slots and Macs (spec §6).
public struct DeviceID: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
  public let rawValue: String
  public init(_ rawValue: String) { self.rawValue = rawValue }

  public static func serial(_ serial: String) -> DeviceID { DeviceID("sn:\(serial)") }
  public static func unit(_ unitID: String) -> DeviceID { DeviceID("unit:\(unitID)") }
  public static func slot(wpid: UInt16, slot: UInt8) -> DeviceID {
    DeviceID(String(format: "wpid:%04X:slot:%d", wpid, slot))
  }

  public var description: String { rawValue }
  public static func < (a: DeviceID, b: DeviceID) -> Bool { a.rawValue < b.rawValue }

  public init(from decoder: Decoder) throws {
    rawValue = try decoder.singleValueContainer().decode(String.self)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.singleValueContainer()
    try c.encode(rawValue)
  }
}

extension DeviceID: CodingKeyRepresentable {
  private struct Key: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
  }

  public var codingKey: CodingKey { Key(stringValue: rawValue) }
  public init?<T: CodingKey>(codingKey: T) { self.init(codingKey.stringValue) }
}

public enum DeviceKind: String, Codable, Sendable, CaseIterable {
  case keyboard, mouse, trackball, touchpad, numpad, presenter, headset, other

  /// Maps the HID++ feature 0x0005 getDeviceType value.
  public init(hidppType: UInt8) {
    switch hidppType {
    case 0: self = .keyboard
    case 1: self = .presenter  // remote control
    case 2: self = .numpad
    case 3: self = .mouse
    case 4: self = .touchpad
    case 5: self = .trackball
    case 6: self = .presenter
    case 8: self = .headset
    default: self = .other
    }
  }
}

public enum LevelWord: String, Codable, Sendable {
  case critical, low, good, full

  /// Percent used when a word-only reading is compared with percent triggers (spec §4).
  public var equivalentPercent: Int {
    switch self {
    case .critical: return 5
    case .low: return 10
    case .good: return 50
    case .full: return 100
    }
  }
}

public enum BatteryLevel: Hashable, Sendable, Codable {
  case percent(Int)
  case word(LevelWord)

  public var equivalentPercent: Int {
    switch self {
    case .percent(let p): return p
    case .word(let w): return w.equivalentPercent
    }
  }

  public var isFull: Bool {
    switch self {
    case .percent(let p): return p >= 100
    case .word(let w): return w == .full
    }
  }

  private enum CodingKeys: String, CodingKey { case percent, word }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    if let p = try c.decodeIfPresent(Int.self, forKey: .percent) {
      self = .percent(p)
    } else {
      self = .word(try c.decode(LevelWord.self, forKey: .word))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .percent(let p): try c.encode(p, forKey: .percent)
    case .word(let w): try c.encode(w, forKey: .word)
    }
  }
}

/// Where a reading came from. Only `.local` readings may fire alerts (spec §4).
public enum ReadingSource: Hashable, Sendable, Codable {
  case local
  case synced(macID: String)

  public init(from decoder: Decoder) throws {
    let raw = try decoder.singleValueContainer().decode(String.self)
    if raw == "local" {
      self = .local
    } else if raw.hasPrefix("synced:") {
      self = .synced(macID: String(raw.dropFirst("synced:".count)))
    } else {
      throw DecodingError.dataCorrupted(
        .init(codingPath: decoder.codingPath, debugDescription: "Unknown reading source \(raw)"))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.singleValueContainer()
    switch self {
    case .local: try c.encode("local")
    case .synced(let macID): try c.encode("synced:\(macID)")
    }
  }
}

public struct Reading: Hashable, Sendable, Codable {
  public var device: DeviceID
  public var level: BatteryLevel
  public var charging: Bool
  public var observedAt: Date
  public var source: ReadingSource

  public init(device: DeviceID, level: BatteryLevel, charging: Bool, observedAt: Date,
              source: ReadingSource = .local) {
    self.device = device
    self.level = level
    self.charging = charging
    self.observedAt = observedAt
    self.source = source
  }
}

public struct DeviceInfo: Hashable, Sendable, Codable {
  public var id: DeviceID
  public var name: String
  public var kind: DeviceKind

  public init(id: DeviceID, name: String, kind: DeviceKind) {
    self.id = id
    self.name = name
    self.kind = kind
  }
}

public enum ForecastResult: Hashable, Sendable, Codable {
  case learning
  case estimate(daysLeft: Double, emptyAt: Date)
  case unavailable
}

/// Progress of the current discharge run toward the forecaster's thresholds (2 days, 10 points).
public struct LearningProgress: Hashable, Sendable, Codable {
  public var days: Double
  public var drop: Int

  public init(days: Double, drop: Int) {
    self.days = days
    self.drop = drop
  }
}
