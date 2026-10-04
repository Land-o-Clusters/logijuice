# logijuice STATE

What is true NOW. Replace §0 in place and never stack banners. Rules that hold always are in `LAWS.md`.

## §0 Current state (2026-10-04 01:15 UTC)

**Public, with release 0.1.0 (owner said "run it", 2026-10-04).** `Land-o-Clusters/logijuice` was deleted and
recreated from history rewritten to author `penguinspecz` (no legal name). Before the push, a scan of all 66 commits
found zero serials, unit IDs, hardware UUID, computer name, home path, legal name or personal email. The same scan
found them in the pre-scrub bundle, which proves it works. The repo is public with `scripts/github-settings.sh` applied
(private vulnerability reporting on, `main` protected). Release
[v0.1.0](https://github.com/Land-o-Clusters/logijuice/releases/tag/v0.1.0) has the ad-hoc signed zip (sha256
`03748718…f14d`). The downloaded asset matches the cask, `brew fetch` verified it through a tap of this repo, and
`brew audit --cask` is clean.

**Phase:** v1 feature-complete and released. Plan Task 19 Step 3 (manual checklist) is open until the Monday rows
and the charge rows pass. Signing waits for the owner's neutral entity (LAWS).

**Verified:**
- `swift test` at `fd57212` (the release commit) exits 0 with **155 of 155 passing** (Store 10, HID 34, Core 101,
  CLI 10), run by `scripts/release.sh`.
- **Installed:** `/Applications/LogiJuice.app` runs the same app code as 0.1.0 (built at `191bad6`; later commits only
  touch docs, scripts and the cask).
- Widget fix (`811426d`) and capture redaction (`191bad6`) were verified on hardware.
- The README header follows sleight's layout and was checked on the GitHub page. Its centered app icon is
  `docs/assets/logijuice-icon-*.png`, exported from `Resources/AppIcon.icns`. Below it are the menu and widget screenshots
  (`docs/assets/menu.png`, `widgets.png`, cropped from owner screenshots with the debug rows removed).
- The repo's social preview is `docs/assets/social-preview.png` (1280×640), uploaded through Helium with sleight on
  2026-10-04. GraphQL `usesCustomOpenGraphImage` is true. GitHub has no API to set it.
- Owner-verified on hardware earlier: receiver and both devices, notifications, the Low nudge waiting for a lock, the
  widget gallery, Shortcuts, icon, Options+ button, menu bar gauges, hover feedback and the glass settings window.
- Key commits (post-rewrite): spec `48eeb46`, plan `03289df`, bring-up `c68e66c`, app `a987c91`, widget gallery fix
  `b4aff59`, Lightspeed/voltage/headset `201ee79` (untested on hardware), battery health `e7ee17c`, charging `67c5d51`.
- Checklist **passed** #1, #2, #7, #9 to #14. #3 can't be tested because Options+ is a KeepAlive agent.

**In flight:**
- Branch `main` = `origin/main`, HEAD = the commit adding this banner. juice-arch works in the app-made worktree
  `claude/boot-juice-arch-*` and fast-forwards `main`. The repo's git config sets `user.name penguinspecz`.
- Local branch `ci` (`9f805ee`) holds the CI workflow, unpushed until the owner lifts the org `.yml` ruleset.
- **Real IDs still on disk:** the old pre-scrub bundle in an old session scratchpad
  (`logijuice-pre-scrub.bundle`). Deleting it is the owner's call. This session's scratch copies were deleted.
- **Background jobs:** none of ours. A `log stream` with a display/powerd predicate belongs to another session, so
  leave it alone.
- **sleight** (owner's tool, `~/Projects/sleight`, owned by the "sleight arch" session) is installed for Claude Code at
  user scope, version 0.1.1. It asks for approval through its own macOS panel (Allow / Don't Allow, 5-minute timeout).
  An upgrade takes a **new session**, because `/reload-plugins` doesn't respawn its MCP server.
- Health tracking started 2026-10-03 22:24 UTC. The forecast should leave "learning" around Mon 2026-10-05, and health
  shows after 3 full charges.

**Next action:**
1. Owner: lift the org `.yml` ruleset, then juice-arch pushes `ci` and watches the first run.
2. Owner, optional: download the zip in a browser and approve it with Open Anyway, then run `logijuice status` from
   the bundle. This confirms the CLI runs once the app is approved (not yet seen). Quit the installed app first.
3. Owner, optional: run Shortcuts "Get Lowest Battery" once (same snapshot as the widget, not seen since the fix).
4. On the next real charge, confirm the fill rises (log line `charging: re-reading every 60 s`), then #8.
5. Mon 2026-10-05: #4, #5, #6, #15 with the owner. Then tick plan Task 19 Steps 3 and 4.

**Open owner decisions:**
- Signing entity: the owner may give the planned RoleGauge LLC a neutral legal name so open-source projects can sign
  under it (to check with their advisor). Until then, releases stay ad-hoc signed.
- Whether to delete the pre-scrub bundle.
- Spec adjustments 1 to 9 (plan header) stand. They were presented 2026-10-03 and the owner proceeded.
- Untested: a freshly powered receiver on a Mac without Options+ may not send events. The 30-minute re-read covers it.

## Reading List
- `docs/superpowers/specs/2026-10-03-logijuice-design.md`: the spec (what and why).
- `docs/superpowers/plans/2026-10-03-logijuice.md`: the plan (tasks, code, tests, Codex-ready/hardware labels).
- `docs/bringup-notes.md`: real receiver behavior and byte layouts from Task 0.
- `docs/status/LAWS.md`: what is true always.
- `docs/manual-checklist.md`: the owner-run hardware checklist (#4, #5, #6, #15 on Monday, #8 on a full charge).
- `README.md`: the user-facing summary and install instructions.
