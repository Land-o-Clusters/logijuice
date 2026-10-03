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

public struct AlertLevel: Hashable, Sendable, Codable, Identifiable {
  public var id: String
  public var name: String
  public var enabled: Bool
  public var trigger: Trigger
  public var timing: Timing
  public var repeatPolicy: RepeatPolicy
  public var tintsIcon: Bool

  public init(id: String, name: String, enabled: Bool, trigger: Trigger, timing: Timing,
              repeatPolicy: RepeatPolicy, tintsIcon: Bool) {
    self.id = id
    self.name = name
    self.enabled = enabled
    self.trigger = trigger
    self.timing = timing
    self.repeatPolicy = repeatPolicy
    self.tintsIcon = tintsIcon
  }
}

public struct AlertProfile: Hashable, Sendable, Codable {
  /// Ordered least severe → most severe. A level's index is its severity.
  public var levels: [AlertLevel]

  public init(levels: [AlertLevel]) { self.levels = levels }

  public static let `default` = AlertProfile(levels: [
    AlertLevel(id: "low", name: "Low", enabled: true, trigger: .percentAtOrBelow(20),
               timing: .nextMoment, repeatPolicy: .never, tintsIcon: false),
    AlertLevel(id: "veryLow", name: "Very low", enabled: true, trigger: .percentAtOrBelow(10),
               timing: .now, repeatPolicy: .never, tintsIcon: true),
    AlertLevel(id: "critical", name: "Critical", enabled: true, trigger: .percentAtOrBelow(5),
               timing: .now, repeatPolicy: .daily, tintsIcon: true),
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
