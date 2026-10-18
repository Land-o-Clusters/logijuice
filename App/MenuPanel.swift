import AppKit
import os
import SwiftUI

/// The menu bar dropdown's window. MenuBarExtra closes it only when another app takes focus, so it stayed open over
/// Settings. This closes it whenever it stops being key, and on request.
@MainActor
final class MenuPanel {
  static let shared = MenuPanel()
  private weak var window: NSWindow?
  private var observer: NSObjectProtocol?
  private let log = Logger(subsystem: "com.penguinspecz.logijuice", category: "menubar")

  fileprivate func attach(_ w: NSWindow) {
    guard w !== window else { return }
    window = w
    log.debug("dropdown window attached")
    if let observer { NotificationCenter.default.removeObserver(observer) }
    observer = NotificationCenter.default.addObserver(
      forName: NSWindow.didResignKeyNotification, object: w, queue: .main
    ) { [weak self] _ in
      // Next turn of the run loop: if MenuBarExtra is already closing it (a click in another app), leave it be.
      DispatchQueue.main.async { MainActor.assumeIsolated { self?.close() } }
    }
  }

  func close() {
    guard let window, window.isVisible else { return }
    log.debug("closing the dropdown")
    window.close()
  }
}

/// Hands the hosting window of the dropdown to `MenuPanel`.
struct MenuPanelAnchor: NSViewRepresentable {
  func makeNSView(context: Context) -> AnchorView { AnchorView() }
  func updateNSView(_ nsView: AnchorView, context: Context) {}

  final class AnchorView: NSView {
    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      guard let window else { return }
      MainActor.assumeIsolated { MenuPanel.shared.attach(window) }
    }
  }
}
