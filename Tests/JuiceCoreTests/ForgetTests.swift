import XCTest
@testable import JuiceCore

final class ForgetTests: XCTestCase {
  let t0 = Date(timeIntervalSince1970: 1_800_000_000)
  let mouse = DeviceID.serial("TESTMOUSE001")
  let keys = DeviceID.serial("TESTKEYS0001")

  func reading(_ id: DeviceID, _ p: Int, at t: Date) -> Reading {
    Reading(device: id, level: .percent(p), charging: false, observedAt: t)
  }

  func record(_ id: DeviceID, nickname: String? = nil, meta: Date? = nil, readings: [Reading],
              healthSince: Date? = nil) -> DeviceRecord {
    var health: HealthLog?
    if let healthSince {
      var log = HealthLog()
      log.since = healthSince
      log.chargeGain = ["B": 80]
      health = log
    }
    return DeviceRecord(info: DeviceInfo(id: id, name: "Test device", kind: .mouse), nickname: nickname,
                        alertOverride: nil, metaUpdatedAt: meta ?? t0, readings: readings, health: health)
  }

  func file(_ mac: String, _ devices: [DeviceRecord], forgotten: [DeviceID: Date]? = nil) -> SyncFile {
    SyncFile(macID: mac, macName: mac, updatedAt: t0, devices: devices, forgotten: forgotten)
  }

  // MARK: Merge honors forgets

  func testLocallyForgottenDeviceStaysGoneDespiteAnotherMacsFile() {
    let merged = SyncMerge.merge(
      local: [record(keys, readings: [reading(keys, 90, at: t0)])],
      remotes: [file("B", [record(mouse, readings: [reading(mouse, 40, at: t0)])])],
      forgotten: [mouse: t0 + 60], now: t0 + 120)
    XCTAssertEqual(merged.map(\.id), [keys])
  }

  func testForgetFromAnotherMacHidesThisMacsOldRecord() {
    let merged = SyncMerge.merge(
      local: [record(mouse, readings: [reading(mouse, 40, at: t0)])],
      remotes: [file("B", [], forgotten: [mouse: t0 + 60])], now: t0 + 120)
    XCTAssertTrue(merged.isEmpty)
  }

  func testDeviceSeenAgainReturnsWithOnlyNewerData() {
    let forgetAt = t0 + 60
    let merged = SyncMerge.merge(
      local: [record(mouse, readings: [reading(mouse, 35, at: t0 + 600)])],
      remotes: [file("B", [record(mouse, nickname: "Old name", meta: t0,
                                  readings: [reading(mouse, 40, at: t0)], healthSince: t0 - 86_400)])],
      forgotten: [mouse: forgetAt], now: t0 + 600)
    XCTAssertEqual(merged.map(\.id), [mouse])
    XCTAssertEqual(merged[0].readings.map(\.level), [.percent(35)])
    XCTAssertNil(merged[0].nickname, "a name set before the forget is forgotten too")
    XCTAssertNil(merged[0].health, "a health log started before the forget is forgotten too")
  }

  func testDataStartedAfterTheForgetIsKept() {
    let forgetAt = t0 + 60
    let merged = SyncMerge.merge(
      local: [],
      remotes: [file("B", [record(mouse, nickname: "Desk mouse", meta: t0 + 900,
                                  readings: [reading(mouse, 80, at: t0 + 600)], healthSince: t0 + 600)])],
      forgotten: [mouse: forgetAt], now: t0 + 900)
    XCTAssertEqual(merged.first?.nickname, "Desk mouse")
    XCTAssertEqual(merged.first?.health?.since, t0 + 600)
  }

  func testForgetLeavesOtherDevicesAlone() {
    let merged = SyncMerge.merge(
      local: [record(mouse, readings: [reading(mouse, 40, at: t0)]), record(keys, readings: [reading(keys, 90, at: t0)])],
      remotes: [], forgotten: [mouse: t0 + 60], now: t0 + 120)
    XCTAssertEqual(merged.map(\.id), [keys])
    XCTAssertEqual(merged[0].readings.count, 1)
  }

  // MARK: Combining forgets

  func testNewestForgetPerDeviceWinsAcrossMacs() {
    let combined = SyncMerge.forgotten(
      local: [mouse: t0 + 10],
      remotes: [file("B", [], forgotten: [mouse: t0 + 50, keys: t0 + 5]), file("C", [], forgotten: [mouse: t0 + 20])],
      now: t0 + 100)
    XCTAssertEqual(combined, [mouse: t0 + 50, keys: t0 + 5])
  }

  func testForgetsOlderThanRetentionAreDropped() {
    let now = t0 + SyncMerge.forgetRetention + 10
    let combined = SyncMerge.forgotten(local: [mouse: t0], remotes: [file("B", [], forgotten: [keys: now - 10])],
                                       now: now)
    XCTAssertEqual(combined, [keys: now - 10])
  }

  func testFilesFromAFutureSchemaContributeNoForgets() {
    var future = file("B", [], forgotten: [mouse: t0])
    future.schema = SyncFile.currentSchema + 1
    XCTAssertEqual(SyncMerge.forgotten(local: [:], remotes: [future], now: t0), [:])
  }

  // MARK: Purging this Mac's own records

  func testApplyForgottenRemovesTheRecordAndKeepsNewerReadings() {
    let records = [
      record(mouse, readings: [reading(mouse, 40, at: t0)]),
      record(keys, readings: [reading(keys, 90, at: t0), reading(keys, 88, at: t0 + 600)]),
    ]
    let purged = SyncMerge.applyForgotten([mouse: t0 + 60, keys: t0 + 60], to: records)
    XCTAssertEqual(purged.map(\.id), [keys])
    XCTAssertEqual(purged[0].readings.map(\.level), [.percent(88)])
  }

  // MARK: File format

  func testSyncFileEncodesForgetsKeyedByDeviceID() throws {
    let data = try JuiceJSON.encoder.encode(file("A", [], forgotten: [mouse: t0]))
    let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    let forgotten = try XCTUnwrap(json["forgotten"] as? [String: String])
    XCTAssertEqual(Array(forgotten.keys), ["sn:TESTMOUSE001"])
    XCTAssertEqual(json["schema"] as? Int, 1, "the new key is optional, so the schema stays 1 for older Macs")
  }

  func testOlderSyncFileWithoutForgetsDecodes() throws {
    let old = Data(#"{"schema":1,"macID":"A1B2C3D4","macName":"Mac","updatedAt":"2027-01-15T08:00:00Z","devices":[]}"#.utf8)
    let decoded = try JuiceJSON.decoder.decode(SyncFile.self, from: old)
    XCTAssertNil(decoded.forgotten)
  }
}
