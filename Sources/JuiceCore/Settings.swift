import Foundation

public enum MenuBarMode: String, Hashable, Sendable, Codable, CaseIterable {
  case auto, always, never
}

/// Mac-local preferences. Per-device nickname and alert overrides live on `DeviceRecord` (synced).
public struct Settings: Hashable, Sendable, Codable {
  public var profile: AlertProfile = .default
  public var menuBarMode: MenuBarMode = .auto
  public var fullyChargedEnabled = true
  public var endOfDayHour = 17
  public var endOfDayMinute = 30
  public var maxWaitHours = 8
  public var syncEnabled = true

  public init() {}

  private enum CodingKeys: String, CodingKey {
    case profile, menuBarMode, fullyChargedEnabled, endOfDayHour, endOfDayMinute, maxWaitHours,
      syncEnabled
  }

  /// Missing keys fall back to defaults so older settings files keep loading after upgrades.
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let d = Settings()
    profile = try c.decodeIfPresent(AlertProfile.self, forKey: .profile) ?? d.profile
    menuBarMode = try c.decodeIfPresent(MenuBarMode.self, forKey: .menuBarMode) ?? d.menuBarMode
    fullyChargedEnabled =
      try c.decodeIfPresent(Bool.self, forKey: .fullyChargedEnabled) ?? d.fullyChargedEnabled
    endOfDayHour = try c.decodeIfPresent(Int.self, forKey: .endOfDayHour) ?? d.endOfDayHour
    endOfDayMinute = try c.decodeIfPresent(Int.self, forKey: .endOfDayMinute) ?? d.endOfDayMinute
    maxWaitHours = try c.decodeIfPresent(Int.self, forKey: .maxWaitHours) ?? d.maxWaitHours
    syncEnabled = try c.decodeIfPresent(Bool.self, forKey: .syncEnabled) ?? d.syncEnabled
  }
}
