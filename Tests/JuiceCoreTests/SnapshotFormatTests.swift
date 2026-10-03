import XCTest
@testable import JuiceCore

final class SnapshotFormatTests: XCTestCase {
  let t0 = Date(timeIntervalSince1970: 1_800_000_000)

  func record(_ id: String, _ name: String, nickname: String? = nil, readings: [(Double, Int, Bool)]) -> DeviceRecord {
    let did = DeviceID.serial(id)
    return DeviceRecord(
      info: DeviceInfo(id: did, name: name, kind: .mouse), nickname: nickname, alertOverride: nil,
      metaUpdatedAt: t0,
      readings: readings.map { Reading(device: did, level: .percent($0.1), charging: $0.2, observedAt: t0 + $0.0) })
  }

  func device(level: BatteryLevel? = .percent(50), charging: Bool = false, live: Bool = true,
              alerting: Bool = false, tint: IconTint = .none) -> SnapshotDevice {
    SnapshotDevice(id: .serial("X"), name: "MX Keys", nickname: nil, kind: .keyboard, level: level,
                   charging: charging, lastSeen: t0, live: live, forecast: .learning, alerting: alerting, tint: tint)
  }

  func testBuildSortsLowestFirstAndCarriesFlags() {
    let snap = SnapshotBuilder.build(
      records: [record("A", "Keys", readings: [(0, 80, false)]), record("B", "Mouse", readings: [(0, 12, false)])],
      liveDevices: [.serial("B")], receiverPresent: true, alerting: [.serial("B")], tints: [.serial("B"): .yellow], now: t0)
    XCTAssertEqual(snap.devices.map(\.name), ["Mouse", "Keys"])
    XCTAssertEqual(snap.devices[0].level, .percent(12))
    XCTAssertTrue(snap.devices[0].live)
    XCTAssertTrue(snap.devices[0].alerting)
    XCTAssertEqual(snap.devices[0].tint, .yellow)
    XCTAssertEqual(snap.devices[1].tint, IconTint.none)
    XCTAssertFalse(snap.devices[1].live)
    XCTAssertEqual(snap.lowest?.name, "Mouse")
    XCTAssertEqual(snap.schema, 1)
  }

  func testEmptyNicknameFallsBackToName() {
    var d = device()
    d.nickname = "  "
    XCTAssertEqual(d.displayName, "MX Keys")
    d.nickname = "Desk keys"
    XCTAssertEqual(d.displayName, "Desk keys")
  }

  func testNothingVisibleWithNoDevicesOrPins() {
    XCTAssertEqual(MenuBarPolicy.visibleDevices(snapshot: .empty, pinned: [], showAlerting: true), [])
    XCTAssertEqual(MenuBarPolicy.visibleDevices(snapshot: .empty, pinned: [.serial("GONE")], showAlerting: true), [])
  }

  func testVisibleDevices() {
    var mouse = device(level: .percent(70))
    mouse.id = .serial("M")
    var keys = device(level: .percent(90))
    keys.id = .serial("K")
    var low = device(level: .percent(12), alerting: true)
    low.id = .serial("L")
    var charging = device(level: .percent(40), charging: true, live: true)
    charging.id = .serial("C")
    var staleCharging = device(level: .percent(40), charging: true, live: false)
    staleCharging.id = .serial("S")
    let snap = Snapshot(generatedAt: t0, receiverPresent: true, devices: [low, charging, staleCharging, mouse, keys])
    func ids(_ pinned: [DeviceID], _ showAlerting: Bool) -> [String] {
      MenuBarPolicy.visibleDevices(snapshot: snap, pinned: pinned, showAlerting: showAlerting).map(\.id.rawValue)
    }
    // Healthy, unpinned devices never show; low and live-charging ones do when enabled.
    XCTAssertEqual(ids([], true), ["sn:L", "sn:C"])
    XCTAssertEqual(ids([], false), [])
    // Pins come first, in pin order, and are not duplicated.
    XCTAssertEqual(ids([.serial("K"), .serial("M")], true), ["sn:K", "sn:M", "sn:L", "sn:C"])
    XCTAssertEqual(ids([.serial("L")], true), ["sn:L", "sn:C"])
    XCTAssertEqual(ids([.serial("K")], false), ["sn:K"])
  }

  func testTintIsMostSevereFiredLevelColor() {
    var s = DeviceAlertState()
    XCTAssertEqual(MenuBarPolicy.tint(state: s, profile: .default), IconTint.none)
    s.firedAt["low"] = t0
    XCTAssertEqual(MenuBarPolicy.tint(state: s, profile: .default), .yellow)
    s.firedAt["veryLow"] = t0
    XCTAssertEqual(MenuBarPolicy.tint(state: s, profile: .default), .red)
    var quiet = AlertProfile.default
    quiet.levels = quiet.levels.map { var l = $0; l.tint = .none; return l }
    XCTAssertEqual(MenuBarPolicy.tint(state: s, profile: quiet), IconTint.none)
  }

  func testLevelAndForecastStrings() {
    XCTAssertEqual(Format.level(.percent(42)), "42%")
    XCTAssertEqual(Format.level(.word(.low)), "Low")
    XCTAssertEqual(Format.forecast(.estimate(daysLeft: 9.4, emptyAt: t0)), "~9 days")
    XCTAssertEqual(Format.forecast(.estimate(daysLeft: 1.5, emptyAt: t0)), "~36 hours")
    XCTAssertEqual(Format.forecast(.estimate(daysLeft: 0.01, emptyAt: t0)), "~1 hour")
    XCTAssertEqual(Format.forecast(.learning), "learning…")
    XCTAssertNil(Format.forecast(.unavailable))
  }

  func testSeenStrings() {
    XCTAssertEqual(Format.seen(nil, now: t0), "never seen")
    XCTAssertEqual(Format.seen(t0 - 30, now: t0), "seen just now")
    XCTAssertEqual(Format.seen(t0 - 720, now: t0), "seen 12m ago")
    XCTAssertEqual(Format.seen(t0 - 3 * 3600, now: t0), "seen 3h ago")
    XCTAssertEqual(Format.seen(t0 - 3 * 86_400, now: t0), "seen 3d ago")
  }

  func testSubtitle() {
    var d = device()
    d.forecast = .estimate(daysLeft: 9, emptyAt: t0)
    XCTAssertEqual(Format.subtitle(d, now: t0), "~9 days")
    d.live = false
    XCTAssertEqual(Format.subtitle(d, now: t0 + 3 * 3600), "~9 days · seen 3h ago")
  }

  func testNotificationTexts() {
    let reading = Reading(device: .serial("M"), level: .percent(14), charging: false, observedAt: t0)
    let low = AlertDecision(device: .serial("M"),
                            kind: .level(id: "low", name: "Low", timing: .nextMoment, severity: 0, isRepeat: false),
                            reading: reading)
    let forecast = ForecastResult.estimate(daysLeft: 2, emptyAt: t0)
    let plain = Format.notification(for: Delivery(decision: low, moment: nil), displayName: "MX Master 3S", forecast: forecast)
    XCTAssertEqual(plain, NotificationText(title: "MX Master 3S", body: "14% · about 2 days left", identifier: "sn:M.low"))
    let leaving = Format.notification(for: Delivery(decision: low, moment: .receiverDeparted),
                                      displayName: "MX Master 3S", forecast: forecast)
    XCTAssertEqual(leaving.title, "Leaving this desk?")
    XCTAssertEqual(leaving.body, "MX Master 3S is at 14% · about 2 days left")
    let full = AlertDecision(device: .serial("M"), kind: .fullyCharged, reading: reading)
    XCTAssertEqual(Format.notification(for: Delivery(decision: full, moment: nil), displayName: "MX Keys", forecast: .learning),
                   NotificationText(title: "MX Keys", body: "Fully charged. Unplug whenever you like.", identifier: "sn:M.full"))
    XCTAssertEqual(Format.notificationBody(level: .percent(8), forecast: .learning), "8%")
  }

  func testStatusLine() {
    var d = device(level: .percent(80), charging: true, live: false)
    d.forecast = .learning
    XCTAssertEqual(Format.statusLine(d, now: t0 + 3 * 3600), "MX Keys: 80% (charging), learning…, seen 3h ago")
    d = device(level: .percent(42))
    d.forecast = .estimate(daysLeft: 9, emptyAt: t0)
    XCTAssertEqual(Format.statusLine(d, now: t0), "MX Keys: 42%, ~9 days")
  }

  func testStatusLineShowsLearningProgress() {
    var d = device(level: .percent(95))
    d.learning = LearningProgress(days: 0.1, drop: 5)
    XCTAssertEqual(Format.statusLine(d, now: t0), "MX Keys: 95%, learning · first estimate in ~2 days")
  }

  func testBatterySymbolsAndKindSymbols() {
    XCTAssertEqual(Format.batterySymbol(percent: nil), "battery.0percent")
    XCTAssertEqual(Format.batterySymbol(percent: 10), "battery.0percent")
    XCTAssertEqual(Format.batterySymbol(percent: 30), "battery.25percent")
    XCTAssertEqual(Format.batterySymbol(percent: 50), "battery.50percent")
    XCTAssertEqual(Format.batterySymbol(percent: 80), "battery.75percent")
    XCTAssertEqual(Format.batterySymbol(percent: 95), "battery.100percent")
    XCTAssertEqual(DeviceKind.mouse.symbolName, "computermouse")
    XCTAssertEqual(DeviceKind.keyboard.symbolName, "keyboard")
  }

  func testMenuBarText() {
    XCTAssertNil(Format.menuBarText(device(level: .percent(70)), display: .whenLow))
    XCTAssertEqual(Format.menuBarText(device(level: .percent(70)), display: .always), "70%")
    XCTAssertEqual(Format.menuBarText(device(level: .percent(14), alerting: true), display: .whenLow), "14%")
    XCTAssertEqual(Format.menuBarText(device(level: .word(.low), alerting: true), display: .whenLow), "Low")
    XCTAssertNil(Format.menuBarText(device(level: nil), display: .always))
  }

  func testGaugeSymbolsPerKind() {
    XCTAssertEqual(DeviceKind.mouse.gaugeSymbols.outline, "computermouse")
    XCTAssertEqual(DeviceKind.mouse.gaugeSymbols.fill, "computermouse.fill")
    XCTAssertEqual(DeviceKind.keyboard.gaugeSymbols.outline, "keyboard")
    XCTAssertEqual(DeviceKind.keyboard.gaugeSymbols.fill, "keyboard.fill")
    for kind in DeviceKind.allCases {
      XCTAssertFalse(kind.gaugeSymbols.outline.isEmpty)
      XCTAssertFalse(kind.gaugeSymbols.fill.isEmpty)
    }
  }

  func testSnapshotRoundTrips() throws {
    XCTAssertEqual(try JuiceJSON.decoder.decode(Snapshot.self, from: JuiceJSON.encoder.encode(Snapshot.preview)), .preview)
  }
}
