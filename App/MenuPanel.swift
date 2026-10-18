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

  /// MenuBarExtra doesn't resize its panel when the content changes height while open, which clipped the
  /// expanded device details. This fits the panel to the content, keeping its top edge under the menu bar.
  func fit(contentHeight height: CGFloat) {
    guard let window, window.isVisible, height > 0 else { return }
    let current = window.contentRect(forFrameRect: window.frame)
    guard abs(current.height - height) > 0.5 else { return }
    var content = current
    content.origin.y += current.height - height
    content.size.height = height
    let frame = window.frameRect(forContentRect: content)
    NSAnimationContext.runAnimationGroup { context in
      context.duration = Self.resizeDuration
      context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
      window.animator().setFrame(frame, display: true)
    }
  }

  /// Shared with the SwiftUI fade on the details so the window and its content move together.
  static let resizeDuration: TimeInterval = 0.2

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
