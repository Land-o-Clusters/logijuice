import AppKit
import Foundation
import JuiceCore
import JuiceStore
import WidgetKit

@MainActor
final class AppModel: ObservableObject {
  static let shared = AppModel()

  @Published var settings: Settings {
    didSet {
      guard settings != oldValue else { return }
      try? settingsStore.save(settings)
      state.scheduler.maxWait = TimeInterval(settings.maxWaitHours) * 3600
      moments.reschedule(endOfDayHour: settings.endOfDayHour, minute: settings.endOfDayMinute)
      if settings.syncEnabled != oldValue.syncEnabled {
        if settings.syncEnabled { sync.start() } else { sync.stop() }
      }
      publish()
    }
  }
  @Published private(set) var snapshot: Snapshot = .empty
  @Published private(set) var receiverPresent = false

  let paths: JuicePaths
  let notifier = Notifier()
  let moments = MomentMonitor()
  let hid = HIDCoordinator()
  let sync: SyncCoordinator
  private let settingsStore: SettingsStore
  private let stateStore: StateStore
  private let snapshotStore: SnapshotStore
  private let cliSnapshotStore: SnapshotStore
  private(set) var state: LocalState
  var remoteFiles: [SyncFile] = []
  private var liveDevices: Set<DeviceID> = []
  private var tickTimer: Timer?
  private var saveWork: DispatchWorkItem?

  init(paths: JuicePaths = .standard()) {
    self.paths = paths
    settingsStore = SettingsStore(url: paths.settingsURL)
    stateStore = StateStore(url: paths.stateURL)
    snapshotStore = SnapshotStore(url: paths.snapshotURL)
    cliSnapshotStore = SnapshotStore(url: paths.cliSnapshotURL)
    sync = SyncCoordinator(store: SyncStore(folder: paths.iCloudFolder, macID: MacIdentity.hardwareUUID()))
    let loadedSettings = settingsStore.load(default: Settings())
    settings = loadedSettings
    var loadedState = stateStore.load(default: LocalState())
    loadedState.scheduler.maxWait = TimeInterval(loadedSettings.maxWaitHours) * 3600
    state = loadedState
  }

  var isFirstRun: Bool { state.records.isEmpty }
  var menuBarDevices: [SnapshotDevice] {
    MenuBarPolicy.visibleDevices(snapshot: snapshot, pinned: settings.pinnedDevices,
                                 showAlerting: settings.showAlertingInMenuBar)
  }
  var menuBarVisible: Bool { !menuBarDevices.isEmpty }
  var syncAvailable: Bool { sync.isAvailable }

  func isPinned(_ id: DeviceID) -> Bool { settings.pinnedDevices.contains(id) }

  func setPinned(_ pinned: Bool, for id: DeviceID) {
    if pinned {
      if !settings.pinnedDevices.contains(id) { settings.pinnedDevices.append(id) }
    } else {
      settings.pinnedDevices.removeAll { $0 == id }
    }
  }

  /// One-time migration of the pre-2026-10-03 Auto/Always/Never setting.
  private func migrateLegacyMenuBarMode() {
    guard let legacy = settings.legacyMenuBarMode else { return }
    var next = settings
    switch legacy {
    case .always: next.pinnedDevices = mergedRecords.map(\.info.id).filter { !$0.rawValue.hasPrefix("debug:") }
    case .never: next.showAlertingInMenuBar = false
    case .auto: break
    }
    next.legacyMenuBarMode = nil
    settings = next
  }

  var mergedRecords: [DeviceRecord] {
    SyncMerge.merge(local: state.records, remotes: settings.syncEnabled ? remoteFiles : [], now: Date())
  }

  func start() {
    if !UserDefaults.standard.bool(forKey: "registeredLoginItem") {
      LoginItem.set(true)
      UserDefaults.standard.set(true, forKey: "registeredLoginItem")
    }
    notifier.onSnooze = { [weak self] id in self?.snooze(id) }
    notifier.start()
    moments.onMoment = { [weak self] moment in self?.handleMoment(moment) }
    moments.start(endOfDayHour: settings.endOfDayHour, minute: settings.endOfDayMinute)
    hid.onReading = { [weak self] reading, info in self?.ingest(reading, info: info) }
    hid.onReceiverChange = { [weak self] present in self?.receiverChanged(present) }
    hid.start()
    sync.onRemoteFiles = { [weak self] files in
      self?.remoteFiles = files
      self?.publish()
    }
    if settings.syncEnabled { sync.start() }
    migrateLegacyMenuBarMode()
    tickTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.handleTick() }
    }
    publish()
  }

  // MARK: Pipeline

  func ingest(_ reading: Reading, info: DeviceInfo) {
    let now = reading.observedAt
    let history = mergedRecords.first { $0.info.id == reading.device }?.readings ?? []
    let previous = state.records.first { $0.info.id == reading.device }?.readings.last
    let macID = sync.store.macID
    upsertLocal(info) { record in
      record.health = HealthTracker.update(record.health, previous: previous, reading: reading, history: history,
                                           macID: macID)
      record.readings = History.appending(reading, to: record.readings, now: now)
    }
    if reading.source == .local { liveDevices.insert(reading.device) }
    let record = mergedRecords.first { $0.info.id == reading.device }
    let forecast = Forecaster.forecast(record?.readings ?? [reading], now: now)
    let profile = record?.alertOverride ?? settings.profile
    let (next, decisions) = AlertEngine.evaluate(
      reading: reading, profile: profile, forecast: forecast, fullyChargedEnabled: settings.fullyChargedEnabled,
      state: state.alertStates[reading.device] ?? DeviceAlertState(), now: now)
    state.alertStates[reading.device] = next
    if reading.charging { state.scheduler.dropPending(for: reading.device) }
    publish()
    for decision in decisions { deliver(state.scheduler.schedule(decision, now: now)) }
    if let record { checkDrain(record, reading: reading, now: now) }
    saveSoon()
    if settings.syncEnabled { sync.write(records: state.records, force: false) }
  }

  /// Opt-in alert when a device drains about twice as fast as its own history; at most once per discharge run.
  private func checkDrain(_ record: DeviceRecord, reading: Reading, now: Date) {
    guard settings.drainAlertEnabled, reading.source == .local, !reading.charging,
      let ratio = HealthTracker.drainRatio(record.health, history: record.readings, now: now),
      ratio >= HealthTracker.drainAlertRatio,
      let runStart = HealthTracker.currentRunStart(record.readings),
      state.drainAlertedRuns?[reading.device] != runStart
    else { return }
    let typical = HealthTracker.report(record.health).daysPerCharge ?? 0
    notifier.post(Format.drainAlert(displayName: record.displayName, device: reading.device, ratio: ratio,
                                    typicalDays: typical), device: reading.device)
    var alerted = state.drainAlertedRuns ?? [:]
    alerted[reading.device] = runStart
    state.drainAlertedRuns = alerted
  }

  func deliver(_ deliveries: [Delivery]) {
    for delivery in deliveries {
      let device = snapshot.devices.first { $0.id == delivery.decision.device }
      let text = Format.notification(for: delivery, displayName: device?.displayName ?? "Logitech device",
                                     forecast: device?.forecast ?? .learning)
      notifier.post(text, device: delivery.decision.device)
    }
  }

  func handleMoment(_ moment: Moment) {
    deliver(state.scheduler.onMoment(moment, now: Date()))
    if moment == .willSleep || moment == .receiverDeparted {
      saveNow()
      if settings.syncEnabled { sync.write(records: state.records, force: true) }
    } else {
      saveSoon()
    }
  }

  func handleTick() {
    deliver(state.scheduler.onTick(now: Date()))
    publish()
  }

  func snooze(_ id: DeviceID) {
    let profile = alertOverride(for: id) ?? settings.profile
    state.alertStates[id] = AlertEngine.snooze(state.alertStates[id] ?? DeviceAlertState(), profile: profile, now: Date())
    saveSoon()
  }

  func receiverChanged(_ present: Bool) {
    receiverPresent = present
    if !present {
      liveDevices.removeAll()
      handleMoment(.receiverDeparted)
    }
    publish()
  }

  func publish() {
    let now = Date()
    let records = mergedRecords
    var alerting = Set<DeviceID>()
    var tints: [DeviceID: IconTint] = [:]
    for record in records {
      let alertState = state.alertStates[record.info.id] ?? DeviceAlertState()
      if !alertState.firedAt.isEmpty { alerting.insert(record.info.id) }
      tints[record.info.id] = MenuBarPolicy.tint(state: alertState, profile: record.alertOverride ?? settings.profile)
    }
    let next = SnapshotBuilder.build(records: records, liveDevices: liveDevices, receiverPresent: receiverPresent,
                                     alerting: alerting, tints: tints, now: now)
    let changed = next.devices != snapshot.devices || next.receiverPresent != snapshot.receiverPresent
    snapshot = next
    if changed {
      try? snapshotStore.save(next)
      try? cliSnapshotStore.save(next)
      WidgetCenter.shared.reloadAllTimelines()
    }
  }

  // MARK: Settings-window API

  func alertOverride(for id: DeviceID) -> AlertProfile? {
    mergedRecords.first { $0.info.id == id }?.alertOverride
  }

  func setAlertOverride(_ profile: AlertProfile?, for id: DeviceID) {
    mutateMeta(id) { $0.alertOverride = profile }
  }

  func setNickname(_ name: String, for id: DeviceID) {
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    mutateMeta(id) { $0.nickname = trimmed.isEmpty ? nil : trimmed }
  }

  /// Debug aid (enable with `defaults write com.penguinspecz.logijuice debugMenu -bool true`).
  func simulateLowBattery(percent: Int) {
    let info = DeviceInfo(id: DeviceID("debug:test-mouse"), name: "Test Mouse", kind: .mouse)
    ingest(Reading(device: info.id, level: .percent(percent), charging: false, observedAt: Date()), info: info)
  }

  func forgetTestDevice() {
    state.records.removeAll { $0.info.id == DeviceID("debug:test-mouse") }
    state.alertStates[DeviceID("debug:test-mouse")] = nil
    publish()
    saveSoon()
  }

  // MARK: Persistence

  func saveSoon() {
    saveWork?.cancel()
    let work = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.saveNow() } }
    saveWork = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: work)
  }

  func saveNow() {
    saveWork?.cancel()
    try? stateStore.save(state)
  }

  private func upsertLocal(_ info: DeviceInfo, _ mutate: (inout DeviceRecord) -> Void) {
    if let i = state.records.firstIndex(where: { $0.info.id == info.id }) {
      state.records[i].info = info
      mutate(&state.records[i])
    } else {
      var record = DeviceRecord(info: info, nickname: nil, alertOverride: nil, metaUpdatedAt: .distantPast, readings: [])
      mutate(&record)
      state.records.append(record)
    }
  }

  /// Metadata edits bump `metaUpdatedAt` so they win the cross-Mac merge.
  private func mutateMeta(_ id: DeviceID, _ mutate: (inout DeviceRecord) -> Void) {
    let current = mergedRecords.first { $0.info.id == id }
    if !state.records.contains(where: { $0.info.id == id }), var copy = current {
      copy.readings = []
      state.records.append(copy)
    }
    guard let i = state.records.firstIndex(where: { $0.info.id == id }) else { return }
    if let current {
      state.records[i].nickname = current.nickname
      state.records[i].alertOverride = current.alertOverride
    }
    mutate(&state.records[i])
    state.records[i].metaUpdatedAt = Date()
    publish()
    saveSoon()
    if settings.syncEnabled { sync.write(records: state.records, force: true) }
  }
}
