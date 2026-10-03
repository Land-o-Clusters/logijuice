# logijuice — STATE

What is true NOW. Replace §0 in place; never stack banners. Rules that hold always live in `LAWS.md`.

## §0 Current state (2026-10-03, juice-arch re-booted 22:28 UTC)

**Phase:** v1 feature-complete. Plan Tasks 0–18 are done; Task 19 Steps 1–2 are done. What's left: **Task 19 Step 3**
(the manual checklist, owner-run) and the hub-switch check, plus the post-plan items under Next.

**Verified (2026-10-03):**
- `swift test` at `674d204` (re-run on boot): **145 passed, 0 failed**, rc 0 (Store 9, HID 34, Core 96, CLI 6). `scripts/build-app.sh` rc 0: universal, ad-hoc, with widget,
  `Metadata.appintents` and icon; it refuses to package a widget without `_NSExtensionMain` or without intents metadata.
  The app is installed to `/Applications/LogiJuice.app` from `71e9da1` and is running.
- Owner-verified on hardware: receiver and both devices, notifications, the Low nudge waiting for a lock, the widget in
  the gallery, Shortcuts actions, the icon, Options+ button, menu bar gauges, hover feedback, glass settings with the
  backdrop tuned.
- Key commits: spec `0f2a347`, plan `9286109`, bring-up `6426d0d`, app `48e85f2`, widget fix `cf291fc`, glass settings
  `914786c`, backdrop `cf774a0`, Lightspeed/voltage/headset `8c261f2` (untested on hardware), battery health `71e9da1`.
- **Secrets scrub done:** serials and unit IDs were replaced by fakes in all history (`TESTKEYS0001`, `TESTMOUSE001`,
  `A1B2C3D4`, `D4C3B2A1`). History was rewritten and force-pushed; every SHA here is post-rewrite. A pre-scrub bundle
  `logijuice-pre-scrub.bundle` sits in the session scratchpad only (it contains the real IDs; never push it).
- Manual checklist (`docs/manual-checklist.md`, committed on boot: it was cited here but never in git; the plan's
  checkboxes for Tasks 0–18 and Task 19 Steps 1–2 were also ticked then, after being left blank):
  - Passed: #1, #2, #9, #10, #12, #14. #14 caught the CLI learning text, which was fixed in `dd0f4a9`.
  - Owner still to report: **#6 (sleep/wake), #7 (charging bolt), #11 (snooze, then escalation), #13 (rename)**.
  - Parked to **Mon 2026-10-05**: #4, #5, #15 (hub switch, second Mac).
  - #3 isn't testable (Options+ is a KeepAlive agent). #8 happens on the next full charge.

**In flight:**
- Branch `main` at the commit adding this banner, 0 ahead / 0 behind `origin/main` (`Land-o-Clusters/logijuice`,
  **private**). Working tree clean. Only worktree: the main checkout. No other local branches.
- **Test settings still on (owner's Mac):** `debugMenu = 1` in `com.penguinspecz.logijuice` defaults. Checklist #11
  needs it. Revert after #11: `defaults delete com.penguinspecz.logijuice debugMenu`, then "Debug: forget Test Mouse"
  from the dropdown if a Test Mouse exists.
- Background jobs: none of ours. (A `log stream` with a display/powerd predicate is running; it belongs to another
  session. Don't touch it.)
- The Puddle widget crash was FYI'd to the "puddle arch" session. It filed `WIDGET-EXTENSION-MAIN-1`, crediting
  `cf291fc`. Nothing more is owed.
- Health tracking started 2026-10-03 22:24 UTC on both devices. The forecast leaves "learning" around Mon 2026-10-05;
  health appears after 3 full charges.

**Next action:**
1. Collect the owner's checklist results for #6/#7/#11/#13. Fix anything that fails test-first. Then revert the test
   settings.
2. Mon 2026-10-05: hub switch with the owner (#4, #5, #15).
3. When the owner says the Apple Developer membership is bought: wire `SIGNING_IDENTITY` and notarization into
   `build-app.sh`, make a release zip, fill in the cask `sha256`. Then, **with an explicit owner yes**, delete and
   recreate the GitHub repo from the scrubbed history (old SHAs stay fetchable on GitHub otherwise) and make it public.

**Open owner decisions:**
- Going public: needs the Apple membership, then an explicit yes to delete+recreate and flip visibility.
- Spec adjustments 1–9 (plan header) stand. They were presented 2026-10-03, and the owner proceeded.
- Untested: a freshly powered receiver on a Mac without Options+ may send no events. It's mitigated by the 30-minute
  re-read.

## Reading List
- `docs/superpowers/specs/2026-10-03-logijuice-design.md`: the spec (what and why).
- `docs/superpowers/plans/2026-10-03-logijuice.md`: the plan (tasks, code, tests, Codex-ready/hardware labels).
- `docs/bringup-notes.md`: real receiver behavior and byte layouts from Task 0.
- `docs/status/LAWS.md`: what is true always.
- `docs/manual-checklist.md`: the owner-run hardware checklist (live: #6/#7/#11/#13 pending, #4/#5/#15 Monday).
- `README.md`: the user-facing summary, including the Supported hardware table (what is and isn't tested).
