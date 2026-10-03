import Foundation

public struct NotificationText: Hashable, Sendable {
  public var title: String
  public var body: String
  public var identifier: String

  public init(title: String, body: String, identifier: String) {
    self.title = title
    self.body = body
    self.identifier = identifier
  }
}

public enum Format {
  public static func level(_ level: BatteryLevel) -> String {
    switch level {
    case .percent(let p): return "\(p)%"
    case .word(let w):
      switch w {
      case .critical: return "Critical"
      case .low: return "Low"
      case .good: return "Good"
      case .full: return "Full"
      }
    }
  }

  public static func duration(days: Double) -> String {
    if days >= 2 { return "\(Int(days.rounded())) days" }
    let hours = max(1, Int((days * 24).rounded()))
    return hours == 1 ? "1 hour" : "\(hours) hours"
  }

  public static func forecast(_ f: ForecastResult) -> String? {
    switch f {
    case .learning: return "learning…"
    case .unavailable: return nil
    case .estimate(let days, _): return "~" + duration(days: days)
    }
  }

  public static func seen(_ date: Date?, now: Date) -> String {
    guard let date else { return "never seen" }
    let s = max(0, now.timeIntervalSince(date))
    switch s {
    case ..<120: return "seen just now"
    case ..<3600: return "seen \(Int(s / 60))m ago"
    case ..<172_800: return "seen \(Int(s / 3600))h ago"
    default: return "seen \(Int(s / 86_400))d ago"
    }
  }

  /// Secondary line used by the menu, settings and widget: forecast, plus staleness when not live.
  public static func subtitle(_ d: SnapshotDevice, now: Date) -> String {
    let estimate = d.learning.map(learning) ?? forecast(d.forecast)
    return [estimate, d.live ? nil : seen(d.lastSeen, now: now)].compactMap { $0 }.joined(separator: " · ")
  }

  public static func learning(_ p: LearningProgress) -> String {
    let daysLeft = Forecaster.minimumSpan / 86_400 - p.days
    if daysLeft > 0 {
      let n = max(1, Int(daysLeft.rounded(.up)))
      return "learning · first estimate in ~\(n) \(n == 1 ? "day" : "days")"
    }
    let dropLeft = max(1, Int(Forecaster.minimumDrop) - p.drop)
    return "learning · after another \(dropLeft)% drop"
  }

  public static func notificationBody(level: BatteryLevel, forecast: ForecastResult) -> String {
    var s = Format.level(level)
    if case .estimate(let days, _) = forecast { s += " · about " + duration(days: days) + " left" }
    return s
  }

  public static func notification(for delivery: Delivery, displayName: String,
                                  forecast: ForecastResult) -> NotificationText {
    let d = delivery.decision
    switch d.kind {
    case .fullyCharged:
      return NotificationText(title: displayName, body: "Fully charged. Unplug whenever you like.",
                              identifier: "\(d.device.rawValue).full")
    case .level(let id, _, _, _, _):
      let body = notificationBody(level: d.reading.level, forecast: forecast)
      let identifier = "\(d.device.rawValue).\(id)"
      if delivery.moment == .receiverDeparted {
        return NotificationText(title: "Leaving this desk?", body: "\(displayName) is at \(body)", identifier: identifier)
      }
      return NotificationText(title: displayName, body: body, identifier: identifier)
    }
  }

  public static func statusLine(_ d: SnapshotDevice, now: Date) -> String {
    var line = "\(d.displayName): \(d.level.map(level) ?? "unknown")"
    if d.charging { line += " (charging)" }
    if let f = forecast(d.forecast) { line += ", \(f)" }
    if !d.live { line += ", \(seen(d.lastSeen, now: now))" }
    return line
  }

  /// Text beside a menu bar gauge: always, or only while that device is alerting.
  public static func menuBarText(_ device: SnapshotDevice, display: PercentDisplay) -> String? {
    guard let level = device.level else { return nil }
    switch display {
    case .always: return Format.level(level)
    case .whenLow: return device.alerting ? Format.level(level) : nil
    }
  }

  public static func batterySymbol(percent: Int?) -> String {
    guard let p = percent else { return "battery.0percent" }
    switch p {
    case ..<13: return "battery.0percent"
    case ..<38: return "battery.25percent"
    case ..<63: return "battery.50percent"
    case ..<88: return "battery.75percent"
    default: return "battery.100percent"
    }
  }
}

extension DeviceKind {
  /// Outline + filled SF Symbol pair: the menu bar draws the device's own shape as its battery gauge.
  public var gaugeSymbols: (outline: String, fill: String) {
    switch self {
    case .keyboard: return ("keyboard", "keyboard.fill")
    case .mouse: return ("computermouse", "computermouse.fill")
    case .trackball: return ("circle.circle", "circle.circle.fill")
    case .touchpad: return ("rectangle.and.hand.point.up.left", "rectangle.and.hand.point.up.left.fill")
    case .numpad: return ("number.square", "number.square.fill")
    case .presenter: return ("av.remote", "av.remote.fill")
    case .other: return ("circle", "circle.fill")
    }
  }

  /// SF Symbol for the device kind, shared by menu, settings and widget.
  public var symbolName: String {
    switch self {
    case .keyboard: return "keyboard"
    case .mouse: return "computermouse"
    case .trackball: return "circle.circle"
    case .touchpad: return "rectangle.and.hand.point.up.left"
    case .numpad: return "number.square"
    case .presenter: return "av.remote"
    case .other: return "dot.radiowaves.left.and.right"
    }
  }
}
