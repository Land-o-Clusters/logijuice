import XCTest
@testable import JuiceCore

final class SettingsTests: XCTestCase {
  func testMutedDevicesRoundTripAndDefaultToNone() throws {
    XCTAssertEqual(Settings().mutedDevices, [])
    var s = Settings()
    s.mutedDevices = [.serial("TESTMOUSE001")]
    let back = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(s))
    XCTAssertEqual(back.mutedDevices, [.serial("TESTMOUSE001")])
    XCTAssertTrue(back.alertsMuted(for: .serial("TESTMOUSE001")))
    XCTAssertFalse(back.alertsMuted(for: .serial("TESTKEYS0001")))
  }

  func testOlderSettingsFileWithoutMutedDevicesLoads() throws {
    let old = Data(#"{"pinnedDevices":["sn:TESTKEYS0001"],"syncEnabled":true}"#.utf8)
    let s = try JSONDecoder().decode(Settings.self, from: old)
    XCTAssertEqual(s.mutedDevices, [])
    XCTAssertEqual(s.pinnedDevices, [.serial("TESTKEYS0001")])
  }
}
