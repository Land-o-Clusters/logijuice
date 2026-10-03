import Foundation

public enum History {
  public static let retention: TimeInterval = 90 * 86_400
  public static let maxReadings = 2_000
  /// Identical readings closer than this are collapsed so event bursts don't flood history.
  public static let duplicateWindow: TimeInterval = 600

  public static func appending(_ reading: Reading, to readings: [Reading], now: Date) -> [Reading] {
    if let last = readings.last, last.level == reading.level, last.charging == reading.charging,
      reading.observedAt.timeIntervalSince(last.observedAt) < duplicateWindow
    {
      return readings
    }
    return trim(readings + [reading], now: now)
  }

  public static func trim(_ readings: [Reading], now: Date) -> [Reading] {
    let cutoff = now.addingTimeInterval(-retention)
    let kept = readings.filter { $0.observedAt >= cutoff }.sorted { $0.observedAt < $1.observedAt }
    return Array(kept.suffix(maxReadings))
  }
}
