import AppKit
import JuiceCore
import SwiftUI

@MainActor
final class SettingsWindowController {
  static let shared = SettingsWindowController()
  private var window: NSWindow?

  func show() {
    if window == nil {
      let model = AppModel.shared
      let hosting = NSHostingController(rootView: SettingsView(model: model, notifier: model.notifier))
      let w = NSWindow(contentViewController: hosting)
      w.title = "LogiJuice"
      w.styleMask = [.titled, .closable, .miniaturizable]
      w.isReleasedWhenClosed = false
      w.center()
      window = w
    }
    AppModel.shared.notifier.refreshAuthorization()
    NSApp.activate(ignoringOtherApps: true)
    window?.makeKeyAndOrderFront(nil)
  }
}

struct SettingsView: View {
  @ObservedObject var model: AppModel
  @ObservedObject var notifier: Notifier

  var body: some View {
    List(model.snapshot.devices) { DeviceRow(device: $0, now: Date()) }
      .frame(width: 420, height: 300)
  }
}
