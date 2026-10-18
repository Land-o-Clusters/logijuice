# logijuice STATE

What is true NOW. Replace §0 in place and never stack banners. Rules that hold always are in `LAWS.md`.

## §0 Current state (2026-10-18 21:30 UTC, flushed for a clear)

**Phase:** v1 is released and in use. [v0.1.2](https://github.com/Land-o-Clusters/logijuice/releases/tag/v0.1.2) is
the latest (2026-10-18, owner's yes). Plan Task 19 Steps 3 (manual checklist) and 4 (final commit) are still open.
They close when checklist rows #4, #5, #6, #15 and #8 pass on hardware. No code work is pending.

**What 0.1.2 added (2026-10-18, owner asked):** `StatusItemWatchdog` re-adds the menu bar item when macOS parks it
off-screen. That was seen at (-1, 1428) after 4 days up, and a relaunch fixed it then. The dropdown now:
- closes over Settings and other LogiJuice windows,
- fits and animates its height, with tighter metrics.

Clicking a device (dropdown row, Settings gauge or info button) toggles its details from `Format.details`. Each
device has an Alerts chip (`Settings.mutedDevices`). Settings can forget a device that isn't connected, synced as
the sync file's optional `forgotten` map (schema still 1). The Forget work came from a side session on branch
`claude/jovial-cerf-69ac40` (`7ac5808`), merged as `d087051`.

**Verified (2026-10-18):**
- `swift test` 182 of 182 (Store 10, HID 34, Core 128, CLI 10), `build-app.sh` and `scripts/release.sh` exit 0 on
  `6b3ce32`, the commit tagged v0.1.2. CI on `6b3ce32` passed. CI on `0035d2b` (STATE only) was still running at
  the flush.
- Release: the downloaded asset matches `Casks/logijuice.rb` (version 0.1.2, build 3, sha256 `ada6e69f…5386`), and
  `brew fetch` and `brew audit --cask` pass through a tap of this repo (untapped after).
- Installed: `/Applications/LogiJuice.app` is 0.1.2 from the downloaded zip, running. Its menu bar item is at
  (1853, 2), and `logijuice status` shows both devices at 100%.
- Owner-checked on hardware: the dropdown closes over Settings and reopens on one click. The details fit, and the
  animation is smooth. sleight checked the Settings details, the gauge toggle and Forget.
- Still true from 2026-10-04: `scripts/github-settings.sh` is applied and the history was scrubbed before going
  public. Ad-hoc builds leave out the Shortcuts actions. Checklist #1, #2, #7 and #9 to #14 passed (#3 can't be
  tested).
- **Not verified:** a device forgotten on one Mac dropping on another, and a real off-screen item being re-added
  (only unit tests and the debug-menu re-add exercise that).

**In flight:**
- Branch `main` = `origin/main` (0 ahead, 0 behind) at the commit adding this banner. `git status --porcelain` is
  empty in every worktree.
- Worktrees:
  - the main checkout (`main`);
  - `.claude/worktrees/logijuice-menubar-missing-03d620` (branch of the same name, = `main`; this session's);
  - `.claude/worktrees/jovial-cerf-69ac40` (`claude/jovial-cerf-69ac40` at `7ac5808`, merged; its session is idle,
    and the owner can archive it).
  - The local branch `claude/boot-juice-arch-3eb485` (`9cc6e50`) has no worktree and can be deleted.
- The repo's own git config sets `user.name penguinspecz`.
- **Background jobs:** none. The other session's `log stream` (pid 84839) has ended.
- `state.json` keeps a harmless `debug:test-mouse` forget from the Forget session's test. The owner's broken
  Shortcuts test shortcut "LogiJuice test" can be deleted.
- Health tracking started 2026-10-03. Both devices show 1 completed run. Health needs 3 full charges, and its trend needs 6.

**Next action:**
1. With the owner at the desk: checklist #4 and #5 (hub away and back, including the "Leaving this desk?" nudge),
   #6 (sleep/wake; also that the menu bar icon stays on screen) and #15 (second Mac: synced readings, only the
   receiver's Mac alerts, and a device forgotten on one Mac disappears on the other). These were planned for
   2026-10-05 and never run.
2. On the owner's next full charge: #8 (one "Fully charged" notification, with the fill rising every 60 s).
3. When those pass: record them in `docs/manual-checklist.md`, then tick plan Task 19 Steps 3 and 4.
4. When the owner pairs the MX Master 3S over Bluetooth: run phase 0 of the Bluetooth plan (read-only probe).

**Open owner decisions:**
- Bluetooth-direct devices: the owner asked for scoping (2026-10-18) and deferred the probe. Path A (HID++ over
  BLE) needs Input Monitoring, opt-in. Path B (IORegistry) doesn't need a permission, if it exists for Logitech. Plan:
  `docs/superpowers/plans/2026-10-18-bluetooth-direct.md`.
- Signing entity: releases stay ad-hoc signed (owner reconfirmed 2026-10-04) until the owner settles a neutral
  entity. Signing brings back the Shortcuts actions.
- Spec adjustments 1 to 9 (plan header) stand. They were presented 2026-10-03 and the owner proceeded.

**Blockers:** none.

## Reading List
- `docs/superpowers/specs/2026-10-03-logijuice-design.md`: the spec (what and why).
- `docs/superpowers/plans/2026-10-03-logijuice.md`: the plan (Task 19 is the open one).
- `docs/bringup-notes.md`: real receiver behavior and byte layouts from Task 0.
- `docs/status/LAWS.md`: what is true always.
- `docs/superpowers/plans/2026-10-18-bluetooth-direct.md`: the scoping plan for Bluetooth-direct devices (awaiting the owner).
- `docs/manual-checklist.md`: the owner-run hardware checklist (#4, #5, #6, #15 on Monday, #8 on a full charge).
- `README.md`: the user-facing summary and install instructions.
