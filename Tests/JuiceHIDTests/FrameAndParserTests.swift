import XCTest
import JuiceCore
@testable import JuiceHID

final class FrameAndParserTests: XCTestCase {
  func pad(_ b: [UInt8], to n: Int) -> [UInt8] { b + Array(repeating: 0, count: n - b.count) }

  func testDecodeLongFrame() throws {
    let f = try XCTUnwrap(HIDPPFrame(bytes: pad([0x11, 0x01, 0x04, 0x1A, 42, 0x04, 0, 0], to: 20)))
    XCTAssertEqual(f.reportID, 0x11)
    XCTAssertEqual(f.deviceIndex, 1)
    XCTAssertEqual(f.featureIndex, 4)
    XCTAssertEqual(f.function, 1)
    XCTAssertEqual(f.softwareID, 0x0A)
    XCTAssertEqual(f.params.count, 16)
    XCTAssertEqual(Array(f.params.prefix(2)), [42, 0x04])
  }

  func testRequestEncodesPaddedLongFrame() {
    let f = HIDPPFrame.request(device: 1, featureIndex: 4, function: 1, softwareID: 0x0A, params: [7])
    XCTAssertEqual(f.bytes, pad([0x11, 0x01, 0x04, 0x1A, 7], to: 20))
  }

  func testRejectsUnknownReportIDAndShortBuffers() {
    XCTAssertNil(HIDPPFrame(bytes: [0x20, 1, 2, 3, 4, 5, 6]))
    XCTAssertNil(HIDPPFrame(bytes: [0x11, 1, 2]))
    XCTAssertNil(HIDPPFrame(bytes: [0x11, 1, 2, 3, 4]))
  }

  func testErrorAndNotificationFlags() throws {
    XCTAssertTrue(try XCTUnwrap(HIDPPFrame(bytes: pad([0x11, 1, 0xFF, 4, 0x1A, 0x05], to: 20))).isError)
    XCTAssertTrue(try XCTUnwrap(HIDPPFrame(bytes: [0x10, 2, 0x8F, 0x00, 0x1A, 0x09, 0])).isError)
    let note = try XCTUnwrap(HIDPPFrame(bytes: [0x10, 1, 0x41, 0x10, 0x00, 0x8A, 0x40]))
    XCTAssertTrue(note.isNotification)
    XCTAssertFalse(note.isError)
  }

  func testGetFeatureIndex() {
    XCTAssertEqual(FeatureParsers.featureIndex(fromGetFeature: [4, 0, 1]), 4)
    XCTAssertNil(FeatureParsers.featureIndex(fromGetFeature: [0, 0, 0]))
    XCTAssertNil(FeatureParsers.featureIndex(fromGetFeature: []))
  }

  func testUnifiedBattery() {
    XCTAssertTrue(FeatureParsers.unifiedBatteryPercentSupported([0x0F, 0x02]))
    XCTAssertFalse(FeatureParsers.unifiedBatteryPercentSupported([0x0F, 0x01]))
    XCTAssertEqual(FeatureParsers.unifiedBatteryStatus([42, 0x04, 0, 0], percentSupported: true),
                   BatteryReport(level: .percent(42), charging: false))
    XCTAssertEqual(FeatureParsers.unifiedBatteryStatus([42, 0x04, 1, 1], percentSupported: true)?.charging, true)
    XCTAssertEqual(FeatureParsers.unifiedBatteryStatus([42, 0x04, 2, 1], percentSupported: true)?.charging, true)
    XCTAssertEqual(FeatureParsers.unifiedBatteryStatus([100, 0x08, 3, 1], percentSupported: true),
                   BatteryReport(level: .percent(100), charging: false))
    XCTAssertEqual(FeatureParsers.unifiedBatteryStatus([0, 0x04, 0, 0], percentSupported: false)?.level, .word(.good))
  }

  func testUnifiedRejectsOutOfRangePercent() {
    XCTAssertEqual(FeatureParsers.unifiedBatteryStatus([0, 0x02, 0, 0], percentSupported: true)?.level, .word(.low))
    XCTAssertEqual(FeatureParsers.unifiedBatteryStatus([150, 0x01, 0, 0], percentSupported: true)?.level, .word(.critical))
    XCTAssertNil(FeatureParsers.unifiedBatteryStatus([0, 0x00, 0, 0], percentSupported: true))
    XCTAssertNil(FeatureParsers.unifiedBatteryStatus([42], percentSupported: true))
  }

  func testBatteryStatus1000() {
    XCTAssertEqual(FeatureParsers.batteryStatus([55, 50, 0]), BatteryReport(level: .percent(55), charging: false))
    XCTAssertEqual(FeatureParsers.batteryStatus([55, 50, 1])?.charging, true)
    XCTAssertEqual(FeatureParsers.batteryStatus([55, 50, 4])?.charging, true)
    XCTAssertEqual(FeatureParsers.batteryStatus([0, 0, 3]), BatteryReport(level: .percent(100), charging: false))
  }

  func testBatteryStatusRejectsErrorStatus() {
    XCTAssertNil(FeatureParsers.batteryStatus([55, 50, 5]))
    XCTAssertNil(FeatureParsers.batteryStatus([0, 0, 0]))
    XCTAssertNil(FeatureParsers.batteryStatus([120, 0, 0]))
  }

  func testNameChunk() {
    XCTAssertEqual(FeatureParsers.nameChunk(Array("MX Master 3S".utf8) + [0, 0, 0, 0], remaining: 4), "MX M")
    XCTAssertEqual(FeatureParsers.nameChunk(Array("3S".utf8) + [0, 0], remaining: 10), "3S")
  }

  func testDeviceInformationAndSerial() {
    let info = FeatureParsers.deviceInformation([1, 0xDE, 0xAD, 0xBE, 0xEF, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x01, 0])
    XCTAssertEqual(info, DeviceInformation(unitID: "DEADBEEF", serialSupported: true))
    XCTAssertNil(FeatureParsers.deviceInformation([1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x00, 0])?.unitID)
    XCTAssertNil(FeatureParsers.deviceInformation([1, 2, 3]))
    XCTAssertEqual(FeatureParsers.serialNumber(Array("SERIAL123456".utf8) + [0, 0, 0, 0]), "SERIAL123456")
    XCTAssertNil(FeatureParsers.serialNumber(Array(repeating: 0, count: 16)))
  }

  /// Exact frames captured from the owner's Bolt receiver in Task 0 (docs/bringup-notes.md).
  func testRealCapturedFrames() throws {
    XCTAssertEqual(FeatureParsers.deviceInformation(
      [0x03, 0xA1, 0xB2, 0xC3, 0xD4, 0x00, 0x02, 0xB3, 0x78, 0, 0, 0, 0, 0x00, 0x01, 0x00]),
      DeviceInformation(unitID: "A1B2C3D4", serialSupported: true))
    XCTAssertEqual(FeatureParsers.serialNumber(Array("TESTMOUSE001".utf8) + [0, 0, 0, 0]), "TESTMOUSE001")
    XCTAssertTrue(FeatureParsers.unifiedBatteryPercentSupported([0x0F, 0x03]))
    XCTAssertEqual(FeatureParsers.unifiedBatteryStatus([0x41, 0x08, 0x00, 0x00], percentSupported: true),
                   BatteryReport(level: .percent(65), charging: false))
    XCTAssertEqual(FeatureParsers.unifiedBatteryStatus([0x46, 0x08, 0x01, 0x01], percentSupported: true),
                   BatteryReport(level: .percent(70), charging: true))
    let down = try XCTUnwrap(HIDPPFrame(bytes: [0x10, 0x02, 0x41, 0x10, 0x42, 0x34, 0xB0]))
    XCTAssertEqual(FeatureParsers.connectionNotice(down), ConnectionNotice(slot: 2, linkUp: false, wpid: 0xB034))
    let up2 = try XCTUnwrap(HIDPPFrame(bytes: [0x10, 0x02, 0x41, 0x10, 0x02, 0x34, 0xB0]))
    XCTAssertEqual(FeatureParsers.connectionNotice(up2)?.linkUp, true)
    XCTAssertTrue(try XCTUnwrap(HIDPPFrame(bytes: [0x10, 0x03, 0x8F, 0x00, 0x1A, 0x09, 0x00])).isError)
  }

  func testConnectionNotice() throws {
    let up = try XCTUnwrap(HIDPPFrame(bytes: [0x10, 0x01, 0x41, 0x10, 0x00, 0x8A, 0x40]))
    XCTAssertEqual(FeatureParsers.connectionNotice(up), ConnectionNotice(slot: 1, linkUp: true, wpid: 0x408A))
    let down = try XCTUnwrap(HIDPPFrame(bytes: [0x10, 0x02, 0x41, 0x10, 0x40, 0x8A, 0x40]))
    XCTAssertEqual(FeatureParsers.connectionNotice(down)?.linkUp, false)
    let other = try XCTUnwrap(HIDPPFrame(bytes: pad([0x11, 0x01, 0x04, 0x00, 42], to: 20)))
    XCTAssertNil(FeatureParsers.connectionNotice(other))
  }
}

final class VoltageBatteryTests: XCTestCase {
  func testVoltageToPercentFollowsLithiumIonCurve() {
    XCTAssertEqual(FeatureParsers.percent(fromMillivolts: 4200), 100)
    XCTAssertEqual(FeatureParsers.percent(fromMillivolts: 3811), 50)
    XCTAssertEqual(FeatureParsers.percent(fromMillivolts: 3500), 0)
    XCTAssertEqual(FeatureParsers.percent(fromMillivolts: 3200), 0)
    let mid = FeatureParsers.percent(fromMillivolts: 3890)  // between 3859 (60) and 3922 (70)
    XCTAssertTrue((60...70).contains(mid), "\(mid)")
  }

  func testBatteryVoltageReport() {
    // 0x0EE2 = 3810 mV, flags 0x00 → discharging ~50 %
    XCTAssertEqual(FeatureParsers.batteryVoltage([0x0E, 0xE2, 0x00]), BatteryReport(level: .percent(50), charging: false))
    // charging flag (0x80)
    XCTAssertEqual(FeatureParsers.batteryVoltage([0x0F, 0xA0, 0x80])?.charging, true)
    // nonsense voltage is rejected rather than reported as 0 %
    XCTAssertNil(FeatureParsers.batteryVoltage([0x00, 0x00, 0x00]))
    XCTAssertNil(FeatureParsers.batteryVoltage([0x0E]))
  }
}
