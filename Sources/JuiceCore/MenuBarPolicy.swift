import Foundation

public enum MenuBarPolicy {
  /// Pinned devices first (in pin order), then — if enabled — unpinned devices that are alerting or
  /// charging while live. Empty means the menu bar item hides (spec §7, amended 2026-10-03).
  public static func visibleDevices(snapshot: Snapshot, pinned: [DeviceID], showAlerting: Bool) -> [SnapshotDevice] {
    let byID = Dictionary(snapshot.devices.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    var shown = pinned.compactMap { byID[$0] }
    var seen = Set(shown.map(\.id))
    if showAlerting {
      for d in snapshot.devices where !seen.contains(d.id) && (d.alerting || (d.charging && d.live)) {
        shown.append(d)
        seen.insert(d.id)
      }
    }
    return shown
  }

  /// The color of the most severe fired level that has one.
  public static func tint(state: DeviceAlertState, profile: AlertProfile) -> IconTint {
    profile.levels.filter { state.firedAt[$0.id] != nil }.map(\.tint).max() ?? .none
  }
}
