import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private var statusItem: NSStatusItem!
    private let audio = AudioDeviceManager()

    private let didSetInitialLoginItemKey = "didSetInitialLoginItem"

    // Tags let us tell device menu items apart from the fixed items.
    private enum ItemTag: Int {
        case output = 1000
        case input = 2000
        case loginToggle = 3000
        case quit = 3001
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        enableLoginItemOnFirstRun()

        // Keep the menu fresh when devices are plugged/unplugged.
        audio.onChange = { [weak self] in
            self?.statusItem.menu?.update()
        }
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            let image = NSImage(
                systemSymbolName: "speaker.wave.2",
                accessibilityDescription: "AudioPicker"
            )
            image?.isTemplate = true
            button.image = image
        }

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    // MARK: - Menu construction (rebuilt each time it opens)

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let currentOutput = audio.defaultOutputDeviceID
        let currentInput = audio.defaultInputDeviceID

        addHeader("Output", to: menu)
        let outputs = audio.outputDevices()
        if outputs.isEmpty {
            addDisabled("No output devices", to: menu)
        } else {
            for device in outputs {
                addDeviceItem(device, checked: device.id == currentOutput,
                              tag: .output, action: #selector(selectOutput(_:)), to: menu)
            }
        }

        menu.addItem(.separator())

        addHeader("Input", to: menu)
        let inputs = audio.inputDevices()
        if inputs.isEmpty {
            addDisabled("No input devices", to: menu)
        } else {
            for device in inputs {
                addDeviceItem(device, checked: device.id == currentInput,
                              tag: .input, action: #selector(selectInput(_:)), to: menu)
            }
        }

        menu.addItem(.separator())

        let login = NSMenuItem(title: "Launch at Login",
                               action: #selector(toggleLoginItem(_:)), keyEquivalent: "")
        login.target = self
        login.tag = ItemTag.loginToggle.rawValue
        login.state = isLoginItemEnabled ? .on : .off
        menu.addItem(login)

        let quit = NSMenuItem(title: "Quit AudioPicker",
                              action: #selector(quit(_:)), keyEquivalent: "q")
        quit.target = self
        quit.tag = ItemTag.quit.rawValue
        menu.addItem(quit)
    }

    private func addHeader(_ title: String, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private func addDisabled(_ title: String, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.indentationLevel = 1
        menu.addItem(item)
    }

    private func addDeviceItem(_ device: AudioDevice, checked: Bool, tag: ItemTag,
                               action: Selector, to menu: NSMenu) {
        let item = NSMenuItem(title: device.name, action: action, keyEquivalent: "")
        item.target = self
        item.tag = tag.rawValue
        item.state = checked ? .on : .off
        item.indentationLevel = 1
        item.representedObject = device
        menu.addItem(item)
    }

    // MARK: - Actions

    @objc private func selectOutput(_ sender: NSMenuItem) {
        guard let device = sender.representedObject as? AudioDevice else { return }
        audio.setDefaultOutput(device)
    }

    @objc private func selectInput(_ sender: NSMenuItem) {
        guard let device = sender.representedObject as? AudioDevice else { return }
        audio.setDefaultInput(device)
    }

    @objc private func quit(_ sender: NSMenuItem) {
        NSApp.terminate(nil)
    }

    // MARK: - Launch at login

    private var isLoginItemEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    private func enableLoginItemOnFirstRun() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: didSetInitialLoginItemKey) else { return }
        defaults.set(true, forKey: didSetInitialLoginItemKey)
        setLoginItem(enabled: true)
    }

    @objc private func toggleLoginItem(_ sender: NSMenuItem) {
        setLoginItem(enabled: !isLoginItemEnabled)
    }

    private func setLoginItem(enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't update Launch at Login"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
}
