# logijuice — STATE

What is true NOW. Replace §0 in place; never stack banners. Rules that hold always live in `LAWS.md`.

## §0 Current state (2026-10-03)

**Phase:** implementation. Tasks 0–14 and 17, plus Task 19 Steps 1–2, are on `main`. Task 14 hardware checks C
(lock-screen nudge) and D (hub switch) are in progress with the owner.

**Done (verified):**
- Spec `0f2a347` (§7 amended at `9826453`: device-silhouette gauge), plan `9286109` + fixes, bring-up `ed186d4`.
- Tasks 1–13: `5d06b82` … `10386a7` (core, store, CLI, HID++ codec/broker/session, IOHID + `debug capture` + replay).
- Task 14 app `69a2e2a`. Owner-verified 2026-10-03: first-run window, notification permission granted, Auto hides the
  icon when healthy, Options+ unaffected, dropdown correct, simulated 8 % → one `debug:test-mouse.veryLow` notification
  (usernoted log) and a red icon.
- Gauge `9826453`: the owner rejected the battery glyph (it reads as the Mac's battery). Renders checked by
  juice-arch at 6×.
- Codex delivered Task 17 widget `fe1d865` and Task 19 README/cask `32f8acf` in worktree `../logijuice-codex`. Gated
  by juice-arch: files byte-identical to the plan, widget build rc 0, 109/109. Merged at `4831c17` (Package.swift
  conflict resolved to the union).
- At `4831c17`: `swift test` **111 passed, 0 failed**, widget build rc 0, `build-app.sh` rc 0 (universal, ad-hoc,
  app group). Installed to `/Applications/LogiJuice.app`; pluginkit lists `com.penguinspecz.logijuice.widget`.

**In flight:**
- `main` at the commit adding this banner. Working tree clean. Branches `codex/logijuice-tasks-1-9` and
  `codex/widget-docs` are fully merged; worktree `../logijuice-codex` can be removed.
- **Test settings on the owner's Mac (revert after Task 14):** `defaults write com.penguinspecz.logijuice debugMenu
  -bool true`; `settings.json` `menuBarMode: always`; a "Test Mouse" (`debug:test-mouse`) is in `state.json`. Revert
  with `defaults delete com.penguinspecz.logijuice debugMenu`, mode back to auto, and "Debug: forget Test Mouse".
- **Background job:** `/usr/bin/log stream` for subsystem `com.penguinspecz.logijuice` → `/tmp/lj-app-log.txt` (session
  job; dies at the clear; needed only for Task 14 checks).
- No `origin` remote, so every commit is local-only.

**Next action:** finish Task 14 checks C and D with the owner, then Task 15 (sync), Task 16 (settings window, which
can go to Codex now that the AppModel API exists), Task 18 (Shortcuts), and Task 19 Step 3 (manual checklist).

**Open owner decisions:**
- Spec adjustments 1–9 (plan header): presented 2026-10-03, and the owner proceeded without objection. They stand
  unless overruled.
- Untested: a freshly powered receiver on a Mac **without** Options+ may send no events. The mitigation is a 30-minute
  re-read (decided; in the plan, Task 14).
- Repo creation and visibility, and when to buy the Apple Developer membership: both deferred to the owner.
- **Before the repo goes public:** the device serials and unit IDs in `docs/bringup-notes.md`, this file and
  `Tests/JuiceHIDTests/Fixtures/owner-mouse.json` are the owner's. Decide whether to scrub them (owner-tier).

## Reading List
- `docs/superpowers/specs/2026-10-03-logijuice-design.md`: the spec (what and why).
- `docs/superpowers/plans/2026-10-03-logijuice.md`: the plan (tasks, code, tests, Codex-ready/hardware labels).
- `docs/bringup-notes.md`: real receiver behavior and byte layouts from Task 0.
- `docs/status/LAWS.md`: what is true always.
