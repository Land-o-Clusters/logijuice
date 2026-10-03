import AppKit
import JuiceCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    let model = AppModel.shared
    let firstRun = model.isFirstRun
    model.start()
    if firstRun { SettingsWindowController.shared.show() }
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    SettingsWindowController.shared.show()
    return true
  }

  func application(_ application: NSApplication, open urls: [URL]) {
    SettingsWindowController.shared.show()
  }

  func applicationWillTerminate(_ notification: Notification) {
    AppModel.shared.saveNow()
  }
}

@main
struct LogiJuiceApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
  @ObservedObject private var model = AppModel.shared

  var body: some Scene {
    MenuBarExtra(isInserted: Binding(get: { model.menuBarVisible }, set: { _ in })) {
      MenuContent(model: model)
    } label: {
      MenuBarLabel(snapshot: model.snapshot, tinted: model.iconTinted)
    }
    .menuBarExtraStyle(.window)
  }
}
