# AudioPicker

A tiny macOS menu bar app to switch the active audio **output** and **input**
device — a maintained replacement for the unmaintained
[AudioSwitcher](https://apps.apple.com/us/app/audioswitcher/id561712678?mt=12).

- Lives in the menu bar (speaker icon), no Dock icon.
- Click the icon to see all output and input devices; a checkmark marks the
  active one. Click a device to make it active.
- Selecting an **output** switches both the app default output **and** the
  system sound-effects output.
- **Launch at Login** toggle in the menu (on by default the first time you run
  it).

## Requirements

- macOS 13 or later.
- Swift toolchain (Xcode **or** Command Line Tools — `xcode-select --install`).

## Build & install

```sh
# Build the .app bundle into ./dist and copy it to /Applications
make install

# Then launch it
open /Applications/AudioPicker.app
```

Other targets:

```sh
make app     # build dist/AudioPicker.app (ad-hoc signed), don't install
make run     # build and launch from ./dist
make build   # just compile the executable (debug)
make clean   # remove .build and dist
make uninstall
```

Installing into `/Applications` is recommended so the **Launch at Login**
registration (via `SMAppService`) is stable across updates.

## Usage

1. Click the speaker icon in the menu bar.
2. Under **Output**, pick a device — audio (and system sounds) move to it.
3. Under **Input**, pick a device — the default microphone/input switches.
4. Toggle **Launch at Login** as you like.
5. **Quit AudioPicker** exits the app.

The menu rebuilds every time you open it and also refreshes automatically when
devices are plugged in or removed.

## How it works

- `Sources/AudioPicker/AudioDeviceManager.swift` — CoreAudio HAL wrapper:
  enumerates devices and reads/writes the default output, system output, and
  input devices; installs change listeners.
- `Sources/AudioPicker/AppDelegate.swift` — builds the `NSStatusItem` menu and
  handles selection plus the `SMAppService` login-item toggle.
- `Sources/AudioPicker/main.swift` — starts the app as a menu-bar-only
  `.accessory` process.
- `scripts/build-app.sh` — packages the release binary into `AudioPicker.app`
  with `Info.plist` (`LSUIElement`) and ad-hoc code signing.

## Notes

The app is **ad-hoc signed** (no Apple Developer account needed) — perfect for
personal use, but not notarized for distribution. Switching the input device
only sets the system default, so no microphone-permission prompt appears.

This app was coded by Claude Opus 5.
