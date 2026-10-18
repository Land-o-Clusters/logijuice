import CoreGraphics
import XCTest
@testable import JuiceCore

final class StatusItemPlacementTests: XCTestCase {
  // Two side-by-side 2560×1440 displays in AppKit coordinates (origin bottom-left).
  let screens = [CGRect(x: 0, y: 0, width: 2560, height: 1440), CGRect(x: 2560, y: 0, width: 2560, height: 1440)]
  let t0 = Date(timeIntervalSince1970: 1_800_000_000)

  func testItemInTheMenuBarIsPlaced() {
    let item = CGRect(x: 1848, y: 1440 - 24 - 2, width: 61, height: 24)
    XCTAssertFalse(StatusItemPlacement.isStranded(itemFrames: [item], screenFrames: screens))
  }

  func testItemOnTheSecondDisplaysMenuBarIsPlaced() {
    let item = CGRect(x: 4000, y: 1416, width: 61, height: 24)
    XCTAssertFalse(StatusItemPlacement.isStranded(itemFrames: [item], screenFrames: screens))
  }

  /// Seen 2026-10-18: System Events reported the item at (-1, 1428) top-left, i.e. below the bottom edge.
  func testItemParkedOffScreenIsStranded() {
    let item = CGRect(x: -1, y: -12, width: 61, height: 24)
    XCTAssertTrue(StatusItemPlacement.isStranded(itemFrames: [item], screenFrames: screens))
  }

  func testItemAboveTheTopEdgeCountsAsPlaced() {
    // An auto-hidden menu bar slides its items just above the screen.
    let item = CGRect(x: 1848, y: 1442, width: 61, height: 24)
    XCTAssertFalse(StatusItemPlacement.isStranded(itemFrames: [item], screenFrames: screens))
  }

  func testNoItemsOrNoScreensIsNotStranded() {
    XCTAssertFalse(StatusItemPlacement.isStranded(itemFrames: [], screenFrames: screens))
    XCTAssertFalse(StatusItemPlacement.isStranded(itemFrames: [CGRect(x: -1, y: -12, width: 61, height: 24)],
                                                  screenFrames: []))
  }

  func testReinsertOnlyWhenStrandedAndNotTooSoon() {
    XCTAssertFalse(StatusItemPlacement.shouldReinsert(stranded: false, lastReinsert: nil, now: t0))
    XCTAssertTrue(StatusItemPlacement.shouldReinsert(stranded: true, lastReinsert: nil, now: t0))
    XCTAssertFalse(StatusItemPlacement.shouldReinsert(stranded: true, lastReinsert: t0 - 60, now: t0))
    XCTAssertTrue(StatusItemPlacement.shouldReinsert(
      stranded: true, lastReinsert: t0 - StatusItemPlacement.minimumInterval, now: t0))
  }
}
