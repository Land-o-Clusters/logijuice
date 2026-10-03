# logijuice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build LogiJuice, a macOS menu bar app, widget and command-line tool that shows battery levels and sends reliable low-battery alerts for Logitech devices connected through a Logi Bolt (or Unifying) receiver.

**Architecture:** One Swift package. The pure logic (`JuiceCore`) is unit-tested without hardware. A HID++ 2.0 layer (`JuiceHID`) talks to the receiver through `IOHIDManager`, and a persistence layer (`JuiceStore`) writes JSON files. One menu-bar-only app ties them together and publishes a snapshot file that the WidgetKit extension and the CLI read. Cross-Mac sync works through one JSON file per Mac in iCloud Drive.

**Tech Stack:** Swift 5.10 language mode (Swift 6.4 toolchain), SwiftPM, SwiftUI, AppKit, IOKit HID, WidgetKit, UserNotifications, ServiceManagement, AppIntents, XCTest. No third-party dependencies.

**Spec:** `docs/superpowers/specs/2026-10-03-logijuice-design.md` (read it first; this plan argues from it)

## Global Constraints

- macOS 14.0 minimum (`platforms: [.macOS(.v14)]`, `LSMinimumSystemVersion` 14.0).
- `// swift-tools-version: 5.10`. No third-party packages.
- Every `swift` and `xcrun` command runs with `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`. The owner's `xcode-select` points at the Command Line Tools, which can't build XCTest, WidgetKit or the asset tools.
- Bundle ID `com.penguinspecz.logijuice`. Widget `com.penguinspecz.logijuice.widget`. App group `group.com.penguinspecz.logijuice`. Logger subsystem `com.penguinspecz.logijuice`.
- App display name **LogiJuice**. Repo and CLI command **logijuice**.
- **Read-only toward hardware.** Only send HID++ *getter* functions (root getFeature/ping, 0x0003 fn0/fn2, 0x0005 fn0/fn1/fn2, 0x1004 fn0/fn1, 0x1000 fn0). Never write a register or a device setting.
- Open HID devices **non-exclusively** (`kIOHIDOptionsTypeNone`). Every request uses software ID `0x0A` (unless Task 0 shows Options+ uses it).
- No telemetry and no network traffic. The only data leaving the Mac is the owner's own iCloud Drive file.
- Ad-hoc signing (`codesign --sign -`) by default. `SIGNING_IDENTITY` env var switches to Developer ID signing later.
- README carries: "logijuice is unofficial and not affiliated with or endorsed by Logitech."
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` when an agent commits.

## Spec adjustments made while planning (owner should confirm)

1. **Device discovery** probes slots 1–6 and listens for connection notifications instead of reading Bolt pairing registers. Bolt's register layout is unverified and not needed: a sleeping device simply appears when it first wakes, and history keeps it after that.
2. **Device identity** order is serial number, then the 0x0003 unit ID (unique per device), then `wpid:0000:slot:N`.
3. **Word-only batteries** map to an equivalent percent (critical 5, low 10, good 50, full 100) and go through the normal percent triggers. With default thresholds that gives exactly the spec's mapping, and it also respects custom thresholds.
4. **Nicknames and per-device alert overrides** live on the synced `DeviceRecord`, not in `Settings`, so they propagate across Macs with newest-wins.
5. **Sync reading** polls the folder every 2 minutes and asks iCloud to download `.icloud` placeholders. `NSMetadataQuery` on iCloud Drive requires the iCloud entitlement we don't have.
6. **Settings window** is an AppKit `NSWindow` hosting SwiftUI. On macOS 14 and later, a SwiftUI `Settings` scene can't be opened from an AppDelegate or a notification tap.
7. **CLI product** is `logijuice-cli`, installed in the bundle as `logijuice`. APFS is case-insensitive, so a `logijuice` binary would collide with `LogiJuice` in `.build`.
8. **Snapshot copy for the CLI** goes to `~/Library/Application Support/logijuice/snapshot.json`. The CLI reads it there to avoid macOS 15's "access data from other apps" prompt on group containers.
9. **Shortcuts actions** (Task 18) may be dropped if SwiftPM builds can't produce App Intents metadata. The task says how to check.

## Review Focus

1. **Hub switched away mid-request.** The receiver vanishes while a request is waiting. The request must fail promptly with `.closed`, with no hang or crash, and the app must show "not connected here". Test: Task 11 `testCloseFailsPendingRequest`.
2. **Nonsense battery values from a device.** A state of charge of 0 or over 100, or an error status byte, must never produce a fake "0%" alert. Fall back to the level word, or drop the reading. Tests: Task 10 `testUnifiedRejectsOutOfRangePercent`, `testBatteryStatusRejectsErrorStatus`.
3. **Out-of-order or duplicate readings.** Synced readings arrive late and clocks change, but the forecast and the merge must give the same answer regardless of input order. Tests: Task 5 `testUnsortedInputGivesSameForecast`, Task 6 `testUnionDedupesSameSecond`.
4. **Relaunch after an alert already fired.** A login item restart or a crash must not re-fire alerts that already went out. Test: Task 8 `testLocalStateRoundTripPreservesFiredLevels`.
5. **Fresh install with no data.** The CLI says "No data yet" (exit 1). Auto mode hides the menu bar icon when there are no devices. An empty nickname shows the hardware name. Tests: Task 9 `testStatusWithoutSnapshotFails`, Task 7 `testAutoHiddenWithNoDevices`, `testEmptyNicknameFallsBackToName`.

## Task map and Codex handoff labels

| # | Task | Label | Depends on |
|---|---|---|---|
| 0 | HID++ bring-up spike (throwaway) | **Mac + hardware** | — |
| 1 | Package scaffold and core models | Codex-ready | — |
| 2 | Alert profile and settings | Codex-ready | 1 |
| 3 | Alert engine | Codex-ready | 2 |
| 4 | Nudge scheduler | Codex-ready | 3 |
| 5 | Forecaster | Codex-ready | 1 |
| 6 | History and sync merge | Codex-ready | 2 |
| 7 | Snapshot, formatting, menu bar policy | Codex-ready | 3, 4, 5, 6 |
| 8 | JuiceStore persistence | Codex-ready | 7 |
| 9 | CLI `status` / `devices` | Codex-ready | 8 |
| 10 | HID++ frames and feature parsers | Codex-ready | 1 (+ Task 0 notes if available) |
| 11 | Request broker | Codex-ready | 10 |
| 12 | Receiver session | Codex-ready | 11 |
| 13 | IOHID channel, receiver monitor, `debug capture`, real fixtures | **Mac + hardware** | 0, 9, 12 |
| 14 | App shell: model, HID wiring, notifications, moments, menu bar, build script | **Mac + hardware** | 8, 13 |
| 15 | iCloud Drive sync wiring | **Mac** | 14 |
| 16 | Settings window | Codex-ready (visual check on Mac) | 15 |
| 17 | Widget extension | Codex-ready (verify on Mac) | 14 |
| 18 | Shortcuts actions | **Mac** | 14 |
| 19 | README, cask, manual checklist run | Codex (docs) + **Mac** (checklist) | all |

Two independent tracks can run in parallel after Task 1: **Core** (2→3→4, 5, 6 → 7 → 8 → 9) and **HID** (10 → 11 → 12). If both tracks edit `Package.swift` at once, merge the target lists; every task shows the full file for its own track.

---

### Task 0: HID++ bring-up spike (throwaway, Mac + hardware)

Answers spec §3's unknowns on the owner's real receiver before any `JuiceHID` code is trusted. The output is `docs/bringup-notes.md`. The probe script is deleted afterwards.

**Files:**
- Create: `spikes/hidpp-probe.swift` (deleted in Step 6)
- Create: `docs/bringup-notes.md`

- [ ] **Step 1: Write the probe**

```swift
// spikes/hidpp-probe.swift — THROWAWAY. Run: swift spikes/hidpp-probe.swift
import Foundation
import IOKit.hid

func hex(_ b: [UInt8]) -> String { b.map { String(format: "%02X", $0) }.joined(separator: " ") }
func prop(_ d: IOHIDDevice, _ k: String) -> Int { (IOHIDDeviceGetProperty(d, k as CFString) as? Int) ?? -1 }

let start = Date()
let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
IOHIDManagerSetDeviceMatching(manager, [kIOHIDVendorIDKey: 0x046D] as CFDictionary)
let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
print("IOHIDManagerOpen ->", String(format: "0x%08X", openResult))
let all = (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>) ?? []
for d in all {
  print(String(format: "PID 0x%04X page 0x%04X usage 0x%04X location 0x%08X maxIn %d maxOut %d %@",
               prop(d, kIOHIDProductIDKey), prop(d, kIOHIDPrimaryUsagePageKey), prop(d, kIOHIDPrimaryUsageKey),
               prop(d, kIOHIDLocationIDKey), prop(d, kIOHIDMaxInputReportSizeKey), prop(d, kIOHIDMaxOutputReportSizeKey),
               (IOHIDDeviceGetProperty(d, kIOHIDProductKey as CFString) as? String) ?? "?"))
}
let vendor = all.filter { prop($0, kIOHIDPrimaryUsagePageKey) == 0xFF00 && [0xC548, 0xC52B, 0xC532].contains(prop($0, kIOHIDProductIDKey)) }
guard !vendor.isEmpty else { print("No receiver HID++ interface found"); exit(1) }

var buffers: [UnsafeMutablePointer<UInt8>] = []
for d in vendor {
  print("open usage", String(format: "0x%04X", prop(d, kIOHIDPrimaryUsageKey)), "->",
        String(format: "0x%08X", IOHIDDeviceOpen(d, IOOptionBits(kIOHIDOptionsTypeNone))))
  let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: 64); buffers.append(buf)
  IOHIDDeviceRegisterInputReportCallback(d, buf, 64, { _, _, _, _, reportID, report, length in
    let bytes = Array(UnsafeBufferPointer(start: report, count: length))
    print(String(format: "IN  +%.3fs id=0x%02X ", Date().timeIntervalSince(start), reportID) + hex(bytes))
  }, nil)
  IOHIDDeviceScheduleWithRunLoop(d, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
}

func send(_ bytes: [UInt8]) {
  let wantUsage = bytes[0] == 0x10 ? 0x0001 : 0x0002
  let target = vendor.first { prop($0, kIOHIDPrimaryUsageKey) == wantUsage } ?? vendor[0]
  let r = IOHIDDeviceSetReport(target, kIOHIDReportTypeOutput, CFIndex(bytes[0]), bytes, bytes.count)
  print(String(format: "OUT +%.3fs r=0x%08X ", Date().timeIntervalSince(start), r) + hex(bytes))
}
func long(_ dev: UInt8, _ fi: UInt8, _ fn: UInt8, _ params: [UInt8]) -> [UInt8] {
  Array(([0x11, dev, fi, (fn << 4) | 0x0A] + params + Array(repeating: 0, count: 16)).prefix(20))
}
func pump(_ s: Double) { RunLoop.main.run(until: Date().addingTimeInterval(s)) }

// Receiver notification flags register 0x00 (HID++ 1.0 short read) — READ ONLY.
send([0x10, 0xFF, 0x81, 0x00, 0x00, 0x00, 0x00]); pump(0.5)
for slot: UInt8 in 1...6 {
  send(long(slot, 0x00, 0x1, [0x00, 0x00, 0x5A])); pump(0.4)            // ping / protocol version
  for feature: UInt16 in [0x0003, 0x0005, 0x1000, 0x1004] {             // getFeature
    send(long(slot, 0x00, 0x0, [UInt8(feature >> 8), UInt8(feature & 0xFF)])); pump(0.3)
  }
}
print("\n--- Passive listen 60 s: switch a device off/on, plug/unplug its charge cable, use Options+ ---")
pump(60)
```

- [ ] **Step 2: Run it with Logi Options+ running**

Run: `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer && swift spikes/hidpp-probe.swift | tee /tmp/logijuice-probe-optionsplus.txt`
Expected: the device list includes PID `0xC548` with page `0xFF00`. Some `IN` lines echo our requests with the low nibble `A` in byte 3. During the 60 s listen, power-cycle the mouse and plug in its charging cable.

- [ ] **Step 3: For each slot that answered, send the battery read using the index it reported**

Edit the bottom of the probe to add, for the slot and index you saw (example: slot 1, 0x1004 at index 0x08):
```swift
send(long(1, 0x08, 0x0, [])); pump(0.4)   // 0x1004 getCapabilities
send(long(1, 0x08, 0x1, [])); pump(0.4)   // 0x1004 getStatus
```
If 0x1004 isn't present, use the 0x1000 index with function 0 instead. Run again.

- [ ] **Step 4: Run once with Options+ quit**

Quit Logi Options+ (menu bar → Quit, and `killall logioptionsplus_agent 2>/dev/null`). Run again into `/tmp/logijuice-probe-plain.txt`. Then reopen Options+.

- [ ] **Step 5: Write `docs/bringup-notes.md` answering every question with evidence lines**

```markdown
# HID++ bring-up notes (Task 0)

| Question | Answer | Evidence (log line) |
|---|---|---|
| Receiver PID / product string | | |
| HID++ interfaces (usage page / usage / location) — one collection or separate short (0x0001) + long (0x0002)? | | |
| Does `IN` data include the report ID as byte 0? | | |
| Did IOHIDManagerOpen/IOHIDDeviceOpen trigger an Input Monitoring prompt or return non-zero? | | |
| Notification flags register 0x00 value (are wireless notifications already enabled?) | | |
| Software IDs seen in Options+ traffic (low nibble of byte 3 on non-zero-sw replies) | | |
| Slots that answered ping; protocol version | | |
| Feature indices per slot: 0x0003, 0x0005, 0x1000, 0x1004 | | |
| 0x1004 capabilities bytes; percentage supported (byte 1 bit 0x02)? | | |
| 0x1004 status bytes: state of charge / level mask / charging status | | |
| Percentage granularity (1%, 5%, 10% steps?) | | |
| Battery event observed (sw nibble 0) when plugging the cable? bytes | | |
| Connection notification (0x41) observed on power-cycle? bytes; which byte is flags; wpid | | |
| Asleep device behavior: error reply (which code) or silence? | | |

## Decisions
- Software ID for logijuice: `0x0A` unless it collides with Options+ (then pick an unused nibble).
- `HIDPPInterface.usage` constant for long reports: `0x0002` / other: ___
```

- [ ] **Step 6: Delete the probe and commit the notes**

```bash
git rm -q --cached spikes/hidpp-probe.swift 2>/dev/null; rm -rf spikes
git add docs/bringup-notes.md
git commit -m "Record HID++ bring-up findings for the Bolt receiver"
```

**If a finding contradicts this plan** (for example, the report ID is not byte 0, or no 0x41 notifications arrive unless a register is written), stop and raise it with the owner before Tasks 10–13. Writing receiver registers would break the read-only constraint.

---

### Task 1: Package scaffold and core models (Codex-ready)

**Files:**
- Create: `Package.swift`, `.gitignore`, `LICENSE`
- Create: `Sources/JuiceCore/Models.swift`, `Sources/JuiceCore/JuiceJSON.swift`
- Test: `Tests/JuiceCoreTests/ModelsTests.swift`

**Interfaces:**
- Produces: `DeviceID` (`.serial(_:)`, `.unit(_:)`, `.slot(wpid:slot:)`, `rawValue`), `DeviceKind` (`init(hidppType:)`), `LevelWord`, `BatteryLevel` (`.percent(Int)`, `.word(LevelWord)`, `equivalentPercent`, `isFull`), `ReadingSource` (`.local`, `.synced(macID:)`), `Reading(device:level:charging:observedAt:source:)`, `DeviceInfo(id:name:kind:)`, `ForecastResult` (`.learning`, `.estimate(daysLeft:emptyAt:)`, `.unavailable`), `JuiceJSON.encoder/.prettyEncoder/.decoder`.

- [ ] **Step 1: Create the package files**

`Package.swift`:
```swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
  name: "LogiJuice",
  platforms: [.macOS(.v14)],
  targets: [
    .target(name: "JuiceCore"),
    .testTarget(name: "JuiceCoreTests", dependencies: ["JuiceCore"]),
  ]
)
```

`.gitignore`:
```
.build/
.swiftpm/
dist/
*.xcuserdata
.DS_Store
```

`LICENSE`: the MIT License text with the line `Copyright (c) 2026 penguinspecz` (same as `~/Projects/puddle/LICENSE`):
```bash
cp ~/Projects/puddle/LICENSE LICENSE
```

- [ ] **Step 2: Write the failing test**

`Tests/JuiceCoreTests/ModelsTests.swift`:
```swift
import XCTest
@testable import JuiceCore

final class ModelsTests: XCTestCase {
  let t0 = Date(timeIntervalSince1970: 1_800_000_000)

  func testReadingRoundTripsThroughJSON() throws {
    let r = Reading(device: .serial("ABC"), level: .percent(42), charging: false, observedAt: t0,
                    source: .synced(macID: "MAC-1"))
    let data = try JuiceJSON.encoder.encode(r)
    let json = String(decoding: data, as: UTF8.self)
    XCTAssertTrue(json.contains("\"device\":\"sn:ABC\""), json)
    XCTAssertTrue(json.contains("\"source\":\"synced:MAC-1\""), json)
    XCTAssertTrue(json.contains("\"level\":{\"percent\":42}"), json)
    XCTAssertEqual(try JuiceJSON.decoder.decode(Reading.self, from: data), r)
  }

  func testWordLevelAndLocalSourceRoundTrip() throws {
    let r = Reading(device: .unit("DEADBEEF"), level: .word(.low), charging: true, observedAt: t0)
    let data = try JuiceJSON.encoder.encode(r)
    XCTAssertTrue(String(decoding: data, as: UTF8.self).contains("\"source\":\"local\""))
    XCTAssertEqual(try JuiceJSON.decoder.decode(Reading.self, from: data), r)
  }

  func testEquivalentPercentAndFull() {
    XCTAssertEqual(BatteryLevel.word(.critical).equivalentPercent, 5)
    XCTAssertEqual(BatteryLevel.word(.low).equivalentPercent, 10)
    XCTAssertEqual(BatteryLevel.word(.good).equivalentPercent, 50)
    XCTAssertEqual(BatteryLevel.word(.full).equivalentPercent, 100)
    XCTAssertEqual(BatteryLevel.percent(37).equivalentPercent, 37)
    XCTAssertTrue(BatteryLevel.percent(100).isFull)
    XCTAssertTrue(BatteryLevel.word(.full).isFull)
    XCTAssertFalse(BatteryLevel.percent(99).isFull)
  }

  func testDeviceKindFromHIDPPType() {
    XCTAssertEqual(DeviceKind(hidppType: 0), .keyboard)
    XCTAssertEqual(DeviceKind(hidppType: 2), .numpad)
    XCTAssertEqual(DeviceKind(hidppType: 3), .mouse)
    XCTAssertEqual(DeviceKind(hidppType: 4), .touchpad)
    XCTAssertEqual(DeviceKind(hidppType: 5), .trackball)
    XCTAssertEqual(DeviceKind(hidppType: 6), .presenter)
    XCTAssertEqual(DeviceKind(hidppType: 7), .other)
  }

  func testDeviceIDFactoriesAndDictionaryKeys() throws {
    XCTAssertEqual(DeviceID.slot(wpid: 0x408A, slot: 2).rawValue, "wpid:408A:slot:2")
    let dict: [DeviceID: Int] = [.serial("A"): 1]
    let json = String(decoding: try JuiceJSON.encoder.encode(dict), as: UTF8.self)
    XCTAssertEqual(json, "{\"sn:A\":1}")
    XCTAssertEqual(try JuiceJSON.decoder.decode([DeviceID: Int].self, from: Data(json.utf8)), dict)
  }

  func testForecastResultRoundTrips() throws {
    for f in [ForecastResult.learning, .unavailable, .estimate(daysLeft: 9.5, emptyAt: t0)] {
      XCTAssertEqual(try JuiceJSON.decoder.decode(ForecastResult.self, from: JuiceJSON.encoder.encode(f)), f)
    }
  }
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer && swift test --filter JuiceCoreTests.ModelsTests`
Expected: FAIL to compile with "cannot find 'Reading' in scope".

- [ ] **Step 4: Implement**

`Sources/JuiceCore/JuiceJSON.swift`:
```swift
import Foundation

/// One JSON configuration for every file logijuice writes (settings, state, snapshot, sync).
public enum JuiceJSON {
  public static var encoder: JSONEncoder {
    let e = JSONEncoder()
    e.dateEncodingStrategy = .iso8601
    e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return e
  }

  public static var prettyEncoder: JSONEncoder {
    let e = encoder
    e.outputFormatting = [.sortedKeys, .withoutEscapingSlashes, .prettyPrinted]
    return e
  }

  public static var decoder: JSONDecoder {
    let d = JSONDecoder()
    d.dateDecodingStrategy = .iso8601
    return d
  }
}
```

`Sources/JuiceCore/Models.swift`:
```swift
import Foundation

/// Stable identity of one physical device across receivers, slots and Macs (spec §6).
public struct DeviceID: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
  public let rawValue: String
  public init(_ rawValue: String) { self.rawValue = rawValue }

  public static func serial(_ serial: String) -> DeviceID { DeviceID("sn:\(serial)") }
  public static func unit(_ unitID: String) -> DeviceID { DeviceID("unit:\(unitID)") }
  public static func slot(wpid: UInt16, slot: UInt8) -> DeviceID {
    DeviceID(String(format: "wpid:%04X:slot:%d", wpid, slot))
  }

  public var description: String { rawValue }
  public static func < (a: DeviceID, b: DeviceID) -> Bool { a.rawValue < b.rawValue }

  public init(from decoder: Decoder) throws {
    rawValue = try decoder.singleValueContainer().decode(String.self)
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.singleValueContainer()
    try c.encode(rawValue)
  }
}

extension DeviceID: CodingKeyRepresentable {
  private struct Key: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
  }

  public var codingKey: CodingKey { Key(stringValue: rawValue) }
  public init?<T: CodingKey>(codingKey: T) { self.init(codingKey.stringValue) }
}

public enum DeviceKind: String, Codable, Sendable, CaseIterable {
  case keyboard, mouse, trackball, touchpad, numpad, presenter, other

  /// Maps the HID++ feature 0x0005 getDeviceType value.
  public init(hidppType: UInt8) {
    switch hidppType {
    case 0: self = .keyboard
    case 2: self = .numpad
    case 3: self = .mouse
    case 4: self = .touchpad
    case 5: self = .trackball
    case 6: self = .presenter
    default: self = .other
    }
  }
}

public enum LevelWord: String, Codable, Sendable {
  case critical, low, good, full

  /// Percent used when a word-only reading is compared with percent triggers (spec §4).
  public var equivalentPercent: Int {
    switch self {
    case .critical: return 5
    case .low: return 10
    case .good: return 50
    case .full: return 100
    }
  }
}

public enum BatteryLevel: Hashable, Sendable, Codable {
  case percent(Int)
  case word(LevelWord)

  public var equivalentPercent: Int {
    switch self {
    case .percent(let p): return p
    case .word(let w): return w.equivalentPercent
    }
  }

  public var isFull: Bool {
    switch self {
    case .percent(let p): return p >= 100
    case .word(let w): return w == .full
    }
  }

  private enum CodingKeys: String, CodingKey { case percent, word }

  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    if let p = try c.decodeIfPresent(Int.self, forKey: .percent) {
      self = .percent(p)
    } else {
      self = .word(try c.decode(LevelWord.self, forKey: .word))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .percent(let p): try c.encode(p, forKey: .percent)
    case .word(let w): try c.encode(w, forKey: .word)
    }
  }
}

/// Where a reading came from. Only `.local` readings may fire alerts (spec §4).
public enum ReadingSource: Hashable, Sendable, Codable {
  case local
  case synced(macID: String)

  public init(from decoder: Decoder) throws {
    let raw = try decoder.singleValueContainer().decode(String.self)
    if raw == "local" {
      self = .local
    } else if raw.hasPrefix("synced:") {
      self = .synced(macID: String(raw.dropFirst("synced:".count)))
    } else {
      throw DecodingError.dataCorrupted(
        .init(codingPath: decoder.codingPath, debugDescription: "Unknown reading source \(raw)"))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var c = encoder.singleValueContainer()
    switch self {
    case .local: try c.encode("local")
    case .synced(let macID): try c.encode("synced:\(macID)")
    }
  }
}

public struct Reading: Hashable, Sendable, Codable {
  public var device: DeviceID
  public var level: BatteryLevel
  public var charging: Bool
  public var observedAt: Date
  public var source: ReadingSource

  public init(device: DeviceID, level: BatteryLevel, charging: Bool, observedAt: Date,
              source: ReadingSource = .local) {
    self.device = device
    self.level = level
    self.charging = charging
    self.observedAt = observedAt
    self.source = source
  }
}

public struct DeviceInfo: Hashable, Sendable, Codable {
  public var id: DeviceID
  public var name: String
  public var kind: DeviceKind

  public init(id: DeviceID, name: String, kind: DeviceKind) {
    self.id = id
    self.name = name
    self.kind = kind
  }
}

public enum ForecastResult: Hashable, Sendable, Codable {
  case learning
  case estimate(daysLeft: Double, emptyAt: Date)
  case unavailable
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `swift test --filter JuiceCoreTests.ModelsTests`
Expected: PASS (6 tests).

- [ ] **Step 6: Commit**

```bash
git add Package.swift .gitignore LICENSE Sources Tests
git commit -m "Scaffold package and core models"
```

---

### Task 2: Alert profile and settings (Codex-ready)

**Files:**
- Create: `Sources/JuiceCore/AlertProfile.swift`, `Sources/JuiceCore/Settings.swift`
- Test: `Tests/JuiceCoreTests/AlertProfileTests.swift`

**Interfaces:**
- Consumes: `Reading`, `BatteryLevel.equivalentPercent`, `ForecastResult` (Task 1).
- Produces: `Trigger` (`.percentAtOrBelow(Int)`, `.forecastDaysAtOrBelow(Double)`), `Timing` (`.now`, `.nextMoment`), `RepeatPolicy` (`.never`, `.everyHours(Int)`, `.daily`, `interval: TimeInterval?`), `AlertLevel(id:name:enabled:trigger:timing:repeatPolicy:tintsIcon:)`, `AlertProfile(levels:)` with `.default` and `isTriggered(_:by:forecast:) -> Bool`, `MenuBarMode` (`.auto`, `.always`, `.never`), `Settings` (fields below; `init()` gives defaults; decodes missing keys as defaults).

- [ ] **Step 1: Write the failing test**

`Tests/JuiceCoreTests/AlertProfileTests.swift`:
```swift
import XCTest
@testable import JuiceCore

final class AlertProfileTests: XCTestCase {
  let t0 = Date(timeIntervalSince1970: 1_800_000_000)

  func reading(_ level: BatteryLevel) -> Reading {
    Reading(device: .serial("M"), level: level, charging: false, observedAt: t0)
  }

  func testDefaultProfileMatchesSpec() {
    let p = AlertProfile.default
    XCTAssertEqual(p.levels.map(\.id), ["low", "veryLow", "critical"])
    XCTAssertEqual(p.levels.map(\.name), ["Low", "Very low", "Critical"])
    XCTAssertEqual(p.levels.map(\.trigger), [.percentAtOrBelow(20), .percentAtOrBelow(10), .percentAtOrBelow(5)])
    XCTAssertEqual(p.levels.map(\.timing), [.nextMoment, .now, .now])
    XCTAssertEqual(p.levels.map(\.repeatPolicy), [.never, .never, .daily])
    XCTAssertEqual(p.levels.map(\.tintsIcon), [false, true, true])
    XCTAssertTrue(p.levels.allSatisfy(\.enabled))
  }

  func testPercentTrigger() {
    let low = AlertProfile.default.levels[0]
    XCTAssertTrue(AlertProfile.default.isTriggered(low, by: reading(.percent(20)), forecast: .learning))
    XCTAssertFalse(AlertProfile.default.isTriggered(low, by: reading(.percent(21)), forecast: .learning))
    XCTAssertTrue(AlertProfile.default.isTriggered(low, by: reading(.word(.low)), forecast: .learning))
    XCTAssertFalse(AlertProfile.default.isTriggered(low, by: reading(.word(.good)), forecast: .learning))
  }

  func testForecastTriggerOnlyWithEstimate() {
    var level = AlertProfile.default.levels[0]
    level.trigger = .forecastDaysAtOrBelow(3)
    let p = AlertProfile(levels: [level])
    XCTAssertTrue(p.isTriggered(level, by: reading(.percent(60)), forecast: .estimate(daysLeft: 2.5, emptyAt: t0)))
    XCTAssertFalse(p.isTriggered(level, by: reading(.percent(60)), forecast: .estimate(daysLeft: 3.5, emptyAt: t0)))
    XCTAssertFalse(p.isTriggered(level, by: reading(.percent(1)), forecast: .learning))
  }

  func testRepeatIntervals() {
    XCTAssertNil(RepeatPolicy.never.interval)
    XCTAssertEqual(RepeatPolicy.everyHours(4).interval, 4 * 3600)
    XCTAssertEqual(RepeatPolicy.everyHours(0).interval, 3600)
    XCTAssertEqual(RepeatPolicy.daily.interval, 86_400)
  }

  func testSettingsDefaults() {
    let s = Settings()
    XCTAssertEqual(s.profile, .default)
    XCTAssertEqual(s.menuBarMode, .auto)
    XCTAssertTrue(s.fullyChargedEnabled)
    XCTAssertEqual(s.endOfDayHour, 17)
    XCTAssertEqual(s.endOfDayMinute, 30)
    XCTAssertEqual(s.maxWaitHours, 8)
    XCTAssertTrue(s.syncEnabled)
  }

  func testSettingsRoundTripAndMissingKeysUseDefaults() throws {
    var s = Settings()
    s.menuBarMode = .always
    s.maxWaitHours = 3
    XCTAssertEqual(try JuiceJSON.decoder.decode(Settings.self, from: JuiceJSON.encoder.encode(s)), s)
    let partial = try JuiceJSON.decoder.decode(Settings.self, from: Data("{\"maxWaitHours\":2}".utf8))
    XCTAssertEqual(partial.maxWaitHours, 2)
    XCTAssertEqual(partial.profile, .default)
    XCTAssertEqual(partial.menuBarMode, .auto)
  }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter JuiceCoreTests.AlertProfileTests`
Expected: FAIL to compile with "cannot find 'AlertProfile' in scope".

- [ ] **Step 3: Implement**

`Sources/JuiceCore/AlertProfile.swift`:
```swift
import Foundation

public enum Trigger: Hashable, Sendable, Codable {
  case percentAtOrBelow(Int)
  /// Only evaluated when the forecast is a confident estimate.
  case forecastDaysAtOrBelow(Double)
}

public enum Timing: String, Hashable, Sendable, Codable {
  case now
  case nextMoment
}

public enum RepeatPolicy: Hashable, Sendable, Codable {
  case never
  case everyHours(Int)
  case daily

  public var interval: TimeInterval? {
    switch self {
    case .never: return nil
    case .everyHours(let hours): return TimeInterval(max(1, hours)) * 3600
    case .daily: return 86_400
    }
  }
}

public struct AlertLevel: Hashable, Sendable, Codable, Identifiable {
  public var id: String
  public var name: String
  public var enabled: Bool
  public var trigger: Trigger
  public var timing: Timing
  public var repeatPolicy: RepeatPolicy
  public var tintsIcon: Bool

  public init(id: String, name: String, enabled: Bool, trigger: Trigger, timing: Timing,
              repeatPolicy: RepeatPolicy, tintsIcon: Bool) {
    self.id = id
    self.name = name
    self.enabled = enabled
    self.trigger = trigger
    self.timing = timing
    self.repeatPolicy = repeatPolicy
    self.tintsIcon = tintsIcon
  }
}

public struct AlertProfile: Hashable, Sendable, Codable {
  /// Ordered least severe → most severe. A level's index is its severity.
  public var levels: [AlertLevel]

  public init(levels: [AlertLevel]) { self.levels = levels }

  public static let `default` = AlertProfile(levels: [
    AlertLevel(id: "low", name: "Low", enabled: true, trigger: .percentAtOrBelow(20),
               timing: .nextMoment, repeatPolicy: .never, tintsIcon: false),
    AlertLevel(id: "veryLow", name: "Very low", enabled: true, trigger: .percentAtOrBelow(10),
               timing: .now, repeatPolicy: .never, tintsIcon: true),
    AlertLevel(id: "critical", name: "Critical", enabled: true, trigger: .percentAtOrBelow(5),
               timing: .now, repeatPolicy: .daily, tintsIcon: true),
  ])

  public func isTriggered(_ level: AlertLevel, by reading: Reading, forecast: ForecastResult) -> Bool {
    switch level.trigger {
    case .percentAtOrBelow(let threshold):
      return reading.level.equivalentPercent <= threshold
    case .forecastDaysAtOrBelow(let days):
      if case .estimate(let left, _) = forecast { return left <= days }
      return false
    }
  }
}
```

`Sources/JuiceCore/Settings.swift`:
```swift
import Foundation

public enum MenuBarMode: String, Hashable, Sendable, Codable, CaseIterable {
  case auto, always, never
}

/// Mac-local preferences. Per-device nickname and alert overrides live on `DeviceRecord` (synced).
public struct Settings: Hashable, Sendable, Codable {
  public var profile: AlertProfile = .default
  public var menuBarMode: MenuBarMode = .auto
  public var fullyChargedEnabled = true
  public var endOfDayHour = 17
  public var endOfDayMinute = 30
  public var maxWaitHours = 8
  public var syncEnabled = true

  public init() {}

  private enum CodingKeys: String, CodingKey {
    case profile, menuBarMode, fullyChargedEnabled, endOfDayHour, endOfDayMinute, maxWaitHours,
      syncEnabled
  }

  /// Missing keys fall back to defaults so older settings files keep loading after upgrades.
  public init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    let d = Settings()
    profile = try c.decodeIfPresent(AlertProfile.self, forKey: .profile) ?? d.profile
    menuBarMode = try c.decodeIfPresent(MenuBarMode.self, forKey: .menuBarMode) ?? d.menuBarMode
    fullyChargedEnabled =
      try c.decodeIfPresent(Bool.self, forKey: .fullyChargedEnabled) ?? d.fullyChargedEnabled
    endOfDayHour = try c.decodeIfPresent(Int.self, forKey: .endOfDayHour) ?? d.endOfDayHour
    endOfDayMinute = try c.decodeIfPresent(Int.self, forKey: .endOfDayMinute) ?? d.endOfDayMinute
    maxWaitHours = try c.decodeIfPresent(Int.self, forKey: .maxWaitHours) ?? d.maxWaitHours
    syncEnabled = try c.decodeIfPresent(Bool.self, forKey: .syncEnabled) ?? d.syncEnabled
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter JuiceCoreTests.AlertProfileTests`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/JuiceCore Tests/JuiceCoreTests
git commit -m "Add alert profile and settings models"
```

---

### Task 3: Alert engine (Codex-ready)

**Files:**
- Create: `Sources/JuiceCore/AlertEngine.swift`
- Test: `Tests/JuiceCoreTests/AlertEngineTests.swift`

**Interfaces:**
- Consumes: `Reading`, `ForecastResult`, `AlertProfile`, `AlertLevel`, `RepeatPolicy.interval`, `Timing` (Tasks 1–2).
- Produces:
  - `DeviceAlertState` (`firedAt: [String: Date]`, `snoozedUntil: Date?`, `snoozeSeverity: Int?`, `wasCharging: Bool`, `init()`), Codable.
  - `AlertKind` (`.level(id: String, name: String, timing: Timing, severity: Int, isRepeat: Bool)`, `.fullyCharged`), Codable.
  - `AlertDecision(device:kind:reading:)`, Codable.
  - `AlertEngine.evaluate(reading:profile:forecast:fullyChargedEnabled:state:now:) -> (DeviceAlertState, [AlertDecision])`
  - `AlertEngine.snooze(_:profile:now:duration:) -> DeviceAlertState` (default duration 86 400 s)
  - `AlertEngine.rearmMargin == 5`

- [ ] **Step 1: Write the failing test**

`Tests/JuiceCoreTests/AlertEngineTests.swift`:
```swift
import XCTest
@testable import JuiceCore

final class AlertEngineTests: XCTestCase {
  let mouse = DeviceID.serial("MOUSE")
  let t0 = Date(timeIntervalSince1970: 1_800_000_000)

  func reading(_ p: Int, charging: Bool = false, at t: Date? = nil,
               source: ReadingSource = .local) -> Reading {
    Reading(device: mouse, level: .percent(p), charging: charging, observedAt: t ?? t0, source: source)
  }

  func run(_ readings: [Reading], profile: AlertProfile = .default, forecast: ForecastResult = .learning,
           fullyCharged: Bool = true, state: DeviceAlertState = DeviceAlertState())
    -> (DeviceAlertState, [[AlertDecision]])
  {
    var s = state
    var all: [[AlertDecision]] = []
    for r in readings {
      let (next, decisions) = AlertEngine.evaluate(
        reading: r, profile: profile, forecast: forecast, fullyChargedEnabled: fullyCharged,
        state: s, now: r.observedAt)
      s = next
      all.append(decisions)
    }
    return (s, all)
  }

  func levelIDs(_ ds: [AlertDecision]) -> [String] {
    ds.compactMap { if case .level(let id, _, _, _, _) = $0.kind { return id } else { return nil } }
  }

  func testAboveAllThresholdsDoesNothing() {
    let (s, out) = run([reading(25)])
    XCTAssertEqual(out, [[]])
    XCTAssertTrue(s.firedAt.isEmpty)
  }

  func testLowFiresOnceWithNextMomentTiming() {
    let (_, out) = run([reading(20), reading(19, at: t0 + 3600)])
    XCTAssertEqual(levelIDs(out[0]), ["low"])
    guard case .level(_, "Low", .nextMoment, 0, false)? = out[0].first?.kind else {
      return XCTFail("unexpected kind \(String(describing: out[0].first?.kind))")
    }
    XCTAssertEqual(out[1], [])
  }

  func testSteepDropFiresOnlyMostSevere() {
    let (s, out) = run([reading(4)])
    XCTAssertEqual(levelIDs(out[0]), ["critical"])
    XCTAssertEqual(Set(s.firedAt.keys), ["low", "veryLow", "critical"])
  }

  func testHysteresisRearmNeedsFivePointsAboveThreshold() {
    let (_, out) = run([
      reading(20), reading(24, at: t0 + 60), reading(20, at: t0 + 120),
      reading(25, at: t0 + 180), reading(20, at: t0 + 240),
    ])
    XCTAssertEqual(out.map(levelIDs), [["low"], [], [], [], ["low"]])
  }

  func testChargingRearmsAndFullyChargedFires() {
    let (_, out) = run([
      reading(9), reading(50, charging: true, at: t0 + 60), reading(100, at: t0 + 120),
      reading(20, at: t0 + 180),
    ])
    XCTAssertEqual(levelIDs(out[0]), ["veryLow"])
    XCTAssertEqual(out[1], [])
    XCTAssertEqual(out[2].map(\.kind), [.fullyCharged])
    XCTAssertEqual(levelIDs(out[3]), ["low"])
  }

  func testFullyChargedCanBeDisabled() {
    let (_, out) = run([reading(80, charging: true), reading(100, at: t0 + 60)], fullyCharged: false)
    XCTAssertEqual(out[1], [])
  }

  func testUnpluggedBeforeFullDoesNotNotify() {
    let (_, out) = run([reading(60, charging: true), reading(80, at: t0 + 60)])
    XCTAssertEqual(out[1], [])
  }

  func testCriticalRepeatsDaily() {
    let (_, out) = run([reading(5), reading(4, at: t0 + 23 * 3600), reading(4, at: t0 + 24 * 3600)])
    XCTAssertEqual(levelIDs(out[0]), ["critical"])
    XCTAssertEqual(out[1], [])
    guard case .level("critical", _, _, 2, true)? = out[2].first?.kind else {
      return XCTFail("expected a repeat of critical, got \(out[2])")
    }
  }

  func testSyncedReadingsNeverAlert() {
    let (s, out) = run([reading(3, source: .synced(macID: "OTHER"))])
    XCTAssertEqual(out, [[]])
    XCTAssertTrue(s.firedAt.isEmpty)
  }

  func testSnoozeAllowsEscalation() {
    var (s, _) = run([reading(19)])
    s = AlertEngine.snooze(s, profile: .default, now: t0)
    let (_, out) = run([reading(9, at: t0 + 3600)], state: s)
    XCTAssertEqual(levelIDs(out[0]), ["veryLow"])
  }

  func testSnoozeSuppressesRepeatsUntilItExpires() {
    var profile = AlertProfile.default
    profile.levels[2].repeatPolicy = .everyHours(4)
    var (s, _) = run([reading(5)], profile: profile)
    s = AlertEngine.snooze(s, profile: profile, now: t0)
    let (s2, out) = run([reading(5, at: t0 + 5 * 3600)], profile: profile, state: s)
    XCTAssertEqual(out, [[]])
    let (_, later) = run([reading(5, at: t0 + 25 * 3600)], profile: profile, state: s2)
    XCTAssertEqual(levelIDs(later[0]), ["critical"])
  }

  func testDisabledLevelIsSkipped() {
    var profile = AlertProfile.default
    profile.levels[0].enabled = false
    let (s1, out1) = run([reading(20)], profile: profile)
    XCTAssertEqual(out1, [[]])
    XCTAssertTrue(s1.firedAt.isEmpty)
    let (s2, out2) = run([reading(10)], profile: profile)
    XCTAssertEqual(levelIDs(out2[0]), ["veryLow"])
    XCTAssertNil(s2.firedAt["low"])
  }

  func testForecastTrigger() {
    var profile = AlertProfile.default
    profile.levels[0].trigger = .forecastDaysAtOrBelow(3)
    let (_, fires) = run([reading(60)], profile: profile, forecast: .estimate(daysLeft: 2.5, emptyAt: t0))
    XCTAssertEqual(levelIDs(fires[0]), ["low"])
    let (_, silent) = run([reading(60)], profile: profile, forecast: .learning)
    XCTAssertEqual(silent, [[]])
  }

  func testWordReadingsMapToLevels() {
    func word(_ w: LevelWord) -> [String] {
      let r = Reading(device: mouse, level: .word(w), charging: false, observedAt: t0)
      return levelIDs(run([r]).1[0])
    }
    XCTAssertEqual(word(.critical), ["critical"])
    XCTAssertEqual(word(.low), ["veryLow"])
    XCTAssertEqual(word(.good), [])
  }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter JuiceCoreTests.AlertEngineTests`
Expected: FAIL to compile with "cannot find 'DeviceAlertState' in scope".

- [ ] **Step 3: Implement**

`Sources/JuiceCore/AlertEngine.swift`:
```swift
import Foundation

public struct DeviceAlertState: Hashable, Sendable, Codable {
  /// levelID → when it last fired. A present key means the level is disarmed (spec §4).
  public var firedAt: [String: Date] = [:]
  public var snoozedUntil: Date?
  /// Severity index that was current when snoozed; only a more severe level breaks through.
  public var snoozeSeverity: Int?
  public var wasCharging = false

  public init() {}
}

public enum AlertKind: Hashable, Sendable, Codable {
  case level(id: String, name: String, timing: Timing, severity: Int, isRepeat: Bool)
  case fullyCharged
}

public struct AlertDecision: Hashable, Sendable, Codable {
  public var device: DeviceID
  public var kind: AlertKind
  public var reading: Reading

  public init(device: DeviceID, kind: AlertKind, reading: Reading) {
    self.device = device
    self.kind = kind
    self.reading = reading
  }
}

public enum AlertEngine {
  /// A percent level re-arms only after the battery rises this far above its threshold.
  public static let rearmMargin = 5

  public static func evaluate(
    reading: Reading, profile: AlertProfile, forecast: ForecastResult, fullyChargedEnabled: Bool,
    state: DeviceAlertState, now: Date
  ) -> (DeviceAlertState, [AlertDecision]) {
    guard reading.source == .local else { return (state, []) }
    var s = state
    var out: [AlertDecision] = []

    if reading.charging {
      s.firedAt = [:]
      s.snoozedUntil = nil
      s.snoozeSeverity = nil
      s.wasCharging = true
      return (s, out)
    }
    if s.wasCharging {
      s.wasCharging = false
      if fullyChargedEnabled && reading.level.isFull {
        out.append(AlertDecision(device: reading.device, kind: .fullyCharged, reading: reading))
      }
    }

    for level in profile.levels where s.firedAt[level.id] != nil {
      switch level.trigger {
      case .percentAtOrBelow(let threshold):
        if reading.level.equivalentPercent >= threshold + rearmMargin { s.firedAt[level.id] = nil }
      case .forecastDaysAtOrBelow(let days):
        if case .estimate(let left, _) = forecast, left >= days + 1 { s.firedAt[level.id] = nil }
      }
    }

    let triggered = profile.levels.indices.filter {
      profile.levels[$0].enabled && profile.isTriggered(profile.levels[$0], by: reading, forecast: forecast)
    }
    guard let top = triggered.max() else { return (s, out) }
    let level = profile.levels[top]
    let snoozeActive = s.snoozedUntil.map { now < $0 } ?? false
    let suppressed = snoozeActive && top <= (s.snoozeSeverity ?? Int.max)

    func decision(isRepeat: Bool) -> AlertDecision {
      AlertDecision(
        device: reading.device,
        kind: .level(id: level.id, name: level.name, timing: level.timing, severity: top, isRepeat: isRepeat),
        reading: reading)
    }

    if let last = s.firedAt[level.id] {
      if let interval = level.repeatPolicy.interval, now.timeIntervalSince(last) >= interval, !suppressed {
        s.firedAt[level.id] = now
        out.append(decision(isRepeat: true))
      }
    } else {
      // No cascade: crossing several levels at once fires only the most severe (spec §4).
      for i in 0...top where profile.levels[i].enabled { s.firedAt[profile.levels[i].id] = now }
      if !suppressed { out.append(decision(isRepeat: false)) }
    }
    return (s, out)
  }

  public static func snooze(_ state: DeviceAlertState, profile: AlertProfile, now: Date,
                            duration: TimeInterval = 86_400) -> DeviceAlertState {
    var s = state
    s.snoozedUntil = now.addingTimeInterval(duration)
    s.snoozeSeverity = profile.levels.indices.filter { s.firedAt[profile.levels[$0].id] != nil }.max() ?? -1
    return s
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter JuiceCoreTests.AlertEngineTests`
Expected: PASS (14 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/JuiceCore/AlertEngine.swift Tests/JuiceCoreTests/AlertEngineTests.swift
git commit -m "Add alert engine with escalation, hysteresis, repeat and snooze"
```

---

### Task 4: Nudge scheduler (Codex-ready)

**Files:**
- Create: `Sources/JuiceCore/NudgeScheduler.swift`
- Test: `Tests/JuiceCoreTests/NudgeSchedulerTests.swift`

**Interfaces:**
- Consumes: `AlertDecision`, `AlertKind`, `Timing`, `DeviceID` (Task 3).
- Produces:
  - `Moment` (`.screenLocked`, `.willSleep`, `.endOfDay`, `.receiverDeparted`, `.maxWait`)
  - `Delivery(decision:moment:)` with `moment == nil` meaning immediate
  - `NudgeScheduler(maxWait:)` (Codable, Hashable) with `maxWait`, read-only `pending`, and:
    - `schedule(_:now:) -> [Delivery]`
    - `onMoment(_:now:) -> [Delivery]`
    - `onTick(now:) -> [Delivery]`
    - `dropPending(for:)`
    - `static nextEndOfDay(after:hour:minute:calendar:) -> Date`

- [ ] **Step 1: Write the failing test**

`Tests/JuiceCoreTests/NudgeSchedulerTests.swift`:
```swift
import XCTest
@testable import JuiceCore

final class NudgeSchedulerTests: XCTestCase {
  let t0 = Date(timeIntervalSince1970: 1_800_000_000)  // 2027-01-15 08:00:00 UTC

  func decision(_ id: String, _ timing: Timing, device: String = "A") -> AlertDecision {
    AlertDecision(
      device: .serial(device),
      kind: .level(id: id, name: id, timing: timing, severity: 0, isRepeat: false),
      reading: Reading(device: .serial(device), level: .percent(15), charging: false, observedAt: t0))
  }

  func testNextMomentIsHeldUntilAMoment() {
    var s = NudgeScheduler(maxWait: 8 * 3600)
    XCTAssertEqual(s.schedule(decision("low", .nextMoment), now: t0), [])
    XCTAssertEqual(s.pending.count, 1)
    let out = s.onMoment(.screenLocked, now: t0 + 60)
    XCTAssertEqual(out.map(\.moment), [.screenLocked])
    XCTAssertEqual(out.first?.decision, decision("low", .nextMoment))
    XCTAssertTrue(s.pending.isEmpty)
  }

  func testNowIsImmediateAndSupersedesPendingForSameDevice() {
    var s = NudgeScheduler(maxWait: 8 * 3600)
    _ = s.schedule(decision("low", .nextMoment), now: t0)
    _ = s.schedule(decision("low", .nextMoment, device: "B"), now: t0)
    let out = s.schedule(decision("veryLow", .now), now: t0 + 10)
    XCTAssertEqual(out, [Delivery(decision: decision("veryLow", .now), moment: nil)])
    XCTAssertEqual(s.pending.map(\.decision.device), [.serial("B")])
  }

  func testNewerNudgeReplacesOlderForSameDevice() {
    var s = NudgeScheduler(maxWait: 8 * 3600)
    _ = s.schedule(decision("low", .nextMoment), now: t0)
    _ = s.schedule(decision("low2", .nextMoment), now: t0 + 5)
    XCTAssertEqual(s.pending.count, 1)
    XCTAssertEqual(s.pending.first?.queuedAt, t0)  // keeps the original wait clock
  }

  func testMaxWaitDeliversOnTick() {
    var s = NudgeScheduler(maxWait: 8 * 3600)
    _ = s.schedule(decision("low", .nextMoment), now: t0)
    XCTAssertEqual(s.onTick(now: t0 + 8 * 3600 - 1), [])
    XCTAssertEqual(s.onTick(now: t0 + 8 * 3600).map(\.moment), [.maxWait])
    XCTAssertTrue(s.pending.isEmpty)
  }

  func testDropPendingWhenCharging() {
    var s = NudgeScheduler(maxWait: 8 * 3600)
    _ = s.schedule(decision("low", .nextMoment), now: t0)
    s.dropPending(for: .serial("A"))
    XCTAssertEqual(s.onMoment(.willSleep, now: t0 + 1), [])
  }

  func testFullyChargedIsImmediate() {
    var s = NudgeScheduler(maxWait: 8 * 3600)
    let full = AlertDecision(device: .serial("A"), kind: .fullyCharged,
                             reading: Reading(device: .serial("A"), level: .percent(100), charging: false, observedAt: t0))
    XCTAssertEqual(s.schedule(full, now: t0), [Delivery(decision: full, moment: nil)])
  }

  func testNextEndOfDay() {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    XCTAssertEqual(NudgeScheduler.nextEndOfDay(after: t0, hour: 17, minute: 30, calendar: cal),
                   t0 + 9.5 * 3600)
    XCTAssertEqual(NudgeScheduler.nextEndOfDay(after: t0 + 10 * 3600, hour: 17, minute: 30, calendar: cal),
                   t0 + 9.5 * 3600 + 86_400)
  }

  func testSchedulerRoundTripsThroughJSON() throws {
    var s = NudgeScheduler(maxWait: 3600)
    _ = s.schedule(decision("low", .nextMoment), now: t0)
    XCTAssertEqual(try JuiceJSON.decoder.decode(NudgeScheduler.self, from: JuiceJSON.encoder.encode(s)), s)
  }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter JuiceCoreTests.NudgeSchedulerTests`
Expected: FAIL to compile with "cannot find 'NudgeScheduler' in scope".

- [ ] **Step 3: Implement**

`Sources/JuiceCore/NudgeScheduler.swift`:
```swift
import Foundation

public enum Moment: String, Hashable, Sendable, Codable {
  case screenLocked, willSleep, endOfDay, receiverDeparted, maxWait
}

public struct Delivery: Hashable, Sendable {
  public var decision: AlertDecision
  /// nil = delivered immediately (timing `.now` or fully charged).
  public var moment: Moment?

  public init(decision: AlertDecision, moment: Moment?) {
    self.decision = decision
    self.moment = moment
  }
}

/// Holds `.nextMoment` alerts until a natural moment (spec §4). Pure: the app feeds it events.
public struct NudgeScheduler: Hashable, Sendable, Codable {
  public struct Pending: Hashable, Sendable, Codable {
    public var decision: AlertDecision
    public var queuedAt: Date
  }

  public var maxWait: TimeInterval
  public private(set) var pending: [Pending] = []

  public init(maxWait: TimeInterval) { self.maxWait = maxWait }

  public mutating func schedule(_ decision: AlertDecision, now: Date) -> [Delivery] {
    if case .level(_, _, .nextMoment, _, _) = decision.kind {
      let queuedAt = pending.first { $0.decision.device == decision.device }?.queuedAt ?? now
      pending.removeAll { $0.decision.device == decision.device }
      pending.append(Pending(decision: decision, queuedAt: queuedAt))
      return []
    }
    if case .level = decision.kind {
      pending.removeAll { $0.decision.device == decision.device }
    }
    return [Delivery(decision: decision, moment: nil)]
  }

  public mutating func onMoment(_ moment: Moment, now: Date) -> [Delivery] {
    let out = pending.map { Delivery(decision: $0.decision, moment: moment) }
    pending = []
    return out
  }

  public mutating func onTick(now: Date) -> [Delivery] {
    let due = pending.filter { now.timeIntervalSince($0.queuedAt) >= maxWait }
    pending.removeAll { now.timeIntervalSince($0.queuedAt) >= maxWait }
    return due.map { Delivery(decision: $0.decision, moment: .maxWait) }
  }

  public mutating func dropPending(for device: DeviceID) {
    pending.removeAll { $0.decision.device == device }
  }

  public static func nextEndOfDay(after date: Date, hour: Int, minute: Int, calendar: Calendar) -> Date {
    let today = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
    if today > date { return today }
    return calendar.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86_400)
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter JuiceCoreTests.NudgeSchedulerTests`
Expected: PASS (8 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/JuiceCore/NudgeScheduler.swift Tests/JuiceCoreTests/NudgeSchedulerTests.swift
git commit -m "Add natural-moment nudge scheduler"
```

---

### Task 5: Forecaster (Codex-ready)

**Files:**
- Create: `Sources/JuiceCore/Forecaster.swift`
- Test: `Tests/JuiceCoreTests/ForecasterTests.swift`

**Interfaces:**
- Consumes: `Reading`, `ForecastResult` (Task 1).
- Produces: `Forecaster.forecast(_ readings: [Reading], now: Date) -> ForecastResult`, plus `Forecaster.minimumDrop == 10` and `Forecaster.minimumSpan == 2 days`.

**Rules (spec §5):**
- Sort the readings by time.
- If the latest reading is a word, return `.unavailable`. If it's charging, or there are no readings, return `.learning`.
- Split into discharge runs at every charging reading, or when a rise of 10 or more points happens without the charging flag.
- A run is confident when it has dropped at least 10 points over at least 2 days. Its slope is the Theil–Sen estimate over at most its last 500 points.
- Use the current run's slope if confident. Otherwise use the most recent earlier confident run's slope. Otherwise return `.learning`.
- Calculation: `emptyAt = latest.time + latest% / -slope` days, and `daysLeft = max(0, emptyAt - now)`.

- [ ] **Step 1: Write the failing test**

`Tests/JuiceCoreTests/ForecasterTests.swift`:
```swift
import XCTest
@testable import JuiceCore

final class ForecasterTests: XCTestCase {
  let dev = DeviceID.serial("M")
  let t0 = Date(timeIntervalSince1970: 1_800_000_000)

  func r(_ day: Double, _ p: Int, charging: Bool = false) -> Reading {
    Reading(device: dev, level: .percent(p), charging: charging, observedAt: t0 + day * 86_400)
  }

  func days(_ f: ForecastResult) -> Double? {
    if case .estimate(let d, _) = f { return d }
    return nil
  }

  var linear: [Reading] {
    stride(from: 0.0, through: 6.0, by: 0.25).map { r($0, 100 - Int(($0 * 5).rounded())) }
  }

  func testNoReadingsIsLearning() {
    XCTAssertEqual(Forecaster.forecast([], now: t0), .learning)
  }

  func testWordOnlyIsUnavailable() {
    let w = Reading(device: dev, level: .word(.good), charging: false, observedAt: t0)
    XCTAssertEqual(Forecaster.forecast([w], now: t0), .unavailable)
  }

  func testChargingIsLearning() {
    XCTAssertEqual(Forecaster.forecast(linear + [r(6.1, 72, charging: true)], now: t0 + 6.1 * 86_400), .learning)
  }

  func testLinearDrain() throws {
    let d = try XCTUnwrap(days(Forecaster.forecast(linear, now: t0 + 6 * 86_400)))
    XCTAssertEqual(d, 14, accuracy: 0.5)
  }

  func testCoarseTenPercentSteps() throws {
    let rs = stride(from: 0.0, through: 6.0, by: 0.5).map { r($0, 100 - 10 * Int($0 / 2)) }
    let d = try XCTUnwrap(days(Forecaster.forecast(rs, now: t0 + 6 * 86_400)))
    XCTAssertEqual(d, 14, accuracy: 3)
  }

  func testTooLittleDataIsLearning() {
    XCTAssertEqual(Forecaster.forecast([r(0, 80), r(3, 75)], now: t0 + 3 * 86_400), .learning)
    XCTAssertEqual(Forecaster.forecast([r(0, 80), r(1, 60)], now: t0 + 86_400), .learning)
  }

  func testBorrowsPreviousRunAfterCharge() throws {
    let rs = [r(0, 100), r(1, 95), r(2, 90), r(3, 85), r(4, 80), r(4.1, 90, charging: true),
              r(4.5, 100), r(5, 98)]
    let d = try XCTUnwrap(days(Forecaster.forecast(rs, now: t0 + 5 * 86_400)))
    XCTAssertEqual(d, 19.6, accuracy: 0.3)
  }

  func testRiseWithoutChargeFlagStartsNewRun() throws {
    let rs = [r(0, 100), r(1, 95), r(2, 90), r(3, 85), r(4, 80), r(4.2, 95), r(5, 94)]
    let d = try XCTUnwrap(days(Forecaster.forecast(rs, now: t0 + 5 * 86_400)))
    XCTAssertEqual(d, 18.8, accuracy: 0.3)
  }

  func testOutlierDoesNotSkew() throws {
    var rs = linear
    rs.append(r(3.1, 5))
    let d = try XCTUnwrap(days(Forecaster.forecast(rs, now: t0 + 6 * 86_400)))
    XCTAssertEqual(d, 14, accuracy: 1)
  }

  func testNowAfterLatestReducesDaysLeft() throws {
    let d = try XCTUnwrap(days(Forecaster.forecast(linear, now: t0 + 8 * 86_400)))
    XCTAssertEqual(d, 12, accuracy: 0.5)
  }

  func testUnsortedInputGivesSameForecast() {
    let now = t0 + 6 * 86_400
    XCTAssertEqual(Forecaster.forecast(linear.reversed(), now: now), Forecaster.forecast(linear, now: now))
  }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter JuiceCoreTests.ForecasterTests`
Expected: FAIL to compile with "cannot find 'Forecaster' in scope".

- [ ] **Step 3: Implement**

`Sources/JuiceCore/Forecaster.swift`:
```swift
import Foundation

/// Time-left forecast from local + synced history (spec §5).
public enum Forecaster {
  public static let minimumDrop = 10.0
  public static let minimumSpan: TimeInterval = 2 * 86_400
  static let riseSplit = 10.0
  static let maxPointsPerRun = 500

  struct Point: Hashable {
    var t: Date
    var p: Double
  }

  public static func forecast(_ readings: [Reading], now: Date) -> ForecastResult {
    let sorted = readings.sorted { $0.observedAt < $1.observedAt }
    guard let latest = sorted.last else { return .learning }
    guard case .percent(let latestPercent) = latest.level else { return .unavailable }
    if latest.charging { return .learning }

    let runs = dischargeRuns(sorted)
    guard let current = runs.last else { return .learning }
    var slope: Double?
    if isConfident(current) {
      slope = theilSenSlope(current)
    } else {
      for run in runs.dropLast().reversed() where isConfident(run) {
        slope = theilSenSlope(run)
        break
      }
    }
    guard let perDay = slope, perDay < 0 else { return .learning }

    let daysFromLatest = Double(latestPercent) / -perDay
    let emptyAt = latest.observedAt.addingTimeInterval(daysFromLatest * 86_400)
    let daysLeft = max(0, emptyAt.timeIntervalSince(now) / 86_400)
    return .estimate(daysLeft: daysLeft, emptyAt: emptyAt)
  }

  static func dischargeRuns(_ sorted: [Reading]) -> [[Point]] {
    var runs: [[Point]] = []
    var current: [Point] = []
    for reading in sorted {
      guard case .percent(let p) = reading.level else { continue }
      if reading.charging {
        if !current.isEmpty { runs.append(current); current = [] }
        continue
      }
      let value = Double(p)
      if let last = current.last, value >= last.p + riseSplit {
        runs.append(current)
        current = []
      }
      current.append(Point(t: reading.observedAt, p: value))
    }
    if !current.isEmpty { runs.append(current) }
    return runs
  }

  static func isConfident(_ run: [Point]) -> Bool {
    guard let first = run.first, let last = run.last else { return false }
    return first.p - last.p >= minimumDrop && last.t.timeIntervalSince(first.t) >= minimumSpan
  }

  /// Median of pairwise slopes, in percent per day. Robust to coarse steps and outliers.
  static func theilSenSlope(_ run: [Point]) -> Double? {
    let points = Array(run.suffix(maxPointsPerRun))
    guard let origin = points.first?.t else { return nil }
    let xs = points.map { $0.t.timeIntervalSince(origin) / 86_400 }
    var slopes: [Double] = []
    slopes.reserveCapacity(points.count * points.count / 2)
    for i in 0..<points.count {
      for j in (i + 1)..<points.count where xs[j] > xs[i] {
        slopes.append((points[j].p - points[i].p) / (xs[j] - xs[i]))
      }
    }
    guard !slopes.isEmpty else { return nil }
    slopes.sort()
    let mid = slopes.count / 2
    return slopes.count % 2 == 1 ? slopes[mid] : (slopes[mid - 1] + slopes[mid]) / 2
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter JuiceCoreTests.ForecasterTests`
Expected: PASS (11 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/JuiceCore/Forecaster.swift Tests/JuiceCoreTests/ForecasterTests.swift
git commit -m "Add Theil-Sen battery forecaster"
```

---

### Task 6: History and sync merge (Codex-ready)

**Files:**
- Create: `Sources/JuiceCore/History.swift`, `Sources/JuiceCore/SyncModel.swift`
- Test: `Tests/JuiceCoreTests/SyncMergeTests.swift`

**Interfaces:**
- Consumes: `Reading`, `DeviceInfo`, `AlertProfile` (Tasks 1–2).
- Produces:
  - `History.appending(_:to:now:) -> [Reading]`, `History.trim(_:now:) -> [Reading]`, `History.retention` (90 days), `History.maxReadings` (2000)
  - `DeviceRecord(info:nickname:alertOverride:metaUpdatedAt:readings:)`, with `displayName`
  - `SyncFile(schema:macID:macName:updatedAt:devices:)`, with `SyncFile.currentSchema == 1`
  - `SyncMerge.merge(local:remotes:now:) -> [DeviceRecord]`

- [ ] **Step 1: Write the failing test**

`Tests/JuiceCoreTests/SyncMergeTests.swift`:
```swift
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter JuiceCoreTests.SyncMergeTests`
Expected: FAIL to compile with "cannot find 'DeviceRecord' in scope".

- [ ] **Step 3: Implement**

`Sources/JuiceCore/History.swift`:
```swift
import Foundation

public enum History {
  public static let retention: TimeInterval = 90 * 86_400
  public static let maxReadings = 2_000
  /// Identical readings closer than this are collapsed so event bursts don't flood history.
  public static let duplicateWindow: TimeInterval = 600

  public static func appending(_ reading: Reading, to readings: [Reading], now: Date) -> [Reading] {
    if let last = readings.last, last.level == reading.level, last.charging == reading.charging,
      reading.observedAt.timeIntervalSince(last.observedAt) < duplicateWindow
    {
      return readings
    }
    return trim(readings + [reading], now: now)
  }

  public static func trim(_ readings: [Reading], now: Date) -> [Reading] {
    let cutoff = now.addingTimeInterval(-retention)
    let kept = readings.filter { $0.observedAt >= cutoff }.sorted { $0.observedAt < $1.observedAt }
    return Array(kept.suffix(maxReadings))
  }
}
```

`Sources/JuiceCore/SyncModel.swift`:
```swift
import Foundation

/// Everything known about one device. Metadata (nickname, override) syncs newest-wins by `metaUpdatedAt`.
public struct DeviceRecord: Hashable, Sendable, Codable, Identifiable {
  public var info: DeviceInfo
  public var nickname: String?
  public var alertOverride: AlertProfile?
  public var metaUpdatedAt: Date
  public var readings: [Reading]

  public init(info: DeviceInfo, nickname: String?, alertOverride: AlertProfile?, metaUpdatedAt: Date,
              readings: [Reading]) {
    self.info = info
    self.nickname = nickname
    self.alertOverride = alertOverride
    self.metaUpdatedAt = metaUpdatedAt
    self.readings = readings
  }

  public var id: DeviceID { info.id }

  public var displayName: String {
    if let nickname, !nickname.trimmingCharacters(in: .whitespaces).isEmpty { return nickname }
    return info.name
  }
}

/// One Mac's file in `iCloud Drive/logijuice/<macID>.json` (spec §6). Contains only that Mac's own readings.
public struct SyncFile: Hashable, Sendable, Codable {
  public static let currentSchema = 1
  public var schema: Int
  public var macID: String
  public var macName: String
  public var updatedAt: Date
  public var devices: [DeviceRecord]

  public init(schema: Int = SyncFile.currentSchema, macID: String, macName: String, updatedAt: Date,
              devices: [DeviceRecord]) {
    self.schema = schema
    self.macID = macID
    self.macName = macName
    self.updatedAt = updatedAt
    self.devices = devices
  }
}

public enum SyncMerge {
  public static func merge(local: [DeviceRecord], remotes: [SyncFile], now: Date) -> [DeviceRecord] {
    var byID: [DeviceID: DeviceRecord] = [:]
    for record in local { byID[record.info.id] = record }

    for file in remotes where file.schema <= SyncFile.currentSchema {
      for remote in file.devices {
        let retagged = remote.readings.filter { $0.source == .local }.map { r -> Reading in
          var copy = r
          copy.source = .synced(macID: file.macID)
          return copy
        }
        if var existing = byID[remote.info.id] {
          existing.readings = union(existing.readings, retagged)
          if remote.metaUpdatedAt > existing.metaUpdatedAt {
            existing.info = remote.info
            existing.nickname = remote.nickname
            existing.alertOverride = remote.alertOverride
            existing.metaUpdatedAt = remote.metaUpdatedAt
          }
          byID[remote.info.id] = existing
        } else {
          var fresh = remote
          fresh.readings = union([], retagged)
          byID[remote.info.id] = fresh
        }
      }
    }

    return byID.values.map { record -> DeviceRecord in
      var copy = record
      copy.readings = History.trim(copy.readings, now: now)
      return copy
    }.sorted { $0.info.id < $1.info.id }
  }

  /// Union keyed by whole second; a local reading wins over a synced one at the same second.
  static func union(_ a: [Reading], _ b: [Reading]) -> [Reading] {
    var bySecond: [Int: Reading] = [:]
    for r in a + b {
      let key = Int(r.observedAt.timeIntervalSince1970.rounded(.down))
      if let existing = bySecond[key], existing.source == .local { continue }
      bySecond[key] = r
    }
    return bySecond.values.sorted { $0.observedAt < $1.observedAt }
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter JuiceCoreTests.SyncMergeTests`
Expected: PASS (9 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/JuiceCore Tests/JuiceCoreTests/SyncMergeTests.swift
git commit -m "Add reading history and cross-Mac sync merge"
```

---

### Task 7: Snapshot, formatting, menu bar policy (Codex-ready)

**Files:**
- Create: `Sources/JuiceCore/Snapshot.swift`, `Sources/JuiceCore/Format.swift`, `Sources/JuiceCore/MenuBarPolicy.swift`
- Test: `Tests/JuiceCoreTests/SnapshotFormatTests.swift`

**Interfaces:**
- Consumes: `DeviceRecord`, `Forecaster`, `DeviceAlertState`, `AlertProfile`, `MenuBarMode`, `Delivery`, `Moment` (Tasks 2–6).
- Produces:
  - `SnapshotDevice` (`id, name, nickname, kind, level: BatteryLevel?, charging, lastSeen: Date?, live, forecast, alerting, tinted`, plus `displayName`)
  - `Snapshot` (`schema`, `generatedAt`, `receiverPresent`, `devices`, plus `lowest`, `.empty`, `.preview`, `currentSchema == 1`)
  - `SnapshotBuilder.build(records:liveDevices:receiverPresent:alerting:tinted:now:) -> Snapshot`
  - `MenuBarPolicy.isVisible(mode:snapshot:) -> Bool`, `MenuBarPolicy.isTinted(state:profile:) -> Bool`
  - `Format.level(_:)`, `Format.forecast(_:) -> String?`, `Format.duration(days:)`, `Format.seen(_:now:)`, `Format.subtitle(_:now:)`, `Format.notificationBody(level:forecast:)`, `Format.notification(for:displayName:forecast:) -> NotificationText`, `Format.statusLine(_:now:)`, `Format.batterySymbol(percent:)`
  - `NotificationText(title:body:identifier:)`
  - `DeviceKind.symbolName`

- [ ] **Step 1: Write the failing test**

`Tests/JuiceCoreTests/SnapshotFormatTests.swift`:
```swift
import XCTest
@testable import JuiceCore

final class SnapshotFormatTests: XCTestCase {
  let t0 = Date(timeIntervalSince1970: 1_800_000_000)

  func record(_ id: String, _ name: String, nickname: String? = nil, readings: [(Double, Int, Bool)]) -> DeviceRecord {
    let did = DeviceID.serial(id)
    return DeviceRecord(
      info: DeviceInfo(id: did, name: name, kind: .mouse), nickname: nickname, alertOverride: nil,
      metaUpdatedAt: t0,
      readings: readings.map { Reading(device: did, level: .percent($0.1), charging: $0.2, observedAt: t0 + $0.0) })
  }

  func device(level: BatteryLevel? = .percent(50), charging: Bool = false, live: Bool = true,
              alerting: Bool = false, tinted: Bool = false) -> SnapshotDevice {
    SnapshotDevice(id: .serial("X"), name: "MX Keys", nickname: nil, kind: .keyboard, level: level,
                   charging: charging, lastSeen: t0, live: live, forecast: .learning, alerting: alerting, tinted: tinted)
  }

  func testBuildSortsLowestFirstAndCarriesFlags() {
    let snap = SnapshotBuilder.build(
      records: [record("A", "Keys", readings: [(0, 80, false)]), record("B", "Mouse", readings: [(0, 12, false)])],
      liveDevices: [.serial("B")], receiverPresent: true, alerting: [.serial("B")], tinted: [], now: t0)
    XCTAssertEqual(snap.devices.map(\.name), ["Mouse", "Keys"])
    XCTAssertEqual(snap.devices[0].level, .percent(12))
    XCTAssertTrue(snap.devices[0].live)
    XCTAssertTrue(snap.devices[0].alerting)
    XCTAssertFalse(snap.devices[1].live)
    XCTAssertEqual(snap.lowest?.name, "Mouse")
    XCTAssertEqual(snap.schema, 1)
  }

  func testEmptyNicknameFallsBackToName() {
    var d = device()
    d.nickname = "  "
    XCTAssertEqual(d.displayName, "MX Keys")
    d.nickname = "Desk keys"
    XCTAssertEqual(d.displayName, "Desk keys")
  }

  func testAutoHiddenWithNoDevices() {
    XCTAssertFalse(MenuBarPolicy.isVisible(mode: .auto, snapshot: .empty))
    XCTAssertTrue(MenuBarPolicy.isVisible(mode: .always, snapshot: .empty))
  }

  func testAutoVisibility() {
    func snap(_ d: SnapshotDevice) -> Snapshot { Snapshot(generatedAt: t0, receiverPresent: true, devices: [d]) }
    XCTAssertFalse(MenuBarPolicy.isVisible(mode: .auto, snapshot: snap(device())))
    XCTAssertTrue(MenuBarPolicy.isVisible(mode: .auto, snapshot: snap(device(alerting: true))))
    XCTAssertTrue(MenuBarPolicy.isVisible(mode: .auto, snapshot: snap(device(charging: true, live: true))))
    XCTAssertFalse(MenuBarPolicy.isVisible(mode: .auto, snapshot: snap(device(charging: true, live: false))))
    XCTAssertFalse(MenuBarPolicy.isVisible(mode: .never, snapshot: snap(device(alerting: true))))
  }

  func testIsTinted() {
    var s = DeviceAlertState()
    s.firedAt["low"] = t0
    XCTAssertFalse(MenuBarPolicy.isTinted(state: s, profile: .default))
    s.firedAt["veryLow"] = t0
    XCTAssertTrue(MenuBarPolicy.isTinted(state: s, profile: .default))
  }

  func testLevelAndForecastStrings() {
    XCTAssertEqual(Format.level(.percent(42)), "42%")
    XCTAssertEqual(Format.level(.word(.low)), "Low")
    XCTAssertEqual(Format.forecast(.estimate(daysLeft: 9.4, emptyAt: t0)), "~9 days")
    XCTAssertEqual(Format.forecast(.estimate(daysLeft: 1.5, emptyAt: t0)), "~36 hours")
    XCTAssertEqual(Format.forecast(.estimate(daysLeft: 0.01, emptyAt: t0)), "~1 hour")
    XCTAssertEqual(Format.forecast(.learning), "learning…")
    XCTAssertNil(Format.forecast(.unavailable))
  }

  func testSeenStrings() {
    XCTAssertEqual(Format.seen(nil, now: t0), "never seen")
    XCTAssertEqual(Format.seen(t0 - 30, now: t0), "seen just now")
    XCTAssertEqual(Format.seen(t0 - 720, now: t0), "seen 12m ago")
    XCTAssertEqual(Format.seen(t0 - 3 * 3600, now: t0), "seen 3h ago")
    XCTAssertEqual(Format.seen(t0 - 3 * 86_400, now: t0), "seen 3d ago")
  }

  func testSubtitle() {
    var d = device()
    d.forecast = .estimate(daysLeft: 9, emptyAt: t0)
    XCTAssertEqual(Format.subtitle(d, now: t0), "~9 days")
    d.live = false
    XCTAssertEqual(Format.subtitle(d, now: t0 + 3 * 3600), "~9 days · seen 3h ago")
  }

  func testNotificationTexts() {
    let reading = Reading(device: .serial("M"), level: .percent(14), charging: false, observedAt: t0)
    let low = AlertDecision(device: .serial("M"),
                            kind: .level(id: "low", name: "Low", timing: .nextMoment, severity: 0, isRepeat: false),
                            reading: reading)
    let forecast = ForecastResult.estimate(daysLeft: 2, emptyAt: t0)
    let plain = Format.notification(for: Delivery(decision: low, moment: nil), displayName: "MX Master 3S", forecast: forecast)
    XCTAssertEqual(plain, NotificationText(title: "MX Master 3S", body: "14% · about 2 days left", identifier: "sn:M.low"))
    let leaving = Format.notification(for: Delivery(decision: low, moment: .receiverDeparted),
                                      displayName: "MX Master 3S", forecast: forecast)
    XCTAssertEqual(leaving.title, "Leaving this desk?")
    XCTAssertEqual(leaving.body, "MX Master 3S is at 14% · about 2 days left")
    let full = AlertDecision(device: .serial("M"), kind: .fullyCharged, reading: reading)
    XCTAssertEqual(Format.notification(for: Delivery(decision: full, moment: nil), displayName: "MX Keys", forecast: .learning),
                   NotificationText(title: "MX Keys", body: "Fully charged. Unplug whenever you like.", identifier: "sn:M.full"))
    XCTAssertEqual(Format.notificationBody(level: .percent(8), forecast: .learning), "8%")
  }

  func testStatusLine() {
    var d = device(level: .percent(80), charging: true, live: false)
    d.forecast = .learning
    XCTAssertEqual(Format.statusLine(d, now: t0 + 3 * 3600), "MX Keys: 80% (charging), learning…, seen 3h ago")
    d = device(level: .percent(42))
    d.forecast = .estimate(daysLeft: 9, emptyAt: t0)
    XCTAssertEqual(Format.statusLine(d, now: t0), "MX Keys: 42%, ~9 days")
  }

  func testBatterySymbolsAndKindSymbols() {
    XCTAssertEqual(Format.batterySymbol(percent: nil), "battery.0percent")
    XCTAssertEqual(Format.batterySymbol(percent: 10), "battery.0percent")
    XCTAssertEqual(Format.batterySymbol(percent: 30), "battery.25percent")
    XCTAssertEqual(Format.batterySymbol(percent: 50), "battery.50percent")
    XCTAssertEqual(Format.batterySymbol(percent: 80), "battery.75percent")
    XCTAssertEqual(Format.batterySymbol(percent: 95), "battery.100percent")
    XCTAssertEqual(DeviceKind.mouse.symbolName, "computermouse")
    XCTAssertEqual(DeviceKind.keyboard.symbolName, "keyboard")
  }

  func testSnapshotRoundTrips() throws {
    XCTAssertEqual(try JuiceJSON.decoder.decode(Snapshot.self, from: JuiceJSON.encoder.encode(Snapshot.preview)), .preview)
  }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter JuiceCoreTests.SnapshotFormatTests`
Expected: FAIL to compile with "cannot find 'SnapshotBuilder' in scope".

- [ ] **Step 3: Implement**

`Sources/JuiceCore/Snapshot.swift`:
```swift
import Foundation

public struct SnapshotDevice: Hashable, Sendable, Codable, Identifiable {
  public var id: DeviceID
  public var name: String
  public var nickname: String?
  public var kind: DeviceKind
  public var level: BatteryLevel?
  public var charging: Bool
  public var lastSeen: Date?
  public var live: Bool
  public var forecast: ForecastResult
  public var alerting: Bool
  public var tinted: Bool

  public init(id: DeviceID, name: String, nickname: String?, kind: DeviceKind, level: BatteryLevel?,
              charging: Bool, lastSeen: Date?, live: Bool, forecast: ForecastResult, alerting: Bool,
              tinted: Bool) {
    self.id = id
    self.name = name
    self.nickname = nickname
    self.kind = kind
    self.level = level
    self.charging = charging
    self.lastSeen = lastSeen
    self.live = live
    self.forecast = forecast
    self.alerting = alerting
    self.tinted = tinted
  }

  public var displayName: String {
    if let nickname, !nickname.trimmingCharacters(in: .whitespaces).isEmpty { return nickname }
    return name
  }
}

/// The only contract between the app, the widget and the CLI (spec §7).
public struct Snapshot: Hashable, Sendable, Codable {
  public static let currentSchema = 1
  public var schema: Int
  public var generatedAt: Date
  public var receiverPresent: Bool
  public var devices: [SnapshotDevice]

  public init(schema: Int = Snapshot.currentSchema, generatedAt: Date, receiverPresent: Bool,
              devices: [SnapshotDevice]) {
    self.schema = schema
    self.generatedAt = generatedAt
    self.receiverPresent = receiverPresent
    self.devices = devices
  }

  public var lowest: SnapshotDevice? {
    devices.filter { $0.level != nil }.min {
      ($0.level?.equivalentPercent ?? 101) < ($1.level?.equivalentPercent ?? 101)
    }
  }

  public static let empty = Snapshot(generatedAt: Date(timeIntervalSince1970: 0), receiverPresent: false, devices: [])

  public static let preview = Snapshot(
    generatedAt: Date(timeIntervalSince1970: 1_800_000_000), receiverPresent: true,
    devices: [
      SnapshotDevice(id: .serial("PREVIEW-MOUSE"), name: "MX Master 3S", nickname: nil, kind: .mouse,
                     level: .percent(14), charging: false, lastSeen: Date(timeIntervalSince1970: 1_800_000_000),
                     live: true, forecast: .estimate(daysLeft: 2, emptyAt: Date(timeIntervalSince1970: 1_800_172_800)),
                     alerting: true, tinted: false),
      SnapshotDevice(id: .serial("PREVIEW-KEYS"), name: "MX Keys S", nickname: nil, kind: .keyboard,
                     level: .percent(72), charging: false, lastSeen: Date(timeIntervalSince1970: 1_800_000_000),
                     live: true, forecast: .learning, alerting: false, tinted: false),
    ])
}

public enum SnapshotBuilder {
  public static func build(records: [DeviceRecord], liveDevices: Set<DeviceID>, receiverPresent: Bool,
                           alerting: Set<DeviceID>, tinted: Set<DeviceID>, now: Date) -> Snapshot {
    let devices = records.map { r -> SnapshotDevice in
      let latest = r.readings.max { $0.observedAt < $1.observedAt }
      return SnapshotDevice(
        id: r.info.id, name: r.info.name, nickname: r.nickname, kind: r.info.kind, level: latest?.level,
        charging: latest?.charging ?? false, lastSeen: latest?.observedAt, live: liveDevices.contains(r.info.id),
        forecast: Forecaster.forecast(r.readings, now: now), alerting: alerting.contains(r.info.id),
        tinted: tinted.contains(r.info.id))
    }.sorted {
      ($0.level?.equivalentPercent ?? 101, $0.displayName) < ($1.level?.equivalentPercent ?? 101, $1.displayName)
    }
    return Snapshot(generatedAt: now, receiverPresent: receiverPresent, devices: devices)
  }
}
```

`Sources/JuiceCore/MenuBarPolicy.swift`:
```swift
import Foundation

public enum MenuBarPolicy {
  /// Auto: visible while any device has a fired level, or a live device is charging (spec §7).
  public static func isVisible(mode: MenuBarMode, snapshot: Snapshot) -> Bool {
    switch mode {
    case .always: return true
    case .never: return false
    case .auto: return snapshot.devices.contains { $0.alerting || ($0.charging && $0.live) }
    }
  }

  public static func isTinted(state: DeviceAlertState, profile: AlertProfile) -> Bool {
    profile.levels.contains { $0.tintsIcon && state.firedAt[$0.id] != nil }
  }
}
```

`Sources/JuiceCore/Format.swift`:
```swift
import Foundation

public struct NotificationText: Hashable, Sendable {
  public var title: String
  public var body: String
  public var identifier: String

  public init(title: String, body: String, identifier: String) {
    self.title = title
    self.body = body
    self.identifier = identifier
  }
}

public enum Format {
  public static func level(_ level: BatteryLevel) -> String {
    switch level {
    case .percent(let p): return "\(p)%"
    case .word(let w):
      switch w {
      case .critical: return "Critical"
      case .low: return "Low"
      case .good: return "Good"
      case .full: return "Full"
      }
    }
  }

  public static func duration(days: Double) -> String {
    if days >= 2 { return "\(Int(days.rounded())) days" }
    let hours = max(1, Int((days * 24).rounded()))
    return hours == 1 ? "1 hour" : "\(hours) hours"
  }

  public static func forecast(_ f: ForecastResult) -> String? {
    switch f {
    case .learning: return "learning…"
    case .unavailable: return nil
    case .estimate(let days, _): return "~" + duration(days: days)
    }
  }

  public static func seen(_ date: Date?, now: Date) -> String {
    guard let date else { return "never seen" }
    let s = max(0, now.timeIntervalSince(date))
    switch s {
    case ..<120: return "seen just now"
    case ..<3600: return "seen \(Int(s / 60))m ago"
    case ..<172_800: return "seen \(Int(s / 3600))h ago"
    default: return "seen \(Int(s / 86_400))d ago"
    }
  }

  /// Secondary line used by the menu, settings and widget: forecast, plus staleness when not live.
  public static func subtitle(_ d: SnapshotDevice, now: Date) -> String {
    [forecast(d.forecast), d.live ? nil : seen(d.lastSeen, now: now)].compactMap { $0 }.joined(separator: " · ")
  }

  public static func notificationBody(level: BatteryLevel, forecast: ForecastResult) -> String {
    var s = Format.level(level)
    if case .estimate(let days, _) = forecast { s += " · about " + duration(days: days) + " left" }
    return s
  }

  public static func notification(for delivery: Delivery, displayName: String,
                                  forecast: ForecastResult) -> NotificationText {
    let d = delivery.decision
    switch d.kind {
    case .fullyCharged:
      return NotificationText(title: displayName, body: "Fully charged. Unplug whenever you like.",
                              identifier: "\(d.device.rawValue).full")
    case .level(let id, _, _, _, _):
      let body = notificationBody(level: d.reading.level, forecast: forecast)
      let identifier = "\(d.device.rawValue).\(id)"
      if delivery.moment == .receiverDeparted {
        return NotificationText(title: "Leaving this desk?", body: "\(displayName) is at \(body)", identifier: identifier)
      }
      return NotificationText(title: displayName, body: body, identifier: identifier)
    }
  }

  public static func statusLine(_ d: SnapshotDevice, now: Date) -> String {
    var line = "\(d.displayName): \(d.level.map(level) ?? "unknown")"
    if d.charging { line += " (charging)" }
    if let f = forecast(d.forecast) { line += ", \(f)" }
    if !d.live { line += ", \(seen(d.lastSeen, now: now))" }
    return line
  }

  public static func batterySymbol(percent: Int?) -> String {
    guard let p = percent else { return "battery.0percent" }
    switch p {
    case ..<13: return "battery.0percent"
    case ..<38: return "battery.25percent"
    case ..<63: return "battery.50percent"
    case ..<88: return "battery.75percent"
    default: return "battery.100percent"
    }
  }
}

extension DeviceKind {
  /// SF Symbol for the device kind, shared by menu, settings and widget.
  public var symbolName: String {
    switch self {
    case .keyboard: return "keyboard"
    case .mouse: return "computermouse"
    case .trackball: return "circle.circle"
    case .touchpad: return "rectangle.and.hand.point.up.left"
    case .numpad: return "number.square"
    case .presenter: return "av.remote"
    case .other: return "dot.radiowaves.left.and.right"
    }
  }
}
```

- [ ] **Step 4: Run all core tests to verify they pass**

Run: `swift test --filter JuiceCoreTests`
Expected: PASS (all JuiceCore tests, including 13 new).

- [ ] **Step 5: Commit**

```bash
git add Sources/JuiceCore Tests/JuiceCoreTests/SnapshotFormatTests.swift
git commit -m "Add snapshot, formatting and menu bar policy"
```

---

### Task 8: JuiceStore persistence (Codex-ready)

**Files:**
- Modify: `Package.swift`
- Create: `Sources/JuiceStore/JuicePaths.swift`, `Sources/JuiceStore/FileStores.swift`, `Sources/JuiceStore/SyncStore.swift`, `Sources/JuiceStore/MacIdentity.swift`
- Test: `Tests/JuiceStoreTests/StoreTests.swift`

**Interfaces:**
- Consumes: `Settings`, `DeviceRecord`, `DeviceAlertState`, `NudgeScheduler`, `Snapshot`, `SyncFile`, `JuiceJSON` (Tasks 1–7).
- Produces:
  - `JuicePaths(appSupport:groupContainer:iCloudFolder:)` and `.standard()`. Properties: `settingsURL`, `stateURL`, `snapshotURL` (group container), `cliSnapshotURL` (app support). `JuicePaths.appGroupID`.
  - `JSONFileStore<Value>(url:)` with `load(default:)`, `save(_:) throws`, `read() -> Value?`
  - Typealiases `SettingsStore`, `StateStore`, `SnapshotStore`
  - `LocalState` (`records`, `alertStates`, `scheduler`)
  - `AtomicFile.write(_:to:)`
  - `SyncStore(folder:macID:)` with `isAvailable`, `ownURL`, `writeOwn(_:) throws`, `readOthers() -> [SyncFile]`
  - `MacIdentity.hardwareUUID()`, `MacIdentity.name()`

- [ ] **Step 1: Add the target**

`Package.swift`:
```swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
  name: "LogiJuice",
  platforms: [.macOS(.v14)],
  targets: [
    .target(name: "JuiceCore"),
    .target(name: "JuiceStore", dependencies: ["JuiceCore"], linkerSettings: [.linkedFramework("IOKit")]),
    .testTarget(name: "JuiceCoreTests", dependencies: ["JuiceCore"]),
    .testTarget(name: "JuiceStoreTests", dependencies: ["JuiceStore", "JuiceCore"]),
  ]
)
```

- [ ] **Step 2: Write the failing test**

`Tests/JuiceStoreTests/StoreTests.swift`:
```swift
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
    s.menuBarMode = .never
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
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `swift test --filter JuiceStoreTests`
Expected: FAIL. With no `Sources/JuiceStore` directory yet, SwiftPM reports that the target has no sources, or the compiler reports that it can't find `SettingsStore`.

- [ ] **Step 4: Implement**

`Sources/JuiceStore/JuicePaths.swift`:
```swift
import Foundation

public struct JuicePaths: Sendable {
  public static let appGroupID = "group.com.penguinspecz.logijuice"

  public var appSupport: URL
  public var groupContainer: URL
  public var iCloudFolder: URL

  public init(appSupport: URL, groupContainer: URL, iCloudFolder: URL) {
    self.appSupport = appSupport
    self.groupContainer = groupContainer
    self.iCloudFolder = iCloudFolder
  }

  public static func standard() -> JuicePaths {
    let fm = FileManager.default
    let home = fm.homeDirectoryForCurrentUser
    let group = fm.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
      ?? home.appendingPathComponent("Library/Group Containers/\(appGroupID)")
    return JuicePaths(
      appSupport: home.appendingPathComponent("Library/Application Support/logijuice"),
      groupContainer: group,
      iCloudFolder: home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/logijuice"))
  }

  public var settingsURL: URL { appSupport.appendingPathComponent("settings.json") }
  public var stateURL: URL { appSupport.appendingPathComponent("state.json") }
  /// Read by the widget (sandboxed, app group).
  public var snapshotURL: URL { groupContainer.appendingPathComponent("snapshot.json") }
  /// Read by the CLI, avoiding macOS's cross-app group-container prompt.
  public var cliSnapshotURL: URL { appSupport.appendingPathComponent("snapshot.json") }
}
```

`Sources/JuiceStore/FileStores.swift`:
```swift
import Foundation
import JuiceCore

public enum AtomicFile {
  public static func write<T: Encodable>(_ value: T, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JuiceJSON.encoder.encode(value).write(to: url, options: .atomic)
  }
}

public struct JSONFileStore<Value: Codable>: Sendable {
  public let url: URL

  public init(url: URL) { self.url = url }

  /// Missing → default. Corrupt → moved aside to `<name>.corrupt.json`, then default.
  public func load(default makeDefault: @autoclosure () -> Value) -> Value {
    guard let data = try? Data(contentsOf: url) else { return makeDefault() }
    do {
      return try JuiceJSON.decoder.decode(Value.self, from: data)
    } catch {
      let backup = url.deletingPathExtension().appendingPathExtension("corrupt.json")
      try? FileManager.default.removeItem(at: backup)
      try? FileManager.default.moveItem(at: url, to: backup)
      return makeDefault()
    }
  }

  public func read() -> Value? {
    guard let data = try? Data(contentsOf: url) else { return nil }
    return try? JuiceJSON.decoder.decode(Value.self, from: data)
  }

  public func save(_ value: Value) throws { try AtomicFile.write(value, to: url) }
}

/// This Mac's private state: local readings, alert state, pending nudges.
public struct LocalState: Hashable, Sendable, Codable {
  public var records: [DeviceRecord] = []
  public var alertStates: [DeviceID: DeviceAlertState] = [:]
  public var scheduler = NudgeScheduler(maxWait: 8 * 3600)

  public init() {}
}

public typealias SettingsStore = JSONFileStore<Settings>
public typealias StateStore = JSONFileStore<LocalState>
public typealias SnapshotStore = JSONFileStore<Snapshot>
```

`Sources/JuiceStore/SyncStore.swift`:
```swift
import Foundation
import JuiceCore

/// `iCloud Drive/logijuice/<macID>.json`: each Mac writes only its own file (spec §6).
public struct SyncStore: Sendable {
  public let folder: URL
  public let macID: String

  public init(folder: URL, macID: String) {
    self.folder = folder
    self.macID = macID
  }

  /// iCloud Drive is on when its root (`com~apple~CloudDocs`) exists.
  public var isAvailable: Bool {
    FileManager.default.fileExists(atPath: folder.deletingLastPathComponent().path)
  }

  public var ownURL: URL { folder.appendingPathComponent("\(macID).json") }

  public func writeOwn(_ file: SyncFile) throws { try AtomicFile.write(file, to: ownURL) }

  public func readOthers() -> [SyncFile] {
    guard let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return [] }
    var files: [SyncFile] = []
    for name in names {
      if name.hasPrefix("."), name.hasSuffix(".icloud") {
        // Evicted by iCloud: ask for it; it'll be read on a later poll.
        let real = folder.appendingPathComponent(String(name.dropFirst().dropLast(".icloud".count)))
        try? FileManager.default.startDownloadingUbiquitousItem(at: real)
        continue
      }
      guard name.hasSuffix(".json"), name != "\(macID).json" else { continue }
      guard let data = try? Data(contentsOf: folder.appendingPathComponent(name)),
        let file = try? JuiceJSON.decoder.decode(SyncFile.self, from: data)
      else { continue }
      files.append(file)
    }
    return files.sorted { $0.macID < $1.macID }
  }
}
```

`Sources/JuiceStore/MacIdentity.swift`:
```swift
import Foundation
import IOKit

public enum MacIdentity {
  public static func hardwareUUID() -> String {
    let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
    defer { IOObjectRelease(service) }
    let value = IORegistryEntryCreateCFProperty(service, "IOPlatformUUID" as CFString, kCFAllocatorDefault, 0)?
      .takeRetainedValue() as? String
    return value ?? "unknown-\(ProcessInfo.processInfo.hostName)"
  }

  public static func name() -> String { Host.current().localizedName ?? "Mac" }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `swift test --filter JuiceStoreTests`
Expected: PASS (9 tests).

- [ ] **Step 6: Commit**

```bash
git add Package.swift Sources/JuiceStore Tests/JuiceStoreTests
git commit -m "Add JSON stores, sync folder store and Mac identity"
```

---

### Task 9: CLI `status` / `devices` (Codex-ready)

**Files:**
- Modify: `Package.swift`
- Create: `Sources/JuiceCLIKit/CLI.swift`, `Sources/LogiJuiceCLI/main.swift`
- Test: `Tests/JuiceCLIKitTests/CLITests.swift`

**Interfaces:**
- Consumes: `SnapshotStore`, `JuicePaths.cliSnapshotURL`, `Format.statusLine`, `Format.seen`, `JuiceJSON.prettyEncoder`.
- Produces: `CLI.run(_ args: [String], snapshotURL: URL, now: Date, out: (String) -> Void, err: (String) -> Void) -> Int32` and `CLI.usage`. Product `logijuice-cli`.

- [ ] **Step 1: Add the targets**

`Package.swift`:
```swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
  name: "LogiJuice",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "logijuice-cli", targets: ["LogiJuiceCLI"]),
  ],
  targets: [
    .target(name: "JuiceCore"),
    .target(name: "JuiceStore", dependencies: ["JuiceCore"], linkerSettings: [.linkedFramework("IOKit")]),
    .target(name: "JuiceCLIKit", dependencies: ["JuiceCore", "JuiceStore"]),
    .executableTarget(name: "LogiJuiceCLI", dependencies: ["JuiceCLIKit", "JuiceStore"]),
    .testTarget(name: "JuiceCoreTests", dependencies: ["JuiceCore"]),
    .testTarget(name: "JuiceStoreTests", dependencies: ["JuiceStore", "JuiceCore"]),
    .testTarget(name: "JuiceCLIKitTests", dependencies: ["JuiceCLIKit", "JuiceStore", "JuiceCore"]),
  ]
)
```

- [ ] **Step 2: Write the failing test**

`Tests/JuiceCLIKitTests/CLITests.swift`:
```swift
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
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `swift test --filter JuiceCLIKitTests`
Expected: FAIL to compile with "cannot find 'CLI' in scope".

- [ ] **Step 4: Implement**

`Sources/JuiceCLIKit/CLI.swift`:
```swift
import Foundation
import JuiceCore
import JuiceStore

public enum CLI {
  public static let usage = """
    usage: logijuice <command>
      status [--json]                              battery for each known device
      devices                                      device IDs, names and kinds
      debug capture [--seconds N] [--out FILE] [--probe]
                                                   record raw HID++ frames (troubleshooting)
    """

  public static func run(_ args: [String], snapshotURL: URL, now: Date = Date(),
                         out: (String) -> Void, err: (String) -> Void) -> Int32 {
    guard let command = args.first else {
      out(usage)
      return 0
    }
    switch command {
    case "-h", "--help", "help":
      out(usage)
      return 0
    case "status", "devices":
      guard let snapshot = SnapshotStore(url: snapshotURL).read(), snapshot.schema <= Snapshot.currentSchema else {
        err("No data yet. Is LogiJuice running?")
        return 1
      }
      if command == "status" {
        if args.contains("--json") {
          let data = (try? JuiceJSON.prettyEncoder.encode(snapshot)) ?? Data()
          out(String(decoding: data, as: UTF8.self))
          return 0
        }
        if snapshot.devices.isEmpty {
          out("No devices seen yet.")
          return 0
        }
        snapshot.devices.forEach { out(Format.statusLine($0, now: now)) }
      } else {
        snapshot.devices.forEach {
          out("\($0.id.rawValue)\t\($0.displayName)\t\($0.kind.rawValue)\t\(Format.seen($0.lastSeen, now: now))")
        }
      }
      return 0
    default:
      err("unknown command: \(command)\n\(usage)")
      return 64
    }
  }
}
```

`Sources/LogiJuiceCLI/main.swift`:
```swift
import Foundation
import JuiceCLIKit
import JuiceStore

let args = Array(CommandLine.arguments.dropFirst())
let code = CLI.run(
  args, snapshotURL: JuicePaths.standard().cliSnapshotURL,
  out: { print($0) },
  err: { FileHandle.standardError.write(Data(($0 + "\n").utf8)) })
exit(code)
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `swift test --filter JuiceCLIKitTests && swift build --product logijuice-cli && .build/debug/logijuice-cli status; echo "exit $?"`
Expected: tests PASS (6). The CLI prints `No data yet. Is LogiJuice running?` and `exit 1`.

- [ ] **Step 6: Commit**

```bash
git add Package.swift Sources/JuiceCLIKit Sources/LogiJuiceCLI Tests/JuiceCLIKitTests
git commit -m "Add logijuice CLI status and devices commands"
```

---

### Task 10: HID++ frames and feature parsers (Codex-ready)

The byte layouts below follow Logitech's HID++ 2.0 feature documentation as implemented by Solaar. If Task 0's `docs/bringup-notes.md` exists and disagrees with any layout, follow the notes and adjust the test bytes to match.

**Files:**
- Modify: `Package.swift`
- Create: `Sources/JuiceHID/HIDPPFrame.swift`, `Sources/JuiceHID/FeatureParsers.swift`
- Test: `Tests/JuiceHIDTests/FrameAndParserTests.swift`

**Interfaces:**
- Consumes: `BatteryLevel`, `LevelWord`, `DeviceKind` (Task 1).
- Produces:
  - `HIDPPFrame(reportID:deviceIndex:featureIndex:functionAndSoftwareID:params:)`, `init?(bytes:)`, `bytes`, `function`, `softwareID`, `isError`, `isNotification`, `static request(device:featureIndex:function:softwareID:params:)`, `static length(forReportID:)`
  - `FeatureID` (`.root` 0x0000, `.deviceInformation` 0x0003, `.deviceNameType` 0x0005, `.batteryStatus` 0x1000, `.unifiedBattery` 0x1004)
  - `BatteryReport(level:charging:)`, `DeviceInformation(unitID:serialSupported:)`, `ConnectionNotice(slot:linkUp:wpid:)`
  - `FeatureParsers`: `featureIndex(fromGetFeature:)`, `unifiedBatteryPercentSupported(_:)`, `unifiedBatteryStatus(_:percentSupported:)`, `batteryStatus(_:)`, `nameChunk(_:remaining:)`, `deviceInformation(_:)`, `serialNumber(_:)`, `connectionNotice(_:)`

- [ ] **Step 1: Add the target**

Add these to `Package.swift` `targets` (keep everything already there):
```swift
    .target(name: "JuiceHID", dependencies: ["JuiceCore"], linkerSettings: [.linkedFramework("IOKit")]),
    .testTarget(name: "JuiceHIDTests", dependencies: ["JuiceHID", "JuiceCore"]),
```

- [ ] **Step 2: Write the failing test**

`Tests/JuiceHIDTests/FrameAndParserTests.swift`:
```swift
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

  func testConnectionNotice() throws {
    let up = try XCTUnwrap(HIDPPFrame(bytes: [0x10, 0x01, 0x41, 0x10, 0x00, 0x8A, 0x40]))
    XCTAssertEqual(FeatureParsers.connectionNotice(up), ConnectionNotice(slot: 1, linkUp: true, wpid: 0x408A))
    let down = try XCTUnwrap(HIDPPFrame(bytes: [0x10, 0x02, 0x41, 0x10, 0x40, 0x8A, 0x40]))
    XCTAssertEqual(FeatureParsers.connectionNotice(down)?.linkUp, false)
    let other = try XCTUnwrap(HIDPPFrame(bytes: pad([0x11, 0x01, 0x04, 0x00, 42], to: 20)))
    XCTAssertNil(FeatureParsers.connectionNotice(other))
  }
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `swift test --filter JuiceHIDTests.FrameAndParserTests`
Expected: FAIL to compile with "cannot find 'HIDPPFrame' in scope".

- [ ] **Step 4: Implement**

`Sources/JuiceHID/HIDPPFrame.swift`:
```swift
import Foundation

/// One HID++ report: short (0x10, 7 B), long (0x11, 20 B) or very long (0x12, 64 B).
/// For HID++ 1.0 frames `featureIndex` is the sub-ID and `functionAndSoftwareID` the address.
public struct HIDPPFrame: Hashable, Sendable {
  public var reportID: UInt8
  public var deviceIndex: UInt8
  public var featureIndex: UInt8
  public var functionAndSoftwareID: UInt8
  public var params: [UInt8]

  public init(reportID: UInt8, deviceIndex: UInt8, featureIndex: UInt8, functionAndSoftwareID: UInt8,
              params: [UInt8]) {
    self.reportID = reportID
    self.deviceIndex = deviceIndex
    self.featureIndex = featureIndex
    self.functionAndSoftwareID = functionAndSoftwareID
    let count = (Self.length(forReportID: reportID) ?? 20) - 4
    self.params = Array((params + Array(repeating: 0, count: count)).prefix(count))
  }

  public init?(bytes: [UInt8]) {
    guard let first = bytes.first, let length = Self.length(forReportID: first), bytes.count >= length else {
      return nil
    }
    self.init(reportID: bytes[0], deviceIndex: bytes[1], featureIndex: bytes[2],
              functionAndSoftwareID: bytes[3], params: Array(bytes[4..<length]))
  }

  public static func length(forReportID id: UInt8) -> Int? {
    switch id {
    case 0x10: return 7
    case 0x11: return 20
    case 0x12: return 64
    default: return nil
    }
  }

  public static func request(device: UInt8, featureIndex: UInt8, function: UInt8, softwareID: UInt8,
                             params: [UInt8]) -> HIDPPFrame {
    HIDPPFrame(reportID: 0x11, deviceIndex: device, featureIndex: featureIndex,
               functionAndSoftwareID: (function << 4) | (softwareID & 0x0F), params: params)
  }

  public var bytes: [UInt8] { [reportID, deviceIndex, featureIndex, functionAndSoftwareID] + params }
  public var function: UInt8 { functionAndSoftwareID >> 4 }
  public var softwareID: UInt8 { functionAndSoftwareID & 0x0F }

  /// HID++ 2.0 error (0xFF) or HID++ 1.0 error (0x8F). Both carry: byte3 = original feature index,
  /// params[0] = original function|swID, params[1] = error code.
  public var isError: Bool { featureIndex == 0xFF || featureIndex == 0x8F }

  /// HID++ 1.0 receiver notifications such as 0x41 device connection.
  public var isNotification: Bool { reportID == 0x10 && (0x40...0x7F).contains(featureIndex) }
}
```

`Sources/JuiceHID/FeatureParsers.swift`:
```swift
import Foundation
import JuiceCore

public enum FeatureID: UInt16, Sendable {
  case root = 0x0000
  case deviceInformation = 0x0003
  case deviceNameType = 0x0005
  case batteryStatus = 0x1000
  case unifiedBattery = 0x1004
}

public struct BatteryReport: Hashable, Sendable {
  public var level: BatteryLevel
  public var charging: Bool

  public init(level: BatteryLevel, charging: Bool) {
    self.level = level
    self.charging = charging
  }
}

public struct DeviceInformation: Hashable, Sendable {
  public var unitID: String?
  public var serialSupported: Bool
}

public struct ConnectionNotice: Hashable, Sendable {
  public var slot: UInt8
  public var linkUp: Bool
  public var wpid: UInt16
}

public enum FeatureParsers {
  /// Root getFeature reply: [index, type, version]. Index 0 means "not supported".
  public static func featureIndex(fromGetFeature p: [UInt8]) -> UInt8? {
    guard let index = p.first, index != 0 else { return nil }
    return index
  }

  /// 0x1004 getCapabilities: [supported level mask, flags]; flags bit 0x02 = state of charge (%).
  public static func unifiedBatteryPercentSupported(_ p: [UInt8]) -> Bool {
    p.count >= 2 && p[1] & 0x02 != 0
  }

  /// 0x1004 getStatus / battery event: [state of charge, level mask, charging status, external power].
  public static func unifiedBatteryStatus(_ p: [UInt8], percentSupported: Bool) -> BatteryReport? {
    guard p.count >= 3 else { return nil }
    let soc = Int(p[0])
    let mask = p[1]
    let status = p[2]
    let word: LevelWord? =
      mask & 0x08 != 0 ? .full : mask & 0x04 != 0 ? .good : mask & 0x02 != 0 ? .low : mask & 0x01 != 0 ? .critical : nil
    let level: BatteryLevel
    if percentSupported, (1...100).contains(soc) {
      level = .percent(soc)
    } else if let word {
      level = .word(word)
    } else {
      return nil
    }
    return BatteryReport(level: level, charging: status == 1 || status == 2)
  }

  /// 0x1000 getBatteryLevelStatus / event: [discharge %, next level %, status].
  /// Status 0 discharging, 1 recharging, 2 almost full, 3 full, 4 slow recharge, 5+ battery error.
  public static func batteryStatus(_ p: [UInt8]) -> BatteryReport? {
    guard p.count >= 3, p[2] <= 4 else { return nil }
    let status = p[2]
    if status == 3 { return BatteryReport(level: .percent(100), charging: false) }
    let percent = Int(p[0])
    guard (1...100).contains(percent) else { return nil }
    return BatteryReport(level: .percent(percent), charging: [1, 2, 4].contains(status))
  }

  /// 0x0005 getDeviceName chunk: ASCII bytes, stop at NUL or `remaining`.
  public static func nameChunk(_ p: [UInt8], remaining: Int) -> String {
    let bytes = p.prefix(max(0, remaining)).prefix { $0 != 0 }
    return String(decoding: bytes, as: UTF8.self)
  }

  /// 0x0003 getDeviceInfo: [entityCount, unitID×4, transport×2, modelID×6, extendedModelID, capabilities].
  public static func deviceInformation(_ p: [UInt8]) -> DeviceInformation? {
    guard p.count >= 15 else { return nil }
    let unit = p[1...4]
    let unitID = unit.allSatisfy({ $0 == 0 }) ? nil : unit.map { String(format: "%02X", $0) }.joined()
    return DeviceInformation(unitID: unitID, serialSupported: p[14] & 0x01 != 0)
  }

  /// 0x0003 getSerialNumber: 12 ASCII characters.
  public static func serialNumber(_ p: [UInt8]) -> String? {
    let text = String(decoding: p.prefix(12).prefix { $0 != 0 }, as: UTF8.self)
      .trimmingCharacters(in: .whitespaces)
    return text.isEmpty ? nil : text
  }

  /// HID++ 1.0 device connection notification: [0x10, slot, 0x41, protocol, flags, wpidLo, wpidHi].
  /// flags bit 0x40 set = link NOT established.
  public static func connectionNotice(_ f: HIDPPFrame) -> ConnectionNotice? {
    guard f.reportID == 0x10, f.featureIndex == 0x41, (1...6).contains(f.deviceIndex), f.params.count >= 3 else {
      return nil
    }
    return ConnectionNotice(slot: f.deviceIndex, linkUp: f.params[0] & 0x40 == 0,
                            wpid: UInt16(f.params[2]) << 8 | UInt16(f.params[1]))
  }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `swift test --filter JuiceHIDTests.FrameAndParserTests`
Expected: PASS (13 tests).

- [ ] **Step 6: Commit**

```bash
git add Package.swift Sources/JuiceHID Tests/JuiceHIDTests
git commit -m "Add HID++ frame codec and feature parsers"
```

---

### Task 11: Request broker (Codex-ready)

**Files:**
- Create: `Sources/JuiceHID/RequestBroker.swift`
- Test: `Tests/JuiceHIDTests/RequestBrokerTests.swift`, `Tests/JuiceHIDTests/FakeChannel.swift`

**Interfaces:**
- Consumes: `HIDPPFrame` (Task 10).
- Produces:
  - `protocol ReportChannel: AnyObject, Sendable { func send(_ bytes: [UInt8]) throws; func setReportHandler(_ handler: @escaping @Sendable ([UInt8]) -> Void) }`
  - `HIDPPError` (`.timeout`, `.sendFailed`, `.closed`, `.protocolError(code: UInt8)`)
  - `actor RequestBroker`:
    - `init(channel:softwareID:)` (default software ID `0x0A`)
    - `nonisolated start()`
    - `request(device:featureIndex:function:params:timeout:) async throws -> [UInt8]` (returns the reply params, 16 bytes for a long reply)
    - `nonisolated events: AsyncStream<HIDPPFrame>` (software-ID-0 frames and receiver notifications)
    - `close()`
  - Requests are serialized. A reply with a foreign software ID is ignored.

- [ ] **Step 1: Write the test helper and the failing test**

`Tests/JuiceHIDTests/FakeChannel.swift`:
```swift
import Foundation
@testable import JuiceHID

/// In-memory ReportChannel. `responder` maps each sent report to the reports the "receiver" sends back.
final class FakeChannel: ReportChannel, @unchecked Sendable {
  private let lock = NSLock()
  private var handler: (@Sendable ([UInt8]) -> Void)?
  private var _sent: [[UInt8]] = []
  var responder: (([UInt8]) -> [[UInt8]])?
  var failSends = false

  var sent: [[UInt8]] { lock.withLock { _sent } }

  func send(_ bytes: [UInt8]) throws {
    if failSends { throw HIDPPError.sendFailed }
    lock.withLock { _sent.append(bytes) }
    for reply in responder?(bytes) ?? [] { inject(reply) }
  }

  func setReportHandler(_ handler: @escaping @Sendable ([UInt8]) -> Void) {
    lock.withLock { self.handler = handler }
  }

  func inject(_ bytes: [UInt8]) {
    let h = lock.withLock { handler }
    h?(bytes)
  }
}

func long(_ b: [UInt8]) -> [UInt8] { b + Array(repeating: 0, count: 20 - b.count) }
```

`Tests/JuiceHIDTests/RequestBrokerTests.swift`:
```swift
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter JuiceHIDTests.RequestBrokerTests`
Expected: FAIL to compile with "cannot find type 'ReportChannel' in scope".

- [ ] **Step 3: Implement**

`Sources/JuiceHID/RequestBroker.swift`:
```swift
import Foundation

public protocol ReportChannel: AnyObject, Sendable {
  func send(_ bytes: [UInt8]) throws
  func setReportHandler(_ handler: @escaping @Sendable ([UInt8]) -> Void)
}

public enum HIDPPError: Error, Equatable, Sendable {
  case timeout
  case sendFailed
  case closed
  case protocolError(code: UInt8)
}

/// Serializes HID++ requests on one receiver and routes replies by software ID, so logijuice
/// coexists with Logi Options+ on the same non-exclusively opened device (spec §3).
public actor RequestBroker {
  public static let defaultSoftwareID: UInt8 = 0x0A

  public nonisolated let events: AsyncStream<HIDPPFrame>
  public let softwareID: UInt8

  private let channel: ReportChannel
  private let eventSink: AsyncStream<HIDPPFrame>.Continuation
  private let inbound: AsyncStream<[UInt8]>
  private let inboundSink: AsyncStream<[UInt8]>.Continuation
  private var pending: Pending?
  private var nextToken = 0
  private var inFlight = false
  private var waiters: [CheckedContinuation<Void, Never>] = []
  private var closed = false
  private var pump: Task<Void, Never>?

  private struct Pending {
    let token: Int
    let device: UInt8
    let featureIndex: UInt8
    let functionAndSoftwareID: UInt8
    let continuation: CheckedContinuation<[UInt8], Error>
  }

  public init(channel: ReportChannel, softwareID: UInt8 = RequestBroker.defaultSoftwareID) {
    precondition((1...0x0F).contains(softwareID), "software ID must be 1...15")
    self.channel = channel
    self.softwareID = softwareID
    let (events, eventSink) = AsyncStream.makeStream(of: HIDPPFrame.self)
    self.events = events
    self.eventSink = eventSink
    let (inbound, inboundSink) = AsyncStream.makeStream(of: [UInt8].self)
    self.inbound = inbound
    self.inboundSink = inboundSink
    channel.setReportHandler { bytes in inboundSink.yield(bytes) }
  }

  /// Begins consuming inbound reports in arrival order. Reports received earlier are buffered.
  public nonisolated func start() {
    Task { await self.beginPump() }
  }

  private func beginPump() {
    guard pump == nil, !closed else { return }
    let stream = inbound
    pump = Task { [weak self] in
      for await bytes in stream { await self?.handle(bytes) }
    }
  }

  public func request(device: UInt8, featureIndex: UInt8, function: UInt8, params: [UInt8] = [],
                      timeout: Duration = .seconds(2)) async throws -> [UInt8] {
    await acquire()
    defer { release() }
    if closed { throw HIDPPError.closed }
    let frame = HIDPPFrame.request(device: device, featureIndex: featureIndex, function: function,
                                   softwareID: softwareID, params: params)
    nextToken += 1
    let token = nextToken
    return try await withCheckedThrowingContinuation { continuation in
      pending = Pending(token: token, device: device, featureIndex: featureIndex,
                        functionAndSoftwareID: frame.functionAndSoftwareID, continuation: continuation)
      do {
        try channel.send(frame.bytes)
      } catch {
        pending = nil
        continuation.resume(throwing: HIDPPError.sendFailed)
        return
      }
      Task { [weak self] in
        try? await Task.sleep(for: timeout)
        await self?.expire(token)
      }
    }
  }

  public func close() {
    closed = true
    if let p = pending {
      pending = nil
      p.continuation.resume(throwing: HIDPPError.closed)
    }
    pump?.cancel()
    inboundSink.finish()
    eventSink.finish()
  }

  func handle(_ bytes: [UInt8]) {
    guard let frame = HIDPPFrame(bytes: bytes) else { return }
    if let p = pending, Self.matches(frame, p) {
      pending = nil
      if frame.isError {
        p.continuation.resume(throwing: HIDPPError.protocolError(code: frame.params.count > 1 ? frame.params[1] : 0))
      } else {
        p.continuation.resume(returning: frame.params)
      }
      return
    }
    if frame.isNotification || (frame.softwareID == 0 && !frame.isError) {
      eventSink.yield(frame)
    }
  }

  private func expire(_ token: Int) {
    guard let p = pending, p.token == token else { return }
    pending = nil
    p.continuation.resume(throwing: HIDPPError.timeout)
  }

  private static func matches(_ f: HIDPPFrame, _ p: Pending) -> Bool {
    guard f.deviceIndex == p.device else { return false }
    if f.isError {
      return f.functionAndSoftwareID == p.featureIndex && f.params.first == p.functionAndSoftwareID
    }
    return f.featureIndex == p.featureIndex && f.functionAndSoftwareID == p.functionAndSoftwareID
  }

  private func acquire() async {
    if !inFlight {
      inFlight = true
      return
    }
    await withCheckedContinuation { waiters.append($0) }
  }

  private func release() {
    if waiters.isEmpty {
      inFlight = false
    } else {
      waiters.removeFirst().resume()
    }
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `swift test --filter JuiceHIDTests.RequestBrokerTests`
Expected: PASS (8 tests). If the compiler rejects mutating `pending` inside the `withCheckedThrowingContinuation` closure, add `isolation: #isolation` as the first argument (Swift 6 toolchains support it), then rerun.

- [ ] **Step 5: Commit**

```bash
git add Sources/JuiceHID/RequestBroker.swift Tests/JuiceHIDTests
git commit -m "Add HID++ request broker with software-ID routing"
```

---

### Task 12: Receiver session (Codex-ready)

**Files:**
- Create: `Sources/JuiceHID/ReceiverSession.swift`
- Test: `Tests/JuiceHIDTests/ReceiverSessionTests.swift`

**Interfaces:**
- Consumes: `RequestBroker`, `FeatureParsers`, `FeatureID`, `BatteryReport`, `DeviceInfo`, `DeviceID`, `DeviceKind` (Tasks 1, 10, 11).
- Produces:
  - `BatteryFeature` (`.unified(index: UInt8, percent: Bool)`, `.legacy(index: UInt8)`, `.none`)
  - `SlotInfo(slot:info:battery:)`
  - `SessionEvent` (`.battery(slot: UInt8, BatteryReport)`, `.linkUp(slot: UInt8)`, `.linkDown(slot: UInt8)`), Equatable
  - `actor ReceiverSession(broker:)`, with `identify(slot:) async -> SlotInfo?`, `readBattery(_:) async -> BatteryReport?`, and `static interpret(_:slots:) -> SessionEvent?`

- [ ] **Step 1: Write the failing test**

`Tests/JuiceHIDTests/ReceiverSessionTests.swift`:
```swift
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `swift test --filter JuiceHIDTests.ReceiverSessionTests`
Expected: FAIL to compile with "cannot find 'ReceiverSession' in scope".

- [ ] **Step 3: Implement**

`Sources/JuiceHID/ReceiverSession.swift`:
```swift
import Foundation
import JuiceCore

public enum BatteryFeature: Hashable, Sendable {
  case unified(index: UInt8, percent: Bool)
  case legacy(index: UInt8)
  case none
}

public struct SlotInfo: Hashable, Sendable {
  public var slot: UInt8
  public var info: DeviceInfo
  public var battery: BatteryFeature

  public init(slot: UInt8, info: DeviceInfo, battery: BatteryFeature) {
    self.slot = slot
    self.info = info
    self.battery = battery
  }
}

public enum SessionEvent: Hashable, Sendable {
  case battery(slot: UInt8, BatteryReport)
  case linkUp(slot: UInt8)
  case linkDown(slot: UInt8)
}

/// Identifies paired devices and reads their batteries. Getter functions only (read-only, spec §1).
public actor ReceiverSession {
  private let broker: RequestBroker

  public init(broker: RequestBroker) { self.broker = broker }

  /// nil when the slot is empty or the device is asleep (no reply / error).
  public func identify(slot: UInt8) async -> SlotInfo? {
    guard (try? await broker.request(device: slot, featureIndex: 0, function: 1, params: [0, 0, 0x5A])) != nil else {
      return nil
    }

    var name = "Logitech device \(slot)"
    var kind = DeviceKind.other
    if let idx = await featureIndex(slot, .deviceNameType) {
      if let countParams = try? await broker.request(device: slot, featureIndex: idx, function: 0),
        let count = countParams.first, count > 0
      {
        var text = ""
        while text.utf8.count < Int(count) {
          guard let chunk = try? await broker.request(device: slot, featureIndex: idx, function: 1,
                                                      params: [UInt8(text.utf8.count)]) else { break }
          let part = FeatureParsers.nameChunk(chunk, remaining: Int(count) - text.utf8.count)
          if part.isEmpty { break }
          text += part
        }
        if !text.isEmpty { name = text }
      }
      if let t = try? await broker.request(device: slot, featureIndex: idx, function: 2), let v = t.first {
        kind = DeviceKind(hidppType: v)
      }
    }

    var id = DeviceID.slot(wpid: 0, slot: slot)
    if let idx = await featureIndex(slot, .deviceInformation),
      let p = try? await broker.request(device: slot, featureIndex: idx, function: 0),
      let info = FeatureParsers.deviceInformation(p)
    {
      if info.serialSupported,
        let sp = try? await broker.request(device: slot, featureIndex: idx, function: 2),
        let serial = FeatureParsers.serialNumber(sp)
      {
        id = .serial(serial)
      } else if let unit = info.unitID {
        id = .unit(unit)
      }
    }

    var battery = BatteryFeature.none
    if let idx = await featureIndex(slot, .unifiedBattery) {
      let caps = try? await broker.request(device: slot, featureIndex: idx, function: 0)
      battery = .unified(index: idx, percent: caps.map(FeatureParsers.unifiedBatteryPercentSupported) ?? false)
    } else if let idx = await featureIndex(slot, .batteryStatus) {
      battery = .legacy(index: idx)
    }

    return SlotInfo(slot: slot, info: DeviceInfo(id: id, name: name, kind: kind), battery: battery)
  }

  public func readBattery(_ slot: SlotInfo) async -> BatteryReport? {
    switch slot.battery {
    case .unified(let idx, let percent):
      guard let p = try? await broker.request(device: slot.slot, featureIndex: idx, function: 1) else { return nil }
      return FeatureParsers.unifiedBatteryStatus(p, percentSupported: percent)
    case .legacy(let idx):
      guard let p = try? await broker.request(device: slot.slot, featureIndex: idx, function: 0) else { return nil }
      return FeatureParsers.batteryStatus(p)
    case .none:
      return nil
    }
  }

  /// Maps an unsolicited frame (from `RequestBroker.events`) to a session event.
  public static func interpret(_ frame: HIDPPFrame, slots: [UInt8: SlotInfo]) -> SessionEvent? {
    if let notice = FeatureParsers.connectionNotice(frame) {
      return notice.linkUp ? .linkUp(slot: notice.slot) : .linkDown(slot: notice.slot)
    }
    guard frame.softwareID == 0, frame.function == 0, let s = slots[frame.deviceIndex] else { return nil }
    switch s.battery {
    case .unified(let idx, let percent) where frame.featureIndex == idx:
      return FeatureParsers.unifiedBatteryStatus(frame.params, percentSupported: percent).map { .battery(slot: s.slot, $0) }
    case .legacy(let idx) where frame.featureIndex == idx:
      return FeatureParsers.batteryStatus(frame.params).map { .battery(slot: s.slot, $0) }
    default:
      return nil
    }
  }

  private func featureIndex(_ slot: UInt8, _ feature: FeatureID) async -> UInt8? {
    let id = feature.rawValue
    guard let p = try? await broker.request(device: slot, featureIndex: 0, function: 0,
                                            params: [UInt8(id >> 8), UInt8(id & 0xFF)]) else { return nil }
    return FeatureParsers.featureIndex(fromGetFeature: p)
  }
}
```

- [ ] **Step 4: Run all HID tests to verify they pass**

Run: `swift test --filter JuiceHIDTests`
Expected: PASS (all, including 6 new).

- [ ] **Step 5: Commit**

```bash
git add Sources/JuiceHID/ReceiverSession.swift Tests/JuiceHIDTests/ReceiverSessionTests.swift
git commit -m "Add receiver session: identify devices, read and interpret battery"
```

---

### Task 13: IOHID channel, receiver monitor, `debug capture`, real fixtures (Mac + hardware)

**Files:**
- Create: `Sources/JuiceHID/IOHIDReceiver.swift`, `Sources/JuiceCLIKit/DebugCapture.swift`
- Modify: `Package.swift` (JuiceCLIKit gains a `JuiceHID` dependency), `Sources/LogiJuiceCLI/main.swift`
- Create: `Tests/JuiceHIDTests/Fixtures/owner-mouse.json` (recorded), `Tests/JuiceHIDTests/ReplayTests.swift`

**Interfaces:**
- Consumes: `ReportChannel`, `HIDPPError`, `RequestBroker`, `ReceiverSession` (Tasks 11–12), plus `docs/bringup-notes.md` (Task 0).
- Produces:
  - `HIDPPInterface` (`vendorID`, `receiverProductIDs`, `usagePage`)
  - `IOHIDReceiverChannel(devices:) throws` (a `ReportChannel`; `devices`, `close()`)
  - `ReceiverMonitor()` with `onArrive: ((IOHIDReceiverChannel) -> Void)?`, `onDepart: (() -> Void)?`, `start()`
  - `DebugCapture.run(arguments:) -> Int32`

- [ ] **Step 1: Implement the IOHID channel and monitor**

`Sources/JuiceHID/IOHIDReceiver.swift`:
```swift
import Foundation
import IOKit.hid

public enum HIDPPInterface {
  public static let vendorID = 0x046D
  /// Bolt, Unifying, Unifying (newer).
  public static let receiverProductIDs = [0xC548, 0xC52B, 0xC532]
  public static let usagePage = 0xFF00
  static let shortUsage = 0x0001
  static let longUsage = 0x0002
}

private func intProperty(_ d: IOHIDDevice, _ key: String) -> Int {
  (IOHIDDeviceGetProperty(d, key as CFString) as? Int) ?? -1
}

/// All vendor-page collections of one physical receiver. Opened non-exclusively (coexists with Options+).
public final class IOHIDReceiverChannel: ReportChannel, @unchecked Sendable {
  public let devices: [IOHIDDevice]
  private let lock = NSLock()
  private var handler: (@Sendable ([UInt8]) -> Void)?
  private var buffers: [UnsafeMutablePointer<UInt8>] = []
  private var opened: [IOHIDDevice] = []

  public init(devices: [IOHIDDevice]) throws {
    self.devices = devices
    let context = Unmanaged.passUnretained(self).toOpaque()
    for device in devices {
      guard IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else { continue }
      let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
      buffers.append(buffer)
      opened.append(device)
      IOHIDDeviceRegisterInputReportCallback(device, buffer, 64, { ctx, _, _, _, reportID, report, length in
        guard let ctx else { return }
        let channel = Unmanaged<IOHIDReceiverChannel>.fromOpaque(ctx).takeUnretainedValue()
        var bytes = Array(UnsafeBufferPointer(start: report, count: length))
        if bytes.first != UInt8(truncatingIfNeeded: reportID) { bytes.insert(UInt8(truncatingIfNeeded: reportID), at: 0) }
        channel.deliver(bytes)
      }, context)
      IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
    }
    guard !opened.isEmpty else { throw HIDPPError.sendFailed }
  }

  deinit {
    close()
    buffers.forEach { $0.deallocate() }
  }

  public func send(_ bytes: [UInt8]) throws {
    guard let first = bytes.first else { throw HIDPPError.sendFailed }
    let wanted = first == 0x10 ? HIDPPInterface.shortUsage : HIDPPInterface.longUsage
    guard let target = opened.first(where: { intProperty($0, kIOHIDPrimaryUsageKey) == wanted }) ?? opened.first else {
      throw HIDPPError.closed
    }
    let result = IOHIDDeviceSetReport(target, kIOHIDReportTypeOutput, CFIndex(first), bytes, bytes.count)
    guard result == kIOReturnSuccess else { throw HIDPPError.sendFailed }
  }

  public func setReportHandler(_ handler: @escaping @Sendable ([UInt8]) -> Void) {
    lock.withLock { self.handler = handler }
  }

  public func close() {
    for device in opened {
      IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
      IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
    }
    opened = []
  }

  private func deliver(_ bytes: [UInt8]) {
    let h = lock.withLock { handler }
    h?(bytes)
  }
}

/// Watches for the receiver arriving and leaving (the hub switching Macs). Main run loop only.
public final class ReceiverMonitor {
  public var onArrive: ((IOHIDReceiverChannel) -> Void)?
  public var onDepart: (() -> Void)?

  private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
  private var matched: [IOHIDDevice] = []
  private var channel: IOHIDReceiverChannel?
  private var settle: DispatchWorkItem?

  public init() {}

  public func start() {
    let criteria = HIDPPInterface.receiverProductIDs.map {
      [kIOHIDVendorIDKey: HIDPPInterface.vendorID, kIOHIDProductIDKey: $0,
       kIOHIDDeviceUsagePageKey: HIDPPInterface.usagePage] as [String: Any]
    }
    IOHIDManagerSetDeviceMatchingMultiple(manager, criteria as CFArray)
    let context = Unmanaged.passUnretained(self).toOpaque()
    IOHIDManagerRegisterDeviceMatchingCallback(manager, { ctx, _, _, device in
      guard let ctx else { return }
      Unmanaged<ReceiverMonitor>.fromOpaque(ctx).takeUnretainedValue().added(device)
    }, context)
    IOHIDManagerRegisterDeviceRemovalCallback(manager, { ctx, _, _, device in
      guard let ctx else { return }
      Unmanaged<ReceiverMonitor>.fromOpaque(ctx).takeUnretainedValue().removed(device)
    }, context)
    IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
    IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
  }

  private func added(_ device: IOHIDDevice) {
    matched.append(device)
    // Collections of one receiver arrive one by one; wait for them to settle.
    settle?.cancel()
    let work = DispatchWorkItem { [weak self] in self?.emit() }
    settle = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
  }

  private func emit() {
    guard channel == nil, let first = matched.first else { return }
    let location = intProperty(first, kIOHIDLocationIDKey)
    let group = matched.filter { intProperty($0, kIOHIDLocationIDKey) == location }
    guard let ch = try? IOHIDReceiverChannel(devices: group) else { return }
    channel = ch
    onArrive?(ch)
  }

  private func removed(_ device: IOHIDDevice) {
    matched.removeAll { $0 == device }
    if let ch = channel, ch.devices.contains(device) {
      ch.close()
      channel = nil
      onDepart?()
      if !matched.isEmpty { emit() }  // a second receiver was also attached
    }
  }
}
```

If `docs/bringup-notes.md` shows a single collection carrying both report IDs, no code change is needed: `send` falls back to the first opened device. If it shows the report ID is **not** byte 0 of `IN` data, the prepend in the callback already handles it.

- [ ] **Step 2: Implement `debug capture`**

`Package.swift`: change the JuiceCLIKit target to
```swift
    .target(name: "JuiceCLIKit", dependencies: ["JuiceCore", "JuiceStore", "JuiceHID"]),
```

`Sources/JuiceCLIKit/DebugCapture.swift`:
```swift
import Foundation
import JuiceHID

/// `logijuice debug capture [--seconds N] [--out FILE] [--probe]` — records raw HID++ frames (spec §3).
public enum DebugCapture {
  struct Frame: Codable {
    var t: Double
    var dir: String
    var hex: String
  }

  struct Capture: Codable {
    var capturedAt: Date
    var frames: [Frame]
  }

  final class Log: @unchecked Sendable {
    private let lock = NSLock()
    private let start = Date()
    private(set) var frames: [Frame] = []

    func add(_ dir: String, _ bytes: [UInt8]) {
      let frame = Frame(t: Date().timeIntervalSince(start), dir: dir,
                        hex: bytes.map { String(format: "%02X", $0) }.joined(separator: " "))
      lock.withLock { frames.append(frame) }
      print("\(dir) \(frame.hex)")
    }

    var snapshot: [Frame] { lock.withLock { frames } }
  }

  final class RecordingChannel: ReportChannel, @unchecked Sendable {
    let inner: ReportChannel
    let log: Log

    init(inner: ReportChannel, log: Log) {
      self.inner = inner
      self.log = log
    }

    func send(_ bytes: [UInt8]) throws {
      log.add("out", bytes)
      try inner.send(bytes)
    }

    func setReportHandler(_ handler: @escaping @Sendable ([UInt8]) -> Void) {
      let log = self.log
      inner.setReportHandler { bytes in
        log.add("in", bytes)
        handler(bytes)
      }
    }
  }

  public static func run(arguments: [String]) -> Int32 {
    func value(_ flag: String) -> String? {
      guard let i = arguments.firstIndex(of: flag), i + 1 < arguments.count else { return nil }
      return arguments[i + 1]
    }
    let seconds = Double(value("--seconds") ?? "30") ?? 30
    let out = URL(fileURLWithPath: value("--out") ?? "logijuice-capture.json")
    let probe = arguments.contains("--probe")
    let log = Log()
    let monitor = ReceiverMonitor()
    var keepAlive: [AnyObject] = []

    monitor.onArrive = { channel in
      let recorder = RecordingChannel(inner: channel, log: log)
      keepAlive.append(recorder)
      if probe {
        let broker = RequestBroker(channel: recorder)
        broker.start()
        let session = ReceiverSession(broker: broker)
        Task {
          for slot in UInt8(1)...6 {
            if let info = await session.identify(slot: slot) {
              print("slot \(slot): \(info.info.name) \(info.info.kind) \(info.info.id) \(info.battery)")
              print("battery:", String(describing: await session.readBattery(info)))
            }
          }
        }
        keepAlive.append(broker)
      } else {
        recorder.setReportHandler { _ in }
      }
    }
    monitor.onDepart = { print("receiver departed") }
    monitor.start()
    print("Capturing for \(Int(seconds)) s… (Ctrl-C to abort)")
    RunLoop.main.run(until: Date().addingTimeInterval(seconds))

    do {
      try FileManager.default.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      encoder.dateEncodingStrategy = .iso8601
      try encoder.encode(Capture(capturedAt: Date(), frames: log.snapshot)).write(to: out)
      print("Wrote \(log.snapshot.count) frames to \(out.path)")
      return 0
    } catch {
      FileHandle.standardError.write(Data("Could not write capture: \(error)\n".utf8))
      return 1
    }
  }
}
```

`Sources/LogiJuiceCLI/main.swift` (replace):
```swift
import Foundation
import JuiceCLIKit
import JuiceStore

let args = Array(CommandLine.arguments.dropFirst())
if args.starts(with: ["debug", "capture"]) {
  exit(DebugCapture.run(arguments: Array(args.dropFirst(2))))
}
let code = CLI.run(
  args, snapshotURL: JuicePaths.standard().cliSnapshotURL,
  out: { print($0) },
  err: { FileHandle.standardError.write(Data(($0 + "\n").utf8)) })
exit(code)
```

- [ ] **Step 3: Build and run a live probe against the owner's receiver**

Run: `swift build --product logijuice-cli && .build/debug/logijuice-cli debug capture --seconds 20 --probe --out Tests/JuiceHIDTests/Fixtures/owner-mouse.json`
Expected: a line per paired device such as `slot 1: MX Master 3S mouse sn:… unified(index: 8, percent: true)`, then `battery: Optional(BatteryReport(level: .percent(NN), charging: false))`. If the mouse is asleep, move it and rerun. Logi Options+ keeps working while this runs: check that its window still shows the battery.

If identify returns nil for an awake device, compare the `out`/`in` lines with `docs/bringup-notes.md` and fix the parser or layout in Task 10/12 (with its test) before continuing.

- [ ] **Step 4: Write a replay test from the recorded capture**

`Tests/JuiceHIDTests/ReplayTests.swift`:
```swift
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
```

Add the fixture resources to the test target in `Package.swift`:
```swift
    .testTarget(name: "JuiceHIDTests", dependencies: ["JuiceHID", "JuiceCore"], resources: [.copy("Fixtures")]),
```

Note: identify sends requests in a fixed order, so it re-issues the same `out` frames as the probe. The ReplayChannel matches by exact bytes, which is why the recording used `--probe`.

- [ ] **Step 5: Run the full test suite**

Run: `swift test`
Expected: PASS (all targets, including `ReplayTests`).

- [ ] **Step 6: Commit**

```bash
git add Package.swift Sources Tests/JuiceHIDTests
git commit -m "Add IOHID receiver channel, hotplug monitor, debug capture and real-device replay test"
```

---

### Task 14: App shell (Mac + hardware)

**Files:**
- Modify: `Package.swift`
- Create: `App/LogiJuiceApp.swift`, `App/AppModel.swift`, `App/HIDCoordinator.swift`, `App/Notifier.swift`, `App/MomentMonitor.swift`, `App/MenuContent.swift`, `App/SettingsWindow.swift`, `App/OptionsPlus.swift`
- Create: `Config/LogiJuice.entitlements`, `scripts/build-app.sh`

**Interfaces:**
- Consumes: everything in `JuiceCore`, `JuiceStore`, `JuiceHID`.
- Produces (used by Tasks 15–18):
  - `AppModel.shared`, with `settings` (published, settable), `snapshot` (published), `receiverPresent`, `notifier`, `mergedRecords`, `menuBarVisible`, `iconTinted`
  - Methods: `setNickname(_:for:)`, `alertOverride(for:) -> AlertProfile?`, `setAlertOverride(_:for:)`, `publish()`, `saveNow()`, `simulateLowBattery(percent:)`
  - `SettingsWindowController.shared.show()`, `OptionsPlus.isInstalled` / `.open()`
  - App bundle at `dist/LogiJuice.app`

- [ ] **Step 1: Add the app target**

`Package.swift` (full; merge any targets from parallel tasks):
```swift
// swift-tools-version: 5.10
import PackageDescription

let package = Package(
  name: "LogiJuice",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "LogiJuice", targets: ["LogiJuice"]),
    .executable(name: "logijuice-cli", targets: ["LogiJuiceCLI"]),
  ],
  targets: [
    .target(name: "JuiceCore"),
    .target(name: "JuiceStore", dependencies: ["JuiceCore"], linkerSettings: [.linkedFramework("IOKit")]),
    .target(name: "JuiceHID", dependencies: ["JuiceCore"], linkerSettings: [.linkedFramework("IOKit")]),
    .target(name: "JuiceCLIKit", dependencies: ["JuiceCore", "JuiceStore", "JuiceHID"]),
    .executableTarget(name: "LogiJuiceCLI", dependencies: ["JuiceCLIKit", "JuiceStore"]),
    .executableTarget(
      name: "LogiJuice",
      dependencies: ["JuiceCore", "JuiceStore", "JuiceHID"],
      path: "App",
      linkerSettings: [
        .linkedFramework("WidgetKit"), .linkedFramework("ServiceManagement"),
        .linkedFramework("UserNotifications"),
      ]),
    .testTarget(name: "JuiceCoreTests", dependencies: ["JuiceCore"]),
    .testTarget(name: "JuiceStoreTests", dependencies: ["JuiceStore", "JuiceCore"]),
    .testTarget(name: "JuiceCLIKitTests", dependencies: ["JuiceCLIKit", "JuiceStore", "JuiceCore"]),
    .testTarget(name: "JuiceHIDTests", dependencies: ["JuiceHID", "JuiceCore"], resources: [.copy("Fixtures")]),
  ]
)
```

- [ ] **Step 2: Write the app sources**

`App/OptionsPlus.swift`:
```swift
import AppKit

enum OptionsPlus {
  static let url = URL(fileURLWithPath: "/Applications/logioptionsplus.app")
  static var isInstalled: Bool { FileManager.default.fileExists(atPath: url.path) }
  static func open() { NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) }
}
```

`App/Notifier.swift`:
```swift
import AppKit
import JuiceCore
import UserNotifications

@MainActor
final class Notifier: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
  static let categoryID = "logijuice.battery"
  @Published private(set) var authorized = true
  var onSnooze: ((DeviceID) -> Void)?
  private let center = UNUserNotificationCenter.current()

  func start() {
    center.delegate = self
    var actions = [UNNotificationAction(identifier: "snooze", title: "Snooze 1 day")]
    if OptionsPlus.isInstalled {
      actions.append(UNNotificationAction(identifier: "openOptions", title: "Open Logi Options+", options: [.foreground]))
    }
    center.setNotificationCategories([
      UNNotificationCategory(identifier: Self.categoryID, actions: actions, intentIdentifiers: [])
    ])
    center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
      Task { @MainActor in self.authorized = granted }
    }
  }

  func refreshAuthorization() {
    center.getNotificationSettings { settings in
      let ok = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
      Task { @MainActor in self.authorized = ok }
    }
  }

  func post(_ text: NotificationText, device: DeviceID) {
    let content = UNMutableNotificationContent()
    content.title = text.title
    content.body = text.body
    content.sound = .default
    content.categoryIdentifier = Self.categoryID
    content.userInfo = ["device": device.rawValue]
    center.add(UNNotificationRequest(identifier: text.identifier, content: content, trigger: nil))
  }

  nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                          willPresent notification: UNNotification) async
    -> UNNotificationPresentationOptions
  {
    [.banner, .sound]
  }

  nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                          didReceive response: UNNotificationResponse) async {
    let raw = response.notification.request.content.userInfo["device"] as? String
    let action = response.actionIdentifier
    await MainActor.run {
      switch action {
      case "snooze": if let raw { self.onSnooze?(DeviceID(raw)) }
      case "openOptions": OptionsPlus.open()
      default: SettingsWindowController.shared.show()
      }
    }
  }
}
```

`App/MomentMonitor.swift`:
```swift
import AppKit
import JuiceCore

/// Turns system signals into natural moments for the nudge scheduler (spec §4).
@MainActor
final class MomentMonitor {
  var onMoment: ((Moment) -> Void)?
  private var observers: [NSObjectProtocol] = []
  private var endOfDayTimer: Timer?

  func start(endOfDayHour: Int, minute: Int) {
    observers.append(DistributedNotificationCenter.default().addObserver(
      forName: Notification.Name("com.apple.screenIsLocked"), object: nil, queue: .main
    ) { [weak self] _ in MainActor.assumeIsolated { self?.onMoment?(.screenLocked) } })
    let workspace = NSWorkspace.shared.notificationCenter
    for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification] {
      observers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
        MainActor.assumeIsolated { self?.onMoment?(.willSleep) }
      })
    }
    reschedule(endOfDayHour: endOfDayHour, minute: minute)
  }

  func reschedule(endOfDayHour: Int, minute: Int) {
    endOfDayTimer?.invalidate()
    let fire = NudgeScheduler.nextEndOfDay(after: Date(), hour: endOfDayHour, minute: minute, calendar: .current)
    let timer = Timer(fire: fire, interval: 0, repeats: false) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.onMoment?(.endOfDay)
        self?.reschedule(endOfDayHour: endOfDayHour, minute: minute)
      }
    }
    RunLoop.main.add(timer, forMode: .common)
    endOfDayTimer = timer
  }
}
```

`App/HIDCoordinator.swift`:
```swift
import Foundation
import JuiceCore
import JuiceHID
import os

/// Owns the receiver connection: attach/detach on hotplug, identify slots, emit readings.
@MainActor
final class HIDCoordinator {
  var onReading: ((Reading, DeviceInfo) -> Void)?
  var onReceiverChange: ((Bool) -> Void)?

  private let log = Logger(subsystem: "com.penguinspecz.logijuice", category: "hid")
  private let monitor = ReceiverMonitor()
  private var broker: RequestBroker?
  private var session: ReceiverSession?
  private var slots: [UInt8: SlotInfo] = [:]
  private var eventTask: Task<Void, Never>?
  private var safetyTimer: Timer?

  func start() {
    monitor.onArrive = { [weak self] channel in MainActor.assumeIsolated { self?.attach(channel) } }
    monitor.onDepart = { [weak self] in MainActor.assumeIsolated { self?.detach() } }
    monitor.start()
    safetyTimer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.refreshAll() }
    }
  }

  func refreshAll() {
    Task { await self.scan() }
  }

  private func attach(_ channel: IOHIDReceiverChannel) {
    log.info("receiver attached")
    let broker = RequestBroker(channel: channel)
    broker.start()
    self.broker = broker
    session = ReceiverSession(broker: broker)
    onReceiverChange?(true)
    eventTask = Task { [weak self] in
      for await frame in broker.events { await self?.handle(frame) }
    }
    refreshAll()
  }

  private func detach() {
    log.info("receiver departed")
    eventTask?.cancel()
    eventTask = nil
    if let broker { Task { await broker.close() } }
    broker = nil
    session = nil
    slots = [:]
    onReceiverChange?(false)
  }

  private func scan() async {
    guard let session else { return }
    for slot in UInt8(1)...6 where slots[slot] == nil {
      if let info = await session.identify(slot: slot) {
        log.info("slot \(slot): \(info.info.name, privacy: .public) \(info.info.id.rawValue, privacy: .public)")
        slots[slot] = info
      }
    }
    for info in slots.values.sorted(by: { $0.slot < $1.slot }) { await read(info) }
  }

  private func read(_ info: SlotInfo) async {
    guard let session, let report = await session.readBattery(info) else { return }
    emit(report, info)
  }

  private func emit(_ report: BatteryReport, _ info: SlotInfo) {
    onReading?(Reading(device: info.info.id, level: report.level, charging: report.charging, observedAt: Date()), info.info)
  }

  private func handle(_ frame: HIDPPFrame) async {
    switch ReceiverSession.interpret(frame, slots: slots) {
    case .battery(let slot, let report)?:
      if let info = slots[slot] { emit(report, info) }
    case .linkUp(let slot)?:
      if slots[slot] == nil, let session, let info = await session.identify(slot: slot) { slots[slot] = info }
      if let info = slots[slot] { await read(info) }
    case .linkDown?, nil:
      break
    }
  }
}
```

`App/AppModel.swift`:
```swift
import AppKit
import Foundation
import JuiceCore
import JuiceStore
import WidgetKit

@MainActor
final class AppModel: ObservableObject {
  static let shared = AppModel()

  @Published var settings: Settings {
    didSet {
      guard settings != oldValue else { return }
      try? settingsStore.save(settings)
      state.scheduler.maxWait = TimeInterval(settings.maxWaitHours) * 3600
      moments.reschedule(endOfDayHour: settings.endOfDayHour, minute: settings.endOfDayMinute)
      publish()
    }
  }
  @Published private(set) var snapshot: Snapshot = .empty
  @Published private(set) var receiverPresent = false

  let paths: JuicePaths
  let notifier = Notifier()
  let moments = MomentMonitor()
  let hid = HIDCoordinator()
  private let settingsStore: SettingsStore
  private let stateStore: StateStore
  private let snapshotStore: SnapshotStore
  private let cliSnapshotStore: SnapshotStore
  private(set) var state: LocalState
  var remoteFiles: [SyncFile] = []
  private var liveDevices: Set<DeviceID> = []
  private var tickTimer: Timer?
  private var saveWork: DispatchWorkItem?

  init(paths: JuicePaths = .standard()) {
    self.paths = paths
    settingsStore = SettingsStore(url: paths.settingsURL)
    stateStore = StateStore(url: paths.stateURL)
    snapshotStore = SnapshotStore(url: paths.snapshotURL)
    cliSnapshotStore = SnapshotStore(url: paths.cliSnapshotURL)
    let loadedSettings = settingsStore.load(default: Settings())
    settings = loadedSettings
    var loadedState = stateStore.load(default: LocalState())
    loadedState.scheduler.maxWait = TimeInterval(loadedSettings.maxWaitHours) * 3600
    state = loadedState
  }

  var isFirstRun: Bool { state.records.isEmpty }
  var menuBarVisible: Bool { MenuBarPolicy.isVisible(mode: settings.menuBarMode, snapshot: snapshot) }
  var iconTinted: Bool { snapshot.devices.contains { $0.tinted } }

  var mergedRecords: [DeviceRecord] {
    SyncMerge.merge(local: state.records, remotes: settings.syncEnabled ? remoteFiles : [], now: Date())
  }

  func start() {
    notifier.onSnooze = { [weak self] id in self?.snooze(id) }
    notifier.start()
    moments.onMoment = { [weak self] moment in self?.handleMoment(moment) }
    moments.start(endOfDayHour: settings.endOfDayHour, minute: settings.endOfDayMinute)
    hid.onReading = { [weak self] reading, info in self?.ingest(reading, info: info) }
    hid.onReceiverChange = { [weak self] present in self?.receiverChanged(present) }
    hid.start()
    tickTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.handleTick() }
    }
    publish()
  }

  // MARK: Pipeline

  func ingest(_ reading: Reading, info: DeviceInfo) {
    let now = reading.observedAt
    upsertLocal(info) { $0.readings = History.appending(reading, to: $0.readings, now: now) }
    if reading.source == .local { liveDevices.insert(reading.device) }
    let record = mergedRecords.first { $0.info.id == reading.device }
    let forecast = Forecaster.forecast(record?.readings ?? [reading], now: now)
    let profile = record?.alertOverride ?? settings.profile
    let (next, decisions) = AlertEngine.evaluate(
      reading: reading, profile: profile, forecast: forecast, fullyChargedEnabled: settings.fullyChargedEnabled,
      state: state.alertStates[reading.device] ?? DeviceAlertState(), now: now)
    state.alertStates[reading.device] = next
    if reading.charging { state.scheduler.dropPending(for: reading.device) }
    publish()
    for decision in decisions { deliver(state.scheduler.schedule(decision, now: now)) }
    saveSoon()
  }

  func deliver(_ deliveries: [Delivery]) {
    for delivery in deliveries {
      let device = snapshot.devices.first { $0.id == delivery.decision.device }
      let text = Format.notification(for: delivery, displayName: device?.displayName ?? "Logitech device",
                                     forecast: device?.forecast ?? .learning)
      notifier.post(text, device: delivery.decision.device)
    }
  }

  func handleMoment(_ moment: Moment) {
    deliver(state.scheduler.onMoment(moment, now: Date()))
    if moment == .willSleep { saveNow() } else { saveSoon() }
  }

  func handleTick() {
    deliver(state.scheduler.onTick(now: Date()))
    publish()
  }

  func snooze(_ id: DeviceID) {
    let profile = alertOverride(for: id) ?? settings.profile
    state.alertStates[id] = AlertEngine.snooze(state.alertStates[id] ?? DeviceAlertState(), profile: profile, now: Date())
    saveSoon()
  }

  func receiverChanged(_ present: Bool) {
    receiverPresent = present
    if !present {
      liveDevices.removeAll()
      handleMoment(.receiverDeparted)
    }
    publish()
  }

  func publish() {
    let now = Date()
    let records = mergedRecords
    var alerting = Set<DeviceID>()
    var tinted = Set<DeviceID>()
    for record in records {
      let alertState = state.alertStates[record.info.id] ?? DeviceAlertState()
      if !alertState.firedAt.isEmpty { alerting.insert(record.info.id) }
      if MenuBarPolicy.isTinted(state: alertState, profile: record.alertOverride ?? settings.profile) {
        tinted.insert(record.info.id)
      }
    }
    let next = SnapshotBuilder.build(records: records, liveDevices: liveDevices, receiverPresent: receiverPresent,
                                     alerting: alerting, tinted: tinted, now: now)
    let changed = next.devices != snapshot.devices || next.receiverPresent != snapshot.receiverPresent
    snapshot = next
    if changed {
      try? snapshotStore.save(next)
      try? cliSnapshotStore.save(next)
      WidgetCenter.shared.reloadAllTimelines()
    }
  }

  // MARK: Settings-window API

  func alertOverride(for id: DeviceID) -> AlertProfile? {
    mergedRecords.first { $0.info.id == id }?.alertOverride
  }

  func setAlertOverride(_ profile: AlertProfile?, for id: DeviceID) {
    mutateMeta(id) { $0.alertOverride = profile }
  }

  func setNickname(_ name: String, for id: DeviceID) {
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    mutateMeta(id) { $0.nickname = trimmed.isEmpty ? nil : trimmed }
  }

  /// Debug aid (enable with `defaults write com.penguinspecz.logijuice debugMenu -bool true`).
  func simulateLowBattery(percent: Int) {
    let info = DeviceInfo(id: DeviceID("debug:test-mouse"), name: "Test Mouse", kind: .mouse)
    ingest(Reading(device: info.id, level: .percent(percent), charging: false, observedAt: Date()), info: info)
  }

  func forgetTestDevice() {
    state.records.removeAll { $0.info.id == DeviceID("debug:test-mouse") }
    state.alertStates[DeviceID("debug:test-mouse")] = nil
    publish()
    saveSoon()
  }

  // MARK: Persistence

  func saveSoon() {
    saveWork?.cancel()
    let work = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.saveNow() } }
    saveWork = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: work)
  }

  func saveNow() {
    saveWork?.cancel()
    try? stateStore.save(state)
  }

  private func upsertLocal(_ info: DeviceInfo, _ mutate: (inout DeviceRecord) -> Void) {
    if let i = state.records.firstIndex(where: { $0.info.id == info.id }) {
      state.records[i].info = info
      mutate(&state.records[i])
    } else {
      var record = DeviceRecord(info: info, nickname: nil, alertOverride: nil, metaUpdatedAt: .distantPast, readings: [])
      mutate(&record)
      state.records.append(record)
    }
  }

  /// Metadata edits bump `metaUpdatedAt` so they win the cross-Mac merge.
  private func mutateMeta(_ id: DeviceID, _ mutate: (inout DeviceRecord) -> Void) {
    let current = mergedRecords.first { $0.info.id == id }
    if !state.records.contains(where: { $0.info.id == id }), var copy = current {
      copy.readings = []
      state.records.append(copy)
    }
    guard let i = state.records.firstIndex(where: { $0.info.id == id }) else { return }
    if let current {
      state.records[i].nickname = current.nickname
      state.records[i].alertOverride = current.alertOverride
    }
    mutate(&state.records[i])
    state.records[i].metaUpdatedAt = Date()
    publish()
    saveSoon()
  }
}
```

`App/MenuContent.swift`:
```swift
import AppKit
import JuiceCore
import SwiftUI

struct MenuBarLabel: View {
  let snapshot: Snapshot
  let tinted: Bool

  var body: some View {
    Image(nsImage: Self.image(percent: snapshot.lowest?.level?.equivalentPercent, tinted: tinted))
  }

  static func image(percent: Int?, tinted: Bool) -> NSImage {
    let base = NSImage(systemSymbolName: Format.batterySymbol(percent: percent),
                       accessibilityDescription: "Logitech battery") ?? NSImage()
    guard tinted, let red = base.withSymbolConfiguration(.init(paletteColors: [.systemRed])) else {
      base.isTemplate = true
      return base
    }
    red.isTemplate = false
    return red
  }
}

struct DeviceRow: View {
  let device: SnapshotDevice
  let now: Date

  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: device.kind.symbolName).frame(width: 22)
      VStack(alignment: .leading, spacing: 2) {
        Text(device.displayName).font(.headline)
        let sub = Format.subtitle(device, now: now)
        if !sub.isEmpty { Text(sub).font(.caption).foregroundStyle(.secondary) }
      }
      Spacer()
      if device.charging { Image(systemName: "bolt.fill").foregroundStyle(.yellow) }
      Text(device.level.map(Format.level) ?? "—")
        .monospacedDigit()
        .foregroundStyle(device.tinted ? Color.red : Color.primary)
    }
  }
}

struct MenuContent: View {
  @ObservedObject var model: AppModel
  private var debugMenu: Bool { UserDefaults.standard.bool(forKey: "debugMenu") }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      if model.snapshot.devices.isEmpty {
        Text(model.receiverPresent ? "Waiting for a device to wake up…" : "Plug in your Logi Bolt receiver.")
          .foregroundStyle(.secondary)
      }
      ForEach(model.snapshot.devices) { DeviceRow(device: $0, now: Date()) }
      if !model.receiverPresent && !model.snapshot.devices.isEmpty {
        Text("Receiver not connected to this Mac").font(.caption).foregroundStyle(.secondary)
      }
      Divider()
      Button("Settings…") { SettingsWindowController.shared.show() }
      if OptionsPlus.isInstalled { Button("Open Logi Options+") { OptionsPlus.open() } }
      if debugMenu {
        Button("Debug: simulate 8% Test Mouse") { model.simulateLowBattery(percent: 8) }
        Button("Debug: forget Test Mouse") { model.forgetTestDevice() }
      }
      Button("Quit LogiJuice") { NSApp.terminate(nil) }
    }
    .buttonStyle(.borderless)
    .padding(14)
    .frame(width: 300)
  }
}
```

`App/SettingsWindow.swift` (Task 16 replaces `SettingsView` with the full form):
```swift
import AppKit
import JuiceCore
import SwiftUI

@MainActor
final class SettingsWindowController {
  static let shared = SettingsWindowController()
  private var window: NSWindow?

  func show() {
    if window == nil {
      let model = AppModel.shared
      let hosting = NSHostingController(rootView: SettingsView(model: model, notifier: model.notifier))
      let w = NSWindow(contentViewController: hosting)
      w.title = "LogiJuice"
      w.styleMask = [.titled, .closable, .miniaturizable]
      w.isReleasedWhenClosed = false
      w.center()
      window = w
    }
    AppModel.shared.notifier.refreshAuthorization()
    NSApp.activate(ignoringOtherApps: true)
    window?.makeKeyAndOrderFront(nil)
  }
}

struct SettingsView: View {
  @ObservedObject var model: AppModel
  @ObservedObject var notifier: Notifier

  var body: some View {
    List(model.snapshot.devices) { DeviceRow(device: $0, now: Date()) }
      .frame(width: 420, height: 300)
  }
}
```

`App/LogiJuiceApp.swift`:
```swift
import AppKit
import JuiceCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    let model = AppModel.shared
    let firstRun = model.isFirstRun
    model.start()
    if firstRun { SettingsWindowController.shared.show() }
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    SettingsWindowController.shared.show()
    return true
  }

  func application(_ application: NSApplication, open urls: [URL]) {
    SettingsWindowController.shared.show()
  }

  func applicationWillTerminate(_ notification: Notification) {
    AppModel.shared.saveNow()
  }
}

@main
struct LogiJuiceApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
  @ObservedObject private var model = AppModel.shared

  var body: some Scene {
    MenuBarExtra(isInserted: Binding(get: { model.menuBarVisible }, set: { _ in })) {
      MenuContent(model: model)
    } label: {
      MenuBarLabel(snapshot: model.snapshot, tinted: model.iconTinted)
    }
    .menuBarExtraStyle(.window)
  }
}
```

`Config/LogiJuice.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.application-groups</key>
  <array>
    <string>group.com.penguinspecz.logijuice</string>
  </array>
</dict>
</plist>
```

- [ ] **Step 3: Write the build script**

`scripts/build-app.sh` (it already handles the widget, which Task 17 adds):
```bash
#!/bin/bash
# Builds dist/LogiJuice.app (app + widget + CLI). Ad-hoc signed unless SIGNING_IDENTITY is set.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

VERSION="${LOGIJUICE_VERSION:-0.1.0}"
BUILD_NUMBER="${LOGIJUICE_BUILD_NUMBER:-1}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"
ARCH_FLAGS=(--arch arm64 --arch x86_64)
APP="$ROOT/dist/LogiJuice.app"

sign() {
  if [[ "$SIGNING_IDENTITY" == "-" ]]; then
    codesign --force --sign - --timestamp=none "$@"
  else
    codesign --force --sign "$SIGNING_IDENTITY" --options runtime --timestamp "$@"
  fi
}

swift build -c release "${ARCH_FLAGS[@]}" --product LogiJuice
swift build -c release "${ARCH_FLAGS[@]}" --product logijuice-cli
HAS_WIDGET=0
if [[ -d WidgetExtension ]]; then
  HAS_WIDGET=1
  swift build -c release "${ARCH_FLAGS[@]}" --product LogiJuiceWidgetExtension
fi
BIN="$(swift build -c release "${ARCH_FLAGS[@]}" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/bin"
cp "$BIN/LogiJuice" "$APP/Contents/MacOS/LogiJuice"
cp "$BIN/logijuice-cli" "$APP/Contents/Resources/bin/logijuice"
chmod 0755 "$APP/Contents/Resources/bin/logijuice"
cp LICENSE "$APP/Contents/Resources/LICENSE"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>LogiJuice</string>
<key>CFBundleIdentifier</key><string>com.penguinspecz.logijuice</string>
<key>CFBundleName</key><string>LogiJuice</string>
<key>CFBundleDisplayName</key><string>LogiJuice</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
<key>CFBundleURLTypes</key><array><dict>
  <key>CFBundleURLName</key><string>com.penguinspecz.logijuice</string>
  <key>CFBundleURLSchemes</key><array><string>logijuice</string></array>
</dict></array>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST

if [[ "$HAS_WIDGET" == 1 ]]; then
  APPEX="$APP/Contents/PlugIns/LogiJuiceWidgetExtension.appex"
  mkdir -p "$APPEX/Contents/MacOS"
  cp "$BIN/LogiJuiceWidgetExtension" "$APPEX/Contents/MacOS/LogiJuiceWidgetExtension"
  cp WidgetExtension/Info.plist "$APPEX/Contents/Info.plist"
  plutil -replace CFBundleShortVersionString -string "$VERSION" "$APPEX/Contents/Info.plist"
  plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$APPEX/Contents/Info.plist"
  plutil -lint "$APPEX/Contents/Info.plist"
  sign --entitlements Config/LogiJuiceWidget.entitlements "$APPEX"
fi

plutil -lint "$APP/Contents/Info.plist"
sign "$APP/Contents/Resources/bin/logijuice"
sign --entitlements Config/LogiJuice.entitlements "$APP"
codesign --verify --deep --strict "$APP"
echo "$APP"
```

Run: `chmod +x scripts/build-app.sh`

- [ ] **Step 4: Build, run and verify on the owner's Mac**

Run: `swift test && scripts/build-app.sh && open dist/LogiJuice.app`
Expected:
1. All tests PASS. The script prints `.../dist/LogiJuice.app`.
2. On first launch the settings window opens (with the simple device list for now) and macOS asks for notification permission. Allow it.
3. Within a few seconds the list shows the owner's devices with percentages (move the mouse and type to wake them). `log stream --predicate 'subsystem == "com.penguinspecz.logijuice"' --level info` shows `receiver attached` and the `slot N:` lines.
4. With mode Auto and healthy batteries, there is no menu bar icon.
5. Quit the app. Run `defaults write com.penguinspecz.logijuice debugMenu -bool true` and write `{"menuBarMode":"always"}` to `~/Library/Application Support/logijuice/settings.json`. Missing keys load as defaults, and the Settings UI only arrives in Task 16. Relaunch: the icon appears. Click "Debug: simulate 8% Test Mouse". Within a second there's a "Test Mouse · 8%" notification, and the icon turns red.
6. Lock the screen (⌃⌘Q) with a pending Low nudge: simulate 18% after a "Debug: forget Test Mouse" (which re-arms). The nudge arrives at lock.
7. `dist/LogiJuice.app/Contents/Resources/bin/logijuice status` lists the devices.
8. Logi Options+ still shows battery and remapping still works while LogiJuice runs.
9. Unplug the receiver (or switch the hub). The menu dropdown shows "Receiver not connected to this Mac" and "seen …" times. Plug it back in and readings resume.

Record any failure with its log lines before changing code.

- [ ] **Step 5: Commit**

```bash
git add Package.swift App Config scripts
git commit -m "Add LogiJuice menu bar app: receiver wiring, alerts, nudges, notifications"
```

---

### Task 15: iCloud Drive sync wiring (Mac)

**Files:**
- Create: `App/SyncCoordinator.swift`
- Modify: `App/AppModel.swift`

**Interfaces:**
- Consumes: `SyncStore`, `SyncFile`, `MacIdentity`, `AppModel.remoteFiles`, `AppModel.publish()`.
- Produces: `AppModel.syncAvailable: Bool` (used by Task 16).

- [ ] **Step 1: Write the coordinator**

`App/SyncCoordinator.swift`:
```swift
import Foundation
import JuiceCore
import JuiceStore
import os

/// Writes this Mac's file (throttled) and polls the others (spec §6).
@MainActor
final class SyncCoordinator {
  static let writeInterval: TimeInterval = 300
  static let pollInterval: TimeInterval = 120

  let store: SyncStore
  var onRemoteFiles: (([SyncFile]) -> Void)?
  private let log = Logger(subsystem: "com.penguinspecz.logijuice", category: "sync")
  private var timer: Timer?
  private var lastWrite = Date.distantPast

  init(store: SyncStore) { self.store = store }

  var isAvailable: Bool { store.isAvailable }

  func start() {
    poll()
    timer?.invalidate()
    timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.poll() }
    }
  }

  func stop() {
    timer?.invalidate()
    timer = nil
    onRemoteFiles?([])
  }

  func poll() {
    onRemoteFiles?(store.isAvailable ? store.readOthers() : [])
  }

  func write(records: [DeviceRecord], force: Bool, now: Date = Date()) {
    guard store.isAvailable, force || now.timeIntervalSince(lastWrite) >= Self.writeInterval else { return }
    let own = records.map { record -> DeviceRecord in
      var copy = record
      copy.readings = record.readings.filter { $0.source == .local }
      return copy
    }
    do {
      try store.writeOwn(SyncFile(macID: store.macID, macName: MacIdentity.name(), updatedAt: now, devices: own))
      lastWrite = now
    } catch {
      log.error("sync write failed: \(error.localizedDescription, privacy: .public)")
    }
  }
}
```

- [ ] **Step 2: Wire it into `AppModel`**

In `App/AppModel.swift`:

Add a stored property after `let hid = HIDCoordinator()`:
```swift
  let sync: SyncCoordinator
```

In `init`, before `let loadedSettings = …`:
```swift
    sync = SyncCoordinator(store: SyncStore(folder: paths.iCloudFolder, macID: MacIdentity.hardwareUUID()))
```

Add a computed property next to `menuBarVisible`:
```swift
  var syncAvailable: Bool { sync.isAvailable }
```

In `settings.didSet`, after `moments.reschedule(…)`:
```swift
      if settings.syncEnabled != oldValue.syncEnabled {
        if settings.syncEnabled { sync.start() } else { sync.stop() }
      }
```

In `start()`, before `publish()`:
```swift
    sync.onRemoteFiles = { [weak self] files in
      self?.remoteFiles = files
      self?.publish()
    }
    if settings.syncEnabled { sync.start() }
```

In `ingest`, after `saveSoon()`:
```swift
    if settings.syncEnabled { sync.write(records: state.records, force: false) }
```

In `handleMoment`, replace `if moment == .willSleep { saveNow() } else { saveSoon() }` with:
```swift
    if moment == .willSleep || moment == .receiverDeparted {
      saveNow()
      if settings.syncEnabled { sync.write(records: state.records, force: true) }
    } else {
      saveSoon()
    }
```

In `mutateMeta`, after `saveSoon()`:
```swift
    if settings.syncEnabled { sync.write(records: state.records, force: true) }
```

- [ ] **Step 3: Build and verify**

Run: `swift test && scripts/build-app.sh && open dist/LogiJuice.app`
Expected:
1. `ls ~/Library/Mobile\ Documents/com~apple~CloudDocs/logijuice/` shows `<hardware-UUID>.json` after the first reading (write at most every 5 minutes; switching the hub away forces one).
2. On a second Mac with the same build, after switching the hub over, the first Mac's device shows "seen …" with the readings from the second Mac within about 2 to 5 minutes, and **only the Mac holding the receiver** posts notifications.
3. Renaming a device (Task 16 adds the field; for now edit via a debugger, or check after Task 16) propagates.

If only one Mac is available, copy your own file to `TEST-OTHER.json` in that folder, with its `macID` changed to `TEST-OTHER` and one reading's time edited. Confirm that reading appears tagged `synced:TEST-OTHER` in `logijuice status --json`, then delete the file.

- [ ] **Step 4: Commit**

```bash
git add App
git commit -m "Wire iCloud Drive sync: throttled own-file writes, remote polling"
```

---

### Task 16: Settings window (Codex-ready; visual check on Mac)

**Files:**
- Modify: `App/SettingsWindow.swift` (replace `SettingsView`)
- Create: `App/LoginItem.swift`, `App/AlertLevelEditor.swift`
- Modify: `App/AppModel.swift` (register the login item on first run)

**Interfaces:**
- Consumes: the `AppModel` settings-window API (Task 14), `AppModel.syncAvailable` (Task 15), `Notifier.authorized`, `OptionsPlus`.
- Produces: `LoginItem.isEnabled`, `LoginItem.set(_:)`.

- [ ] **Step 1: Write the login item helper**

`App/LoginItem.swift`:
```swift
import Foundation
import os
import ServiceManagement

enum LoginItem {
  static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

  static func set(_ enabled: Bool) {
    do {
      if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
    } catch {
      Logger(subsystem: "com.penguinspecz.logijuice", category: "login")
        .error("login item change failed: \(error.localizedDescription, privacy: .public)")
    }
  }
}
```

In `App/AppModel.swift` `start()`, as the first line:
```swift
    if !UserDefaults.standard.bool(forKey: "registeredLoginItem") {
      LoginItem.set(true)
      UserDefaults.standard.set(true, forKey: "registeredLoginItem")
    }
```

- [ ] **Step 2: Write the level editor**

`App/AlertLevelEditor.swift`:
```swift
import JuiceCore
import SwiftUI

struct LevelList: View {
  @Binding var profile: AlertProfile
  let showAdvanced: Bool

  var body: some View {
    ForEach($profile.levels) { $level in
      LevelRow(level: $level, showAdvanced: showAdvanced)
    }
  }
}

struct LevelRow: View {
  @Binding var level: AlertLevel
  let showAdvanced: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        Toggle("", isOn: $level.enabled).labelsHidden()
        TextField("Name", text: $level.name).frame(width: 80)
        TriggerEditor(trigger: $level.trigger)
        Picker("", selection: $level.timing) {
          Text("now").tag(Timing.now)
          Text("at a natural moment").tag(Timing.nextMoment)
        }
        .labelsHidden()
        .fixedSize()
      }
      if showAdvanced {
        HStack(spacing: 12) {
          Picker("Repeat", selection: $level.repeatPolicy) {
            Text("never").tag(RepeatPolicy.never)
            Text("every 4 h").tag(RepeatPolicy.everyHours(4))
            Text("every 12 h").tag(RepeatPolicy.everyHours(12))
            Text("daily").tag(RepeatPolicy.daily)
          }
          .fixedSize()
          Toggle("Red icon", isOn: $level.tintsIcon)
        }
        .padding(.leading, 28)
      }
    }
    .opacity(level.enabled ? 1 : 0.5)
  }
}

struct TriggerEditor: View {
  @Binding var trigger: Trigger

  private var isPercent: Binding<Bool> {
    Binding(
      get: { if case .percentAtOrBelow = trigger { return true } else { return false } },
      set: { trigger = $0 ? .percentAtOrBelow(20) : .forecastDaysAtOrBelow(3) })
  }

  var body: some View {
    HStack(spacing: 4) {
      switch trigger {
      case .percentAtOrBelow(let p):
        Stepper("≤ \(p)", value: Binding(get: { p }, set: { trigger = .percentAtOrBelow($0) }), in: 1...95)
          .fixedSize()
      case .forecastDaysAtOrBelow(let d):
        Stepper("≤ \(Int(d))", value: Binding(get: { Int(d) }, set: { trigger = .forecastDaysAtOrBelow(Double($0)) }),
                in: 1...30)
          .fixedSize()
      }
      Picker("", selection: isPercent) {
        Text("%").tag(true)
        Text("days left").tag(false)
      }
      .labelsHidden()
      .fixedSize()
    }
  }
}
```

- [ ] **Step 3: Replace `SettingsView`**

In `App/SettingsWindow.swift`, replace the `SettingsView` struct with:
```swift
struct SettingsView: View {
  @ObservedObject var model: AppModel
  @ObservedObject var notifier: Notifier
  @State private var showAdvanced = false
  @State private var launchAtLogin = LoginItem.isEnabled

  private var endOfDay: Binding<Date> {
    Binding(
      get: {
        Calendar.current.date(bySettingHour: model.settings.endOfDayHour, minute: model.settings.endOfDayMinute,
                              second: 0, of: Date()) ?? Date()
      },
      set: {
        let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
        model.settings.endOfDayHour = c.hour ?? 17
        model.settings.endOfDayMinute = c.minute ?? 30
      })
  }

  var body: some View {
    Form {
      Section("Devices") {
        if model.snapshot.devices.isEmpty {
          Text("No devices yet. Plug in your Logi Bolt receiver and wake your devices.").foregroundStyle(.secondary)
        }
        ForEach(model.snapshot.devices) { device in
          DeviceSettingsRow(model: model, device: device)
        }
      }
      Section("Alerts") {
        LevelList(profile: $model.settings.profile, showAdvanced: showAdvanced)
        DisclosureGroup("Advanced", isExpanded: $showAdvanced) {
          Stepper("Hold nudges at most \(model.settings.maxWaitHours) h",
                  value: $model.settings.maxWaitHours, in: 1...24)
          DatePicker("End of day", selection: endOfDay, displayedComponents: .hourAndMinute)
          Toggle("Notify when fully charged", isOn: $model.settings.fullyChargedEnabled)
        }
      }
      Section("General") {
        Picker("Menu bar icon", selection: $model.settings.menuBarMode) {
          Text("Auto (when low or charging)").tag(MenuBarMode.auto)
          Text("Always").tag(MenuBarMode.always)
          Text("Never").tag(MenuBarMode.never)
        }
        Toggle("Launch at login", isOn: $launchAtLogin)
          .onChange(of: launchAtLogin) { _, on in
            LoginItem.set(on)
            launchAtLogin = LoginItem.isEnabled
          }
        Toggle("Sync across Macs (iCloud Drive)", isOn: $model.settings.syncEnabled)
          .disabled(!model.syncAvailable)
        if !model.syncAvailable {
          Text("Sync off: iCloud Drive not enabled").font(.caption).foregroundStyle(.secondary)
        }
        if !notifier.authorized {
          HStack {
            Text("Notifications are off for LogiJuice.").foregroundStyle(.red)
            Button("Open Notification Settings") {
              NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!)
            }
          }
        }
        if OptionsPlus.isInstalled { Button("Open Logi Options+") { OptionsPlus.open() } }
      }
    }
    .formStyle(.grouped)
    .frame(width: 520)
    .frame(minHeight: 520)
  }
}

struct DeviceSettingsRow: View {
  @ObservedObject var model: AppModel
  let device: SnapshotDevice
  @State private var nickname = ""

  private var custom: Binding<Bool> {
    Binding(
      get: { model.alertOverride(for: device.id) != nil },
      set: { model.setAlertOverride($0 ? model.settings.profile : nil, for: device.id) })
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 10) {
        Image(systemName: device.kind.symbolName).frame(width: 22)
        TextField(device.name, text: $nickname)
          .textFieldStyle(.plain)
          .frame(maxWidth: 200)
          .onSubmit { model.setNickname(nickname, for: device.id) }
        Spacer()
        Text(Format.subtitle(device, now: Date())).font(.caption).foregroundStyle(.secondary)
        Text(device.level.map(Format.level) ?? "—").monospacedDigit()
      }
      Toggle("Custom alerts for this device", isOn: custom).font(.caption)
      if let override = model.alertOverride(for: device.id) {
        LevelList(profile: Binding(get: { override }, set: { model.setAlertOverride($0, for: device.id) }),
                  showAdvanced: false)
          .padding(.leading, 28)
      }
    }
    .onAppear { nickname = device.nickname ?? "" }
    .onDisappear {
      if nickname != (device.nickname ?? "") { model.setNickname(nickname, for: device.id) }
    }
  }
}
```

- [ ] **Step 4: Build and check visually**

Run: `swift test && scripts/build-app.sh && open dist/LogiJuice.app` then open Settings from the menu (or relaunch the app).
Expected:
1. Three sections. Devices lists each device with an editable nickname. Rename the mouse and press Return; the menu dropdown shows the new name.
2. Alerts shows three rows matching the defaults. Toggling Low off, then simulating 15% (debug menu), sends no notification.
3. Advanced reveals repeat, red-icon, max wait, end of day and fully charged.
4. "Custom alerts for this device" reveals a per-device level list. Changing it doesn't change the global list.
5. Launch at login appears ON in System Settings → General → Login Items.
6. Quit and relaunch: every change persisted (`settings.json` and `state.json`).
7. Take a screenshot of the window in light and dark mode for the owner.

- [ ] **Step 5: Commit**

```bash
git add App
git commit -m "Add settings window: devices, alert levels, general options, login item"
```

---

### Task 17: Widget extension (Codex-ready; verify on Mac)

**Files:**
- Modify: `Package.swift`
- Create: `WidgetExtension/LogiJuiceWidget.swift`, `WidgetExtension/Info.plist`, `Config/LogiJuiceWidget.entitlements`

**Interfaces:**
- Consumes: `SnapshotStore`, `JuicePaths.snapshotURL`, `Snapshot`, `SnapshotDevice`, `Format`, `DeviceKind.symbolName`.
- Produces: the `LogiJuiceWidgetExtension` product, bundled by `scripts/build-app.sh` (already handled).

- [ ] **Step 1: Add the target and product**

In `Package.swift` add to `products`:
```swift
    .executable(name: "LogiJuiceWidgetExtension", targets: ["LogiJuiceWidgetExtension"]),
```
and to `targets`:
```swift
    .executableTarget(
      name: "LogiJuiceWidgetExtension",
      dependencies: ["JuiceCore", "JuiceStore"],
      path: "WidgetExtension",
      exclude: ["Info.plist"],
      linkerSettings: [.linkedFramework("WidgetKit")]),
```

- [ ] **Step 2: Write the widget**

`WidgetExtension/LogiJuiceWidget.swift`:
```swift
import JuiceCore
import JuiceStore
import SwiftUI
import WidgetKit

struct BatteryEntry: TimelineEntry {
  let date: Date
  let snapshot: Snapshot?
}

struct BatteryProvider: TimelineProvider {
  private func load() -> Snapshot? {
    guard let s = SnapshotStore(url: JuicePaths.standard().snapshotURL).read(), s.schema <= Snapshot.currentSchema else {
      return nil
    }
    return s
  }

  func placeholder(in context: Context) -> BatteryEntry { BatteryEntry(date: .now, snapshot: .preview) }

  func getSnapshot(in context: Context, completion: @escaping (BatteryEntry) -> Void) {
    completion(BatteryEntry(date: .now, snapshot: context.isPreview ? .preview : load()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<BatteryEntry>) -> Void) {
    // The app reloads timelines on every change; the hourly refresh keeps "seen Xh ago" honest.
    completion(Timeline(entries: [BatteryEntry(date: .now, snapshot: load())],
                        policy: .after(.now.addingTimeInterval(3600))))
  }
}

struct Ring: View {
  let fraction: Double
  let tinted: Bool

  var body: some View {
    ZStack {
      Circle().stroke(.quaternary, lineWidth: 8)
      Circle()
        .trim(from: 0, to: max(0.02, min(1, fraction)))
        .stroke(tinted ? Color.red : Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
        .rotationEffect(.degrees(-90))
    }
  }
}

struct SmallBatteryView: View {
  let device: SnapshotDevice
  let now: Date

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      ZStack {
        Ring(fraction: Double(device.level?.equivalentPercent ?? 0) / 100, tinted: device.tinted || device.alerting)
        VStack(spacing: 2) {
          Image(systemName: device.charging ? "bolt.fill" : device.kind.symbolName).font(.caption)
          Text(device.level.map(Format.level) ?? "—").font(.title3.bold()).monospacedDigit()
        }
      }
      .frame(width: 80, height: 80)
      Spacer(minLength: 0)
      Text(device.displayName).font(.caption.bold()).lineLimit(1)
      Text(Format.subtitle(device, now: now)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct MediumBatteryView: View {
  let devices: [SnapshotDevice]
  let now: Date

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(devices) { d in
        HStack(spacing: 10) {
          Image(systemName: d.kind.symbolName).frame(width: 20)
          VStack(alignment: .leading, spacing: 1) {
            Text(d.displayName).font(.callout.bold()).lineLimit(1)
            Text(Format.subtitle(d, now: now)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
          }
          Spacer()
          if d.charging { Image(systemName: "bolt.fill").foregroundStyle(.yellow) }
          Text(d.level.map(Format.level) ?? "—")
            .font(.title3.bold()).monospacedDigit()
            .foregroundStyle(d.tinted ? Color.red : Color.primary)
        }
      }
    }
  }
}

struct BatteryWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: BatteryEntry

  var body: some View {
    Group {
      if let snapshot = entry.snapshot, let first = snapshot.lowest ?? snapshot.devices.first {
        if family == .systemSmall {
          SmallBatteryView(device: first, now: entry.date)
        } else {
          MediumBatteryView(devices: Array(snapshot.devices.prefix(3)), now: entry.date)
        }
      } else {
        VStack(spacing: 6) {
          Image(systemName: "battery.0percent").font(.title2)
          Text("Open LogiJuice to start").font(.caption).multilineTextAlignment(.center)
        }
      }
    }
    .containerBackground(.fill.tertiary, for: .widget)
    .widgetURL(URL(string: "logijuice://open"))
  }
}

struct BatteryWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "LogiJuiceBattery", provider: BatteryProvider()) { entry in
      BatteryWidgetView(entry: entry)
    }
    .configurationDisplayName("Logitech Battery")
    .description("Battery for your receiver-connected Logitech keyboard and mouse.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

@main
struct LogiJuiceWidgets: WidgetBundle {
  var body: some Widget { BatteryWidget() }
}
```

`WidgetExtension/Info.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>LogiJuice</string>
  <key>CFBundleExecutable</key>
  <string>LogiJuiceWidgetExtension</string>
  <key>CFBundleIdentifier</key>
  <string>com.penguinspecz.logijuice.widget</string>
  <key>CFBundleName</key>
  <string>LogiJuice Widget</string>
  <key>CFBundlePackageType</key>
  <string>XPC!</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSExtension</key>
  <dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.widgetkit-extension</string>
  </dict>
</dict>
</plist>
```

`Config/LogiJuiceWidget.entitlements`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.app-sandbox</key>
  <true/>
  <key>com.apple.security.application-groups</key>
  <array>
    <string>group.com.penguinspecz.logijuice</string>
  </array>
</dict>
</plist>
```

- [ ] **Step 3: Build and verify on the Mac**

Run: `swift test && scripts/build-app.sh && cp -R dist/LogiJuice.app /Applications/ && open /Applications/LogiJuice.app`
Expected:
1. `codesign --verify --deep --strict` passes (the script prints the app path).
2. Right-click the desktop → Edit Widgets → search "LogiJuice". The Small and Medium "Logitech Battery" widgets are listed. Add both.
3. Small shows the lowest device as a ring with its percent. Medium shows up to 3 rows. Both match the menu dropdown.
4. Simulate 8% (debug menu): the widgets update within seconds and the ring turns red.
5. Clicking a widget opens the LogiJuice settings window.

The widget only registers when the app runs from `/Applications` (or another standard location), which is why it's copied there. If the widget doesn't show up, run `pluginkit -m -p com.apple.widgetkit-extension | grep logijuice` and check the extension is registered.

- [ ] **Step 4: Commit**

```bash
git add Package.swift WidgetExtension Config
git commit -m "Add small and medium battery widgets"
```

---

### Task 18: Shortcuts actions (Mac; may be dropped)

**Files:**
- Create: `App/ShortcutsIntents.swift`
- Modify: `Package.swift` (link AppIntents on the app target)

**Interfaces:**
- Consumes: `SnapshotStore`, `JuicePaths.snapshotURL`, `Format`.
- Produces: the "Get Device Battery" and "Get Lowest Battery" actions.

- [ ] **Step 1: Write the intents**

In `Package.swift`, add `.linkedFramework("AppIntents")` to the `LogiJuice` target's `linkerSettings`.

`App/ShortcutsIntents.swift`:
```swift
import AppIntents
import JuiceCore
import JuiceStore

private func currentSnapshot() -> Snapshot? {
  SnapshotStore(url: JuicePaths.standard().snapshotURL).read()
}

private func summary(_ d: SnapshotDevice) -> String {
  Format.statusLine(d, now: Date())
}

struct LogitechDeviceEntity: AppEntity {
  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Logitech Device"
  static var defaultQuery = LogitechDeviceQuery()

  let id: String
  let name: String

  var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct LogitechDeviceQuery: EntityQuery {
  func entities(for identifiers: [String]) async throws -> [LogitechDeviceEntity] {
    try await suggestedEntities().filter { identifiers.contains($0.id) }
  }

  func suggestedEntities() async throws -> [LogitechDeviceEntity] {
    (currentSnapshot()?.devices ?? []).map { LogitechDeviceEntity(id: $0.id.rawValue, name: $0.displayName) }
  }
}

struct GetDeviceBatteryIntent: AppIntent {
  static var title: LocalizedStringResource = "Get Device Battery"
  static var description = IntentDescription("Battery level, charging state and time left for one Logitech device.")

  @Parameter(title: "Device") var device: LogitechDeviceEntity

  func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
    guard let d = currentSnapshot()?.devices.first(where: { $0.id.rawValue == device.id }) else {
      return .result(value: "Unknown", dialog: "LogiJuice hasn't seen \(device.name) yet.")
    }
    let text = summary(d)
    return .result(value: text, dialog: "\(text)")
  }
}

struct GetLowestBatteryIntent: AppIntent {
  static var title: LocalizedStringResource = "Get Lowest Battery"
  static var description = IntentDescription("The Logitech device with the lowest battery.")

  func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
    guard let d = currentSnapshot()?.lowest else {
      return .result(value: "Unknown", dialog: "LogiJuice has no battery readings yet.")
    }
    let text = summary(d)
    return .result(value: text, dialog: "\(text)")
  }
}

struct LogiJuiceShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(intent: GetLowestBatteryIntent(),
                phrases: ["Get lowest battery in \(.applicationName)", "Which battery is low in \(.applicationName)"],
                shortTitle: "Lowest Battery", systemImageName: "battery.25percent")
  }
}
```

- [ ] **Step 2: Build and check whether Shortcuts sees the actions**

Run: `scripts/build-app.sh && rm -rf /Applications/LogiJuice.app && cp -R dist/LogiJuice.app /Applications/ && open /Applications/LogiJuice.app`
Then open Shortcuts.app, create a new shortcut and search the action library for "LogiJuice".
Expected: "Get Device Battery" and "Get Lowest Battery" are listed. Running "Get Lowest Battery" shows the same line as `logijuice status` for the lowest device.

- [ ] **Step 3: Decide**

- **If the actions appear:** commit.
  ```bash
  git add Package.swift App/ShortcutsIntents.swift
  git commit -m "Add Shortcuts actions for device and lowest battery"
  ```
- **If they don't appear:** SwiftPM didn't generate App Intents metadata (`Contents/Resources/Metadata.appintents` is missing from the bundle). Don't spend more than 30 minutes on it. Revert (`git checkout Package.swift && rm App/ShortcutsIntents.swift`). Then add a line to the README's "Scripting" section: "Use `logijuice status --json` from a Shortcuts *Run Shell Script* action." Commit that, and tell the owner the native actions are deferred.

---

### Task 19: README, cask, manual checklist run (Codex docs + Mac checklist)

**Files:**
- Create: `README.md`, `Casks/logijuice.rb`, `docs/manual-checklist.md`

- [ ] **Step 1: Write the README**

`README.md`:
````markdown
# logijuice 🔋🐧

Battery levels and low-battery alerts for Logitech keyboards and mice connected through a **Logi Bolt** (or Unifying) receiver, which macOS's own battery UI can't see.

> logijuice is unofficial and not affiliated with or endorsed by Logitech. "Logitech", "Logi Bolt", "Unifying" and "Logi Options+" are trademarks of Logitech.

## What it does

- **Stays out of the way.** The menu bar icon appears only when a battery is low or charging (or always, if you prefer).
- **Escalating alerts, all customizable.**
  - Low (20%) waits for a natural moment: screen lock, end of day, before sleep, or when your hub switches away ("Leaving this desk?").
  - Very low (10%) and Critical (5%) alert right away. Critical repeats daily until you charge.
- **Time-left forecast.** It learns each device's real drain rate: "~9 days left".
- **Widgets.** Small and medium desktop and Notification Center widgets.
- **Works across Macs.** Readings sync through your own iCloud Drive, so a hub-switching setup still shows recent values, and only the Mac holding the receiver alerts you.
- **Plays nicely with Logi Options+.** logijuice only *reads* battery information and never changes device settings.
- **Scriptable.** `logijuice status --json`.

## Install (from source)

Requirements: macOS 14+, Xcode (full install).

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift test
scripts/build-app.sh
cp -R dist/LogiJuice.app /Applications/
open /Applications/LogiJuice.app
```

The app is ad-hoc signed. On first launch, macOS may ask you to approve it in **System Settings → Privacy & Security → Open Anyway**.

## Command line

```sh
ln -sf /Applications/LogiJuice.app/Contents/Resources/bin/logijuice /usr/local/bin/logijuice
logijuice status          # MX Master 3S: 42%, ~9 days
logijuice status --json
logijuice devices
logijuice debug capture --seconds 30 --probe   # raw HID++ frames, for bug reports
```

## Privacy

No telemetry and no network access. Data stays in `~/Library/Application Support/logijuice/`, the app's group container, and (if sync is on) `iCloud Drive/logijuice/`.

## License

MIT
````

- [ ] **Step 2: Write the cask**

`Casks/logijuice.rb`:
```ruby
cask "logijuice" do
  version "0.1.0"
  sha256 :no_check

  url "https://github.com/Land-o-Clusters/logijuice/releases/download/v#{version}/LogiJuice-#{version}.zip"
  name "LogiJuice"
  desc "Unofficial battery levels and alerts for Logi Bolt receiver devices"
  homepage "https://github.com/Land-o-Clusters/logijuice"

  depends_on macos: ">= :sonoma"

  app "LogiJuice.app"
  binary "#{appdir}/LogiJuice.app/Contents/Resources/bin/logijuice"

  uninstall quit: "com.penguinspecz.logijuice"

  zap trash: [
    "~/Library/Application Support/logijuice",
    "~/Library/Group Containers/group.com.penguinspecz.logijuice",
    "~/Library/Preferences/com.penguinspecz.logijuice.plist",
  ]
end
```

`sha256 :no_check` is replaced with the real hash when the first release zip exists (`shasum -a 256 LogiJuice-0.1.0.zip`). No release is published in this plan.

- [ ] **Step 3: Write and run the manual checklist**

`docs/manual-checklist.md`:
```markdown
# Manual hardware checklist

Run on the owner's Mac with the Bolt receiver, a percent-reporting mouse and keyboard. Record pass/fail and notes.

| # | Check | Expected | Result |
|---|---|---|---|
| 1 | Fresh launch (delete `~/Library/Application Support/logijuice` first) | Settings window opens; notification prompt; devices appear within ~10 s of waking them | |
| 2 | Logi Options+ running alongside | Options+ battery and remapping keep working; LogiJuice readings match Options+ | |
| 3 | Quit Options+ | LogiJuice keeps reading (wake a device → updates) | |
| 4 | Hub switched away | Dropdown says "Receiver not connected to this Mac"; "seen …" times; pending Low nudge delivered as "Leaving this desk?" | |
| 5 | Hub switched back | Readings resume without relaunching | |
| 6 | Sleep / wake the Mac | No crash; readings resume after wake; pending nudge delivered on sleep | |
| 7 | Charging cable plugged into the mouse | Menu bar icon appears (Auto) with a bolt; pending nudges dropped | |
| 8 | Charge to full | "Fully charged" notification once | |
| 9 | Debug simulate 18% → lock screen | Low nudge arrives at lock, not before | |
| 10 | Debug simulate 8% | Immediate Very low notification; red icon; widget ring red | |
| 11 | Notification "Snooze 1 day" on a Low alert, then simulate 4% | Critical still alerts (escalation) | |
| 12 | Relaunch after alerts fired | No duplicate notifications | |
| 13 | Rename a device in Settings | Menu, widget and `logijuice status` show the nickname | |
| 14 | `logijuice status --json` | Valid JSON matching the menu | |
| 15 | Second Mac (if available) | Other Mac shows synced readings; only the Mac with the receiver alerts | |
```

Go through every row on the Mac and fill in the Result column. Fix failures through the owning task's tests before marking them as passing.

- [ ] **Step 4: Commit**

```bash
git add README.md Casks docs/manual-checklist.md
git commit -m "Add README, Homebrew cask and completed manual checklist"
```

---

## After the plan

- Creating `Land-o-Clusters/logijuice` (private) on GitHub and pushing are **owner decisions**. Ask before running `gh repo create`.
- Developer ID signing and notarization, the official Homebrew tap, and battery health stay in the spec's "Later" list.
