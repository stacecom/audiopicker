import AppKit

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
