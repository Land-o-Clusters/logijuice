import XCTest
import JuiceCore
@testable import JuiceStore

final class StoreTests: XCTestCase {
  var dir: URL!
  let t0 = Date(timeIntervalSince1970: 1_800_000_000)

  override func setUpWithError() throws {
    dir = FileManager.default.temporaryDirectory.appendingPathComponent("logijuice-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

  func testSettingsMissingFileGivesDefaults() {
    XCTAssertEqual(SettingsStore(url: dir.appendingPathComponent("s.json")).load(default: Settings()), Settings())
  }

  func testSettingsRoundTrip() throws {
    let store = SettingsStore(url: dir.appendingPathComponent("nested/s.json"))
    var s = Settings()
    s.showAlertingInMenuBar = false
    try store.save(s)
    XCTAssertEqual(store.load(default: Settings()), s)
  }

  func testCorruptFileIsBackedUpAndDefaultsReturned() throws {
    let url = dir.appendingPathComponent("s.json")
    try Data("{not json".utf8).write(to: url)
    XCTAssertEqual(SettingsStore(url: url).load(default: Settings()), Settings())
    XCTAssertTrue(FileManager.default.fileExists(atPath: dir.appendingPathComponent("s.corrupt.json").path))
    XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
  }

  func testLocalStateRoundTripPreservesFiredLevels() throws {
    var state = LocalState()
    var alert = DeviceAlertState()
    alert.firedAt["veryLow"] = t0
    state.alertStates[.serial("M")] = alert
    state.records = [DeviceRecord(info: DeviceInfo(id: .serial("M"), name: "Mouse", kind: .mouse), nickname: nil,
                                  alertOverride: nil, metaUpdatedAt: t0,
                                  readings: [Reading(device: .serial("M"), level: .percent(9), charging: false, observedAt: t0)])]
    let store = StateStore(url: dir.appendingPathComponent("state.json"))
    try store.save(state)
    let loaded = store.load(default: LocalState())
    XCTAssertEqual(loaded, state)
    XCTAssertEqual(loaded.alertStates[.serial("M")]?.firedAt["veryLow"], t0)
  }

  func testSnapshotReadReturnsNilWhenMissing() {
    XCTAssertNil(SnapshotStore(url: dir.appendingPathComponent("none.json")).read())
  }

  func testSyncWritesOwnAndReadsOthers() throws {
    let folder = dir.appendingPathComponent("logijuice")
    let mine = SyncStore(folder: folder, macID: "MAC-A")
    let theirs = SyncStore(folder: folder, macID: "MAC-B")
    try mine.writeOwn(SyncFile(macID: "MAC-A", macName: "A", updatedAt: t0, devices: []))
    try theirs.writeOwn(SyncFile(macID: "MAC-B", macName: "B", updatedAt: t0, devices: []))
    try Data("garbage".utf8).write(to: folder.appendingPathComponent("MAC-C.json"))
    try Data().write(to: folder.appendingPathComponent(".MAC-D.json.icloud"))
    XCTAssertEqual(mine.readOthers().map(\.macID), ["MAC-B"])
    XCTAssertEqual(theirs.readOthers().map(\.macID), ["MAC-A"])
  }

  func testSyncAvailabilityFollowsParentFolder() {
    XCTAssertTrue(SyncStore(folder: dir.appendingPathComponent("logijuice"), macID: "A").isAvailable)
    XCTAssertFalse(SyncStore(folder: dir.appendingPathComponent("missing/logijuice"), macID: "A").isAvailable)
  }

  func testStandardPaths() {
    let p = JuicePaths.standard()
    XCTAssertTrue(p.settingsURL.path.hasSuffix("Library/Application Support/logijuice/settings.json"))
    XCTAssertTrue(p.cliSnapshotURL.path.hasSuffix("Library/Application Support/logijuice/snapshot.json"))
    XCTAssertTrue(p.snapshotURL.path.contains(JuicePaths.appGroupID))
    XCTAssertTrue(p.iCloudFolder.path.hasSuffix("Mobile Documents/com~apple~CloudDocs/logijuice"))
  }

  func testMacIdentityIsStable() {
    XCTAssertFalse(MacIdentity.hardwareUUID().isEmpty)
    XCTAssertEqual(MacIdentity.hardwareUUID(), MacIdentity.hardwareUUID())
  }
}
