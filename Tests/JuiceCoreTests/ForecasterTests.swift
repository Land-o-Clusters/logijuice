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
