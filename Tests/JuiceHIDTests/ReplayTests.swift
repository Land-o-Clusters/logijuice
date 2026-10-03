import XCTest
import JuiceCore
@testable import JuiceHID

/// Answers each request with the "in" frame that followed the identical "out" frame in a real capture.
final class ReplayChannel: ReportChannel, @unchecked Sendable {
  private var handler: (@Sendable ([UInt8]) -> Void)?
  private var script: [(out: [UInt8], reply: [UInt8])] = []

  init(captureURL: URL) throws {
    struct Frame: Decodable { var dir: String; var hex: String }
    struct Capture: Decodable { var frames: [Frame] }
    let frames = try JSONDecoder().decode(Capture.self, from: Data(contentsOf: captureURL)).frames
    func bytes(_ hex: String) -> [UInt8] { hex.split(separator: " ").compactMap { UInt8($0, radix: 16) } }
    for (i, f) in frames.enumerated() where f.dir == "out" {
      let request = bytes(f.hex)
      if let reply = frames[(i + 1)...].first(where: { frame in
        guard frame.dir == "in" else { return false }
        let b = bytes(frame.hex)
        return b.count > 3 && b[1] == request[1] && (b[3] == request[3] || b[2] == 0xFF || b[2] == 0x8F)
      }) {
        script.append((request, bytes(reply.hex)))
      }
    }
  }

  func send(_ bytes: [UInt8]) throws {
    guard let i = script.firstIndex(where: { $0.out == bytes }) else { return }  // silence = asleep
    let reply = script.remove(at: i).reply
    handler?(reply)
  }

  func setReportHandler(_ handler: @escaping @Sendable ([UInt8]) -> Void) { self.handler = handler }
}

final class ReplayTests: XCTestCase {
  func testOwnerMouseCaptureIdentifiesAndReadsBattery() async throws {
    let url = try XCTUnwrap(Bundle.module.url(forResource: "owner-mouse", withExtension: "json", subdirectory: "Fixtures"))
    let broker = RequestBroker(channel: try ReplayChannel(captureURL: url))
    broker.start()
    let session = ReceiverSession(broker: broker)
    var found: [SlotInfo] = []
    for slot in UInt8(1)...6 {
      if let info = await session.identify(slot: slot) { found.append(info) }
    }
    XCTAssertFalse(found.isEmpty, "capture should contain at least one awake device")
    for info in found where info.battery != .none {
      let report = await session.readBattery(info)
      XCTAssertNotNil(report, "battery read for \(info.info.name)")
    }
  }
}
