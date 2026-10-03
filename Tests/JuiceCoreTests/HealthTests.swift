import XCTest
@testable import JuiceCore

final class HealthTests: XCTestCase {
  let dev = DeviceID.serial("M")
  let t0 = Date(timeIntervalSince1970: 1_800_000_000)  // 2027-01-15

  func r(_ day: Double, _ p: Int, charging: Bool = false) -> Reading {
    Reading(device: dev, level: .percent(p), charging: charging, observedAt: t0 + day * 86_400)
  }

  /// Feeds readings one by one, as the app does, returning the final log.
  func replay(_ readings: [Reading], mac: String = "A", start: HealthLog? = nil) -> HealthLog {
    var log = start
    var history: [Reading] = []
    for reading in readings {
      log = HealthTracker.update(log, previous: history.last, reading: reading, history: history, macID: mac)
      history.append(reading)
    }
    return log ?? HealthLog()
  }

  /// One full discharge of `days` from 100 to 20, then a charge back to 100.
  func cycle(from day: Double, days: Double) -> [Reading] {
    let steps = 8
    var out = (0...steps).map { i -> Reading in
      r(day + days * Double(i) / Double(steps), 100 - 10 * i)
    }
    out.append(r(day + days + 0.1, 30, charging: true))
    out.append(r(day + days + 0.2, 100))
    return out
  }

  func testCompletedRunIsSummarisedWhenChargingStarts() throws {
    let log = replay(cycle(from: 0, days: 8))  // 80 points in 8 days → 10 %/day → 10 days per charge
    XCTAssertEqual(log.runs.count, 1)
    let run = try XCTUnwrap(log.runs.first)
    XCTAssertEqual(run.perDay, 10, accuracy: 0.5)
    XCTAssertEqual(run.daysPerCharge, 10, accuracy: 0.5)
    XCTAssertEqual(run.startPercent, 100)
    XCTAssertEqual(run.endPercent, 20)
  }

  func testShortRunsAreNotSummarised() {
    let log = replay([r(0, 80), r(0.5, 78), r(0.6, 79, charging: true)])
    XCTAssertTrue(log.runs.isEmpty)
  }

  func testChargeGainCountsOnlyCharging() {
    // The 20 → 22 rebound without charging is ignored; charging then takes 22 → 100 = 78 points.
    let log = replay([r(0, 22), r(0.1, 20), r(0.2, 22), r(0.3, 50, charging: true), r(0.4, 100, charging: true)])
    XCTAssertEqual(log.chargeGain["A"] ?? 0, 78, accuracy: 0.01)
    XCTAssertEqual(log.cycles, 0.78, accuracy: 0.001)
  }

  func testReportNeedsThreeRuns() {
    let one = HealthTracker.report(replay(cycle(from: 0, days: 8)))
    XCTAssertFalse(one.ready)
    XCTAssertEqual(one.completedRuns, 1)
    XCTAssertNil(one.daysPerCharge)
    let three = HealthTracker.report(replay(cycle(from: 0, days: 8) + cycle(from: 10, days: 8) + cycle(from: 20, days: 8)))
    XCTAssertTrue(three.ready)
    XCTAssertEqual(three.daysPerCharge ?? 0, 10, accuracy: 0.5)
    XCTAssertNil(three.changePercent, "a trend needs six runs")
  }

  func testTrendComparesFirstAndLastThreeRuns() throws {
    var readings: [Reading] = []
    var day = 0.0
    for days in [8.0, 8, 8, 6.4, 6.4, 6.4] {  // later runs drain 25 % faster → 20 % fewer days
      readings += cycle(from: day, days: days)
      day += days + 1
    }
    let report = HealthTracker.report(replay(readings))
    XCTAssertEqual(report.completedRuns, 6)
    XCTAssertEqual(try XCTUnwrap(report.changePercent), -20, accuracy: 2)
    XCTAssertEqual(report.series.count, 6)
    XCTAssertEqual(report.baselineDate, t0)
  }

  func testMergeUnionsRunsAndKeepsPerMacCharge() {
    let a = replay(cycle(from: 0, days: 8), mac: "A")
    let b = replay(cycle(from: 0, days: 8) + cycle(from: 10, days: 8), mac: "B")
    let merged = HealthLog.merge(a, b)
    XCTAssertEqual(merged?.runs.count, 2, "the shared first run is not duplicated")
    XCTAssertEqual(merged?.chargeGain["A"] ?? 0, a.chargeGain["A"] ?? -1, accuracy: 0.01)
    XCTAssertEqual(merged?.chargeGain["B"] ?? 0, b.chargeGain["B"] ?? -1, accuracy: 0.01)
    XCTAssertNil(HealthLog.merge(nil, nil))
  }

  func testDrainRatio() {
    let history = cycle(from: 0, days: 8) + cycle(from: 10, days: 8) + cycle(from: 20, days: 8)
    let log = replay(history)
    // Current run (from the 100 % at day 28.2): ~19 %/day, about twice the usual 10 %/day.
    let fast = history + [r(29, 90), r(30, 70), r(31, 50)]
    XCTAssertEqual(HealthTracker.drainRatio(log, history: fast, now: t0 + 31 * 86_400) ?? 0, 1.9, accuracy: 0.2)
    // Not enough of the current run yet.
    let young = history + [r(30, 100), r(30.3, 98)]
    XCTAssertNil(HealthTracker.drainRatio(log, history: young, now: t0 + 30.3 * 86_400))
    // No baseline yet.
    XCTAssertNil(HealthTracker.drainRatio(replay(cycle(from: 0, days: 8)), history: fast, now: t0 + 31 * 86_400))
  }

  func testCurrentRunStart() {
    XCTAssertEqual(HealthTracker.currentRunStart(cycle(from: 0, days: 8) + [r(9, 95)]), t0 + 8.2 * 86_400)
    XCTAssertNil(HealthTracker.currentRunStart([]))
  }

  func testHealthTexts() {
    let utc = TimeZone(identifier: "UTC")!
    var report = HealthReport(completedRuns: 1, daysPerCharge: nil, changePercent: nil, baselineDate: nil, cycles: 0.4,
                              since: t0, series: [])
    XCTAssertEqual(Format.health(report, timeZone: utc), "health · ready after 2 more full charges")
    report.completedRuns = 2
    XCTAssertEqual(Format.health(report, timeZone: utc), "health · ready after 1 more full charge")
    report = HealthReport(completedRuns: 3, daysPerCharge: 61.6, changePercent: nil, baselineDate: nil, cycles: 0.4,
                          since: t0, series: [62, 61, 61])
    XCTAssertEqual(Format.health(report, timeZone: utc), "a charge lasts ~62 days · <1 cycle")
    report.completedRuns = 6
    report.changePercent = -11.2
    report.baselineDate = t0
    report.cycles = 14.4
    XCTAssertEqual(Format.health(report, timeZone: utc), "a charge lasts ~62 days · −11% since Jan · ~14 cycles")
  }

  func testDrainAlertText() {
    let text = Format.drainAlert(displayName: "MX Master 3S", device: dev, ratio: 2.3, typicalDays: 62)
    XCTAssertEqual(text, NotificationText(title: "MX Master 3S is draining fast",
                                          body: "About 2× faster than usual. A charge usually lasts ~62 days.",
                                          identifier: "sn:M.drain"))
  }

  func testDrainAlertSettingDefaultsOff() throws {
    XCTAssertFalse(Settings().drainAlertEnabled)
    let s = try JuiceJSON.decoder.decode(Settings.self, from: Data(#"{"drainAlertEnabled":true}"#.utf8))
    XCTAssertTrue(s.drainAlertEnabled)
  }

  func testRecordsWithoutHealthStillDecodeAndMergeCarriesHealth() throws {
    let old = #"{"info":{"id":"sn:M","name":"M","kind":"mouse"},"metaUpdatedAt":"2027-01-15T08:00:00Z","readings":[]}"#
    let rec = try JuiceJSON.decoder.decode(DeviceRecord.self, from: Data(old.utf8))
    XCTAssertNil(rec.health)
    var local = rec
    local.health = replay(cycle(from: 0, days: 8), mac: "A")
    var remote = rec
    remote.health = replay(cycle(from: 10, days: 8), mac: "B")
    let merged = SyncMerge.merge(local: [local], remotes: [SyncFile(macID: "B", macName: "B", updatedAt: t0, devices: [remote])],
                                 now: t0)
    XCTAssertEqual(merged.first?.health?.runs.count, 2)
  }
}
