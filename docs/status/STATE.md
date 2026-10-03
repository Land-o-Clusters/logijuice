# logijuice — STATE

What is true NOW. Replace §0 in place; never stack banners. Rules that hold always live in `LAWS.md`.

## §0 Current state (2026-10-03)

**Phase:** feature-complete for v1 except the owner-run checks. Tasks 0–18 done; Task 19 Steps 1–2 done.

**Done (verified):**
- Spec `0f2a347` (§7 amended: device-silhouette gauge, per-Mac pins, per-level tints), plan `9286109` + fixes, bring-up
  `6426d0d`. Tasks 1–13 `8cfa168`…`42c135a`; app `48e85f2`; widget fix `cf291fc` (owner saw it in the gallery);
  redesign `ca9dfc7`; sync + settings `131fa20`; settings clipping fix `3e001fe`; settings polish `ca6d726` (alert bar,
  device gauge rows); app icon `e756b16`; Shortcuts `a40db04` (App Intents metadata built by build-app.sh outside Xcode).
  Learning progress `9220136`; Liquid Glass settings `914786c`; backdrop `cf774a0` (.popover material at full blur, owner-tuned 3% fade).
- `swift test` at the battery-health commit: **145 passed, 0 failed**. build-app.sh rc 0 (universal, ad-hoc, widget + Metadata.appintents
  + icon). Installed to /Applications at `a40db04`.
- Owner-verified on hardware: receiver + both devices, notifications, Low nudge waits for lock, the widget in the
  gallery, three menu bar gauges, hover feedback, settings layout (pre-polish).
- **GitHub:** `Land-o-Clusters/logijuice` created **private** 2026-10-03 (owner: "all of it"); `main` pushed and tracking.

- **Secrets scrub 2026-10-03 (owner: "definitely big secrets scrub"):** device serials and unit IDs replaced in all
  history with fakes (`TESTKEYS0001`, `TESTMOUSE001`, `A1B2C3D4`, `D4C3B2A1`, including hex-encoded bytes in the
  replay fixture). History rewritten with filter-branch and force-pushed; SHAs cited here are post-rewrite. A pre-scrub
  backup bundle exists only in the session scratchpad (contains the real IDs; never push it).

- Lightspeed + 0x1001 voltage + headset kind `8c261f2` (untested on hardware; README says so). Battery health and
  the opt-in drain alert landed 2026-10-03 (owner-approved design; health appears after 3 full charges).
- Checklist 2026-10-03: #12 (no duplicate notifications on relaunch) and #14 (CLI JSON) passed; #14 caught the
  CLI learning text (fixed). #1, #2, #9 and #10 were covered earlier. Owner still to report #6, #7, #11 and #13.
  Parked to Monday: #4, #5 and #15 (hub switch, second Mac). #3 isn't testable (Options+ restarts itself). #8
  happens naturally.

**In flight:**
- `main` at the commit adding this banner, pushed. Working tree clean. Merged branches `codex/logijuice-tasks-1-9` and
  `codex/widget-docs` are local only; worktree `../logijuice-codex` (Codex's, idle) can be removed.
- **Test settings still on (owner's Mac):** `defaults … debugMenu -bool true` and a "Test Mouse" (`debug:test-mouse`).
  Revert after the checklist: `defaults delete com.penguinspecz.logijuice debugMenu`, then "Debug: forget Test Mouse".
- No background jobs (the log stream hit its time limit and is not needed).

**Next action:** owner reports checklist #6/#7/#11/#13; then check D (Monday) (hub
switch) and the Task 19 Step 3 manual checklist (`docs/manual-checklist.md`) with the owner, then revert the test
settings.

**Open owner decisions:**
- Spec adjustments 1–9 (plan header): presented 2026-10-03, and the owner proceeded without objection. They stand
  unless overruled.
- Untested: a freshly powered receiver on a Mac **without** Options+ may send no events. The mitigation is a 30-minute
  re-read (decided; in the plan, Task 14).
- Repo creation and visibility, and when to buy the Apple Developer membership: both deferred to the owner.
- Puddle has the same widget crash. A task chip was offered to the owner (the Puddle repo isn't touched from here).
- **Before the repo goes public:** serials are scrubbed. GitHub may still serve the old commits by direct SHA, so
  recreate the repo (delete + create) before flipping it public. That's owner-tier and needs an explicit yes.

## Reading List
- `docs/superpowers/specs/2026-10-03-logijuice-design.md`: the spec (what and why).
- `docs/superpowers/plans/2026-10-03-logijuice.md`: the plan (tasks, code, tests, Codex-ready/hardware labels).
- `docs/bringup-notes.md`: real receiver behavior and byte layouts from Task 0.
- `docs/status/LAWS.md`: what is true always.
