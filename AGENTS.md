# AGENTS.md — logijuice

Battery visibility and low-battery alerts for Logitech devices on a Bolt/Unifying receiver.
`docs/status/LAWS.md` holds the binding rules (what is always true); `docs/status/STATE.md`
holds the current work. Read both before changing anything.

## Review bar

- `swift test` and `scripts/build-app.sh` were re-run and their exit codes read (run bare, never
  through a pipe). Hardware claims need a hardware run.
- A UI change is verified in its real host (widget in the gallery, icon in the menu bar, alerts
  in Notification Center); "it builds" is not "it works".

## Hard rules (full text in LAWS.md)

- Read-only toward hardware: send only the HID++ getters LAWS.md lists. Never write a register
  or device setting.
- No personal identifiers in the repo (serials, unit IDs, hardware UUIDs, Mac names, home paths).
- `main` is public and protected; never rewrite history. Commit with the pathspec on the
  commit; never `git add -A`.
- Owner-tier, always ask first: repo create/publish/delete/visibility, spending money, any
  hardware write, publishing a release, and scope changes to the spec.
