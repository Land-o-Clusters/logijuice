import XCTest
@testable import JuiceCore

final class ThresholdLayoutTests: XCTestCase {
  func testSegmentsCoverZeroToHundredInThresholdOrder() {
    let segs = ThresholdLayout.segments(.default)
    XCTAssertEqual(segs.map(\.from), [0, 5, 10, 20])
    XCTAssertEqual(segs.map(\.to), [5, 10, 20, 100])
    XCTAssertEqual(segs.map(\.tint), [.red, .red, .yellow, IconTint.none])
    XCTAssertEqual(segs.map(\.levelID), ["critical", "veryLow", "low", nil])
  }

  func testDisabledAndForecastLevelsAreNotOnTheBar() {
    var p = AlertProfile.default
    p.levels[1].enabled = false
    p.levels[2].trigger = .forecastDaysAtOrBelow(3)
    let segs = ThresholdLayout.segments(p)
    XCTAssertEqual(segs.map(\.levelID), ["low", nil])
    XCTAssertEqual(segs.map(\.to), [20, 100])
    XCTAssertEqual(ThresholdLayout.markers(p).map(\.levelID), ["low"])
  }

  func testMarkersAreSortedByThreshold() {
    XCTAssertEqual(ThresholdLayout.markers(.default).map(\.threshold), [5, 10, 20])
    XCTAssertEqual(ThresholdLayout.markers(.default).map(\.levelIndex), [2, 1, 0])
  }

  func testClampKeepsSeverityOrder() {
    let p = AlertProfile.default  // low 20 (index 0), veryLow 10 (1), critical 5 (2)
    XCTAssertEqual(ThresholdLayout.clamp(35, levelAt: 0, in: p), 35)
    XCTAssertEqual(ThresholdLayout.clamp(7, levelAt: 0, in: p), 11)   // must stay above Very low
    XCTAssertEqual(ThresholdLayout.clamp(25, levelAt: 1, in: p), 19)  // below Low
    XCTAssertEqual(ThresholdLayout.clamp(2, levelAt: 1, in: p), 6)    // above Critical
    XCTAssertEqual(ThresholdLayout.clamp(0, levelAt: 2, in: p), 1)
    XCTAssertEqual(ThresholdLayout.clamp(99, levelAt: 0, in: p), 95)
  }

  func testClampIgnoresDisabledNeighbours() {
    var p = AlertProfile.default
    p.levels[1].enabled = false
    XCTAssertEqual(ThresholdLayout.clamp(7, levelAt: 0, in: p), 7)
  }

  func testSetThresholdOnlyTouchesPercentTriggers() {
    var p = AlertProfile.default
    ThresholdLayout.setThreshold(30, levelAt: 0, in: &p)
    XCTAssertEqual(p.levels[0].trigger, .percentAtOrBelow(30))
    ThresholdLayout.setThreshold(25, levelAt: 1, in: &p)
    XCTAssertEqual(p.levels[1].trigger, .percentAtOrBelow(25))  // < Low (30)
    p.levels[2].trigger = .forecastDaysAtOrBelow(3)
    ThresholdLayout.setThreshold(2, levelAt: 2, in: &p)
    XCTAssertEqual(p.levels[2].trigger, .forecastDaysAtOrBelow(3))
  }
}
