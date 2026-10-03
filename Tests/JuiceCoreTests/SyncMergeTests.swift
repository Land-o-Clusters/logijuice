import XCTest
@testable import JuiceCore

final class SyncMergeTests: XCTestCase {
  let t0 = Date(timeIntervalSince1970: 1_800_000_000)
  let id = DeviceID.serial("M")

  func reading(_ p: Int, at t: Date, source: ReadingSource = .local) -> Reading {
    Reading(device: id, level: .percent(p), charging: false, observedAt: t, source: source)
  }

  func record(nickname: String? = nil, meta: Date, readings: [Reading]) -> DeviceRecord {
    DeviceRecord(info: DeviceInfo(id: id, name: "MX Master 3S", kind: .mouse), nickname: nickname,
                 alertOverride: nil, metaUpdatedAt: meta, readings: readings)
  }

  func file(_ mac: String, schema: Int = 1, _ devices: [DeviceRecord]) -> SyncFile {
    SyncFile(schema: schema, macID: mac, macName: mac, updatedAt: t0, devices: devices)
  }

  func testUnionRetagsRemoteReadings() {
    let merged = SyncMerge.merge(
      local: [record(meta: t0, readings: [reading(50, at: t0)])],
      remotes: [file("B", [record(meta: t0, readings: [reading(48, at: t0 + 60)])])], now: t0 + 60)
    XCTAssertEqual(merged.count, 1)
    XCTAssertEqual(merged[0].readings.map(\.source), [.local, .synced(macID: "B")])
  }

  func testUnionDedupesSameSecond() {
    let merged = SyncMerge.merge(
      local: [record(meta: t0, readings: [reading(50, at: t0 + 0.4)])],
      remotes: [file("B", [record(meta: t0, readings: [reading(50, at: t0)])])], now: t0)
    XCTAssertEqual(merged[0].readings.count, 1)
    XCTAssertEqual(merged[0].readings[0].source, .local)
  }

  func testNewestMetadataWins() {
    let merged = SyncMerge.merge(
      local: [record(nickname: "Desk mouse", meta: t0, readings: [])],
      remotes: [file("B", [record(nickname: "Travel", meta: t0 + 10, readings: [])])], now: t0)
    XCTAssertEqual(merged[0].nickname, "Travel")
    XCTAssertEqual(merged[0].displayName, "Travel")
  }

  func testRemoteOnlyDeviceAppears() {
    let merged = SyncMerge.merge(
      local: [], remotes: [file("B", [record(meta: t0, readings: [reading(70, at: t0)])])], now: t0)
    XCTAssertEqual(merged.map(\.info.id), [id])
    XCTAssertEqual(merged[0].readings.first?.source, .synced(macID: "B"))
  }

  func testFutureSchemaIsSkipped() {
    let merged = SyncMerge.merge(
      local: [], remotes: [file("B", schema: 2, [record(meta: t0, readings: [reading(70, at: t0)])])], now: t0)
    XCTAssertTrue(merged.isEmpty)
  }

  func testThirdPartySyncedReadingsAreNotPropagated() {
    let relayed = reading(70, at: t0, source: .synced(macID: "C"))
    let merged = SyncMerge.merge(
      local: [], remotes: [file("B", [record(meta: t0, readings: [relayed])])], now: t0)
    XCTAssertEqual(merged.first?.readings ?? [], [])
  }

  func testDisplayNameFallsBackWhenNicknameEmpty() {
    XCTAssertEqual(record(nickname: "", meta: t0, readings: []).displayName, "MX Master 3S")
    XCTAssertEqual(record(nickname: nil, meta: t0, readings: []).displayName, "MX Master 3S")
  }

  func testHistoryTrimsOldAndCaps() {
    let old = reading(90, at: t0 - 91 * 86_400)
    XCTAssertEqual(History.trim([old, reading(50, at: t0)], now: t0).count, 1)
    let many = (0..<2100).map { reading(50, at: t0 + Double($0)) }
    let trimmed = History.trim(many, now: t0 + 2100)
    XCTAssertEqual(trimmed.count, 2000)
    XCTAssertEqual(trimmed.first?.observedAt, t0 + 100)
  }

  func testHistoryAppendingSkipsNearDuplicate() {
    var h = History.appending(reading(50, at: t0), to: [], now: t0)
    h = History.appending(reading(50, at: t0 + 300), to: h, now: t0 + 300)
    XCTAssertEqual(h.count, 1)
    h = History.appending(reading(49, at: t0 + 360), to: h, now: t0 + 360)
    h = History.appending(reading(49, at: t0 + 1000), to: h, now: t0 + 1000)
    XCTAssertEqual(h.map(\.level), [.percent(50), .percent(49), .percent(49)])
  }
}
