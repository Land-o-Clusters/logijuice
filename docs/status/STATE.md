# logijuice — STATE

What is true NOW. Replace §0 in place; never stack banners. Rules that hold always live in `LAWS.md`.

## §0 Current state (2026-10-03)

**Phase:** implementation. Tasks 0–13 landed and verified on `main`. Next is Task 14 (the app), which needs the owner
present.

**Done (verified):**
- Spec `0f2a347`, plan `9286109` (fixes `4d45b9e` and the test counts in later commits), Task 0 bring-up `ed186d4`.
- Tasks 1–9 (core, store, CLI): `5d06b82` … `3da48f8`. Tasks 10–12 (HID++ codec, broker, session): `9009ece`,
  `fb5d42d`, `1c76bd1`. Task 13 (IOHID channel, hotplug monitor, `debug capture`, replay test): `10386a7`.
- Full `swift test` at `10386a7`: **109 test cases, 0 failures, rc 0**. The broker tests (timing-based) were re-run 5×
  at `fb5d42d`, all green.
- **Live hardware run at `10386a7`** (`logijuice-cli debug capture --probe`, Options+ running): MX Keys S slot 1
  `sn:TESTKEYS0001` 100 %, MX Master 3S slot 2 `sn:TESTMOUSE001` 70 %, both 0x1004 at index 8 with a percentage. The
  capture is committed as `Tests/JuiceHIDTests/Fixtures/owner-mouse.json` and replayed by `ReplayTests`.

**In flight:**
- Branch `main` at the commit adding this banner. Working tree clean. `codex/logijuice-tasks-1-9` points at
  `10386a7` (fully merged; safe to delete). Codex is not running.
- Plan files are copied verbatim by a helper that extracts each file's block from the plan (session scratchpad,
  not committed). Files that appear in several plan tasks (`Package.swift`, `Sources/LogiJuiceCLI/main.swift`) are
  written by hand per task.
- No background jobs. **No `origin` remote** (repo creation is owner-tier), so every commit is local-only.

**Next action:** Task 14 (app shell + `scripts/build-app.sh`). Its Step 4 needs the owner at the Mac: the
notification-permission prompt, the menu bar check, lock-screen timing, and a hub switch. Then Task 15 (sync), Task 16
(settings), Task 17 (widget), Task 18 (Shortcuts), Task 19 (docs + manual checklist).

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
