import XCTest
import JuiceCore
@testable import JuiceHID

/// Emulates one MX-style mouse in slot 1; every other slot answers "unknown device" (HID++ 1.0 error 0x09).
func fakeMouseResponder(serial: Bool = true, name: String = "MX Master 3S") -> ([UInt8]) -> [[UInt8]] {
  let features: [UInt16: UInt8] = [0x0003: 2, 0x0005: 3, 0x1004: 4]
  return { req in
    let dev = req[1], fi = req[2], fs = req[3], fn = fs >> 4
    func ok(_ p: [UInt8]) -> [[UInt8]] { [long([0x11, dev, fi, fs] + p)] }
    guard dev == 1 else { return [[0x10, dev, 0x8F, fi, fs, 0x09, 0]] }
    switch (fi, fn) {
    case (0, 0):
      let id = UInt16(req[4]) << 8 | UInt16(req[5])
      return ok([features[id] ?? 0, 0, 0])
    case (0, 1): return ok([4, 5, 0x5A])
    case (3, 0): return ok([UInt8(name.utf8.count)])
    case (3, 1): return ok(Array(Array(name.utf8).dropFirst(Int(req[4])).prefix(16)))
    case (3, 2): return ok([3])
    case (2, 0): return ok([1, 0xDE, 0xAD, 0xBE, 0xEF, 0, 0, 0, 0, 0, 0, 0, 0, 0, serial ? 0x01 : 0x00])
    case (2, 2): return ok(Array("SERIAL123456".utf8))
    case (4, 0): return ok([0x0F, 0x02])
    case (4, 1): return ok([42, 0x04, 0, 0])
    default: return [long([0x11, dev, 0xFF, fi, fs, 0x02])]
    }
  }
}

final class ReceiverSessionTests: XCTestCase {
  func session(_ responder: @escaping ([UInt8]) -> [[UInt8]]) -> ReceiverSession {
    let ch = FakeChannel()
    ch.responder = responder
    let broker = RequestBroker(channel: ch)
    broker.start()
    return ReceiverSession(broker: broker)
  }

  func testIdentifyMouse() async throws {
    let s = session(fakeMouseResponder())
    let info = try await XCTUnwrapAsync(await s.identify(slot: 1))
    XCTAssertEqual(info.slot, 1)
    XCTAssertEqual(info.info, DeviceInfo(id: .serial("SERIAL123456"), name: "MX Master 3S", kind: .mouse))
    XCTAssertEqual(info.battery, .unified(index: 4, percent: true))
  }

  func testIdentifyFallsBackToUnitID() async throws {
    let s = session(fakeMouseResponder(serial: false))
    let info = try await XCTUnwrapAsync(await s.identify(slot: 1))
    XCTAssertEqual(info.info.id, .unit("DEADBEEF"))
  }

  func testLongNameIsReadInChunks() async throws {
    let s = session(fakeMouseResponder(name: "Logitech Wireless Mouse MX"))
    let info = try await XCTUnwrapAsync(await s.identify(slot: 1))
    XCTAssertEqual(info.info.name, "Logitech Wireless Mouse MX")
  }

  func testEmptySlotIsNil() async {
    let s = session(fakeMouseResponder())
    let info = await s.identify(slot: 2)
    XCTAssertNil(info)
  }

  func testReadBattery() async throws {
    let s = session(fakeMouseResponder())
    let info = try await XCTUnwrapAsync(await s.identify(slot: 1))
    let report = await s.readBattery(info)
    XCTAssertEqual(report, BatteryReport(level: .percent(42), charging: false))
  }

  func testInterpret() throws {
    let slot = SlotInfo(slot: 1, info: DeviceInfo(id: .serial("S"), name: "M", kind: .mouse),
                        battery: .unified(index: 4, percent: true))
    let slots: [UInt8: SlotInfo] = [1: slot]
    let event = try XCTUnwrap(HIDPPFrame(bytes: long([0x11, 1, 4, 0x00, 37, 0x04, 1, 1])))
    XCTAssertEqual(ReceiverSession.interpret(event, slots: slots),
                   .battery(slot: 1, BatteryReport(level: .percent(37), charging: true)))
    let wrongIndex = try XCTUnwrap(HIDPPFrame(bytes: long([0x11, 1, 5, 0x00, 37, 0x04])))
    XCTAssertNil(ReceiverSession.interpret(wrongIndex, slots: slots))
    let reply = try XCTUnwrap(HIDPPFrame(bytes: long([0x11, 1, 4, 0x1A, 37, 0x04])))
    XCTAssertNil(ReceiverSession.interpret(reply, slots: slots))
    let up = try XCTUnwrap(HIDPPFrame(bytes: [0x10, 2, 0x41, 0x10, 0x00, 0x8A, 0x40]))
    XCTAssertEqual(ReceiverSession.interpret(up, slots: slots), .linkUp(slot: 2))
  }
}

func XCTUnwrapAsync<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) async throws -> T {
  try XCTUnwrap(value, file: file, line: line)
}

final class VoltageSessionTests: XCTestCase {
  /// A G-series-style mouse that only exposes 0x1001 Battery Voltage (index 5).
  func responder() -> ([UInt8]) -> [[UInt8]] {
    { req in
      let dev = req[1], fi = req[2], fs = req[3], fn = fs >> 4
      func ok(_ p: [UInt8]) -> [[UInt8]] { [long([0x11, dev, fi, fs] + p)] }
      guard dev == 1 else { return [[0x10, dev, 0x8F, fi, fs, 0x09, 0]] }
      switch (fi, fn) {
      case (0, 0):
        let id = UInt16(req[4]) << 8 | UInt16(req[5])
        return ok([id == 0x1001 ? 5 : id == 0x0005 ? 3 : 0, 0, 0])
      case (0, 1): return ok([4, 2, 0x5A])
      case (3, 0): return ok([3])
      case (3, 1): return ok(Array("G P".utf8))
      case (3, 2): return ok([3])
      case (5, 0): return ok([0x0E, 0xE2, 0x00])
      default: return [long([0x11, dev, 0xFF, fi, fs, 0x02])]
      }
    }
  }

  func testIdentifyAndReadVoltageOnlyDevice() async throws {
    let ch = FakeChannel()
    ch.responder = responder()
    let broker = RequestBroker(channel: ch)
    broker.start()
    let session = ReceiverSession(broker: broker)
    let identified = await session.identify(slot: 1)
    let info = try XCTUnwrap(identified)
    XCTAssertEqual(info.battery, .voltage(index: 5))
    let report = await session.readBattery(info)
    XCTAssertEqual(report, BatteryReport(level: .percent(50), charging: false))
  }

  func testInterpretVoltageEvent() throws {
    let slot = SlotInfo(slot: 1, info: DeviceInfo(id: .serial("G"), name: "G", kind: .mouse), battery: .voltage(index: 5))
    let event = try XCTUnwrap(HIDPPFrame(bytes: long([0x11, 1, 5, 0x00, 0x0E, 0xE2, 0x80])))
    XCTAssertEqual(ReceiverSession.interpret(event, slots: [1: slot]),
                   .battery(slot: 1, BatteryReport(level: .percent(50), charging: true)))
  }
}
