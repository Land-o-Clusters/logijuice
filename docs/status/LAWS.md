# logijuice — LAWS

What is true ALWAYS. A line belongs here only if it would change when we were **wrong**. Anything that changes when the
**world** moves (progress, measurements, SHAs, what's next) belongs in `STATE.md`. Never put a measurement here.

## Product
- **The scope is battery only.** logijuice fills one gap: battery visibility and reliable low-battery alerts for
  Logitech devices on a Bolt/Unifying receiver. It never replaces Logi Options+ or its features (remapping, gestures,
  firmware, pairing). Native-Bluetooth devices and Windows/Linux are out of scope.
- **Read-only toward hardware.** Send only HID++ getter functions: root getFeature/ping, 0x0003 fn0/fn2,
  0x0005 fn0/1/2, 0x1004 fn0/1, 0x1000 fn0. Never write a register or a device setting, including the receiver's
  notification flags (register 0x00).
- **Coexist with Options+.** Open HID devices non-exclusively. Every request carries software ID `0x0A`; replies with
  any other non-zero software ID are ignored (Options+ uses `0xF`).
- **Use the percentage** when 0x1004 capabilities say it's supported. The level mask is too coarse to drive anything.
- **Only `.local` readings fire alerts.** Synced readings update displays and forecasts only.
- **No telemetry, no network.** The only data leaving the Mac is the owner's own iCloud Drive file
  (`iCloud Drive/logijuice/<hardware-UUID>.json`, one per Mac, each Mac writes only its own).
- **Unofficial.** The README always carries: "logijuice is unofficial and not affiliated with or endorsed by Logitech."

## Platform and build
- macOS 14.0 minimum. `swift-tools-version: 5.10`, Swift 5 language mode. No third-party dependencies.
- Every `swift`/`xcrun` command runs with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`
  (`xcode-select` points at the Command Line Tools, which can't build XCTest or WidgetKit).
- IDs: bundle `com.penguinspecz.logijuice`, widget `com.penguinspecz.logijuice.widget`, app group
  `group.com.penguinspecz.logijuice`, logger subsystem `com.penguinspecz.logijuice`. App display name **LogiJuice**;
  repo and CLI command **logijuice** (built as product `logijuice-cli`, because APFS is case-insensitive).
- Ad-hoc signing by default. `SIGNING_IDENTITY` switches to Developer ID later. Nothing may depend on an Apple Developer
  membership until the owner buys one.

## Method
- **Verify, never trust.** "Done" means the tests were re-run and their output read. Hardware claims need a hardware run.
- **Run checks bare, capture the exit code, commit only on 0.** Never `check | tail && git commit`: the `&&` reads the
  pipe's status, not the check's.
- **Commit with the pathspec on the commit:** `git commit -m "…" -- <paths>`. Use `git add -- <path>` only for a file
  git doesn't track yet. Never `git add -A`, never a bare commit.
- **Branch authority:** the newest commit touching a status file, on any branch, is authoritative.
- **STATE.md is updated as work happens.** The §0 banner is replaced in place (never stacked); it stays under 32 KB.
  The handoff is amortized, never written at clear time.
- **Decisions are ruled and recorded** in a committed doc with a one-line rationale. The owner overrules explicitly.
- **Owner-tier, always ask first:** creating, publishing or changing visibility of the GitHub repo; spending money; any
  hardware write; scope changes to the spec.
