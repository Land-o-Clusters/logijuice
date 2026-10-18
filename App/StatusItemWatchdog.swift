import AppKit
import JuiceCore
import os

/// Re-adds the menu bar item when macOS has parked it off the menu bar (spec §7; seen 2026-10-18 after days of
/// uptime). Checks after display changes, after wake, and every five minutes. Reading window frames is cheap.
@MainActor
final class StatusItemWatchdog {
  /// Debug menu only: re-adds the item now, to check the re-add path without waiting for macOS to strand it.
  static let forceReinsert = Notification.Name("com.penguinspecz.logijuice.forceReinsert")
  var reinsert: (() -> Void)?
  private var observers: [NSObjectProtocol] = []
  private var timer: Timer?
  private var lastReinsert: Date?
  private let log = Logger(subsystem: "com.penguinspecz.logijuice", category: "menubar")

  func start() {
    observers.append(NotificationCenter.default.addObserver(
      forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
    ) { [weak self] _ in MainActor.assumeIsolated { self?.check(after: 3) } })
    let workspace = NSWorkspace.shared.notificationCenter
    for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
      observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        MainActor.assumeIsolated { self?.check(after: 5) }
      })
    }
    observers.append(NotificationCenter.default.addObserver(forName: Self.forceReinsert, object: nil, queue: .main) {
      [weak self] _ in
      MainActor.assumeIsolated {
        self?.log.notice("re-adding the menu bar item (debug menu)")
        self?.reinsert?()
      }
    })
    check(after: 5)
    timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.checkNow() }
    }
  }

  /// Gives macOS time to finish laying out the menu bar after a display or wake change.
  private func check(after delay: TimeInterval) {
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.checkNow() }
  }

  func checkNow() {
    let items = NSApp.windows.filter { $0.className == "NSStatusBarWindow" }.map(\.frame)
    let screens = NSScreen.screens.map(\.frame)
    let stranded = StatusItemPlacement.isStranded(itemFrames: items, screenFrames: screens)
    log.debug("menu bar item frames \(items.map { NSStringFromRect($0) }, privacy: .public) stranded \(stranded)")
    guard StatusItemPlacement.shouldReinsert(stranded: stranded, lastReinsert: lastReinsert, now: Date()) else { return }
    log.notice("menu bar item is off the menu bar at \(items.map { NSStringFromRect($0) }, privacy: .public); re-adding it")
    lastReinsert = Date()
    reinsert?()
  }
}
