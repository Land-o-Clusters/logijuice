import Foundation

public struct JuicePaths: Sendable {
  public static let appGroupID = "group.com.penguinspecz.logijuice"

  public var appSupport: URL
  public var groupContainer: URL
  public var iCloudFolder: URL

  public init(appSupport: URL, groupContainer: URL, iCloudFolder: URL) {
    self.appSupport = appSupport
    self.groupContainer = groupContainer
    self.iCloudFolder = iCloudFolder
  }

  public static func standard() -> JuicePaths {
    let fm = FileManager.default
    let home = fm.homeDirectoryForCurrentUser
    let group = fm.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
      ?? home.appendingPathComponent("Library/Group Containers/\(appGroupID)")
    return JuicePaths(
      appSupport: home.appendingPathComponent("Library/Application Support/logijuice"),
      groupContainer: group,
      iCloudFolder: home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/logijuice"))
  }

  public var settingsURL: URL { appSupport.appendingPathComponent("settings.json") }
  public var stateURL: URL { appSupport.appendingPathComponent("state.json") }
  /// Read by the widget (sandboxed, app group).
  public var snapshotURL: URL { groupContainer.appendingPathComponent("snapshot.json") }
  /// Read by the CLI, avoiding macOS's cross-app group-container prompt.
  public var cliSnapshotURL: URL { appSupport.appendingPathComponent("snapshot.json") }
}
