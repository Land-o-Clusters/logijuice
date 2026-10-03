# logijuice — design spec

- **Date:** 2026-10-03
- **Status:** draft, awaiting owner review
- **Repo:** `~/Projects/logijuice` → later `Land-o-Clusters/logijuice` (private first)
- **Platform:** macOS 14+, Apple Silicon and Intel, Swift package (layout modeled on Puddle)

> logijuice is unofficial and not affiliated with or endorsed by Logitech. "Logitech", "Logi Bolt",
> "Unifying" and "Logi Options+" are Logitech trademarks.

## 1. Problem and intent

Logitech keyboards and mice connected through a **Logi Bolt receiver** (instead of native Bluetooth)
do not appear in macOS's battery UI. The only way to see their battery is to open Logi Options+, and
its low-battery notice is a single, easily missed toast at 10%.

The owner uses the receiver in a USB-C hub that moves between Macs, which is exactly why Bluetooth
is not an option: the receiver makes keyboard and mouse follow the hub with no re-pairing.

**logijuice fills that one gap:** battery visibility and reliable low-battery warnings for
receiver-connected Logitech devices. Hyper-simple on the surface, quietly clever underneath.

### Success criteria

1. The owner is never surprised by a dead mouse or keyboard.
2. The owner never needs to open Options+ to learn a battery level.
3. Nothing about logijuice is visible when all batteries are fine (unless the owner chooses).
4. Works alongside Logi Options+ (and OSS alternatives) without interfering.

### Non-goals

- Replacing Options+ or any of its features (button remapping, gestures, firmware updates, pairing).
- Writing any setting to a device. logijuice is **read-only** toward hardware.
- Native-Bluetooth devices (macOS already shows those).
- Windows/Linux. All of the owner's machines are Macs.
- Telemetry or any network traffic besides the owner's own iCloud Drive sync.

## 2. Architecture

One process: a menu-bar-only app (`LSUIElement`, no Dock icon) registered as a login item. It owns
the receiver connection, alerting, the menu bar, settings and sync. The widget and the CLI are
read-only consumers of a snapshot file the app publishes.

Rejected alternatives: a separate LaunchAgent daemon plus UI app (two processes and IPC, which is too
much machinery for a battery meter); wrapping `hidapi` (a dependency with no gain over `IOHIDManager`
on macOS).

### Modules (SwiftPM targets)

| Target | Responsibility | Side effects |
|---|---|---|
| `JuiceHID` | HID++ transport and protocol: receiver discovery, device enumeration, feature lookup, battery, name/type, identity, event stream | USB HID |
| `JuiceCore` | Pure logic: models, alert engine, nudge scheduler, forecast, sync merge | none |
| `JuiceStore` | Settings, reading history, snapshot publishing, iCloud Drive file I/O | disk |
| `LogiJuice` (app) | Composition root, menu bar, settings window, notifications, moment signals, login item, App Intents | UI/system |
| `LogiJuiceWidget` | WidgetKit extension (small, medium) | reads snapshot |
| `logijuice` (CLI) | `status`, `devices`, `debug capture` | reads snapshot; `debug capture` opens HID |

`JuiceCore` depends on nothing. `JuiceHID` and `JuiceStore` depend only on `JuiceCore` models. The app
composes all of them. Every `JuiceCore` component is a value-in/value-out type that can be unit-tested
without hardware, a clock, or a disk: the clock and the current settings are injected.

### Data flow

```
receiver event / wake / connect
        │
   JuiceHID ──► Reading(deviceID, level, charging, observedAt, source: .local)
        │
   JuiceStore.history.append ──► JuiceCore.AlertEngine.evaluate(...) ──► [AlertDecision]
        │                                   │
        │                         NudgeScheduler (now vs. defer to moment)
        │                                   │
        │                         UNUserNotificationCenter / menu bar state
        ▼
   JuiceCore.Forecast ──► Snapshot ──► app-group snapshot.json ──► widget reload, CLI
                                   └─► iCloud Drive <mac>.json (throttled)
```

### Identifiers

- Bundle ID `com.penguinspecz.logijuice`, widget `com.penguinspecz.logijuice.widget`
- App group `group.com.penguinspecz.logijuice` (the widget is sandboxed; the app is not, because it
  writes to iCloud Drive without the iCloud entitlement)
- Signing: ad-hoc (`codesign --sign -`) in v1, like Puddle. The build script takes an optional
  `SIGNING_IDENTITY` so Developer ID signing and notarization become a configuration change once the
  owner joins the Apple Developer Program.

## 3. `JuiceHID`: talking to the receiver

**Receivers:** vendor `0x046D`. Bolt `0xC548` (confirmed attached on the owner's Mac). Unifying
(`0xC52B`, `0xC532`) is supported opportunistically because it uses the same HID++ protocol.

**Transport:** `IOHIDManager` matching the receiver's vendor-defined HID++ collection. Short (`0x10`,
7 B) and long (`0x11`, 20 B) reports. Opened **non-exclusively** so Options+ keeps working.

**Coexistence:** every request carries logijuice's own software ID in the low nibble of the
function byte (a fixed non-zero value distinct from Options+'s; chosen during bring-up by observing
Options+ traffic). Replies with a foreign software ID are ignored. Events (software ID 0) are consumed
by everyone.

**Per device (indices 1–6 on the receiver):**
1. Pairing slot info from the receiver (Bolt pairing registers, following Solaar's Bolt implementation)
   gives which slots are occupied, the model/wireless PID and the device kind, without waking the device.
2. Root `0x0000` `getFeature` resolves feature indices, cached per device identity.
3. `0x0005` Device Name & Type gives the marketing name ("MX Master 3S") and type (keyboard/mouse/…).
4. `0x0003` Device Information gives the serial number when supported (the identity key, see §6).
5. Battery: `0x1004` Unified Battery (percentage, level word, charging state, external power).
   Falls back to `0x1000` Battery Status. Devices that expose neither are shown as "battery not reported".

**Events, no polling:** subscribe to receiver connection notifications (device wake/link up) and
battery status broadcast events. On link-up, re-read battery. One low-frequency safety re-read
(every 30 min; see docs/bringup-notes.md) covers missed events and receivers whose notification flags are off.

**Timeouts:** 2 s per request. A sleeping device does not answer; that is normal and not an error.
The request is dropped and retried on the next link-up event. No request ever blocks the main thread.

**Hotplug:** receiver attach/detach (the hub switching between Macs) is a first-class event: detach
emits `ReceiverDeparted` (used by the "leaving this desk" nudge, §4); attach triggers full enumeration.

**Unknowns to verify in the bring-up spike (task 0 of the plan):**
- exact HID usage page/usage of the HID++ collection on the Bolt receiver under macOS
- whether opening it triggers the Input Monitoring TCC prompt (expected: no, since it is vendor-defined)
- Bolt pairing-register layout
- which battery feature the owner's devices expose, and their percentage granularity

`logijuice debug capture` records raw frames (request/response/event, timestamped) to a JSON file.
Captures from the owner's devices become `JuiceHID` parser test fixtures.

## 4. `JuiceCore`: alerts and nudges

### Models

```swift
struct DeviceID: Hashable, Codable          // see §6
enum DeviceKind { keyboard, mouse, trackball, touchpad, numpad, presenter, other }
enum BatteryLevel { percent(Int), word(LevelWord) }   // LevelWord: full, good, low, critical
struct Reading { device: DeviceID; level: BatteryLevel; charging: Bool;
                 observedAt: Date; source: Source /* .local | .synced(macID) */ }
```

### Alert profile

A global profile, with optional per-device overrides. A profile is an ordered list of **levels**:

| Field | Values |
|---|---|
| name | editable text |
| enabled | bool |
| trigger | `percentAtOrBelow(Int)` **or** `forecastDaysAtOrBelow(Double)` (only evaluated when the forecast is confident) |
| timing | `.now` / `.nextMoment` |
| repeat | `.never` / `.everyHours(Int)` / `.daily` |
| tintsIcon | bool (red menu bar icon) |

**Defaults:** Low ≤20% · next moment · never · no tint. Very low ≤10% · now · never · red.
Critical ≤5% · now · daily · red.

Devices that only report words map them as: `critical` → Critical level, `low` → Very low level,
`good`/`full` → none.

### Engine semantics

- `AlertEngine.evaluate(reading, profile, state, now) -> (newState, [AlertDecision])`
- **Only `.local` readings fire alerts.** Synced readings update display and forecast only, which
  prevents duplicate alerts across Macs.
- A level **fires** when its trigger becomes true and it is armed. Firing a more severe level marks all
  less severe levels as fired as well (no cascade of three notifications).
- **Re-arm:** charging starts → every level re-arms. Otherwise a level re-arms only when the level
  rises to at least its threshold + 5 (hysteresis against 19↔20 flapping).
- **Repeat:** a fired level with a repeat policy re-fires after its interval while its trigger is still true.
- **Snooze** (notification action): suppresses that device's alerts for 24 h, except a level escalation.
- **Fully charged** (optional, default on): fires once when charging ends at 100% or the level word `full`.

### Nudge scheduler (natural moments)

`.nextMoment` decisions are held in a queue and delivered at the first of:
- screen lock (`com.apple.screenIsLocked`)
- system or display about to sleep (`NSWorkspace.willSleepNotification`, `screensDidSleepNotification`)
- the configured end-of-day time (default 17:30, local)
- **receiver departed**: "Leaving this desk? MX Master 3S is at 14%"
- **max wait** elapsed (default 8 h), at which point it is delivered anyway

A held nudge is dropped if the device starts charging. It is superseded if a `.now` level fires for
the same device. Moment detection lives in the app. The scheduler itself is pure:
`schedule(decision, now)`, `onMoment(kind, now) -> [Delivery]`, `onTick(now) -> [Delivery]`.

### Notification content

Title: device nickname. Body: `12% · about 2 days left` (forecast clause only when confident).
Actions: **Snooze 1 day**, **Open Logi Options+** (only if `/Applications/logioptionsplus.app` exists).

## 5. `JuiceCore`: forecast

- Input: the merged readings for one device (local + synced), percent-reporting devices only.
- Segment history into **discharge runs**, split wherever charging occurs or the level rises.
- Fit the **current** run with a Theil–Sen slope (robust to coarse steps and outliers) on calendar
  time, so nights and weekends are naturally included.
- **Confident** when the current run spans ≥10 percentage points of drop **and** ≥2 days. Before that,
  borrow the previous run's slope if that one was confident. Otherwise the state is `.learning`.
- Output: `.learning` | `.estimate(daysLeft: Double, emptyAt: Date)` | `.unavailable` (word-only device).
  Displayed as "~N days" (≥2 days), "~N hours" (<2 days), or "learning…".
- History retention: 90 days per device, at most 2,000 readings (oldest dropped first).

## 6. Device identity and sync

### Identity

`DeviceID` is the serial number when `0x0003` provides one. Otherwise it is
`wpid + receiverSerial + slot`, which is stable on one receiver and good enough because the owner's
receiver moves with the hub. Nicknames and per-device overrides are keyed by `DeviceID`.

### iCloud Drive sync (no Apple Developer membership needed)

- Folder: `~/Library/Mobile Documents/com~apple~CloudDocs/logijuice/`
- One file per Mac: `<hardware-UUID>.json` = `{ schema: 1, macName, updatedAt, devices: [{ id, name,
  kind, nickname?, readings: [...] }] }`. Each Mac writes **only its own file**, so there are no write
  conflicts by construction.
- Write: throttled to at most once per 5 min, plus immediately on sleep and on receiver departure.
  Written atomically (temp file + rename).
- Read: `NSMetadataQuery` on the folder. On change, `SyncMerge.merge(localHistory, remoteFiles)` takes
  the union of readings by `(device, observedAt)` and the newest name/nickname by `updatedAt`.
- Nicknames and alert overrides also live in the per-Mac file. Merge takes the newest by `updatedAt`, so
  renaming a device on one Mac renames it everywhere.
- Toggle in settings (default **on** if iCloud Drive exists). If the folder is unavailable the setting
  shows "Sync off: iCloud Drive not enabled".

## 7. UI surfaces

### Menu bar (`MenuBarExtra`)

- Mode: **Auto** (default: visible while any device is at or below its first enabled level, or is
  charging), **Always**, **Never**.
- Glyph (amended 2026-10-03, owner's choice): the lowest device's **own silhouette** (mouse, keyboard, …) used as its
  battery gauge: the solid shape dimmed for "empty", solid up to the level (tall glyphs fill bottom→top, wide ones
  left→right). A battery glyph was rejected because it reads as the Mac's own battery. Red when any fired level has
  `tintsIcon`. The level appears as text beside it while the lowest device is alerting, and a bolt while it charges.
- Dropdown: one row per device (kind glyph, nickname, level, forecast, "seen 3h ago" when not live,
  charging bolt), then **Settings…**, **Open Logi Options+** (if installed), **Quit**.
- With mode Never, or Auto while hidden, opening the app from Spotlight/Finder opens Settings, so the
  app is never unreachable.

### Settings window (one window, SwiftUI `Form`, three sections)

1. **Devices**: rows with glyph, inline-editable nickname, level, forecast, last seen, and a
   **Custom alerts** toggle that reveals that device's level overrides.
2. **Alerts**: one row per level: `[toggle] Name · trigger · timing`. A collapsed **Advanced** group
   holds repeat, max wait, end-of-day time and the fully-charged toggle.
3. **General**: menu bar mode, launch at login (`SMAppService`), iCloud sync, Open Logi Options+.

### Widget

- **Small**: the lowest device as a large ring, with its nickname and forecast.
- **Medium**: up to 3 device rows.
- Stale data shows "seen 3h ago". The app calls `WidgetCenter.reloadAllTimelines()` on every snapshot
  change. The timeline also refreshes hourly so relative times stay right. Tap opens the app.

### Shortcuts (App Intents)

- **Get Device Battery** (parameter: device) returns percent or word, charging, and days left.
- **Get Lowest Battery** returns device and level.

### CLI

- `logijuice status [--json]` prints one line per device. `--json` emits the snapshot schema.
- `logijuice devices` lists IDs, names, kinds and last seen.
- `logijuice debug capture [--seconds N] [--out file]` records raw HID++ frames (see §3).

### Snapshot file

`~/Library/Group Containers/group.com.penguinspecz.logijuice/snapshot.json`:
`{ schema: 1, generatedAt, receiverPresent, devices: [{ id, name, nickname, kind, level, charging,
lastSeen, live, forecast }] }`. Written atomically. It is the only contract between the app, the
widget and the CLI.

## 8. Errors and edge cases

| Situation | Behavior |
|---|---|
| Receiver not on this Mac | State "not connected here"; last-seen data from history and sync |
| Device asleep / no reply | 2 s timeout, silent; re-read on next link-up |
| Device lacks battery features | Listed as "battery not reported", never alerts |
| Word-only battery | Shows the word; forecast `.unavailable`; word→level mapping (§4) |
| Options+ running | Non-exclusive open, software-ID filtering; no device writes ever |
| HID++ error reply | Logged; feature marked unsupported for that device identity until next app launch |
| Notification permission denied | Menu bar and widget still work; Settings shows a one-line warning with a button to open Notification settings |
| iCloud Drive missing / file corrupt | Sync disabled with a reason, or the corrupt remote file skipped; local operation unaffected |
| Clock jumps / sleep gaps | Forecast uses calendar time; the scheduler re-evaluates on wake |

Logging uses `os.Logger` (subsystem `com.penguinspecz.logijuice`). No telemetry.

## 9. Testing

- **`JuiceCore`** (bulk of the tests): table-driven `AlertEngine` cases (fire, escalate, no cascade,
  hysteresis re-arm, charge re-arm, repeat, snooze, synced readings never alert); `NudgeScheduler`
  (each moment kind, max wait, charge-drop, supersede); `Forecast` on synthetic curves (linear, coarse
  10% steps, outliers, charge mid-run, too-little data → `.learning`); `SyncMerge` (union, dedupe,
  newest-wins metadata, corrupt input).
- **`JuiceHID`**: frame encode/decode and feature parsing against captured fixtures from the owner's
  real devices; a fake transport for the request/timeout/software-ID-filtering logic.
- **`JuiceStore`**: snapshot and sync file round-trips; atomic writes; schema version handling.
- **Manual hardware checklist**: Options+ running and quit; hub switch away and back; sleep/wake;
  charging start and finish; low battery (forced with a fake reading through a debug menu item).

## 10. Work split for Codex handoffs

The implementation plan tags each task:
- **Codex-ready:** fully specified by tests or schemas, no hardware: `JuiceCore` (all of it),
  `JuiceStore`, the CLI, the widget, the settings UI, App Intents.
- **Needs the Mac and hardware:** the bring-up spike, `JuiceHID` transport and enumeration, notification
  and moment wiring, the end-to-end checklist.

## 11. Later (explicitly out of v1)

- Developer ID signing and notarization (when the repo goes public; the build script is ready for it)
- Official Homebrew cask (requires notarization); v1 uses a cask in the repo, like Puddle
- Battery health over time (capacity fade across charge cycles)
- Native-Bluetooth Logitech devices
