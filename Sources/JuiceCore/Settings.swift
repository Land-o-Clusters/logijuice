import Foundation

/// Pre-2026-10-03 menu bar setting. Read once from old settings files for migration; never written.
public enum MenuBarMode: String, Hashable, Sendable, Codable, CaseIterable {
  case auto, always, never
}

public enum PercentDisplay: String, Hashable, Sendable, Codable, CaseIterable {
  case whenLow, always
}

/// Mac-local preferences. Per-device nickname and alert overrides live on `DeviceRecord` (synced);
/// menu bar pins live here because menu bar space differs per Mac.
public struct Settings: Hashable, Sendable, Codable {
  public var profile: AlertProfile = .default
  /// Devices always shown in the menu bar, in display order.
  public var pinnedDevices: [DeviceID] = []
  /// Also show unpinned devices while they are low (a level fired) or charging.
  public var showAlertingInMenuBar = true
  public var percentDisplay: PercentDisplay = .whenLow
  public var fullyChargedEnabled = true
  public var endOfDayHour = 17
  public var endOfDayMinute = 30
  public var maxWaitHours = 8
  public var syncEnabled = true
  /// Set only when an old settings file had `menuBarMode`; the app migrates it once, then it disappears.
  public var legacyMenuBarMode: MenuBarMode?

  public init() {}

  private enum CodingKeys: String, CodingKey {
    case profile, pinnedDevices, showAlertingInMenuBar, percentDisplay, fullyChargedEnabled, endOfDayHour,
      endOfDayMinute, maxWaitHours, syncEnabled
    case menuBarMode  // legacy, read only
  }

  /// Missing keys fall back to defaults so older settings files keep loading after upgrades.
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let d = Settings()
    profile = try c.decodeIfPresent(AlertProfile.self, forKey: .profile) ?? d.profile
    pinnedDevices = try c.decodeIfPresent([DeviceID].self, forKey: .pinnedDevices) ?? d.pinnedDevices
    showAlertingInMenuBar =
      try c.decodeIfPresent(Bool.self, forKey: .showAlertingInMenuBar) ?? d.showAlertingInMenuBar
    percentDisplay = try c.decodeIfPresent(PercentDisplay.self, forKey: .percentDisplay) ?? d.percentDisplay
    fullyChargedEnabled =
      try c.decodeIfPresent(Bool.self, forKey: .fullyChargedEnabled) ?? d.fullyChargedEnabled
    endOfDayHour = try c.decodeIfPresent(Int.self, forKey: .endOfDayHour) ?? d.endOfDayHour
    endOfDayMinute = try c.decodeIfPresent(Int.self, forKey: .endOfDayMinute) ?? d.endOfDayMinute
    maxWaitHours = try c.decodeIfPresent(Int.self, forKey: .maxWaitHours) ?? d.maxWaitHours
    syncEnabled = try c.decodeIfPresent(Bool.self, forKey: .syncEnabled) ?? d.syncEnabled
    legacyMenuBarMode = try c.decodeIfPresent(MenuBarMode.self, forKey: .menuBarMode)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(profile, forKey: .profile)
    try c.encode(pinnedDevices, forKey: .pinnedDevices)
    try c.encode(showAlertingInMenuBar, forKey: .showAlertingInMenuBar)
    try c.encode(percentDisplay, forKey: .percentDisplay)
    try c.encode(fullyChargedEnabled, forKey: .fullyChargedEnabled)
    try c.encode(endOfDayHour, forKey: .endOfDayHour)
    try c.encode(endOfDayMinute, forKey: .endOfDayMinute)
    try c.encode(maxWaitHours, forKey: .maxWaitHours)
    try c.encode(syncEnabled, forKey: .syncEnabled)
  }
}
