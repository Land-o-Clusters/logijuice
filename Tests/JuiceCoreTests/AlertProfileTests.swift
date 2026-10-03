import XCTest
@testable import JuiceCore

final class AlertProfileTests: XCTestCase {
  let t0 = Date(timeIntervalSince1970: 1_800_000_000)

  func reading(_ level: BatteryLevel) -> Reading {
    Reading(device: .serial("M"), level: level, charging: false, observedAt: t0)
  }

  func testDefaultProfileMatchesSpec() {
    let p = AlertProfile.default
    XCTAssertEqual(p.levels.map(\.id), ["low", "veryLow", "critical"])
    XCTAssertEqual(p.levels.map(\.name), ["Low", "Very low", "Critical"])
    XCTAssertEqual(p.levels.map(\.trigger), [.percentAtOrBelow(20), .percentAtOrBelow(10), .percentAtOrBelow(5)])
    XCTAssertEqual(p.levels.map(\.timing), [.nextMoment, .now, .now])
    XCTAssertEqual(p.levels.map(\.repeatPolicy), [.never, .never, .daily])
    XCTAssertEqual(p.levels.map(\.tint), [.yellow, .red, .red])
    XCTAssertTrue(p.levels.allSatisfy(\.enabled))
  }

  func testPercentTrigger() {
    let low = AlertProfile.default.levels[0]
    XCTAssertTrue(AlertProfile.default.isTriggered(low, by: reading(.percent(20)), forecast: .learning))
    XCTAssertFalse(AlertProfile.default.isTriggered(low, by: reading(.percent(21)), forecast: .learning))
    XCTAssertTrue(AlertProfile.default.isTriggered(low, by: reading(.word(.low)), forecast: .learning))
    XCTAssertFalse(AlertProfile.default.isTriggered(low, by: reading(.word(.good)), forecast: .learning))
  }

  func testForecastTriggerOnlyWithEstimate() {
    var level = AlertProfile.default.levels[0]
    level.trigger = .forecastDaysAtOrBelow(3)
    let p = AlertProfile(levels: [level])
    XCTAssertTrue(p.isTriggered(level, by: reading(.percent(60)), forecast: .estimate(daysLeft: 2.5, emptyAt: t0)))
    XCTAssertFalse(p.isTriggered(level, by: reading(.percent(60)), forecast: .estimate(daysLeft: 3.5, emptyAt: t0)))
    XCTAssertFalse(p.isTriggered(level, by: reading(.percent(1)), forecast: .learning))
  }

  func testRepeatIntervals() {
    XCTAssertNil(RepeatPolicy.never.interval)
    XCTAssertEqual(RepeatPolicy.everyHours(4).interval, 4 * 3600)
    XCTAssertEqual(RepeatPolicy.everyHours(0).interval, 3600)
    XCTAssertEqual(RepeatPolicy.daily.interval, 86_400)
  }

  func testSettingsDefaults() {
    let s = Settings()
    XCTAssertEqual(s.profile, .default)
    XCTAssertEqual(s.pinnedDevices, [])
    XCTAssertTrue(s.showAlertingInMenuBar)
    XCTAssertEqual(s.percentDisplay, .whenLow)
    XCTAssertNil(s.legacyMenuBarMode)
    XCTAssertTrue(s.fullyChargedEnabled)
    XCTAssertEqual(s.endOfDayHour, 17)
    XCTAssertEqual(s.endOfDayMinute, 30)
    XCTAssertEqual(s.maxWaitHours, 8)
    XCTAssertTrue(s.syncEnabled)
  }

  func testSettingsRoundTripAndMissingKeysUseDefaults() throws {
    var s = Settings()
    s.pinnedDevices = [.serial("M")]
    s.percentDisplay = .always
    s.maxWaitHours = 3
    XCTAssertEqual(try JuiceJSON.decoder.decode(Settings.self, from: JuiceJSON.encoder.encode(s)), s)
    let partial = try JuiceJSON.decoder.decode(Settings.self, from: Data("{\"maxWaitHours\":2}".utf8))
    XCTAssertEqual(partial.maxWaitHours, 2)
    XCTAssertEqual(partial.profile, .default)
    XCTAssertEqual(partial.pinnedDevices, [])
  }

  func testLegacyTintsIconDecodes() throws {
    func level(_ json: String) throws -> AlertLevel {
      try JuiceJSON.decoder.decode(AlertLevel.self, from: Data(json.utf8))
    }
    let base = #"{"id":"x","name":"X","enabled":true,"trigger":{"percentAtOrBelow":{"_0":20}},"timing":"now","repeatPolicy":{"never":{}},"#
    XCTAssertEqual(try level(base + #""tintsIcon":true}"#).tint, .red)
    XCTAssertEqual(try level(base + #""tintsIcon":false}"#).tint, IconTint.none)
    XCTAssertEqual(try level(base + #""tint":"yellow"}"#).tint, .yellow)
  }

  func testLegacyMenuBarModeIsReadButNotWritten() throws {
    let s = try JuiceJSON.decoder.decode(Settings.self, from: Data(#"{"menuBarMode":"always"}"#.utf8))
    XCTAssertEqual(s.legacyMenuBarMode, .always)
    let written = String(decoding: try JuiceJSON.encoder.encode(s), as: UTF8.self)
    XCTAssertFalse(written.contains("menuBarMode"), written)
  }

  func testIconTintOrdering() {
    XCTAssertLessThan(IconTint.none, .yellow)
    XCTAssertLessThan(IconTint.yellow, .red)
  }
}
