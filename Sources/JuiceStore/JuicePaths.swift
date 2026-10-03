import Foundation

public struct JuicePaths: Sendable {
  public var appSupport: URL
  public var iCloudFolder: URL

  public init(appSupport: URL, iCloudFolder: URL) {
    self.appSupport = appSupport
    self.iCloudFolder = iCloudFolder
  }

  public static func standard() -> JuicePaths {
    let home = realHome()
    return JuicePaths(
      appSupport: home.appendingPathComponent("Library/Application Support/logijuice"),
      iCloudFolder: home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/logijuice"))
  }

  /// The user's home from the user record. Inside the widget's sandbox, `homeDirectoryForCurrentUser` is the
  /// sandbox container, so it can't locate the snapshot.
  public static func realHome() -> URL {
    if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
      return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
    }
    return FileManager.default.homeDirectoryForCurrentUser
  }

  public var settingsURL: URL { appSupport.appendingPathComponent("settings.json") }
  public var stateURL: URL { appSupport.appendingPathComponent("state.json") }
  /// The one contract between the app and its readers (widget, CLI, Shortcuts). Not in the app-group container:
  /// macOS refuses the ad-hoc-signed app's writes there (EPERM). The widget reads it through a read-only
  /// sandbox exception for this folder.
  public var snapshotURL: URL { appSupport.appendingPathComponent("snapshot.json") }
}
