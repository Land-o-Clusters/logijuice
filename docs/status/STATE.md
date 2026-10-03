# logijuice — STATE

What is true NOW. Replace §0 in place; never stack banners. Rules that hold always live in `LAWS.md`.

## §0 Current state (2026-10-03)

**Phase:** feature-complete for v1 except the owner-run checks. Tasks 0–18 done; Task 19 Steps 1–2 done.

**Done (verified):**
- Spec `0f2a347` (§7 amended: device-silhouette gauge, per-Mac pins, per-level tints), plan `9286109` + fixes, bring-up
  `ed186d4`. Tasks 1–13 `5d06b82`…`10386a7`; app `69a2e2a`; widget fix `d1a3fab` (owner saw it in the gallery);
  redesign `b06c3ae`; sync + settings `607649c`; settings clipping fix `9b47058`; settings polish `06b27d5` (alert bar,
  device gauge rows); app icon `bee399c`; Shortcuts `63cba5f` (App Intents metadata built by build-app.sh outside Xcode).
- `swift test` at `63cba5f`: **120 passed, 0 failed**. build-app.sh rc 0 (universal, ad-hoc, widget + Metadata.appintents
  + icon). Installed to /Applications at `63cba5f`.
- Owner-verified on hardware: receiver + both devices, notifications, Low nudge waits for lock, the widget in the
  gallery, three menu bar gauges, hover feedback, settings layout (pre-polish).
- **GitHub:** `Land-o-Clusters/logijuice` created **private** 2026-10-03 (owner: "all of it"); `main` pushed and tracking.

**In flight:**
- `main` at the commit adding this banner, pushed. Working tree clean. Merged branches `codex/logijuice-tasks-1-9` and
  `codex/widget-docs` are local only; worktree `../logijuice-codex` (Codex's, idle) can be removed.
- **Test settings still on (owner's Mac):** `defaults … debugMenu -bool true` and a "Test Mouse" (`debug:test-mouse`).
  Revert after the checklist: `defaults delete com.penguinspecz.logijuice debugMenu`, then "Debug: forget Test Mouse".
- No background jobs (the log stream hit its time limit and is not needed).

**Next action:** owner checks the Shortcuts actions, the polished settings window and the icon. Then check D (hub
switch) and the Task 19 Step 3 manual checklist (`docs/manual-checklist.md`) with the owner, then revert the test
settings.

**Open owner decisions:**
- Spec adjustments 1–9 (plan header): presented 2026-10-03, and the owner proceeded without objection. They stand
  unless overruled.
- Untested: a freshly powered receiver on a Mac **without** Options+ may send no events. The mitigation is a 30-minute
  re-read (decided; in the plan, Task 14).
- Repo creation and visibility, and when to buy the Apple Developer membership: both deferred to the owner.
- Puddle has the same widget crash. A task chip was offered to the owner (the Puddle repo isn't touched from here).
- **Before the repo goes public (it is private now):** the device serials and unit IDs in `docs/bringup-notes.md`, this file and
  `Tests/JuiceHIDTests/Fixtures/owner-mouse.json` are the owner's. Decide whether to scrub them (owner-tier).

## Reading List
- `docs/superpowers/specs/2026-10-03-logijuice-design.md`: the spec (what and why).
- `docs/superpowers/plans/2026-10-03-logijuice.md`: the plan (tasks, code, tests, Codex-ready/hardware labels).
- `docs/bringup-notes.md`: real receiver behavior and byte layouts from Task 0.
- `docs/status/LAWS.md`: what is true always.
