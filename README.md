# logijuice 🔋🐧

Battery levels and low-battery alerts for Logitech keyboards and mice connected through a **Logi Bolt** (or Unifying) receiver, which macOS's own battery UI can't see.

> logijuice is unofficial and not affiliated with or endorsed by Logitech. "Logitech", "Logi Bolt", "Unifying" and "Logi Options+" are trademarks of Logitech.

## What it does

- **Stays out of the way.** The menu bar icon appears only when a battery is low or charging (or always, if you prefer).
- **Escalating alerts, all customizable.**
  - Low (20%) waits for a natural moment: screen lock, end of day, before sleep, or when your hub switches away ("Leaving this desk?").
  - Very low (10%) and Critical (5%) alert right away. Critical repeats daily until you charge.
- **Time-left forecast.** It learns each device's real drain rate: "~9 days left".
- **Widgets.** Small and medium desktop and Notification Center widgets.
- **Works across Macs.** Readings sync through your own iCloud Drive, so a hub-switching setup still shows recent values, and only the Mac holding the receiver alerts you.
- **Plays nicely with Logi Options+.** logijuice only *reads* battery information and never changes device settings.
- **Scriptable.** `logijuice status --json`.

## Supported hardware

| Receiver | Status |
|---|---|
| **Logi Bolt** (`C548`) | Tested: MX Keys S, MX Master 3S |
| **Unifying** (`C52B`, `C532`) | Same protocol, not yet tested |
| **Lightspeed** (gaming: `C539`, `C53A`, `C53D`, `C53F`, `C541`, `C545`, `C547`) | Not yet tested |

A device works if it reports battery through HID++ feature 0x1004 (percentage), 0x1000, or 0x1001. Feature 0x1001
reports voltage; logijuice converts it to a percentage with a typical lithium-ion curve, which is common on G-series
mice and untested. Devices without any of these (some gaming headsets, older AA models) are listed as "battery not
reported". Bluetooth-connected devices aren't handled, because macOS already shows those.

Have a device or receiver marked untested? `logijuice debug capture --seconds 30 --probe` records what it reports.
Please open an issue with the file.

## Install (from source)

Requirements: macOS 14+, Xcode (full install).

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift test
scripts/build-app.sh
cp -R dist/LogiJuice.app /Applications/
open /Applications/LogiJuice.app
```

The app is ad-hoc signed. On first launch, macOS may ask you to approve it in **System Settings → Privacy & Security → Open Anyway**.

## Command line

```sh
ln -sf /Applications/LogiJuice.app/Contents/Resources/bin/logijuice /usr/local/bin/logijuice
logijuice status          # MX Master 3S: 42%, ~9 days
logijuice status --json
logijuice devices
logijuice debug capture --seconds 30 --probe   # raw HID++ frames, for bug reports
```

## Privacy

No telemetry and no network access. Data stays in `~/Library/Application Support/logijuice/`, the app's group container, and (if sync is on) `iCloud Drive/logijuice/`.

## License

MIT
