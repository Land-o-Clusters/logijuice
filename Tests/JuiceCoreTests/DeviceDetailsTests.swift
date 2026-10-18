import XCTest
@testable import JuiceCore

final class DeviceDetailsTests: XCTestCase {
  let t0 = Date(timeIntervalSince1970: 1_800_000_000)  // 2027-01-15 08:00 UTC
  let utc = TimeZone(identifier: "UTC")!

  func device(id: DeviceID = .serial("TESTMOUSE001"), nickname: String? = nil, level: BatteryLevel? = .percent(70),
              charging: Bool = false, live: Bool = true, forecast: ForecastResult = .learning,
              health: HealthReport? = nil) -> SnapshotDevice {
    SnapshotDevice(id: id, name: "MX Master 3S", nickname: nickname, kind: .mouse, level: level, charging: charging,
                   lastSeen: t0 - 3 * 3600, live: live, forecast: forecast, alerting: false, tint: .none,
                   health: health)
  }

  func rows(_ d: SnapshotDevice) -> [String: String] {
    Dictionary(uniqueKeysWithValues: Format.details(d, now: t0, timeZone: utc).map { ($0.label, $0.value) })
  }

  func labels(_ d: SnapshotDevice) -> [String] { Format.details(d, now: t0, timeZone: utc).map(\.label) }

  func testLiveDeviceWithEstimate() {
    let d = device(forecast: .estimate(daysLeft: 18.4, emptyAt: t0 + 18.4 * 86_400))
    XCTAssertEqual(labels(d), ["Battery", "Lasts", "Connection", "Serial number"])
    XCTAssertEqual(rows(d)["Battery"], "70%")
    XCTAssertEqual(rows(d)["Lasts"], "~18 days, until about Feb 2")
    XCTAssertEqual(rows(d)["Connection"], "Connected")
    XCTAssertEqual(rows(d)["Serial number"], "TESTMOUSE001")
  }

  func testChargingAndOfflineDevice() {
    let d = device(charging: true, live: false)
    XCTAssertEqual(rows(d)["Battery"], "70%, charging")
    XCTAssertEqual(rows(d)["Connection"], "Seen 3h ago")
    XCTAssertEqual(rows(d)["Lasts"], "learning…")
  }

  func testNicknamedDeviceShowsModel() {
    XCTAssertEqual(rows(device(nickname: "Work mouse"))["Model"], "MX Master 3S")
    XCTAssertNil(rows(device())["Model"])
  }

  func testHealthAndTrackingSince() {
    let h = HealthReport(completedRuns: 1, daysPerCharge: nil, changePercent: nil, baselineDate: nil, cycles: 0.55,
                         since: t0 - 30 * 86_400, series: [18])
    let r = rows(device(health: h))
    XCTAssertEqual(r["Health"], "Ready after 2 more full charges")
    XCTAssertEqual(r["Charge cycles"], "Less than 1")
    XCTAssertEqual(r["Tracked since"], "Dec 16, 2026")
  }

  func testReadyHealthWithTrend() {
    let h = HealthReport(completedRuns: 6, daysPerCharge: 17.6, changePercent: -4.2, baselineDate: t0 - 120 * 86_400,
                         cycles: 6.2, since: t0 - 130 * 86_400, series: [18, 18, 18, 17, 17, 17])
    let r = rows(device(health: h))
    XCTAssertEqual(r["Health"], "A charge lasts ~18 days, −4% since Sep")
    XCTAssertEqual(r["Charge cycles"], "About 6")
  }

  func testOtherIdentityKinds() {
    XCTAssertEqual(rows(device(id: .unit("A1B2C3D4")))["Unit ID"], "A1B2C3D4")
    XCTAssertEqual(rows(device(id: .slot(wpid: 0xB034, slot: 2)))["Receiver slot"], "2 (product B034)")
    XCTAssertNil(rows(device(id: .unit("A1B2C3D4")))["Serial number"])
  }

  func testUnknownLevel() {
    XCTAssertEqual(rows(device(level: nil))["Battery"], "Unknown")
  }
}
