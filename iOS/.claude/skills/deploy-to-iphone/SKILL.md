---
name: deploy-to-iphone
description: Build, install, and launch the KajHobe iOS app on the user's physically-connected iPhone for live testing. Use whenever the user asks to "test on my phone / iPhone / device", "deploy to the phone", "run it on my iPhone", "install on device", or wants to verify a change on real hardware (not just the simulator). Also use after finishing an iOS feature when the user wants to try it live.
---

# Deploy & test KajHobe on the connected iPhone

Build a signed device build, install it, and launch it on the user's iPhone over USB/Wi-Fi.
Use this whenever the user wants to see a change running on their actual phone.

## Known device (verify it's still connected first)

- **Name:** iPhone 12 (iPhone13,2), iOS 18.x
- **devicectl device id:** `00008101-000B44441A6A001E`
- **Bundle id:** `tu-berlin.KajHobe`
- **Scheme / project:** `KajHobe` / `KajHobe.xcodeproj`
- **Signing:** Apple Development — fazlarabby53@gmail.com (team auto-managed; use `-allowProvisioningUpdates`)

The device id can change if the user connects a different phone. Always run step 0 to confirm,
and if a *different* iPhone shows up, use that id for the rest of the steps.

## Steps

All commands run from the iOS project root: `/Users/skfazlarabby/Documents/GitHub/KajHobe/iOS`.

### 0. Confirm a device is connected and capture its id

```bash
xcrun devicectl list devices 2>/dev/null | grep -iE "iphone" | grep -i connected
```

Expect a line containing `connected` and the device id (UDID, the `00008101-…` value).
If nothing is connected, tell the user to plug in / unlock the phone and stop — do not fall
back to the simulator unless they ask.

### 1. (Fast pre-check, optional) Compile against the simulator

A simulator build is faster and catches all compile errors before the slower signed device build.
Skip if you already built green this session.

```bash
xcodebuild -project KajHobe.xcodeproj -scheme KajHobe \
  -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 \
  | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" | head -50
```

### 2. Build a signed build for the device

```bash
xcodebuild -project KajHobe.xcodeproj -scheme KajHobe \
  -destination 'id=00008101-000B44441A6A001E' \
  -derivedDataPath build/DerivedData -allowProvisioningUpdates build 2>&1 \
  | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED|Signing Identity" | head -40
```

Wait for `** BUILD SUCCEEDED **`. The `.app` lands at:
`build/DerivedData/Build/Products/Debug-iphoneos/KajHobe.app`

### 3. Install on the device

```bash
xcrun devicectl device install app --device 00008101-000B44441A6A001E \
  build/DerivedData/Build/Products/Debug-iphoneos/KajHobe.app 2>&1 \
  | grep -iE "installed|error|bundleID" | tail -15
```

Expect `App installed:` with `bundleID: tu-berlin.KajHobe`.

### 4. Launch on the device

```bash
xcrun devicectl device process launch --device 00008101-000B44441A6A001E tu-berlin.KajHobe 2>&1 \
  | grep -iE "launched|error|pid" | tail -10
```

Expect `Launched application with tu-berlin.KajHobe bundle identifier.`

Then tell the user it's running and what to look at for the change you just made.

## Notes & gotchas

- **The shell working directory resets between calls.** Always start device commands with
  `cd /Users/skfazlarabby/Documents/GitHub/KajHobe/iOS && …` (or use absolute paths), otherwise
  `xcodebuild` reports `'KajHobe.xcodeproj' does not exist`.
- **SourceKit / live diagnostics lie here.** Errors like `No such module 'Supabase'`,
  `No such module 'UIKit'`, `Cannot find type … in scope`, or `navigationBarTitleDisplayMode is
  unavailable in macOS` are indexer noise (it mis-targets macOS). **`xcodebuild` is the source of
  truth** — trust BUILD SUCCEEDED/FAILED, not the squiggles.
- **First install after a provisioning change** may require the user to trust the developer profile
  on-device (Settings → General → VPN & Device Management) or unlock the phone. If install fails with
  a trust/lock error, ask them to do that, then retry step 3.
- **Target iOS version:** the app targets iOS 17+; the test phone is on iOS 18.x — fine.
- If the user only wants a quick "does it compile" check, step 1 alone is enough; don't deploy.
