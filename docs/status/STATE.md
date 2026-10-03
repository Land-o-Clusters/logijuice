# logijuice — STATE

What is true NOW. Replace §0 in place; never stack banners. Rules that hold always live in `LAWS.md`.

## §0 Current state (2026-10-03)

**Phase:** implementation. Core track Tasks 1–7 landed and verified. Next is Task 8.

**Done (verified):**
- Spec `0f2a347`, plan `9286109`, Task 0 bring-up `ed186d4` (findings in `docs/bringup-notes.md`).
- Plan fix `4d45b9e`: in Tasks 1, 9 and 10 a target with no sources fails at module resolution, so their expected red
  was wrong (Codex stopped on it at Task 1 Step 3). Every plan commit step now carries a pathspec.
- Tasks 1–7 by juice-arch (taking over from Codex on its branch): `5d06b82` models, `31fd615` profile/settings,
  `0e71f1c` alert engine, `e56f6ab` scheduler, `d1642e0` forecaster, `e2b36f5` history/sync merge, `f390b5b`
  snapshot/format/menu policy. `swift test --filter JuiceCoreTests`: **66 tests, 0 failures, rc 0** at `f390b5b`.
- Hardware facts from the owner's Mac: Bolt `0xC548`, one HID++ collection. MX Keys S slot 1 (`TESTKEYS0001`) and
  MX Master 3S slot 2 (`TESTMOUSE001`), both 0x1004 at index 0x08 with a percentage. Options+ uses software ID `0xF`.

**In flight:**
- Branch `codex/logijuice-tasks-1-9` in the main worktree at the commit adding this banner. Working tree clean.
  `main` is still at `ed186d4` (fast-forwardable). Codex stopped and is not running; juice-arch now owns this branch.
- Plan files are copied verbatim with a helper that extracts each file's block from the plan (in the session
  scratchpad, not committed). Any copy of the plan text works the same way.
- No background jobs. **No `origin` remote** (repo creation is owner-tier), so every commit is local-only.

**Next action:** Task 8 (JuiceStore), then Task 9 (CLI). The HID track (Tasks 10–12) is independent of 8–9. Tasks
13–15 and 18 need the owner's Mac and receiver.

**Open owner decisions:**
- Spec adjustments 1–9 (plan header): presented 2026-10-03, and the owner proceeded without objection. They stand
  unless overruled.
- Untested: a freshly powered receiver on a Mac **without** Options+ may send no events. The mitigation is a 30-minute
  re-read (decided; in the plan, Task 14).
- Repo creation and visibility, and when to buy the Apple Developer membership: both deferred to the owner.

## Reading List
- `docs/superpowers/specs/2026-10-03-logijuice-design.md`: the spec (what and why).
- `docs/superpowers/plans/2026-10-03-logijuice.md`: the plan (tasks, code, tests, Codex-ready/hardware labels).
- `docs/bringup-notes.md`: real receiver behavior and byte layouts from Task 0.
- `docs/status/LAWS.md`: what is true always.
