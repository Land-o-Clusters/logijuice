import Foundation

/// Geometry and editing rules for the settings window's alert bar (0–100 %, one marker per enabled
/// percent-triggered level). Forecast-triggered and disabled levels are not on the bar.
public enum ThresholdLayout {
  public static let minimum = 1
  public static let maximum = 95

  public struct Marker: Hashable, Sendable {
    public var levelID: String
    public var levelIndex: Int
    public var threshold: Int
    public var tint: IconTint
  }

  public struct Segment: Hashable, Sendable {
    public var from: Int
    public var to: Int
    public var tint: IconTint
    /// nil for the healthy segment above every threshold.
    public var levelID: String?
  }

  public static func markers(_ profile: AlertProfile) -> [Marker] {
    profile.levels.enumerated().compactMap { index, level -> Marker? in
      guard level.enabled, case .percentAtOrBelow(let t) = level.trigger else { return nil }
      return Marker(levelID: level.id, levelIndex: index, threshold: t, tint: level.tint)
    }.sorted { $0.threshold < $1.threshold }
  }

  public static func segments(_ profile: AlertProfile) -> [Segment] {
    var out: [Segment] = []
    var from = 0
    for m in markers(profile) {
      out.append(Segment(from: from, to: m.threshold, tint: m.tint, levelID: m.levelID))
      from = m.threshold
    }
    out.append(Segment(from: from, to: 100, tint: .none, levelID: nil))
    return out
  }

  /// Keeps severity order while dragging: a more severe level (higher index) must sit below a less severe one.
  public static func clamp(_ proposed: Int, levelAt index: Int, in profile: AlertProfile) -> Int {
    let others = markers(profile).filter { $0.levelIndex != index }
    let lower = (others.filter { $0.levelIndex > index }.map(\.threshold).max() ?? (minimum - 1)) + 1
    let upper = (others.filter { $0.levelIndex < index }.map(\.threshold).min() ?? (maximum + 1)) - 1
    guard lower <= upper else {
      if case .percentAtOrBelow(let current) = profile.levels[index].trigger { return current }
      return proposed
    }
    return min(max(proposed, lower), upper)
  }

  public static func setThreshold(_ proposed: Int, levelAt index: Int, in profile: inout AlertProfile) {
    guard profile.levels.indices.contains(index), case .percentAtOrBelow = profile.levels[index].trigger else { return }
    profile.levels[index].trigger = .percentAtOrBelow(clamp(proposed, levelAt: index, in: profile))
  }
}
