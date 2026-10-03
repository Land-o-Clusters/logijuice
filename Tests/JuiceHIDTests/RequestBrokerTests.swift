import XCTest
@testable import JuiceHID

final class RequestBrokerTests: XCTestCase {
  func makeBroker(_ channel: FakeChannel) -> RequestBroker {
    let b = RequestBroker(channel: channel)
    b.start()
    return b
  }

  /// Echo-style reply: same header, given params.
  func reply(to req: [UInt8], params: [UInt8], sw: UInt8? = nil) -> [UInt8] {
    var fs = req[3]
    if let sw { fs = (fs & 0xF0) | sw }
    return long([0x11, req[1], req[2], fs] + params)
  }

  func testRequestReturnsParamsOfMatchingReply() async throws {
    let ch = FakeChannel()
    ch.responder = { [self] req in [reply(to: req, params: [42, 4])] }
    let b = makeBroker(ch)
    let p = try await b.request(device: 1, featureIndex: 4, function: 1)
    XCTAssertEqual(Array(p.prefix(2)), [42, 4])
    XCTAssertEqual(ch.sent, [long([0x11, 1, 4, 0x1A])])
  }

  func testForeignSoftwareIDReplyIsIgnoredAndTimesOut() async {
    let ch = FakeChannel()
    ch.responder = { [self] req in [reply(to: req, params: [1], sw: 0x03)] }
    let b = makeBroker(ch)
    do {
      _ = try await b.request(device: 1, featureIndex: 4, function: 1, timeout: .milliseconds(150))
      XCTFail("expected timeout")
    } catch {
      XCTAssertEqual(error as? HIDPPError, .timeout)
    }
  }

  func testHIDPP2ErrorBecomesProtocolError() async {
    let ch = FakeChannel()
    ch.responder = { req in [long([0x11, req[1], 0xFF, req[2], req[3], 0x05])] }
    let b = makeBroker(ch)
    do {
      _ = try await b.request(device: 1, featureIndex: 4, function: 1)
      XCTFail("expected error")
    } catch {
      XCTAssertEqual(error as? HIDPPError, .protocolError(code: 0x05))
    }
  }

  func testHIDPP1ErrorForEmptySlot() async {
    let ch = FakeChannel()
    ch.responder = { req in [[0x10, req[1], 0x8F, req[2], req[3], 0x09, 0]] }
    let b = makeBroker(ch)
    do {
      _ = try await b.request(device: 3, featureIndex: 0, function: 1)
      XCTFail("expected error")
    } catch {
      XCTAssertEqual(error as? HIDPPError, .protocolError(code: 0x09))
    }
  }

  func testEventsStreamGetsSoftwareIDZeroAndNotifications() async {
    let ch = FakeChannel()
    let b = makeBroker(ch)
    var it = b.events.makeAsyncIterator()
    ch.inject(long([0x11, 1, 4, 0x00, 37, 4]))          // battery event
    ch.inject(long([0x11, 1, 4, 0x13, 99]))             // Options+ reply: must NOT surface
    ch.inject([0x10, 1, 0x41, 0x10, 0x00, 0x8A, 0x40])  // connection notification
    let first = await it.next()
    let second = await it.next()
    XCTAssertEqual(first?.params.first, 37)
    XCTAssertEqual(second?.featureIndex, 0x41)
  }

  func testConcurrentRequestsAreSerialized() async throws {
    let ch = FakeChannel()
    ch.responder = { [self] req in [reply(to: req, params: [req[2]])] }
    let b = makeBroker(ch)
    async let a = b.request(device: 1, featureIndex: 2, function: 0)
    async let c = b.request(device: 1, featureIndex: 3, function: 0)
    let (pa, pc) = try await (a, c)
    XCTAssertEqual(pa.first, 2)
    XCTAssertEqual(pc.first, 3)
    XCTAssertEqual(ch.sent.count, 2)
  }

  func testCloseFailsPendingRequest() async {
    let ch = FakeChannel()  // never replies
    let b = makeBroker(ch)
    let task = Task { try await b.request(device: 1, featureIndex: 4, function: 1, timeout: .seconds(30)) }
    try? await Task.sleep(for: .milliseconds(50))
    await b.close()
    do {
      _ = try await task.value
      XCTFail("expected closed")
    } catch {
      XCTAssertEqual(error as? HIDPPError, .closed)
    }
    do {
      _ = try await b.request(device: 1, featureIndex: 4, function: 1)
      XCTFail("expected closed")
    } catch {
      XCTAssertEqual(error as? HIDPPError, .closed)
    }
  }

  func testSendFailure() async {
    let ch = FakeChannel()
    ch.failSends = true
    let b = makeBroker(ch)
    do {
      _ = try await b.request(device: 1, featureIndex: 4, function: 1)
      XCTFail("expected sendFailed")
    } catch {
      XCTAssertEqual(error as? HIDPPError, .sendFailed)
    }
  }
}
