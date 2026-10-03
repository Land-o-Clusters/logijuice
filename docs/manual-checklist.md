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
| 6 | Sleep / wake the Mac | No crash; readings resume after wake; pending nudge delivered on sleep | _pending_ |
| 7 | Charging cable plugged into the mouse | Menu bar icon appears (Auto) with a bolt; pending nudges dropped | _pending_ |
| 8 | Charge to full | "Fully charged" notification once | _pending_ (next full charge) |
| 9 | Debug simulate 18% → lock screen | Low nudge arrives at lock, not before | Pass (2026-10-03) |
| 10 | Debug simulate 8% | Immediate Very low notification; red icon; widget ring red | Pass (2026-10-03) |
| 11 | Notification "Snooze 1 day" on a Low alert, then simulate 4% | Critical still alerts (escalation) | _pending_ (needs `debugMenu = 1`) |
| 12 | Relaunch after alerts fired | No duplicate notifications | Pass (2026-10-03) |
| 13 | Rename a device in Settings | Menu, widget and `logijuice status` show the nickname | _pending_ |
| 14 | `logijuice status --json` | Valid JSON matching the menu | Pass (2026-10-03). The plain `status` showed a bare "learning…"; fixed in `dd0f4a9` to show learning progress |
| 15 | Second Mac (if available) | Other Mac shows synced readings; only the Mac with the receiver alerts | _pending_ (scheduled Mon 2026-10-05) |

Fix failures through the owning task's tests before marking them as passing.
