import AppKit
import JuiceCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let watchdog = StatusItemWatchdog()

  func applicationDidFinishLaunching(_ notification: Notification) {
    let model = AppModel.shared
    let firstRun = model.isFirstRun
    model.start()
    watchdog.reinsert = {
      model.reinsertingMenuBarItem = true
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { model.reinsertingMenuBarItem = false }
    }
    watchdog.start()
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
    MenuBarExtra(isInserted: Binding(get: { model.menuBarVisible && !model.reinsertingMenuBarItem }, set: { _ in })) {
      MenuContent(model: model)
    } label: {
      MenuBarLabel(devices: model.menuBarDevices, display: model.settings.percentDisplay)
    }
    .menuBarExtraStyle(.window)
  }
}
