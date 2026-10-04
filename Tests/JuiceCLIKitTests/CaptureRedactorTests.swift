import JuiceCLIKit
import XCTest

final class CaptureRedactorTests: XCTestCase {
  private func long(_ dev: UInt8, _ idx: UInt8, _ fnSw: UInt8, _ payload: [UInt8]) -> [UInt8] {
    let body = [0x11, dev, idx, fnSw] + payload
    return body + [UInt8](repeating: 0, count: 20 - body.count)
  }

  private let serial = Array("TESTMOUSE001".utf8)
  private let unit: [UInt8] = [0xD4, 0xC3, 0xB2, 0xA1]
  private func deviceInfo() -> [UInt8] { [0x03] + unit + [0x00, 0x02, 0xB0, 0x34, 0, 0, 0, 0, 0x00, 0x01] }

  /// A probe resolves 0x0003 to index 0x02 on device 2, then reads the unit ID (fn0) and serial (fn2).
  /// Options+ (software ID 0xF) asks for the same serial; its reply must be redacted too.
  func testRedactsDeviceInformationRepliesFoundThroughTheProbe() {
    let frames: [CaptureRedactor.RawFrame] = [
      .init(dir: "out", bytes: long(2, 0x00, 0x0A, [0x00, 0x03])),
      .init(dir: "in", bytes: long(2, 0x00, 0x0A, [0x02, 0x00, 0x04])),
      .init(dir: "out", bytes: long(2, 0x02, 0x0A, [])),
      .init(dir: "in", bytes: long(2, 0x02, 0x0A, deviceInfo())),
      .init(dir: "out", bytes: long(2, 0x02, 0x2A, [])),
      .init(dir: "in", bytes: long(2, 0x02, 0x2A, serial)),
      .init(dir: "in", bytes: long(2, 0x02, 0x2F, serial)),
    ]
    let out = CaptureRedactor.redact(frames, knownIDs: [])
    XCTAssertEqual(out.count, frames.count)
    for f in out {
      XCTAssertNil(f.bytes.firstRange(of: serial), "serial left in \(f.bytes)")
      XCTAssertNil(f.bytes.firstRange(of: unit), "unit ID left in \(f.bytes)")
    }
    // The model ID and capabilities stay, so the capture is still useful.
    XCTAssertEqual(Array(out[3].bytes[9...12]), [0x00, 0x02, 0xB0, 0x34])
    XCTAssertEqual(out[0].bytes, frames[0].bytes)
    XCTAssertEqual(out[1].bytes, frames[1].bytes)
  }

  /// A passive capture has no probe to locate 0x0003, so IDs logijuice already knows are swept by content.
  func testSweepsKnownIdentifiersByContent() {
    let frames: [CaptureRedactor.RawFrame] = [
      .init(dir: "in", bytes: long(2, 0x05, 0x2F, serial)),
      .init(dir: "in", bytes: long(2, 0x05, 0x0F, deviceInfo())),
    ]
    let out = CaptureRedactor.redact(frames, knownIDs: ["sn:TESTMOUSE001", "unit:D4C3B2A1", "wpid:B034:0000:slot:2"])
    XCTAssertNil(out[0].bytes.firstRange(of: serial))
    XCTAssertNil(out[1].bytes.firstRange(of: unit))
  }

  func testLeavesOtherTrafficUntouched() {
    let battery = CaptureRedactor.RawFrame(dir: "in", bytes: long(2, 0x08, 0x1A, [0x46, 0x08, 0x00, 0x00]))
    let connect = CaptureRedactor.RawFrame(dir: "in", bytes: [0x10, 0x02, 0x41, 0x10, 0x02, 0x34, 0xB0])
    let out = CaptureRedactor.redact([battery, connect], knownIDs: ["sn:TESTMOUSE001"])
    XCTAssertEqual(out.map(\.bytes), [battery.bytes, connect.bytes])
  }

  func testRedactsIDsInText() {
    XCTAssertEqual(CaptureRedactor.redactID("sn:TESTMOUSE001"), "sn:<redacted>")
    XCTAssertEqual(CaptureRedactor.redactID("unit:D4C3B2A1"), "unit:<redacted>")
    XCTAssertEqual(CaptureRedactor.redactID("wpid:B034:0000:slot:2"), "wpid:B034:0000:slot:2")
  }
}
