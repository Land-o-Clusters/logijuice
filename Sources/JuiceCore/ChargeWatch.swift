import Foundation

/// Tracks which devices are charging, so the app can re-read them often enough for the gauge to fill as they charge.
/// Devices don't reliably announce each step while on the cable, and the 30-minute safety re-read is too slow to watch.
public struct ChargeWatch<Key: Hashable> {
  /// How often a charging device is re-read. Levels move in 5% steps, a few minutes apart on a fast charge.
  public static var interval: TimeInterval { 60 }

  public private(set) var charging: Set<Key> = []
  public var isActive: Bool { !charging.isEmpty }

  public init() {}

  /// Records a device's latest charging state. Pass `charging: false` when it goes out of reach, too.
  public mutating func observe(_ key: Key, charging isCharging: Bool) {
    if isCharging { charging.insert(key) } else { charging.remove(key) }
  }

  public mutating func reset() { charging = [] }
}
