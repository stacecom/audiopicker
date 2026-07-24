# Development & debugging notes

Context for anyone (human or agent) picking this project up to extend or debug it.

## What this is

A menu-bar-only macOS app that switches the active audio **output** and **input**
device — a replacement for the unmaintained
[AudioSwitcher](https://apps.apple.com/us/app/audioswitcher/id561712678?mt=12).

## Design decisions (and why)

- **Menu bar, icon only** (no Dock icon): `LSUIElement=true` in `Info.plist` plus
  `NSApp.setActivationPolicy(.accessory)` in `main.swift`. Chosen to match
  AudioSwitcher's minimal footprint.
- **Selecting an output sets *both* the app default output and the system
  sound-effects output** (`kAudioHardwarePropertyDefaultOutputDevice` +
  `kAudioHardwarePropertyDefaultSystemOutputDevice`). This is the behavior the
  user asked for; if you ever want them decoupled, split
  `AudioDeviceManager.setDefaultOutput(_:)`.
- **Launch at Login defaults ON** on first run, with a menu toggle. Implemented
  with `SMAppService.mainApp` (macOS 13+). First-run detection uses the
  `didSetInitialLoginItem` key in `UserDefaults`.
- **SwiftPM, not an Xcode project**: the dev machine had only Command Line Tools
  (no `xcodebuild`). `scripts/build-app.sh` hand-assembles the `.app` bundle so
  no full Xcode is required.
- **Ad-hoc code signing** (`codesign --sign -`): no Apple Developer account
  assumed. Works for local use and `SMAppService`; not notarized/distributable.

## Layout

| Path | Role |
|------|------|
| `Sources/AudioPicker/AudioDeviceManager.swift` | CoreAudio HAL wrapper: enumerate devices, read/write defaults, change listeners |
| `Sources/AudioPicker/AppDelegate.swift` | `NSStatusItem` + menu, selection handlers, login-item toggle |
| `Sources/AudioPicker/main.swift` | Entry point; also `--list` and `--unregister-login` CLI modes |
| `Resources/Info.plist` | Bundle metadata; `LSUIElement`, bundle id `com.craigstacey.audiopicker` |
| `scripts/build-app.sh` | `swift build -c release` → assemble `.app` → ad-hoc sign |
| `Makefile` | `build` / `app` / `run` / `install` / `uninstall` / `clean` |

## Diagnostics built in

```sh
# Print all devices with current defaults marked (*), no menu bar item, no side effects:
.build/debug/AudioPicker --list        # or: swift run AudioPicker --list

# Remove the launch-at-login registration (used by clean uninstalls):
.build/release/AudioPicker --unregister-login
```

Both flags run in `main.swift` and `exit()` before the AppKit app starts.

## Build / run cycle

```sh
swift build            # quick compile check (debug)
make app               # build ad-hoc-signed dist/AudioPicker.app
make run               # build + launch from ./dist
make install           # copy to /Applications (best for stable login item)
make uninstall         # quit + remove from /Applications
```

Note: `make install`/`open` triggers first-run login-item registration. To fully
undo on a machine: run `--unregister-login`, quit the app, `make uninstall`, then
optionally `defaults delete com.craigstacey.audiopicker`.

## Debugging guide (symptom → where to look)

- **A device doesn't switch when clicked** — the CoreAudio setters return `Bool`
  but the UI ignores it. Add logging in `AudioDeviceManager.setDefaultOutput/
  setDefaultInput` (check the `OSStatus` from `AudioObjectSetPropertyData`).
  Confirm the device is real with `--list`. Aggregate/virtual devices (Teams,
  Zoom, ZoomAudioDevice) behave like normal devices here.
- **A device is missing from the list** — capability detection is
  `channelCount(_:scope:)` on `kAudioDevicePropertyStreamConfiguration`. A device
  shows under Output/Input only if it reports >0 channels on that scope. Check
  there first.
- **Menu shows stale devices/checkmarks** — the menu is rebuilt in
  `menuNeedsUpdate(_:)` every open, and `AudioDeviceManager.onChange` fires the
  HAL property listeners (`kAudioHardwarePropertyDevices`,
  `Default{Output,Input}Device`) to call `menu.update()`. If live refresh breaks,
  verify the listeners are still installed (`installListeners()`).
- **Dock icon appears / app steals focus** — check `LSUIElement` survived into the
  bundled `Info.plist` and `setActivationPolicy(.accessory)` still runs.
- **Launch at Login won't enable / throws** — `SMAppService` is finicky about
  signing and location. Ensure the app is (a) ad-hoc signed (`codesign -dv
  /Applications/AudioPicker.app`) and (b) ideally in `/Applications`. Inspect the
  system's registration with `sfltool dumpbtm` (look for the bundle id) and check
  **System Settings → General → Login Items**. The toggle reflects
  `SMAppService.mainApp.status == .enabled`.
- **`swift build` can't find frameworks** — CoreAudio/AppKit/ServiceManagement are
  system frameworks linked implicitly via `import`; there are no SwiftPM deps. A
  failure here usually means a broken/missing Command Line Tools or SDK
  (`xcode-select -p`, `swift --version`).

## Verified so far

- Compiles clean; `make app` produces a signed bundle (`codesign -dv` shows
  `Signature=adhoc`, `Identifier=com.craigstacey.audiopicker`).
- `--list` correctly enumerates real hardware and marks the active output/input.
- Not yet exercised interactively: clicking menu items to switch, and the
  login-item toggle round-trip (do this on the target machine).

## Known constraints / risks

- Ad-hoc signed → personal use only, not notarized for distribution.
- Targets macOS 13+ (`SMAppService`); developed against macOS 26 / Apple Silicon.
- `Info.plist` and bundle id (`com.craigstacey.audiopicker`) are duplicated
  between `Resources/Info.plist` and `scripts/build-app.sh` — keep them in sync.
