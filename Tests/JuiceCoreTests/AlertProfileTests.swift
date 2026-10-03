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
    XCTAssertEqual(p.levels.map(\.tintsIcon), [false, true, true])
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
    XCTAssertEqual(s.menuBarMode, .auto)
    XCTAssertTrue(s.fullyChargedEnabled)
    XCTAssertEqual(s.endOfDayHour, 17)
    XCTAssertEqual(s.endOfDayMinute, 30)
    XCTAssertEqual(s.maxWaitHours, 8)
    XCTAssertTrue(s.syncEnabled)
  }

  func testSettingsRoundTripAndMissingKeysUseDefaults() throws {
    var s = Settings()
    s.menuBarMode = .always
    s.maxWaitHours = 3
    XCTAssertEqual(try JuiceJSON.decoder.decode(Settings.self, from: JuiceJSON.encoder.encode(s)), s)
    let partial = try JuiceJSON.decoder.decode(Settings.self, from: Data("{\"maxWaitHours\":2}".utf8))
    XCTAssertEqual(partial.maxWaitHours, 2)
    XCTAssertEqual(partial.profile, .default)
    XCTAssertEqual(partial.menuBarMode, .auto)
  }
}
