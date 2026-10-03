# logijuice — STATE

What is true NOW. Replace §0 in place; never stack banners. Rules that hold always live in `LAWS.md`.

## §0 Current state (2026-10-03)

**Phase:** design done, bring-up done, implementation not started.

**Done (verified):**
- Spec approved and committed: `0f2a347`.
- Plan written: `9286109` (20 tasks, numbered 0–19). Task 0 bring-up is done: `ed186d4`. Findings are in
  `docs/bringup-notes.md`, and the plan and spec were updated from them.
- On the owner's Mac, the Bolt receiver (`0xC548`) exposes a single HID++ collection. Slot 1 is the **MX Keys S**
  (serial `TESTKEYS0001`) and slot 2 the **MX Master 3S** (`TESTMOUSE001`). Both report battery through 0x1004 at
  index 0x08 with a percentage. Battery events and 0x41 link events arrive. Options+ uses software ID `0xF`.

**In flight:**
- Branch `main` at the commit that adds this file (`git log -1 -- docs/status/STATE.md`). Working tree clean.
- No other worktrees. No background jobs.
- **No `origin` remote:** `Land-o-Clusters/logijuice` has not been created (owner-tier), so every commit is
  local-only.
- The owner was offered a Codex prompt for plan Tasks 1–9; whether it was dispatched is unknown. **Before starting
  Task 1, check `git log --all` for Task 1 commits** ("Scaffold package and core models").

**Next action:** plan **Task 1** (package scaffold + core models), unless it has landed. The Core track (Tasks 2–9)
and the HID track (Tasks 10–12) can then run in parallel. Tasks 13–15 and 18 need the owner's Mac and receiver.

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
