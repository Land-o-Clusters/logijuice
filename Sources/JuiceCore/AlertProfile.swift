import Foundation

public enum Trigger: Hashable, Sendable, Codable {
  case percentAtOrBelow(Int)
  /// Only evaluated when the forecast is a confident estimate.
  case forecastDaysAtOrBelow(Double)
}

public enum Timing: String, Hashable, Sendable, Codable {
  case now
  case nextMoment
}

public enum RepeatPolicy: Hashable, Sendable, Codable {
  case never
  case everyHours(Int)
  case daily

  public var interval: TimeInterval? {
    switch self {
    case .never: return nil
    case .everyHours(let hours): return TimeInterval(max(1, hours)) * 3600
    case .daily: return 86_400
    }
  }
}

/// Menu bar/widget color a fired level gives its device. Ordered by severity.
public enum IconTint: String, Hashable, Sendable, Codable, CaseIterable, Comparable {
  case none, yellow, red

  private var rank: Int { IconTint.allCases.firstIndex(of: self) ?? 0 }
  public static func < (a: IconTint, b: IconTint) -> Bool { a.rank < b.rank }
}

public struct AlertLevel: Hashable, Sendable, Codable, Identifiable {
  public var id: String
  public var name: String
  public var enabled: Bool
  public var trigger: Trigger
  public var timing: Timing
  public var repeatPolicy: RepeatPolicy
  public var tint: IconTint

  public init(id: String, name: String, enabled: Bool, trigger: Trigger, timing: Timing,
              repeatPolicy: RepeatPolicy, tint: IconTint) {
    self.id = id
    self.name = name
    self.enabled = enabled
    self.trigger = trigger
    self.timing = timing
    self.repeatPolicy = repeatPolicy
    self.tint = tint
  }

  private enum CodingKeys: String, CodingKey {
    case id, name, enabled, trigger, timing, repeatPolicy, tint
    case tintsIcon  // pre-2026-10-03 Bool; read only
  }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    id = try c.decode(String.self, forKey: .id)
    name = try c.decode(String.self, forKey: .name)
    enabled = try c.decode(Bool.self, forKey: .enabled)
    trigger = try c.decode(Trigger.self, forKey: .trigger)
    timing = try c.decode(Timing.self, forKey: .timing)
    repeatPolicy = try c.decode(RepeatPolicy.self, forKey: .repeatPolicy)
    if let tint = try c.decodeIfPresent(IconTint.self, forKey: .tint) {
      self.tint = tint
    } else {
      tint = (try c.decodeIfPresent(Bool.self, forKey: .tintsIcon) ?? false) ? .red : .none
    }
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(id, forKey: .id)
    try c.encode(name, forKey: .name)
    try c.encode(enabled, forKey: .enabled)
    try c.encode(trigger, forKey: .trigger)
    try c.encode(timing, forKey: .timing)
    try c.encode(repeatPolicy, forKey: .repeatPolicy)
    try c.encode(tint, forKey: .tint)
  }
}

public struct AlertProfile: Hashable, Sendable, Codable {
  /// Ordered least severe → most severe. A level's index is its severity.
  public var levels: [AlertLevel]

  public init(levels: [AlertLevel]) { self.levels = levels }

  public static let `default` = AlertProfile(levels: [
    AlertLevel(id: "low", name: "Low", enabled: true, trigger: .percentAtOrBelow(20),
               timing: .nextMoment, repeatPolicy: .never, tint: .yellow),
    AlertLevel(id: "veryLow", name: "Very low", enabled: true, trigger: .percentAtOrBelow(10),
               timing: .now, repeatPolicy: .never, tint: .red),
    AlertLevel(id: "critical", name: "Critical", enabled: true, trigger: .percentAtOrBelow(5),
               timing: .now, repeatPolicy: .daily, tint: .red),
  ])

  public func isTriggered(_ level: AlertLevel, by reading: Reading, forecast: ForecastResult) -> Bool {
    switch level.trigger {
    case .percentAtOrBelow(let threshold):
      return reading.level.equivalentPercent <= threshold
    case .forecastDaysAtOrBelow(let days):
      if case .estimate(let left, _) = forecast { return left <= days }
      return false
    }
  }
}
