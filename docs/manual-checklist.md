# Manual hardware checklist

Run on the owner's Mac with the Bolt receiver, a percent-reporting mouse and keyboard. Record pass/fail and notes.
Results so far come from the 2026-10-03 owner runs. Rows marked _pending_ still need a run.

| # | Check | Expected | Result |
|---|---|---|---|
| 1 | Fresh launch (delete `~/Library/Application Support/logijuice` first) | Settings window opens; notification prompt; devices appear within ~10 s of waking them | Pass (2026-10-03) |
| 2 | Logi Options+ running alongside | Options+ battery and remapping keep working; LogiJuice readings match Options+ | Pass (2026-10-03) |
| 3 | Quit Options+ | LogiJuice keeps reading (wake a device → updates) | Not testable: Options+ is a `KeepAlive` launchd agent (see `bringup-notes.md`) |
| 4 | Hub switched away | Dropdown says "Receiver not connected to this Mac"; "seen …" times; pending Low nudge delivered as "Leaving this desk?" | _pending_ (scheduled Mon 2026-10-05) |
| 5 | Hub switched back | Readings resume without relaunching | _pending_ (scheduled Mon 2026-10-05) |
| 6 | Sleep / wake the Mac | No crash; readings resume after wake; pending nudge delivered on sleep | _pending_ (moved to Mon 2026-10-05, with the hub) |
| 7 | Charging cable plugged into the mouse | Menu bar icon appears (Auto) with a bolt; pending nudges dropped | Pass (2026-10-03), mouse and keyboard. Follow-up: green charging fill and bolt, and a 60 s re-read so the fill rises while charging (re-check on the next real charge) |
| 8 | Charge to full | "Fully charged" notification once | _pending_ (next full charge) |
| 9 | Debug simulate 18% → lock screen | Low nudge arrives at lock, not before | Pass (2026-10-03) |
| 10 | Debug simulate 8% | Immediate Very low notification; red icon; widget ring red | Pass (2026-10-03) |
| 11 | Notification "Snooze 1 day" on a Low alert, then simulate 4% | Critical still alerts (escalation) | Pass (2026-10-03), run with 8% (no 4% button; Very low is the escalation): the Low nudge was held from simulate until lock and posted 0.4 s after it; Snooze set a 24 h snooze at Low; 8% fired Very low anyway and macOS delivered it. Note: macOS silenced the first banner ("display shared", while screen capture was active), so banners can be muted by system settings even when delivery is correct |
| 12 | Relaunch after alerts fired | No duplicate notifications | Pass (2026-10-03) |
| 13 | Rename a device in Settings | Menu, widget and `logijuice status` show the nickname | Pass (2026-10-03): mouse renamed "Desk Mouse" with sleight; Settings, `logijuice status`/`devices`, the menu and both widget sizes (owner screenshots) showed it. The first widget look found it empty: the app's snapshot writes to the app-group container failed (EPERM), fixed in `b8dfffb` |
| 14 | `logijuice status --json` | Valid JSON matching the menu | Pass (2026-10-03). The plain `status` showed a bare "learning…"; fixed in `dd0f4a9` to show learning progress |
| 15 | Second Mac (if available) | Other Mac shows synced readings; only the Mac with the receiver alerts | _pending_ (scheduled Mon 2026-10-05) |

Fix failures through the owning task's tests before marking them as passing.
