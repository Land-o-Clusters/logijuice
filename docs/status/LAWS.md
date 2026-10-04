# logijuice LAWS

What is true ALWAYS. A line belongs here only if it would change when we were **wrong**. Anything that changes when the
**world** moves (progress, measurements, SHAs, what's next) belongs in `STATE.md`. Never put a measurement here.

## Product
- **The scope is battery only.** logijuice fills one gap: battery visibility and reliable low-battery alerts for
  Logitech devices on a Bolt/Unifying receiver. It never replaces Logi Options+ or its features (remapping, gestures,
  firmware, pairing). Native-Bluetooth devices and Windows/Linux are out of scope.
- **Read-only toward hardware.** Send only HID++ getter functions: root getFeature/ping, 0x0003 fn0/fn2,
  0x0005 fn0/1/2, 0x1004 fn0/1, 0x1000 fn0, 0x1001 fn0. Never write a register or a device setting, including the receiver's
  notification flags (register 0x00).
- **Coexist with Options+.** Open HID devices non-exclusively. Every request uses software ID `0x0A`, and replies with
  any other non-zero software ID are ignored (Options+ uses `0xF`).
- **Use the percentage** when 0x1004 capabilities say it's supported. The level mask is too coarse to drive anything.
- **The menu bar icon is the device's own silhouette used as a battery gauge** (owner, 2026-10-03). A battery glyph
  reads as the Mac's own battery. Only the filled part and the percentage take the alert color.
- **Menu bar pins are per Mac** and not synced (menu bar space differs per Mac).
- **Alert colors are per level** (none/yellow/red; defaults Low yellow, Very low and Critical red). Only the fill and
  the percentage take the color. The empty part keeps the neutral color.
- **Charging is green** (owner, 2026-10-03): a charging device's fill and bolt are green, pale on a dark menu bar and
  deeper on a light one. The fill must never read lighter than the empty part. The widget's bolts are green too.
- **A charging device is re-read every 60 s** so the gauge fills while it charges (devices don't reliably send each
  step on the cable). The re-read stops when nothing is charging or the device's link drops.
- **Battery health is an estimate and says so.** It's inferred from runs and charge gains, because the protocol reports
  no capacity or cycles. It's shown only after 3 full charges, and the trend only after 6. The drain alert is opt-in
  and off by default.
- **Untested hardware is labelled untested** in the receiver catalog (`verified: false`) and in the README until a
  hardware run proves it.
- **Only `.local` readings fire alerts.** Synced readings update displays and forecasts only.
- **The only data that leaves the Mac is the owner's own iCloud Drive file** (`iCloud Drive/logijuice/<hardware-UUID>.json`,
  one per Mac, each Mac writes only its own). There is no telemetry and no network code.
- **No personal identifiers in the repo.** Never commit device serials, unit IDs, hardware UUIDs, Mac names or home
  paths. Fixtures use the fakes `TESTKEYS0001`, `TESTMOUSE001`, `A1B2C3D4`, `D4C3B2A1` (including as hex bytes in
  captures).
- **`debug capture` redacts before writing.** Serial numbers and unit IDs are removed from the file and from the
  printed summary, and raw frames are never printed live, because users attach captures to public issues. A change
  to the capture tool needs a hardware capture checked for the real IDs.
- **Unofficial.** The README always includes "logijuice is unofficial and not affiliated with or endorsed by Logitech."

## Platform and build
- macOS 14.0 minimum. `swift-tools-version: 5.10`, Swift 5 language mode. No third-party dependencies.
- Every `swift`/`xcrun` command runs with `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`
  (`xcode-select` points at the Command Line Tools, which can't build XCTest or WidgetKit).
- Bundle ID `com.penguinspecz.logijuice` and widget `com.penguinspecz.logijuice.widget`. The logger subsystem is
  `com.penguinspecz.logijuice`. App display name **LogiJuice**; repo and CLI command **logijuice** (built as product
  `logijuice-cli`, because APFS is case-insensitive).
- **No app-group container while ad-hoc signed.** macOS refuses the non-sandboxed, ad-hoc-signed app's writes there
  (EPERM, silently through `try?`), which left the widget and Shortcuts empty. The one snapshot is stored in
  `~/Library/Application Support/logijuice/`. The sandboxed widget reads it via a read-only home-relative exception
  and resolves the home from `getpwuid` (its own home is the sandbox container). Persistence errors are logged, never
  swallowed.
- **App extensions are linked with `-e _NSExtensionMain`**, as Xcode does. Without it the widget traps at launch and
  never reaches the gallery. `scripts/build-app.sh` refuses to package one that doesn't.
- **App Intents only run in an app with a Team ID.** `linkd` rejects an ad-hoc-signed app (`requiresValidatedBundle`),
  so the actions appear in Shortcuts but fail to run. A Shortcuts check must run an action, not just find it.
- **Shortcuts actions are built only into signed apps** (owner, 2026-10-04). `App/ShortcutsIntents.swift` compiles under
  `LOGIJUICE_APP_INTENTS`, which `build-app.sh` sets when `SIGNING_IDENTITY` is set (`LOGIJUICE_APP_INTENTS=1`
  forces it). An unsigned build that still contains the intents is refused (exit 68).
- **App Intents metadata is built outside Xcode:** the App target's release flags emit Swift const values, and
  `build-app.sh` runs `appintentsmetadataprocessor` when intents are on, refusing to package without
  `GetLowestBatteryIntent`.
- **Releases are ad-hoc signed** (owner, 2026-10-04). The owner's personal name and RoleGauge are never used to
  sign. Developer ID signing waits until the owner settles a neutral signing entity, and `SIGNING_IDENTITY` switches
  to it then. Going public doesn't depend on it. `scripts/release.sh` builds the zip and publishes nothing.
- **A downloaded release is blocked until the user approves it**, including the bundled CLI (Gatekeeper kills it with
  exit 137 while the bundle is quarantined). The download instructions say to open the app once, via Open Anyway,
  before using `logijuice`.

## Repo
- **Docs pass Vale.** `.vale.ini` uses the `ai-tells` pack pinned like sleight's. Run `vale sync` once, then
  `vale README.md .github docs`, and fix prose with the humanizer skill (`.claude/skills/humanizer`) rather than
  word swaps. User-facing text is written to pass before it's committed.
- **GitHub settings come from `scripts/github-settings.sh`**, re-run on any recreated repo. Community files (code of
  conduct, contributing, security, PR template) come from the org `.github` repo, so they aren't duplicated here.
- **Commits are authored as `penguinspecz`** with the GitHub no-reply email, set in the repo's own git config (git
  otherwise falls back to the macOS account's full name). The owner's legal name never goes into a commit.
- **The public history is never rewritten.** `main` is protected against force-push. The one rewrite happened before
  the repo went public (2026-10-04: scrubbed IDs, author name).
- **The org ruleset blocks pushing any `*.yml`/`*.yaml`.** Issue templates are Markdown. Changing a workflow needs the
  owner's yes to set ruleset 22105960 to `disabled`, push, and set it back to `active` right away (verify with
  `gh api orgs/Land-o-Clusters/rulesets/22105960 --jq .enforcement`). CI runs `swift test`, `build-app.sh` and Vale.
- **Releasing:** bump the version and build-number defaults in `build-app.sh` and `release.sh`, run
  `scripts/release.sh`, and put the printed sha256 and version in `Casks/logijuice.rb`. Publishing a release needs the
  owner's yes. After publishing, check that the downloaded asset matches the cask, then `brew tap` this repo, run
  `brew fetch --cask` and `brew audit --cask`, and untap. Release notes pass Vale (`vale --config .vale.ini`).

## Method
- **Verify instead of trusting:** "done" means the tests were re-run and their output read, and hardware claims need
  a hardware run.
- **A UI is verified only in its real host:** the widget in the gallery, the icon in the menu bar, alerts in
  Notification Center. "It builds" or "pluginkit lists it" is not "it works". Puddle's widget pattern was copied
  unverified and crashed.
- **Check UI layout yourself before the owner sees it.** `defaults write com.penguinspecz.logijuice
  debugSettingsSnapshotPath /tmp/x.png` writes a PNG plus metrics of the settings window. It shows layout only: glass
  and behind-window blur don't render into it, so materials need an owner screenshot. The built-in computer-use tools
  can't see LogiJuice (menu-bar-only app). **Drive LogiJuice's UI with sleight**, passing the full path
  `/Applications/LogiJuice.app` (the `dist/` build shares the bundle ID, so the ID is ambiguous).
- **A missing banner is not a missing alert.** macOS hides banners (e.g. "display shared" while the screen is
  captured) after the app posted correctly. Judge alerts by `usernoted` logs ("Delivering … req:<device>.<level>") and
  `state.json`, not by what appeared on screen. sleight reaches LogiJuice's windows only, not its status item or
  Notification Center, so dropdown and notification-action steps are owner-driven.
- **Settings uses a custom glass layout.** On macOS 27 a grouped `Form` needs ≥ ~744pt, and its rows grow label
  columns.
- **Never fade the window's blur by more than ~5%** (`NSVisualEffectView.alphaValue`). Fading cuts holes and the sharp
  desktop shows through. For more translucency, change the material.
- **Run checks bare, capture the exit code, commit only on 0.** Never `check | tail && git commit`: the `&&` reads the
  pipe's status, not the check's.
- **Commit with the pathspec on the commit:** `git commit -m "…" -- <paths>`. Use `git add -- <path>` only for a file
  git doesn't track yet. Never `git add -A`, never a bare commit.
  The one exception is concluding a merge: check that `git status` shows only the merge's files, then `git commit --no-edit`.
- **Branch authority:** for each status file, the newest commit that touches it on any branch is authoritative.
- **STATE.md is updated as work happens.** The §0 banner is replaced in place and never stacked, and the file stays
  under 32 KB. The handoff is written as work goes, not at clear time.
- **Decisions are ruled and recorded** in a committed doc with a one-line rationale. The owner overrules explicitly.
- **Owner-tier, always ask first:** creating, publishing, deleting or changing visibility of the GitHub repo, spending
  money, any hardware write, and scope changes to the spec. The repo is public since 2026-10-04,
  recreated from scrubbed history.
