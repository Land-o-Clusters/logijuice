import XCTest
@testable import JuiceCore

final class AlertEngineTests: XCTestCase {
  let mouse = DeviceID.serial("MOUSE")
  let t0 = Date(timeIntervalSince1970: 1_800_000_000)

  func reading(_ p: Int, charging: Bool = false, at t: Date? = nil,
               source: ReadingSource = .local) -> Reading {
    Reading(device: mouse, level: .percent(p), charging: charging, observedAt: t ?? t0, source: source)
  }

  func run(_ readings: [Reading], profile: AlertProfile = .default, forecast: ForecastResult = .learning,
           fullyCharged: Bool = true, state: DeviceAlertState = DeviceAlertState())
    -> (DeviceAlertState, [[AlertDecision]])
  {
    var s = state
    var all: [[AlertDecision]] = []
    for r in readings {
      let (next, decisions) = AlertEngine.evaluate(
        reading: r, profile: profile, forecast: forecast, fullyChargedEnabled: fullyCharged,
        state: s, now: r.observedAt)
      s = next
      all.append(decisions)
    }
    return (s, all)
  }

  func levelIDs(_ ds: [AlertDecision]) -> [String] {
    ds.compactMap { if case .level(let id, _, _, _, _) = $0.kind { return id } else { return nil } }
  }

  func testAboveAllThresholdsDoesNothing() {
    let (s, out) = run([reading(25)])
    XCTAssertEqual(out, [[]])
    XCTAssertTrue(s.firedAt.isEmpty)
  }

  func testLowFiresOnceWithNextMomentTiming() {
    let (_, out) = run([reading(20), reading(19, at: t0 + 3600)])
    XCTAssertEqual(levelIDs(out[0]), ["low"])
    guard case .level(_, "Low", .nextMoment, 0, false)? = out[0].first?.kind else {
      return XCTFail("unexpected kind \(String(describing: out[0].first?.kind))")
    }
    XCTAssertEqual(out[1], [])
  }

  func testSteepDropFiresOnlyMostSevere() {
    let (s, out) = run([reading(4)])
    XCTAssertEqual(levelIDs(out[0]), ["critical"])
    XCTAssertEqual(Set(s.firedAt.keys), ["low", "veryLow", "critical"])
  }

  func testHysteresisRearmNeedsFivePointsAboveThreshold() {
    let (_, out) = run([
      reading(20), reading(24, at: t0 + 60), reading(20, at: t0 + 120),
      reading(25, at: t0 + 180), reading(20, at: t0 + 240),
    ])
    XCTAssertEqual(out.map(levelIDs), [["low"], [], [], [], ["low"]])
  }

  func testChargingRearmsAndFullyChargedFires() {
    let (_, out) = run([
      reading(9), reading(50, charging: true, at: t0 + 60), reading(100, at: t0 + 120),
      reading(20, at: t0 + 180),
    ])
    XCTAssertEqual(levelIDs(out[0]), ["veryLow"])
    XCTAssertEqual(out[1], [])
    XCTAssertEqual(out[2].map(\.kind), [.fullyCharged])
    XCTAssertEqual(levelIDs(out[3]), ["low"])
  }

  func testFullyChargedCanBeDisabled() {
    let (_, out) = run([reading(80, charging: true), reading(100, at: t0 + 60)], fullyCharged: false)
    XCTAssertEqual(out[1], [])
  }

  func testUnpluggedBeforeFullDoesNotNotify() {
    let (_, out) = run([reading(60, charging: true), reading(80, at: t0 + 60)])
    XCTAssertEqual(out[1], [])
  }

  func testCriticalRepeatsDaily() {
    let (_, out) = run([reading(5), reading(4, at: t0 + 23 * 3600), reading(4, at: t0 + 24 * 3600)])
    XCTAssertEqual(levelIDs(out[0]), ["critical"])
    XCTAssertEqual(out[1], [])
    guard case .level("critical", _, _, 2, true)? = out[2].first?.kind else {
      return XCTFail("expected a repeat of critical, got \(out[2])")
    }
  }

  func testSyncedReadingsNeverAlert() {
    let (s, out) = run([reading(3, source: .synced(macID: "OTHER"))])
    XCTAssertEqual(out, [[]])
    XCTAssertTrue(s.firedAt.isEmpty)
  }

  func testSnoozeAllowsEscalation() {
    var (s, _) = run([reading(19)])
    s = AlertEngine.snooze(s, profile: .default, now: t0)
    let (_, out) = run([reading(9, at: t0 + 3600)], state: s)
    XCTAssertEqual(levelIDs(out[0]), ["veryLow"])
  }

  func testSnoozeSuppressesRepeatsUntilItExpires() {
    var profile = AlertProfile.default
    profile.levels[2].repeatPolicy = .everyHours(4)
    var (s, _) = run([reading(5)], profile: profile)
    s = AlertEngine.snooze(s, profile: profile, now: t0)
    let (s2, out) = run([reading(5, at: t0 + 5 * 3600)], profile: profile, state: s)
    XCTAssertEqual(out, [[]])
    let (_, later) = run([reading(5, at: t0 + 25 * 3600)], profile: profile, state: s2)
    XCTAssertEqual(levelIDs(later[0]), ["critical"])
  }

  func testDisabledLevelIsSkipped() {
    var profile = AlertProfile.default
    profile.levels[0].enabled = false
    let (s1, out1) = run([reading(20)], profile: profile)
    XCTAssertEqual(out1, [[]])
    XCTAssertTrue(s1.firedAt.isEmpty)
    let (s2, out2) = run([reading(10)], profile: profile)
    XCTAssertEqual(levelIDs(out2[0]), ["veryLow"])
    XCTAssertNil(s2.firedAt["low"])
  }

  func testForecastTrigger() {
    var profile = AlertProfile.default
    profile.levels[0].trigger = .forecastDaysAtOrBelow(3)
    let (_, fires) = run([reading(60)], profile: profile, forecast: .estimate(daysLeft: 2.5, emptyAt: t0))
    XCTAssertEqual(levelIDs(fires[0]), ["low"])
    let (_, silent) = run([reading(60)], profile: profile, forecast: .learning)
    XCTAssertEqual(silent, [[]])
  }

  func testWordReadingsMapToLevels() {
    func word(_ w: LevelWord) -> [String] {
      let r = Reading(device: mouse, level: .word(w), charging: false, observedAt: t0)
      return levelIDs(run([r]).1[0])
    }
    XCTAssertEqual(word(.critical), ["critical"])
    XCTAssertEqual(word(.low), ["veryLow"])
    XCTAssertEqual(word(.good), [])
  }
}
