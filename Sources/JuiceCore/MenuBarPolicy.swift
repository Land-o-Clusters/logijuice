import Foundation

public enum MenuBarPolicy {
  /// Auto: visible while any device has a fired level, or a live device is charging (spec §7).
  public static func isVisible(mode: MenuBarMode, snapshot: Snapshot) -> Bool {
    switch mode {
    case .always: return true
    case .never: return false
    case .auto: return snapshot.devices.contains { $0.alerting || ($0.charging && $0.live) }
    }
  }

  public static func isTinted(state: DeviceAlertState, profile: AlertProfile) -> Bool {
    profile.levels.contains { $0.tintsIcon && state.firedAt[$0.id] != nil }
  }
}
