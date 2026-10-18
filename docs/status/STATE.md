# logijuice STATE

What is true NOW. Replace §0 in place and never stack banners. Rules that hold always are in `LAWS.md`.

## §0 Current state (2026-10-04 03:30 UTC, flushed for a clear)

**Phase:** v1 is feature-complete, public and released. The plan's last open steps are Task 19 Step 3 (manual
checklist) and Step 4 (final commit). They close when the Monday rows (#4, #5, #6, #15) and the charge rows (#7
follow-up, #8) pass. No code work is pending.

**Release:** [v0.1.1](https://github.com/Land-o-Clusters/logijuice/releases/tag/v0.1.1) is the latest (build 2, ad-hoc
signed, sha256 `00514f1b…2a65`, published 2026-10-04 with the owner's yes). It removed the Shortcuts actions, which
were broken in 0.1.0. The downloaded asset matches `Casks/logijuice.rb`, and `brew fetch` and `brew audit --cask` pass
through a tap of this repo. v0.1.0 is still listed as an older release.

**Verified (2026-10-04):**
- `swift test` exits 0 with **155 of 155 passing** (Store 10, HID 34, Core 101, CLI 10) at `9e2b1f8`, the code
  commit 0.1.1 was built from (run by `scripts/release.sh`). CI run 37173333170 on `9e2b1f8` passed both jobs
  (build, prose). Later commits only touch docs, the cask and version defaults.
- **Installed:** `/Applications/LogiJuice.app` is 0.1.1, running; `logijuice status` shows the mouse at 70% and the
  keyboard at 90%, both learning.
- On hardware: the widget fix (`811426d`), capture redaction (`191bad6`, no real IDs in a probe capture) and the
  download path (Gatekeeper blocks until Open Anyway, then the bundled CLI runs).
- Shortcuts actions fail in any ad-hoc build: `linkd` logs `Unable to get teamId`, then `Rejecting invalid client
  due to requiresValidatedBundle`. Unsigned builds now leave them out (LAWS). The README points to
  `logijuice status --json` in a Run Shell Script action.
- GitHub: public, `scripts/github-settings.sh` applied (private vulnerability reporting on, `main` protected, topics,
  `hardware` label). The README has the icon header, screenshots and badges. The social preview image is set. The
  history was rewritten before going public: all commits are by `penguinspecz`, and a scan didn't find any serials, unit
  IDs, hardware UUID, computer name, home path, legal name or personal email. The pre-scrub bundle is deleted.
- Every Markdown file passes Vale (`vale README.md .github docs`, 0 findings).
- Checklist **passed** #1, #2, #7, #9 to #14. #3 can't be tested because Options+ is a KeepAlive agent.
- Key commits: spec `48eeb46`, plan `03289df`, bring-up `c68e66c`, app `a987c91`, battery health `e7ee17c`,
  charging `67c5d51`, Lightspeed/voltage/headset `201ee79` (untested on hardware), CI `9178a6e`.

**In flight:**
- Branch `main` = `origin/main` (0 ahead, 0 behind), HEAD = the commit adding this banner, clean (`git status
  --porcelain` empty). Worktrees: the main checkout and the app-made `.claude/worktrees/boot-juice-arch-3eb485`
  (branch `claude/boot-juice-arch-3eb485`, fast-forwarded to `main`). The local `ci` branch was deleted; its commit
  is on `main` as `9178a6e`.
- The repo's own git config sets `user.name penguinspecz`.
- **Background jobs:** none of ours. A `log stream` (pid 84839, kernel/display predicate) belongs to another session;
  leave it.
- The owner's test shortcut "LogiJuice test" in Shortcuts no longer has a working action. The owner can delete it.
- Health tracking started 2026-10-03 22:24 UTC. The forecast should leave "learning" around Mon 2026-10-05. Battery
  health needs 3 full charges, and its trend needs 6.

**0.1.2 published (2026-10-18, owner's yes).** [v0.1.2](https://github.com/Land-o-Clusters/logijuice/releases/tag/v0.1.2)
is tagged at `6b3ce32` on `main` (fast-forwarded from `claude/logijuice-menubar-missing-03d620`, which includes
`refs/heads/claude/jovial-cerf-69ac40`). The downloaded asset matches the cask (sha256 `ada6e69f…5386`), and `brew
fetch` and `brew audit --cask` pass through a tap of this repo (untapped after). `/Applications/LogiJuice.app` is
0.1.2 from the downloaded zip, running, with its menu bar item at (1853, 2), and `logijuice status` reads both devices.
- What's in it: `StatusItemWatchdog` re-adds the menu bar item when macOS parks it off-screen (seen 2026-10-18 at
  (-1, 1428) after 4 days up, and a relaunch fixed it then). The dropdown closes over Settings and other LogiJuice
  windows. Its height now fits the content and animates, with tighter metrics. Clicking a device (dropdown row, Settings gauge
  or info button) toggles its details. Each device has an Alerts chip (`Settings.mutedDevices`). Settings can
  forget a device that isn't connected, synced as a `forgotten` map in the sync file (schema still 1).
- Verified on the merged tree: `swift test` 182 of 182, `build-app.sh` exit 0, `release.sh` exit 0. The owner
  checked the dropdown on hardware. It closes over Settings and reopens on one click. The details fit, and the
  animation is smooth. sleight checked the Settings details, the gauge toggle and Forget. The watchdog sees the
  real item at (1926, 1409) and reports it on screen.
- **Not verified:** a forgotten device dropping on a second Mac (add to #15); a real off-screen item being re-added (only
  the unit tests and the debug-menu re-add exercise it).
- `state.json` keeps a harmless `debug:test-mouse` forget from the Forget session's test.
- Device coverage: receiver devices with 0x1004, 0x1000 or 0x1001 are covered. Bluetooth-direct devices are the
  gap, scoped in `docs/superpowers/plans/2026-10-18-bluetooth-direct.md` (awaiting the owner's probe).

**Next action:**
1. Mon 2026-10-05, with the owner: checklist #4 and #5 (hub away and back, including the "Leaving this desk?" nudge),
   #6 (sleep/wake; also confirm the menu bar icon stays on screen, see the 2026-10-18 note) and #15 (second Mac: synced readings, only the receiver's Mac alerts; with the Forget branch, also that a device
   forgotten on one Mac disappears on the other). If that Mac runs without
   Options+, also check whether a freshly powered receiver sends events.
2. On the owner's next real charge: the fill rises (log line `charging: re-reading every 60 s`), then #8 (one
   "Fully charged" notification).
3. When those pass: record them in `docs/manual-checklist.md`, then tick plan Task 19 Steps 3 and 4.

**Open owner decisions:**
- Bluetooth-direct devices (plan 2026-10-18): run the phase 0 probe (owner pairs the MX Master 3S over Bluetooth),
  then path A (HID++ over BLE, needs Input Monitoring, opt-in) and/or path B (IORegistry, no permission, if it
  exists for Logitech).
- Signing entity: releases stay ad-hoc signed (owner reconfirmed 2026-10-04) until the owner settles a neutral entity,
  possibly a neutrally named RoleGauge LLC. Signing brings back the Shortcuts actions.
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
