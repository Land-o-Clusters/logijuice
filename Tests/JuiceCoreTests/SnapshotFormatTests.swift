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
              alerting: Bool = false, tinted: Bool = false) -> SnapshotDevice {
    SnapshotDevice(id: .serial("X"), name: "MX Keys", nickname: nil, kind: .keyboard, level: level,
                   charging: charging, lastSeen: t0, live: live, forecast: .learning, alerting: alerting, tinted: tinted)
  }

  func testBuildSortsLowestFirstAndCarriesFlags() {
    let snap = SnapshotBuilder.build(
      records: [record("A", "Keys", readings: [(0, 80, false)]), record("B", "Mouse", readings: [(0, 12, false)])],
      liveDevices: [.serial("B")], receiverPresent: true, alerting: [.serial("B")], tinted: [], now: t0)
    XCTAssertEqual(snap.devices.map(\.name), ["Mouse", "Keys"])
    XCTAssertEqual(snap.devices[0].level, .percent(12))
    XCTAssertTrue(snap.devices[0].live)
    XCTAssertTrue(snap.devices[0].alerting)
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

  func testAutoHiddenWithNoDevices() {
    XCTAssertFalse(MenuBarPolicy.isVisible(mode: .auto, snapshot: .empty))
    XCTAssertTrue(MenuBarPolicy.isVisible(mode: .always, snapshot: .empty))
  }

  func testAutoVisibility() {
    func snap(_ d: SnapshotDevice) -> Snapshot { Snapshot(generatedAt: t0, receiverPresent: true, devices: [d]) }
    XCTAssertFalse(MenuBarPolicy.isVisible(mode: .auto, snapshot: snap(device())))
    XCTAssertTrue(MenuBarPolicy.isVisible(mode: .auto, snapshot: snap(device(alerting: true))))
    XCTAssertTrue(MenuBarPolicy.isVisible(mode: .auto, snapshot: snap(device(charging: true, live: true))))
    XCTAssertFalse(MenuBarPolicy.isVisible(mode: .auto, snapshot: snap(device(charging: true, live: false))))
    XCTAssertFalse(MenuBarPolicy.isVisible(mode: .never, snapshot: snap(device(alerting: true))))
  }

  func testIsTinted() {
    var s = DeviceAlertState()
    s.firedAt["low"] = t0
    XCTAssertFalse(MenuBarPolicy.isTinted(state: s, profile: .default))
    s.firedAt["veryLow"] = t0
    XCTAssertTrue(MenuBarPolicy.isTinted(state: s, profile: .default))
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

  func testSnapshotRoundTrips() throws {
    XCTAssertEqual(try JuiceJSON.decoder.decode(Snapshot.self, from: JuiceJSON.encoder.encode(Snapshot.preview)), .preview)
  }
}
