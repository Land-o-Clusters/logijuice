import XCTest
@testable import JuiceCore

final class ForecasterTests: XCTestCase {
  let dev = DeviceID.serial("M")
  let t0 = Date(timeIntervalSince1970: 1_800_000_000)

  func r(_ day: Double, _ p: Int, charging: Bool = false) -> Reading {
    Reading(device: dev, level: .percent(p), charging: charging, observedAt: t0 + day * 86_400)
  }

  func days(_ f: ForecastResult) -> Double? {
    if case .estimate(let d, _) = f { return d }
    return nil
  }

  var linear: [Reading] {
    stride(from: 0.0, through: 6.0, by: 0.25).map { r($0, 100 - Int(($0 * 5).rounded())) }
  }

  func testNoReadingsIsLearning() {
    XCTAssertEqual(Forecaster.forecast([], now: t0), .learning)
  }

  func testWordOnlyIsUnavailable() {
    let w = Reading(device: dev, level: .word(.good), charging: false, observedAt: t0)
    XCTAssertEqual(Forecaster.forecast([w], now: t0), .unavailable)
  }

  func testChargingIsLearning() {
    XCTAssertEqual(Forecaster.forecast(linear + [r(6.1, 72, charging: true)], now: t0 + 6.1 * 86_400), .learning)
  }

  func testLinearDrain() throws {
    let d = try XCTUnwrap(days(Forecaster.forecast(linear, now: t0 + 6 * 86_400)))
    XCTAssertEqual(d, 14, accuracy: 0.5)
  }

  func testCoarseTenPercentSteps() throws {
    let rs = stride(from: 0.0, through: 6.0, by: 0.5).map { r($0, 100 - 10 * Int($0 / 2)) }
    let d = try XCTUnwrap(days(Forecaster.forecast(rs, now: t0 + 6 * 86_400)))
    XCTAssertEqual(d, 14, accuracy: 3)
  }

  func testTooLittleDataIsLearning() {
    XCTAssertEqual(Forecaster.forecast([r(0, 80), r(3, 75)], now: t0 + 3 * 86_400), .learning)
    XCTAssertEqual(Forecaster.forecast([r(0, 80), r(1, 60)], now: t0 + 86_400), .learning)
  }

  func testBorrowsPreviousRunAfterCharge() throws {
    let rs = [r(0, 100), r(1, 95), r(2, 90), r(3, 85), r(4, 80), r(4.1, 90, charging: true),
              r(4.5, 100), r(5, 98)]
    let d = try XCTUnwrap(days(Forecaster.forecast(rs, now: t0 + 5 * 86_400)))
    XCTAssertEqual(d, 19.6, accuracy: 0.3)
  }

  func testRiseWithoutChargeFlagStartsNewRun() throws {
    let rs = [r(0, 100), r(1, 95), r(2, 90), r(3, 85), r(4, 80), r(4.2, 95), r(5, 94)]
    let d = try XCTUnwrap(days(Forecaster.forecast(rs, now: t0 + 5 * 86_400)))
    XCTAssertEqual(d, 18.8, accuracy: 0.3)
  }

  func testOutlierDoesNotSkew() throws {
    var rs = linear
    rs.append(r(3.1, 5))
    let d = try XCTUnwrap(days(Forecaster.forecast(rs, now: t0 + 6 * 86_400)))
    XCTAssertEqual(d, 14, accuracy: 1)
  }

  func testNowAfterLatestReducesDaysLeft() throws {
    let d = try XCTUnwrap(days(Forecaster.forecast(linear, now: t0 + 8 * 86_400)))
    XCTAssertEqual(d, 12, accuracy: 0.5)
  }

  func testUnsortedInputGivesSameForecast() {
    let now = t0 + 6 * 86_400
    XCTAssertEqual(Forecaster.forecast(linear.reversed(), now: now), Forecaster.forecast(linear, now: now))
  }
}

final class LearningProgressTests: XCTestCase {
  let dev = DeviceID.serial("M")
  let t0 = Date(timeIntervalSince1970: 1_800_000_000)

  func r(_ day: Double, _ p: Int, charging: Bool = false) -> Reading {
    Reading(device: dev, level: .percent(p), charging: charging, observedAt: t0 + day * 86_400)
  }

  func testProgressOfCurrentRun() {
    let p = Forecaster.learningProgress([r(0, 70), r(0.5, 68)], now: t0 + 0.75 * 86_400)
    XCTAssertEqual(p?.drop, 2)
    XCTAssertEqual(p?.days ?? 0, 0.75, accuracy: 0.001)
  }

  func testNoProgressWhenEstimating() {
    let linear = stride(from: 0.0, through: 6.0, by: 0.5).map { r($0, 100 - Int(($0 * 5).rounded())) }
    XCTAssertNil(Forecaster.learningProgress(linear, now: t0 + 6 * 86_400))
  }

  func testNoProgressForWordOnlyOrEmpty() {
    XCTAssertNil(Forecaster.learningProgress([], now: t0))
    XCTAssertNil(Forecaster.learningProgress(
      [Reading(device: dev, level: .word(.good), charging: false, observedAt: t0)], now: t0))
  }

  func testLearningTexts() {
    XCTAssertEqual(Format.learning(LearningProgress(days: 0.2, drop: 2)), "learning · first estimate in ~2 days")
    XCTAssertEqual(Format.learning(LearningProgress(days: 1.4, drop: 4)), "learning · first estimate in ~1 day")
    XCTAssertEqual(Format.learning(LearningProgress(days: 3, drop: 6)), "learning · after another 4% drop")
    XCTAssertEqual(Format.learning(LearningProgress(days: 3, drop: 9)), "learning · after another 1% drop")
  }

  func testSubtitleUsesProgress() {
    var d = SnapshotDevice(id: .serial("X"), name: "MX Keys", nickname: nil, kind: .keyboard, level: .percent(95),
                           charging: false, lastSeen: t0, live: true, forecast: .learning, alerting: false, tint: .none)
    d.learning = LearningProgress(days: 0.2, drop: 2)
    XCTAssertEqual(Format.subtitle(d, now: t0), "learning · first estimate in ~2 days")
    d.learning = nil
    XCTAssertEqual(Format.subtitle(d, now: t0), "learning…")
  }

  func testSnapshotBuilderFillsProgress() {
    let rec = DeviceRecord(info: DeviceInfo(id: dev, name: "M", kind: .mouse), nickname: nil, alertOverride: nil,
                           metaUpdatedAt: t0, readings: [r(0, 70), r(0.5, 68)])
    let snap = SnapshotBuilder.build(records: [rec], liveDevices: [], receiverPresent: true, alerting: [], tints: [:],
                                     now: t0 + 86_400)
    XCTAssertEqual(snap.devices.first?.learning?.drop, 2)
  }
}
