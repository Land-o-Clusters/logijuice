# Bluetooth-direct devices: scoping plan

**Status:** proposal for the owner (asked 2026-10-18). Nothing in the spec or LAWS changes until the owner rules on
the decision below. Today LAWS puts native-Bluetooth devices out of scope.

## Why

Many owners pair MX devices to a Mac over Bluetooth with no receiver. logijuice can't see those devices. The
owner's MX Master 3S and MX Keys S both have Bluetooth Easy-Switch channels.

## What's known

Reading a Bluetooth-paired Logitech device's battery on macOS:

| Path | Data | Permission | Evidence |
|---|---|---|---|
| A. HID++ over BLE through IOKit HID | percent, level, charging, name, kind, serial (same parsers as the receiver path) | **Input Monitoring** | Lazy Mouse reads 0x1004 from an MX Master 3S this way on macOS 26 |
| B. IORegistry `BatteryPercent` | percent only | none | works for Apple devices; unknown for Logitech |
| C. CoreBluetooth Battery Service (0x180F) | percent only | Bluetooth | rejected: macOS hides a peripheral it has claimed as a HID device |

Details for path A, from Lazy Mouse's notes, all to be confirmed on hardware:
- Matching by usage page finds nothing over BLE. Match vendor `0x046D`, then keep devices that have an element on
  usage page `0xFF43`, usage `0x0202` (the HID++ collection).
- `IOHIDManagerOpen` on a vendor-ID match fails with `kIOReturnNotPermitted` until the app has Input Monitoring.
  The grant is per app.
- Only long reports (`0x11`) exist. Send with `IOHIDDeviceSetValue` on the output element (`SetReport` reports
  success but doesn't send). Receive with the input report callback. The device index is `0xFF`.
- macOS replaces the `IOHIDDevice` on every reconnect, so the transport has to switch to the new one.

Changes in logijuice's code:
- Requests are already long frames. The receiver transport sends with `SetReport` and treats only short frames as
  notifications, so BLE needs its own send path and long-frame notifications.
- Identity stays the same: 0x0003 gives the serial, so a device that moves between Bolt and Bluetooth keeps one
  `DeviceID` and one history.
- The getter list in LAWS doesn't change. Path A sends the same read-only functions with software ID `0x0A`, and it
  opens the device non-exclusively, next to Options+.

## The decision for the owner

Path A works but needs Input Monitoring. In System Settings that permission reads as access to keystrokes from any
app. A battery app asking for it costs trust, more so while the app is unsigned. Path B doesn't need a permission, but
it may not work for Logitech devices at all.

**Recommendation:** run the phase 0 probe first. If path B works, release it first. Either way, path A is opt-in: a
"Bluetooth devices" switch in Settings, off by default, that asks for Input Monitoring only when it's turned on. Bolt
users never see the prompt.

## Phases

**0. Probe (needs the owner, about 10 minutes).** The owner pairs the MX Master 3S on a Bluetooth channel. With no
new code, read `ioreg -r -l -k BatteryPercent` and `system_profiler SPBluetoothDataType` for a battery value, and
note whether the Control Center Bluetooth menu shows one. Then a throwaway probe lists IOHID devices for vendor
`0x046D` (no open) and records product ID, usage pages and the `0xFF43` element. Result: whether B exists, and A's
exact matching values.

**1. Spec and LAWS (owner's yes).** Change the scope line to include Bluetooth-direct devices. Add the opt-in
Input Monitoring rule and the path or paths that won.

**2. Path B, if the probe found it.** A poller reads `BatteryPercent` from the IORegistry (every 5 minutes and on
IOKit add/remove notifications) and feeds readings into the existing pipeline. With no serial, identity comes from
the Bluetooth device's registry properties. Untested-hardware labels follow LAWS.

**3. Path A.** A `BluetoothHIDTransport` beside `IOHIDReceiver` (vendor match, `0xFF43` filter, `SetValue` send,
input report callback, reconnect adoption) and a `DirectSession` that drives `ReceiverSession`'s identify and read
logic with device index `0xFF`. Unit tests replay captured BLE frames through `FakeChannel`, as the receiver tests
do. `debug capture` gains the BLE transport and redacts as it does today.

**4. Verify on hardware.** Battery, charging and reconnect after sleep, with Options+ running and with it quit. Also
the same device on Bolt and then on Bluetooth shows one history. The README and the receiver catalog keep
"untested" labels on models that haven't been tried.

## Risks

- Path A rests on one third-party project tested on one mouse. Keyboards over BLE may differ (Input Monitoring
  covers them, but their HID++ collection is unconfirmed).
- macOS could tighten HID access again. Check each OS release.
- Polling a BLE device from logijuice and Options+ at once costs some radio time. Polling stays event-driven, as on Bolt.

## Sources

- Lazy Mouse: <https://github.com/RRY/lazy-mouse> (HID++ over BLE on macOS: matching, reports, permission)
- OpenLogi: <https://github.com/Phecda/OpenLogi> (lists Bluetooth-direct battery support; method not documented)
- Nordic DevZone on the Battery Service and the macOS Bluetooth menu:
  <https://devzone.nordicsemi.com/f/nordic-q-a/92015/>
- `ioreg -rk BatteryPercent` for Apple devices: <https://mybyways.com/blog/bluetooth-keyboard-and-trackpad-battery-level/>
