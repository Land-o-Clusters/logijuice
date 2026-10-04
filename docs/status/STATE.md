# logijuice STATE

What is true NOW. Replace §0 in place and never stack banners. Rules that hold always are in `LAWS.md`.

## §0 Current state (2026-10-04 00:45 UTC)

**Unsigned releases (owner, 2026-10-04):** no Developer ID until the owner settles a neutral signing entity (not their
name, not RoleGauge). Going public no longer waits on Apple. `scripts/release.sh` builds `dist/LogiJuice-0.1.0.zip`
(rc 0, 155 tests). The unzipped bundle verifies, and Gatekeeper rejects it while quarantined, as expected for an
unnotarized app (the user clicks Open Anyway).

**Repo hygiene pass (owner asked "fix it all"):** `debug capture` now redacts serial numbers and unit IDs (`b5cf2c5`,
verified on a hardware capture). `scripts/github-settings.sh` applied the description, topics, wiki and projects off,
delete-on-merge and `main` protection. README, issue templates and every doc under `docs/` (plan included) pass
Vale with 0 findings. CI is written and waits on the local `ci` branch
(`e61cdfc`) because the org ruleset blocks `.yml` pushes.

**Phase:** v1 feature-complete (plan Tasks 0 to 18 done, Task 19 Steps 1 and 2 done). Now in **Task 19 Step 3**, the
manual checklist (`docs/manual-checklist.md`). The charging follow-up (`edfd79b`) makes a charging device's fill and
bolt green and re-reads it every 60 s, which still needs a real charge to verify.

**Verified:**
- `swift test` at `b5cf2c5` exits 0 with **155 of 155 passing** (Store 10, HID 34, Core 101, CLI 10).
  `scripts/build-app.sh` rc 0 (universal, ad-hoc, widget with `_NSExtensionMain`, `Metadata.appintents`, icon).
- **Installed:** `/Applications/LogiJuice.app` built from `b5cf2c5`, running. `logijuice status` shows the mouse at 70%
  and the keyboard at 95%, both learning.
- Widget fix (`b8dfffb`): the app's writes to the app-group container failed with EPERM, so the widget and Shortcuts
  had no data. The snapshot moved to Application Support, and the owner confirmed both widget sizes show live data.
- Owner-verified on hardware earlier: receiver and both devices, notifications, the Low nudge waiting for a lock, the
  widget gallery, Shortcuts, icon, Options+ button, menu bar gauges, hover feedback and the glass settings window.
- Key commits: spec `0f2a347`, plan `9286109`, bring-up `6426d0d`, app `48e85f2`, widget gallery fix `cf291fc`,
  Lightspeed/voltage/headset `8c261f2` (untested on hardware), battery health `71e9da1`, charging `edfd79b`.
- **Secrets scrub done:** history was rewritten with fakes (`TESTKEYS0001`, `TESTMOUSE001`, `A1B2C3D4`, `D4C3B2A1`), and
  every SHA here is post-rewrite. The pre-scrub bundle exists only in an old session scratchpad with real IDs. Never
  push it.
- Checklist **passed** #1, #2, #7, #9 to #14. #11 was owner-driven, with evidence from `state.json` and `usernoted` logs.
  **Mon 2026-10-05:** #4, #5, #6, #15 (hub switch, sleep/wake, second Mac). #3 can't be tested because Options+ is a
  KeepAlive agent. #8 comes on the next full charge.

**In flight:**
- Branch `main`, HEAD = the commit adding this banner, pushed to `origin/main` (`Land-o-Clusters/logijuice`,
  **private**, now protected against force-push and deletion). juice-arch works in the app-made worktree
  `claude/boot-juice-arch-*` and fast-forwards `main`. Local branch `ci` holds the CI workflow, unpushed.
- **Test settings:** all reverted. The debug menu is off, Test Mouse is forgotten and the nickname is cleared.
- **Background jobs:** none of ours. A `log stream` with a display/powerd predicate belongs to another session, so
  leave it alone.
- **sleight** (owner's tool, `~/Projects/sleight`, owned by the "sleight arch" session) is installed for Claude Code at
  user scope, version 0.1.1. It asks for approval through its own macOS panel (Allow / Don't Allow, 5-minute timeout).
  An upgrade takes a **new session**, because `/reload-plugins` doesn't respawn its MCP server.
- Health tracking started 2026-10-03 22:24 UTC. The forecast should leave "learning" around Mon 2026-10-05, and health
  shows after 3 full charges.

**Next action:**
1. Optional, owner: run Shortcuts "Get Lowest Battery" once. It reads the same snapshot as the widget but hasn't been
   seen on hardware since the fix.
2. On the next real charge, confirm the fill rises (log line `charging: re-reading every 60 s`).
3. Mon 2026-10-05: #4, #5, #6, #15 with the owner.
4. Going public, each step **with an explicit owner yes**: delete and recreate the GitHub repo from the scrubbed
   history, make it public, then publish release v0.1.0 (see the checklist below).

**Go-public checklist** (on the recreated repo):
- Run `scripts/release.sh`, attach the zip to release v0.1.0, and set the printed `sha256` in `Casks/logijuice.rb`.
- Add download instructions to the README. A downloaded app has to be opened once via Open Anyway before the CLI runs.
- First real download test: after Open Anyway, the app launches and the bundled `logijuice` runs (not yet verified).
- Run `scripts/github-settings.sh`. Private vulnerability reporting is the step that only works once the repo is public.
- CI (owner decided 2026-10-04 to wait until public, when macOS minutes are free): the owner lifts the org ruleset
  for `.yml`, then push branch `ci` (or cherry-pick `e61cdfc`).

**Open owner decisions:**
- Going public needs an explicit yes to delete, recreate and flip visibility, and another to publish the release.
- Signing entity: the owner may give the planned RoleGauge LLC a neutral legal name so open-source projects can sign
  under it (to check with their advisor). Until then, releases stay ad-hoc signed.
- Spec adjustments 1 to 9 (plan header) stand. They were presented 2026-10-03 and the owner proceeded.
- Untested: a freshly powered receiver on a Mac without Options+ may not send events. The 30-minute re-read covers it.

## Reading List
- `docs/superpowers/specs/2026-10-03-logijuice-design.md`: the spec (what and why).
- `docs/superpowers/plans/2026-10-03-logijuice.md`: the plan (tasks, code, tests, Codex-ready/hardware labels).
- `docs/bringup-notes.md`: real receiver behavior and byte layouts from Task 0.
- `docs/status/LAWS.md`: what is true always.
- `docs/manual-checklist.md`: the owner-run hardware checklist (#4, #5, #6, #15 on Monday, #8 on a full charge).
- `README.md`: the user-facing summary, including the Supported hardware table (what is and isn't tested).
