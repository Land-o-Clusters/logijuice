import XCTest
import JuiceCore
import JuiceStore
@testable import JuiceCLIKit

final class CLITests: XCTestCase {
  var url: URL!
  var out: [String] = []
  var err: [String] = []
  let now = Date(timeIntervalSince1970: 1_800_000_000)

  override func setUpWithError() throws {
    url = FileManager.default.temporaryDirectory.appendingPathComponent("cli-\(UUID().uuidString).json")
    out = []
    err = []
  }

  func run(_ args: [String]) -> Int32 {
    CLI.run(args, snapshotURL: url, now: now, out: { self.out.append($0) }, err: { self.err.append($0) })
  }

  func testStatusWithoutSnapshotFails() {
    XCTAssertEqual(run(["status"]), 1)
    XCTAssertEqual(err, ["No data yet. Is LogiJuice running?"])
  }

  func testStatusPrintsOneLinePerDevice() throws {
    try SnapshotStore(url: url).save(.preview)
    XCTAssertEqual(run(["status"]), 0)
    XCTAssertEqual(out, ["MX Master 3S: 14%, ~2 days", "MX Keys S: 72%, learning…"])
  }

  func testStatusJSON() throws {
    try SnapshotStore(url: url).save(.preview)
    XCTAssertEqual(run(["status", "--json"]), 0)
    let decoded = try JuiceJSON.decoder.decode(Snapshot.self, from: Data(out.joined().utf8))
    XCTAssertEqual(decoded, .preview)
  }

  func testDevices() throws {
    try SnapshotStore(url: url).save(.preview)
    XCTAssertEqual(run(["devices"]), 0)
    XCTAssertEqual(out.first, "sn:PREVIEW-MOUSE\tMX Master 3S\tmouse\tseen just now")
  }

  func testEmptySnapshot() throws {
    try SnapshotStore(url: url).save(Snapshot(generatedAt: now, receiverPresent: false, devices: []))
    XCTAssertEqual(run(["status"]), 0)
    XCTAssertEqual(out, ["No devices seen yet."])
  }

  func testHelpAndUnknown() {
    XCTAssertEqual(run([]), 0)
    XCTAssertEqual(out, [CLI.usage])
    XCTAssertEqual(run(["frobnicate"]), 64)
    XCTAssertTrue(err.first?.hasPrefix("unknown command: frobnicate") ?? false)
  }
}
