import XCTest
@testable import JuiceCore

final class ChargeWatchTests: XCTestCase {
  func testIdleUntilSomethingCharges() {
    var w = ChargeWatch<UInt8>()
    XCTAssertFalse(w.isActive)
    w.observe(1, charging: false)
    XCTAssertFalse(w.isActive)
    w.observe(1, charging: true)
    XCTAssertTrue(w.isActive)
    XCTAssertEqual(w.charging, [1])
  }

  func testStaysActiveUntilTheLastDeviceStops() {
    var w = ChargeWatch<UInt8>()
    w.observe(1, charging: true)
    w.observe(2, charging: true)
    w.observe(1, charging: false)
    XCTAssertTrue(w.isActive)
    XCTAssertEqual(w.charging, [2])
    w.observe(2, charging: false)
    XCTAssertFalse(w.isActive)
  }

  func testRepeatedChargingReadingsKeepOneEntry() {
    var w = ChargeWatch<UInt8>()
    w.observe(1, charging: true)
    w.observe(1, charging: true)
    XCTAssertEqual(w.charging, [1])
  }

  func testResetClearsEverything() {
    var w = ChargeWatch<UInt8>()
    w.observe(1, charging: true)
    w.observe(2, charging: true)
    w.reset()
    XCTAssertFalse(w.isActive)
    XCTAssertEqual(w.charging, [])
  }

  func testIntervalIsShortEnoughToSeeEachStep() {
    // Levels move in 5% steps; a fast-charging mouse gains one roughly every few minutes.
    XCTAssertLessThanOrEqual(ChargeWatch<UInt8>.interval, 60)
    XCTAssertGreaterThanOrEqual(ChargeWatch<UInt8>.interval, 30)
  }
}
