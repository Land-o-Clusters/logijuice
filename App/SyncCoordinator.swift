import Foundation
import JuiceCore
import JuiceStore
import os

/// Writes this Mac's file (throttled) and polls the others (spec §6).
@MainActor
final class SyncCoordinator {
  static let writeInterval: TimeInterval = 300
  static let pollInterval: TimeInterval = 120

  let store: SyncStore
  var onRemoteFiles: (([SyncFile]) -> Void)?
  private let log = Logger(subsystem: "com.penguinspecz.logijuice", category: "sync")
  private var timer: Timer?
  private var lastWrite = Date.distantPast

  init(store: SyncStore) { self.store = store }

  var isAvailable: Bool { store.isAvailable }

  func start() {
    poll()
    timer?.invalidate()
    timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.poll() }
    }
  }

  func stop() {
    timer?.invalidate()
    timer = nil
    onRemoteFiles?([])
  }

  func poll() {
    onRemoteFiles?(store.isAvailable ? store.readOthers() : [])
  }

  func write(records: [DeviceRecord], force: Bool, now: Date = Date()) {
    guard store.isAvailable, force || now.timeIntervalSince(lastWrite) >= Self.writeInterval else { return }
    // Debug devices ("debug:…") are local test fixtures and never leave this Mac.
    let own = records.filter { !$0.info.id.rawValue.hasPrefix("debug:") }.map { record -> DeviceRecord in
      var copy = record
      copy.readings = record.readings.filter { $0.source == .local }
      return copy
    }
    do {
      try store.writeOwn(SyncFile(macID: store.macID, macName: MacIdentity.name(), updatedAt: now, devices: own))
      lastWrite = now
    } catch {
      log.error("sync write failed: \(error.localizedDescription, privacy: .public)")
    }
  }
}
