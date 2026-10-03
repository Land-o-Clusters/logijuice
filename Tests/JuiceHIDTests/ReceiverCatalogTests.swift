import XCTest
@testable import JuiceHID

final class ReceiverCatalogTests: XCTestCase {
  func testCatalogRecordsWhatIsVerified() {
    let bolt = HIDPPInterface.receivers.first { $0.productID == 0xC548 }
    XCTAssertEqual(bolt?.family, .bolt)
    XCTAssertEqual(bolt?.verified, true)
    let lightspeed = HIDPPInterface.receivers.filter { $0.family == .lightspeed }
    XCTAssertFalse(lightspeed.isEmpty)
    XCTAssertTrue(lightspeed.allSatisfy { !$0.verified }, "no Lightspeed receiver has been tested on hardware yet")
    XCTAssertTrue(lightspeed.map(\.productID).contains(0xC539))
  }

  func testProductIDsAreUniqueAndMatchTheCatalog() {
    let ids = HIDPPInterface.receivers.map(\.productID)
    XCTAssertEqual(Set(ids).count, ids.count)
    XCTAssertEqual(HIDPPInterface.receiverProductIDs, ids)
  }
}
