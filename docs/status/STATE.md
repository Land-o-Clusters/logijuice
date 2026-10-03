# logijuice — STATE

What is true NOW. Replace §0 in place; never stack banners. Rules that hold always live in `LAWS.md`.

## §0 Current state (2026-10-03 23:35 UTC, flushed for a clear)

**Phase:** v1 feature-complete (plan Tasks 0–18 done, Task 19 Steps 1–2 done). Now in **Task 19 Step 3**, the manual
checklist (`docs/manual-checklist.md`). Charging follow-up landed (`edfd79b`): a charging device's fill and bolt are
green, and charging devices are re-read every 60 s so the fill rises. It still needs a real charge to verify.

**Verified (2026-10-03):**
- `swift test` at `edfd79b`: **150 passed, 0 failed**, rc 0 (Store 9, HID 34, Core 101, CLI 6). `scripts/build-app.sh`
  rc 0 (universal, ad-hoc, widget with `_NSExtensionMain`, `Metadata.appintents`, icon). The icon was rendered offline in
  light and dark: pale green on a dark bar, deeper green on a light one, idle gauges unchanged.
- **Installed:** `/Applications/LogiJuice.app` built from `edfd79b`, running. `logijuice status`: mouse 70%, keyboard
  95%, both learning.
- Owner-verified on hardware (earlier): receiver and both devices, notifications, Low nudge waits for a lock, widget in
  the gallery, Shortcuts, icon, Options+ button, menu bar gauges, hover feedback, glass settings.
- Key commits: spec `0f2a347`, plan `9286109`, bring-up `6426d0d`, app `48e85f2`, widget fix `cf291fc`, Lightspeed/
  voltage/headset `8c261f2` (untested on hardware), battery health `71e9da1`, charging `edfd79b`.
- **Secrets scrub done:** history rewritten with fakes (`TESTKEYS0001`, `TESTMOUSE001`, `A1B2C3D4`, `D4C3B2A1`); all
  SHAs here are post-rewrite. The pre-scrub bundle lives only in an old session scratchpad (real IDs; never push it).
- Checklist: **passed** #1, #2, #7, #9, #10, #12, #14. **Pending:** #11 (snooze, then escalation) and #13 (rename);
  juice-arch drives these with sleight in the next session. **Mon 2026-10-05:** #4, #5, #6, #15 (hub switch, sleep/wake,
  second Mac). #3 isn't testable (Options+ is a KeepAlive agent). #8 comes on the next full charge.

**In flight:**
- Branch `main`, HEAD = the commit adding this banner, 0 ahead / 0 behind `origin/main` (`Land-o-Clusters/logijuice`,
  **private**). Working tree clean. Only worktree: the main checkout. No other branches.
- **Test settings on (owner's Mac):** `debugMenu = 1` in `com.penguinspecz.logijuice`. #11 needs it. After #11:
  `defaults delete com.penguinspecz.logijuice debugMenu`, then "Debug: forget Test Mouse" from the dropdown if one exists.
- **Background jobs:** none of ours. (A `log stream` with a display/powerd predicate belongs to another session; leave it.)
- **sleight** (owner's tool, `~/Projects/sleight`, owned by the "sleight arch" session) is installed for Claude Code at
  user scope, now 0.1.1. 0.1.0 had approvals silently declined in the desktop Code tab; 0.1.1 asks via its own macOS
  panel (Allow / Don't Allow, 5-min timeout). `/reload-plugins` does NOT respawn the MCP server, so it takes a **new
  session**. Both findings were sent to "sleight arch".
- Health tracking started 2026-10-03 22:24 UTC; the forecast leaves "learning" around Mon 2026-10-05; health shows after
  3 full charges.

**Next action:**
1. Run #11 and #13 with sleight (`cua.getApp("/Applications/LogiJuice.app")`; the owner clicks Allow on the panel).
   - **#13:** rename a device in Settings, then check the menu, the widget and `logijuice status`.
   - **#11:** debug "simulate 18%", lock the screen, "Snooze 1 day" on the Low alert, then "simulate 8%". The Very low
     alert must still fire (there's no 4% button; 8% is the escalation).
   Fix failures test-first, record results in the checklist, then revert the test settings.
2. On the next real charge, confirm the fill rises (log line `charging: re-reading every 60 s`).
3. Mon 2026-10-05: #4, #5, #6, #15 with the owner.
4. When the owner says the Apple Developer membership is bought: wire `SIGNING_IDENTITY` and notarization into
   `build-app.sh`, make a release zip, fill in the cask `sha256`. Then, **with an explicit owner yes**, delete and
   recreate the GitHub repo from the scrubbed history and make it public.

**Open owner decisions:**
- Going public: needs the Apple membership, then an explicit yes to delete+recreate and flip visibility.
- Spec adjustments 1–9 (plan header) stand (presented 2026-10-03; owner proceeded).
- Untested: a freshly powered receiver on a Mac without Options+ may send no events (mitigated by the 30-min re-read).

## Reading List
- `docs/superpowers/specs/2026-10-03-logijuice-design.md`: the spec (what and why).
- `docs/superpowers/plans/2026-10-03-logijuice.md`: the plan (tasks, code, tests, Codex-ready/hardware labels).
- `docs/bringup-notes.md`: real receiver behavior and byte layouts from Task 0.
- `docs/status/LAWS.md`: what is true always.
- `docs/manual-checklist.md`: the owner-run hardware checklist (live: #11/#13 pending, #4/#5/#6/#15 Monday).
- `README.md`: the user-facing summary, including the Supported hardware table (what is and isn't tested).
