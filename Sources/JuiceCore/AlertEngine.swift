import Foundation

public struct DeviceAlertState: Hashable, Sendable, Codable {
  /// levelID → when it last fired. A present key means the level is disarmed (spec §4).
  public var firedAt: [String: Date] = [:]
  public var snoozedUntil: Date?
  /// Severity index that was current when snoozed; only a more severe level breaks through.
  public var snoozeSeverity: Int?
  public var wasCharging = false

  public init() {}
}

public enum AlertKind: Hashable, Sendable, Codable {
  case level(id: String, name: String, timing: Timing, severity: Int, isRepeat: Bool)
  case fullyCharged
}

public struct AlertDecision: Hashable, Sendable, Codable {
  public var device: DeviceID
  public var kind: AlertKind
  public var reading: Reading

  public init(device: DeviceID, kind: AlertKind, reading: Reading) {
    self.device = device
    self.kind = kind
    self.reading = reading
  }
}

public enum AlertEngine {
  /// A percent level re-arms only after the battery rises this far above its threshold.
  public static let rearmMargin = 5

  public static func evaluate(
    reading: Reading, profile: AlertProfile, forecast: ForecastResult, fullyChargedEnabled: Bool,
    state: DeviceAlertState, now: Date
  ) -> (DeviceAlertState, [AlertDecision]) {
    guard reading.source == .local else { return (state, []) }
    var s = state
    var out: [AlertDecision] = []

    if reading.charging {
      s.firedAt = [:]
      s.snoozedUntil = nil
      s.snoozeSeverity = nil
      s.wasCharging = true
      return (s, out)
    }
    if s.wasCharging {
      s.wasCharging = false
      if fullyChargedEnabled && reading.level.isFull {
        out.append(AlertDecision(device: reading.device, kind: .fullyCharged, reading: reading))
      }
    }

    for level in profile.levels where s.firedAt[level.id] != nil {
      switch level.trigger {
      case .percentAtOrBelow(let threshold):
        if reading.level.equivalentPercent >= threshold + rearmMargin { s.firedAt[level.id] = nil }
      case .forecastDaysAtOrBelow(let days):
        if case .estimate(let left, _) = forecast, left >= days + 1 { s.firedAt[level.id] = nil }
      }
    }

    let triggered = profile.levels.indices.filter {
      profile.levels[$0].enabled && profile.isTriggered(profile.levels[$0], by: reading, forecast: forecast)
    }
    guard let top = triggered.max() else { return (s, out) }
    let level = profile.levels[top]
    let snoozeActive = s.snoozedUntil.map { now < $0 } ?? false
    let suppressed = snoozeActive && top <= (s.snoozeSeverity ?? Int.max)

    func decision(isRepeat: Bool) -> AlertDecision {
      AlertDecision(
        device: reading.device,
        kind: .level(id: level.id, name: level.name, timing: level.timing, severity: top, isRepeat: isRepeat),
        reading: reading)
    }

    if let last = s.firedAt[level.id] {
      if let interval = level.repeatPolicy.interval, now.timeIntervalSince(last) >= interval, !suppressed {
        s.firedAt[level.id] = now
        out.append(decision(isRepeat: true))
      }
    } else {
      // No cascade: crossing several levels at once fires only the most severe (spec §4).
      for i in 0...top where profile.levels[i].enabled { s.firedAt[profile.levels[i].id] = now }
      if !suppressed { out.append(decision(isRepeat: false)) }
    }
    return (s, out)
  }

  public static func snooze(_ state: DeviceAlertState, profile: AlertProfile, now: Date,
                            duration: TimeInterval = 86_400) -> DeviceAlertState {
    var s = state
    s.snoozedUntil = now.addingTimeInterval(duration)
    s.snoozeSeverity = profile.levels.indices.filter { s.firedAt[profile.levels[$0].id] != nil }.max() ?? -1
    return s
  }
}
