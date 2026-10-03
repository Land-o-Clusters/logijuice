# HID++ bring-up notes (Task 0)

Probed 2026-10-03 on the owner's Mac (macOS 27) with Logi Options+ running (agent `com.logi.cp-dev-mgr`).
Raw logs were in `/tmp/logijuice-probe-*.txt` (not committed); the evidence lines are quoted below.

| Question | Answer | Evidence |
|---|---|---|
| Receiver PID / product string | `0xC548` "USB Receiver" (Logi Bolt) | `PID 0xC548 page 0xFF00 usage 0x0001 location 0x01141000 maxIn 20 maxOut 20 USB Receiver` |
| HID++ interfaces | **One** vendor collection (page `0xFF00`, usage `0x0001`) carries **both** short (0x10) and long (0x11) reports. There is no separate `0x0002` collection. The other collections are keyboard (0x0001/0x0006), mouse (0x0001/0x0002) and digitizer (0x000D/0x0005). | device list above; long requests sent to the 0x0001 collection got long replies |
| Report ID as byte 0 of `IN` data? | **Yes** | `IN id=0x11 11 01 00 1A 04 05 5A …` |
| Input Monitoring prompt / open errors? | **None.** `IOHIDManagerOpen` and `IOHIDDeviceOpen` returned `0x00000000`, and there was no TCC prompt. | `IOHIDManagerOpen -> 0x00000000`, `open usage 0x0001 -> 0x00000000` |
| Notification flags register 0x00 | `00 09 00`: wireless notifications (0x000100) and software-present (0x000800) are **on**. Options+ sets them. | `IN 10 FF 81 00 00 09 00` |
| Software IDs used by Options+ | **`0xF`** (e.g. `02 08 1F …`, `02 0B 0F …`, `02 0B 7F …`). Our `0x0A` does not collide. | replies during the reconnect burst at +65 s |
| Slots that answered; protocol | Slots **1** and **2**, HID++ **4.5**. Slots 3–6 answer at once with a HID++ 1.0 error, code `0x09`. | `11 01 00 1A 04 05 5A`, `10 03 8F 00 1A 09 00` |
| Feature indices (both devices) | 0x0003 → **0x02**, 0x0005 → **0x03**, 0x1000 → **not supported** (0), 0x1004 → **0x08** | `11 01 00 0A 02 00 04`, `… 03 00 00`, `… 00 00 00`, `… 08 00 03` |
| Device 1 | **MX Keys S**, type 0 (keyboard), unit `A1B2C3D4`, model `B378`, serial **`TESTKEYS0001`** | `11 01 03 1A 4D 58 20 4B 65 79 73 20 53`, `11 01 02 0A 03 A1 B2 C3 D4 00 02 B3 78 00 00 00 00 00 01`, `11 01 02 2A 54 45 53 54 …` |
| Device 2 | **MX Master 3S**, type 3 (mouse), unit `D4C3B2A1`, model `B034`, serial **`TESTMOUSE001`** | `11 02 03 1A 4D 58 20 4D 61 73 74 65 72 20 33 53`, `11 02 02 0A 03 D4 C3 B2 A1 00 02 B0 34 … 0A 01`, `11 02 02 2A 54 45 53 54 …` |
| 0x0003 getDeviceInfo layout | Matches the plan: `[entities, unit×4, transport×2, model×6, extModel, capabilities]`; capabilities bit 0 = serial supported | as above |
| 0x1004 capabilities | `0F 03`: all four level bits, flags `0x03`, so the **percentage is supported** (bit 0x02) | `11 01 08 0A 0F 03` |
| 0x1004 status | `[soc, levelMask, chargingStatus, extPower]`. Keyboard `64 08 00 00` = 100 %; mouse `41 08 00 00` = 65 %. Note that the level mask says "full" (0x08) even at 65–70 %, so **use the percentage, not the mask**. | `11 01 08 1A 64 08 00 00`, `11 02 08 1A 41 08 00 00` |
| Percentage granularity | Readings so far: 100, 65, 70. Probably **5 % steps**. The mouse read 70 % right after a power cycle (from 65 %), which is voltage recovery, below the forecaster's 10-point split threshold. | `11 02 08 00 46 08 …` after reconnect |
| Battery event on cable plug/unplug? | **Yes.** Unsolicited `fn0 sw0` on index 0x08 with the getStatus layout: plug → `46 08 01 01` (charging, external power); unplug → `46 08 00 00`. A battery event also arrives right after reconnect. | `+76.551s 11 02 08 00 46 08 01 01`, `+100.627s 11 02 08 00 46 08 00 00`, `+65.241s 11 02 08 00 46 08 00 00` |
| Connection notification (0x41)? | **Yes.** Power-off: `10 02 41 10 42 34 B0` (flags `0x42`, bit 0x40 = link down). Power-on: `10 02 41 10 02 34 B0` (link up). wpid = `0xB034` (lo, hi). Matches the plan's parser. | `+54.895s`, `+65.203s` |
| Asleep device behavior | A request to an idle keyboard **woke it**, and the reply came ~0.5 s later (not an error). Powered-off devices were not probed. | ping to slot 1: OUT `+0.559s`, IN `+1.072s` |
| Other traffic | Heavy `sw 0` event traffic from features Options+ diverts on the mouse (index 0x0F ~2–3/s while scrolling the thumb wheel, 0x09 buttons). `ReceiverSession.interpret` ignores these (wrong index), but they all pass through `RequestBroker.events`. | 179 × `02 0F 00 01`, 16 × `02 09 20 00` in 100 s |
| Name chunk beyond the name length | HID++ 2.0 error `0x02` (invalid argument). The plan's loop never asks past the length. | `11 01 FF 03 1A 02` |

## Not tested: behavior without Options+

Options+ is a launchd agent with `KeepAlive`, so quitting it means unloading its LaunchAgent. More importantly, the
notification flags live in the **receiver's** memory, so quitting Options+ wouldn't clear them. The real unknown
is a receiver that has just been powered on, on a Mac **without** Options+. That Mac may never see `0x41` link-up or
battery events. logijuice must not write register 0x00 (read-only constraint), so the mitigation is in Decisions.

## Decisions

- **Software ID:** keep `0x0A` (Options+ uses `0xF`).
- **Interface:** `HIDPPInterface.usagePage = 0xFF00`. The Bolt receiver has a single HID++ collection (usage `0x0001`)
  for short and long reports. The plan's `IOHIDReceiverChannel.send` already falls back to the first opened
  collection when no usage-`0x0002` collection exists, so no code change is needed.
- **Use the percentage** whenever 0x1004 capabilities say it's supported. The level mask is too coarse ("full" at 65 %).
- **Safety re-read every 30 minutes instead of 6 hours** (Task 14 `HIDCoordinator`). It re-scans unidentified slots and
  re-reads batteries, which covers Macs where the receiver's notification flags are off. Each re-read is one short
  radio exchange per device, which costs a negligible amount of battery.
- **Plan correction:** the Task 0 probe used `Set.filter` and then indexed the result with `[0]`, which doesn't compile.
  Fixed to `Array(all).filter`.
