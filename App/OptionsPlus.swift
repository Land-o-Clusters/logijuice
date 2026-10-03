import AppKit

enum OptionsPlus {
  static let url = URL(fileURLWithPath: "/Applications/logioptionsplus.app")
  static var isInstalled: Bool { FileManager.default.fileExists(atPath: url.path) }
  static func open() { NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) }
}
