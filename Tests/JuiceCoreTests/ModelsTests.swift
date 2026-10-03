import XCTest
@testable import JuiceCore

final class ModelsTests: XCTestCase {
  let t0 = Date(timeIntervalSince1970: 1_800_000_000)

  func testReadingRoundTripsThroughJSON() throws {
    let r = Reading(device: .serial("ABC"), level: .percent(42), charging: false, observedAt: t0,
                    source: .synced(macID: "MAC-1"))
    let data = try JuiceJSON.encoder.encode(r)
    let json = String(decoding: data, as: UTF8.self)
    XCTAssertTrue(json.contains("\"device\":\"sn:ABC\""), json)
    XCTAssertTrue(json.contains("\"source\":\"synced:MAC-1\""), json)
    XCTAssertTrue(json.contains("\"level\":{\"percent\":42}"), json)
    XCTAssertEqual(try JuiceJSON.decoder.decode(Reading.self, from: data), r)
  }

  func testWordLevelAndLocalSourceRoundTrip() throws {
    let r = Reading(device: .unit("DEADBEEF"), level: .word(.low), charging: true, observedAt: t0)
    let data = try JuiceJSON.encoder.encode(r)
    XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("\"source\":\"local\""))
    XCTAssertEqual(try JuiceJSON.decoder.decode(Reading.self, from: data), r)
  }

  func testEquivalentPercentAndFull() {
    XCTAssertEqual(BatteryLevel.word(.critical).equivalentPercent, 5)
    XCTAssertEqual(BatteryLevel.word(.low).equivalentPercent, 10)
    XCTAssertEqual(BatteryLevel.word(.good).equivalentPercent, 50)
    XCTAssertEqual(BatteryLevel.word(.full).equivalentPercent, 100)
    XCTAssertEqual(BatteryLevel.percent(37).equivalentPercent, 37)
    XCTAssertTrue(BatteryLevel.percent(100).isFull)
    XCTAssertTrue(BatteryLevel.word(.full).isFull)
    XCTAssertFalse(BatteryLevel.percent(99).isFull)
  }

  func testDeviceKindFromHIDPPType() {
    XCTAssertEqual(DeviceKind(hidppType: 0), .keyboard)
    XCTAssertEqual(DeviceKind(hidppType: 2), .numpad)
    XCTAssertEqual(DeviceKind(hidppType: 3), .mouse)
    XCTAssertEqual(DeviceKind(hidppType: 4), .touchpad)
    XCTAssertEqual(DeviceKind(hidppType: 5), .trackball)
    XCTAssertEqual(DeviceKind(hidppType: 6), .presenter)
    XCTAssertEqual(DeviceKind(hidppType: 7), .other)
  }

  func testDeviceIDFactoriesAndDictionaryKeys() throws {
    XCTAssertEqual(DeviceID.slot(wpid: 0x408A, slot: 2).rawValue, "wpid:408A:slot:2")
    let dict: [DeviceID: Int] = [.serial("A"): 1]
    let json = String(decoding: try JuiceJSON.encoder.encode(dict), as: UTF8.self)
    XCTAssertEqual(json, "{\"sn:A\":1}")
    XCTAssertEqual(try JuiceJSON.decoder.decode([DeviceID: Int].self, from: Data(json.utf8)), dict)
  }

  func testForecastResultRoundTrips() throws {
    for f in [ForecastResult.learning, .unavailable, .estimate(daysLeft: 9.5, emptyAt: t0)] {
      XCTAssertEqual(try JuiceJSON.decoder.decode(ForecastResult.self, from: JuiceJSON.encoder.encode(f)), f)
    }
  }
}
