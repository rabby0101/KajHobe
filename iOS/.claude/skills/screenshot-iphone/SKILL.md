---
name: screenshot-iphone
description: Capture a screenshot from the user's connected physical iPhone so Claude can see the running KajHobe app. Use whenever you need to visually verify on-device UI — a layout bug, a change you just deployed, "what does it look like now", or to confirm a fix. Works on modern iOS (incl. iOS 26.x) via Xcode 27 devicectl; do NOT use idevicescreenshot (it can't see the CoreDevice DDI).
---

# Screenshot the connected iPhone

Grab a PNG of whatever is currently on the iPhone's screen, save it to `/tmp`, then
Read it to see the running app. This is how you visually verify on-device UI without
asking the user to send a screenshot.

## Why this method

- **`xcrun devicectl device capture screenshot`** (Xcode 27 / Xcode-beta) works on
  iOS 26.x — it uses CoreDevice and the personalized Developer Disk Image.
- **`idevicescreenshot` (libimobiledevice) does NOT work here** — it fails with
  *"you have to mount the Developer disk image"* because it can't see CoreDevice's
  personalized DDI on modern iOS. Don't reach for it.
- The **stable `/Applications/Xcode.app`** tops out at iOS 16.4 device support and
  can't even build/talk to this phone. Always drive device commands through
  **Xcode-beta** via `DEVELOPER_DIR`. See [[testing-use-connected-devices]].

## Known device (verify it's still connected first)

- **iPhone 12 (iPhone13,2), iOS 26.x**
- **UDID:** `00008101-000B44441A6A001E`  (works as `--device`)
- **Bundle id:** `tu-berlin.KajHobe`

The UDID can change if a different phone is plugged in — step 0 re-confirms it.

## Steps

Toolchain prefix used by every command (stable Xcode can't see iOS 26 devices):

```bash
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
```

### 0. Confirm a device is connected and capture its UDID

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcrun devicectl list devices 2>/dev/null | grep -iE "connected" | grep -i "physical"
```

Use the **UDID** (the `00008101-…` value, from `devicectl device info details` Hardware →
UDID) — or just the device **name** ("iPhone") — for `--device`. If nothing is connected,
tell the user to plug in / unlock the phone and stop.

### 1. Capture the screenshot

`--destination` is required and must end in `.png`.

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcrun devicectl device capture screenshot \
    --device 00008101-000B44441A6A001E \
    --destination /tmp/kajhobe-shot.png 2>&1 | tail -2
```

Expect `Screenshot saved to: /tmp/kajhobe-shot.png` and a `Dimensions:` line.
Use a fresh/descriptive filename (e.g. `/tmp/kajhobe-home-before.png`,
`/tmp/kajhobe-home-after.png`) when comparing before/after a fix.

### 2. Look at it

Read the PNG so you can actually see the screen:

```
Read /tmp/kajhobe-shot.png
```

## Driving the app to the screen you need

`devicectl` can launch/terminate the app but **cannot tap or scroll**. To reach a
specific screen:

- **Relaunch fresh** (lands on the default tab / home):
  ```bash
  DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
    xcrun devicectl device process launch --terminate-existing \
      --device 00008101-000B44441A6A001E tu-berlin.KajHobe 2>&1 | grep -iE "launched|error"
  ```
  Then wait ~5s before capturing so the UI settles.
- For taps/navigation you can't trigger from the CLI, ask the user to navigate to the
  screen, then capture.

## Notes & gotchas

- **The PNG is full device resolution** (e.g. 1170×2532). That's fine for Read.
- **`open -a Simulator` / `xcrun simctl boot` are NOT this skill** — prefer the real
  device per [[testing-use-connected-devices]]; only use a simulator if the user asks.
- **Screen recording** is also available if you ever need motion:
  `xcrun devicectl device capture screen-record …`.
- If capture errors with a pairing/trust issue, have the user unlock the phone and tap
  "Trust", then retry.
