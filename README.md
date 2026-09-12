# ScreenStride Gesture Helper

Optional Mac companion for **ScreenStride**, an iPad remote desktop client.
The helper runs on the Mac being controlled and adds continuous three-finger
workspace gestures through its existing Screen Sharing connection.
Screen viewing, audio, typing, clicks and ordinary scrolling work without it.

**Status: preview companion.** The iPad app is still in development. Download
the signed and notarized helper from the [Releases page](https://github.com/roethlar/screenstride-gesture-helper/releases).

## What it does

- Translates marked gesture events into native Mac desktop gesture events.
- Preserves movement, stationary holds, reversal and cancellation.
- Provides a menu bar enable/pause switch and Accessibility setup.
- Offers launch at login as an optional setting, initially off.
- Opens no network listener and requires no second computer or relay.

The iPad gesture setting is optional and off by default. This helper does not
replace the Mac's Screen Sharing server or handle its video/audio streaming.

## Installation

1. Download a signed, notarized ZIP from Releases when available.
2. Unzip and move **ScreenStride Gesture Helper.app** to Applications.
3. Open it and choose **Grant Accessibility Permission** from its hand menu.
4. Enable the helper under System Settings → Privacy & Security → Accessibility.
5. Connect using ScreenStride and enable **Three-finger desktop gestures** in
   the iPad app's Settings.

All four directions, hold/reversal and keyboard show/hide were manually checked
with the A16 iPad and a macOS 26 host. The package targets macOS 14 or later;
earlier Mac versions remain unverified. The helper deliberately
disables gestures on macOS 27 pending an implementation update. It uses
undocumented Mac gesture fields, so OS updates can require helper changes.

## Build from source

Install Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen), then run:

```sh
swift test -c release
xcodegen generate
xcodebuild -project ScreenStrideGestureHelper.xcodeproj -scheme GestureHelper \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
```

The development app is in `build/Build/Products/Release/ScreenStride Gesture Helper.app`.
Unsigned builds are for local development; distribution builds need Developer ID
signing, hardened runtime and Apple notarization. Choose your own signing team
when rebuilding. The published developer's signing credentials are not included.

The artwork master and generation prompt are in `distribution/branding`.
`swift tools/generate_icons.swift` reproduces the helper icon sizes from it.

## Privacy, support and license

Read the [privacy policy](Privacy.md). Report problems through
[Issues](https://github.com/roethlar/screenstride-gesture-helper/issues).
Do not include passwords, authentication captures or private desktop content.

This repository contains the Mac helper and its translator tests. It does not
contain the iPad client's protocol implementation. The helper is distributed
under **AGPL-3.0-or-later**; see [LICENSE](LICENSE). Bundled project attribution
also describes the wider ScreenStride project's upstream dependencies.

Independent software, not affiliated with or endorsed by Apple.
