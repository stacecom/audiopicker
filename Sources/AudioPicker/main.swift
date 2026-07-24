import AppKit
import ServiceManagement

// Maintenance mode: `AudioPicker --unregister-login` removes the launch-at-login
// registration and exits, without showing a menu bar item. Useful for cleanup.
if CommandLine.arguments.contains("--unregister-login") {
    do {
        if SMAppService.mainApp.status == .enabled {
            try SMAppService.mainApp.unregister()
            print("Launch-at-login unregistered.")
        } else {
            print("Launch-at-login was not enabled (status: \(SMAppService.mainApp.status.rawValue)).")
        }
    } catch {
        print("Failed to unregister: \(error.localizedDescription)")
        exit(1)
    }
    exit(0)
}

// Diagnostic mode: `AudioPicker --list` prints devices and current defaults,
// then exits — no menu bar item, no login-item registration.
if CommandLine.arguments.contains("--list") {
    let audio = AudioDeviceManager()
    let currentOutput = audio.defaultOutputDeviceID
    let currentInput = audio.defaultInputDeviceID
    print("Output devices:")
    for d in audio.outputDevices() {
        print("  \(d.id == currentOutput ? "*" : " ") \(d.name)")
    }
    print("Input devices:")
    for d in audio.inputDevices() {
        print("  \(d.id == currentInput ? "*" : " ") \(d.name)")
    }
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Menu-bar-only app: no Dock icon, no main window.
app.setActivationPolicy(.accessory)
app.run()
