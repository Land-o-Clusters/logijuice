import Foundation
import JuiceCore
import JuiceHID
import os

/// Owns the receiver connection: attach/detach on hotplug, identify slots, emit readings.
@MainActor
final class HIDCoordinator {
  var onReading: ((Reading, DeviceInfo) -> Void)?
  var onReceiverChange: ((Bool) -> Void)?

  private let log = Logger(subsystem: "com.penguinspecz.logijuice", category: "hid")
  private let monitor = ReceiverMonitor()
  private var broker: RequestBroker?
  private var session: ReceiverSession?
  private var slots: [UInt8: SlotInfo] = [:]
  private var eventTask: Task<Void, Never>?
  private var safetyTimer: Timer?
  private var chargeWatch = ChargeWatch<UInt8>()
  private var chargeTimer: Timer?

  func start() {
    monitor.onArrive = { [weak self] channel in MainActor.assumeIsolated { self?.attach(channel) } }
    monitor.onDepart = { [weak self] in MainActor.assumeIsolated { self?.detach() } }
    monitor.start()
    // 30 min: covers Macs where the receiver's notification flags are off (bring-up notes).
    safetyTimer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.refreshAll() }
    }
  }

  func refreshAll() {
    Task { await self.scan() }
  }

  private func attach(_ channel: IOHIDReceiverChannel) {
    log.info("receiver attached")
    let broker = RequestBroker(channel: channel)
    broker.start()
    self.broker = broker
    session = ReceiverSession(broker: broker)
    onReceiverChange?(true)
    eventTask = Task { [weak self] in
      for await frame in broker.events { await self?.handle(frame) }
    }
    refreshAll()
  }

  private func detach() {
    log.info("receiver departed")
    eventTask?.cancel()
    eventTask = nil
    if let broker { Task { await broker.close() } }
    broker = nil
    session = nil
    slots = [:]
    chargeWatch.reset()
    updateChargeTimer()
    onReceiverChange?(false)
  }

  private func scan() async {
    guard let session else { return }
    for slot in UInt8(1)...6 where slots[slot] == nil {
      if let info = await session.identify(slot: slot) {
        log.info("slot \(slot): \(info.info.name, privacy: .public) \(info.info.id.rawValue, privacy: .public)")
        slots[slot] = info
      }
    }
    for info in slots.values.sorted(by: { $0.slot < $1.slot }) { await read(info) }
  }

  private func read(_ info: SlotInfo) async {
    guard let session, let report = await session.readBattery(info) else { return }
    emit(report, info)
  }

  private func emit(_ report: BatteryReport, _ info: SlotInfo) {
    chargeWatch.observe(info.slot, charging: report.charging)
    updateChargeTimer()
    onReading?(Reading(device: info.info.id, level: report.level, charging: report.charging, observedAt: Date()), info.info)
  }

  /// Re-reads charging devices every minute so the gauge fills while they charge; stops when none is charging.
  private func updateChargeTimer() {
    if chargeWatch.isActive, chargeTimer == nil {
      log.info("charging: re-reading every \(Int(ChargeWatch<UInt8>.interval), privacy: .public) s")
      chargeTimer = Timer.scheduledTimer(withTimeInterval: ChargeWatch<UInt8>.interval, repeats: true) { [weak self] _ in
        MainActor.assumeIsolated { self?.refreshCharging() }
      }
    } else if !chargeWatch.isActive, let timer = chargeTimer {
      log.info("charging: stopped re-reading")
      timer.invalidate()
      chargeTimer = nil
    }
  }

  private func refreshCharging() {
    Task {
      for slot in chargeWatch.charging.sorted() {
        if let info = slots[slot] { await read(info) }
      }
    }
  }

  private func handle(_ frame: HIDPPFrame) async {
    switch ReceiverSession.interpret(frame, slots: slots) {
    case .battery(let slot, let report)?:
      if let info = slots[slot] { emit(report, info) }
    case .linkUp(let slot)?:
      if slots[slot] == nil, let session, let info = await session.identify(slot: slot) { slots[slot] = info }
      if let info = slots[slot] { await read(info) }
    case .linkDown(let slot)?:
      chargeWatch.observe(slot, charging: false)
      updateChargeTimer()
    case nil:
      break
    }
  }
}
