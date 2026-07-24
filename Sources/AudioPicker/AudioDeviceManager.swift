import CoreAudio
import Foundation

/// A single audio device as seen by CoreAudio.
struct AudioDevice: Identifiable, Equatable {
    let id: AudioObjectID
    let uid: String
    let name: String
    let hasOutput: Bool
    let hasInput: Bool
}

/// Thin wrapper over the CoreAudio HAL for enumerating devices and
/// reading/writing the system default input & output devices.
final class AudioDeviceManager {

    /// Called on the main queue whenever the device list or a default device
    /// changes, so the UI can refresh.
    var onChange: (() -> Void)?

    private let systemObject = AudioObjectID(kAudioObjectSystemObject)

    // Listener blocks are retained so we can remove them on deinit.
    private var listenerBlock: AudioObjectPropertyListenerBlock?
    private var listenedAddresses: [AudioObjectPropertyAddress] = []

    init() {
        installListeners()
    }

    deinit {
        removeListeners()
    }

    // MARK: - Enumeration

    /// All devices, split by the user via `hasOutput` / `hasInput`.
    func allDevices() -> [AudioDevice] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(systemObject, &address, 0, nil, &dataSize) == noErr else {
            return []
        }

        let count = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        guard count > 0 else { return [] }

        var ids = [AudioObjectID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(systemObject, &address, 0, nil, &dataSize, &ids) == noErr else {
            return []
        }

        return ids.compactMap { device(for: $0) }
    }

    func outputDevices() -> [AudioDevice] {
        allDevices().filter { $0.hasOutput }
    }

    func inputDevices() -> [AudioDevice] {
        allDevices().filter { $0.hasInput }
    }

    private func device(for id: AudioObjectID) -> AudioDevice? {
        guard let name = stringProperty(id, kAudioObjectPropertyName) else { return nil }
        let uid = stringProperty(id, kAudioDevicePropertyDeviceUID) ?? ""
        return AudioDevice(
            id: id,
            uid: uid,
            name: name,
            hasOutput: channelCount(id, scope: kAudioObjectPropertyScopeOutput) > 0,
            hasInput: channelCount(id, scope: kAudioObjectPropertyScopeInput) > 0
        )
    }

    // MARK: - Current defaults

    var defaultOutputDeviceID: AudioObjectID? {
        objectIDProperty(systemObject, kAudioHardwarePropertyDefaultOutputDevice)
    }

    var defaultInputDeviceID: AudioObjectID? {
        objectIDProperty(systemObject, kAudioHardwarePropertyDefaultInputDevice)
    }

    // MARK: - Setting defaults

    /// Sets both the app default output *and* the system sound-effects output
    /// to `device` (the "set both together" behavior).
    @discardableResult
    func setDefaultOutput(_ device: AudioDevice) -> Bool {
        let a = setObjectIDProperty(systemObject, kAudioHardwarePropertyDefaultOutputDevice, device.id)
        let b = setObjectIDProperty(systemObject, kAudioHardwarePropertyDefaultSystemOutputDevice, device.id)
        return a && b
    }

    @discardableResult
    func setDefaultInput(_ device: AudioDevice) -> Bool {
        setObjectIDProperty(systemObject, kAudioHardwarePropertyDefaultInputDevice, device.id)
    }

    // MARK: - Property helpers

    private func stringProperty(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize = UInt32(MemoryLayout<CFString?>.size)
        var value: CFString? = nil
        let status = withUnsafeMutablePointer(to: &value) { ptr -> OSStatus in
            AudioObjectGetPropertyData(id, &address, 0, nil, &dataSize, ptr)
        }
        guard status == noErr, let str = value else { return nil }
        return str as String
    }

    private func objectIDProperty(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector) -> AudioObjectID? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value = AudioObjectID(0)
        var dataSize = UInt32(MemoryLayout<AudioObjectID>.size)
        let status = AudioObjectGetPropertyData(id, &address, 0, nil, &dataSize, &value)
        guard status == noErr, value != 0 else { return nil }
        return value
    }

    private func setObjectIDProperty(_ id: AudioObjectID, _ selector: AudioObjectPropertySelector, _ newValue: AudioObjectID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value = newValue
        let dataSize = UInt32(MemoryLayout<AudioObjectID>.size)
        return AudioObjectSetPropertyData(id, &address, 0, nil, dataSize, &value) == noErr
    }

    /// Total channel count for a device on the given scope; 0 means the device
    /// has no streams in that direction.
    private func channelCount(_ id: AudioObjectID, scope: AudioObjectPropertyScope) -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &address, 0, nil, &dataSize) == noErr, dataSize > 0 else {
            return 0
        }

        let bufferList = UnsafeMutableRawPointer.allocate(
            byteCount: Int(dataSize),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { bufferList.deallocate() }

        guard AudioObjectGetPropertyData(id, &address, 0, nil, &dataSize, bufferList) == noErr else {
            return 0
        }

        let listPtr = UnsafeMutableAudioBufferListPointer(bufferList.assumingMemoryBound(to: AudioBufferList.self))
        var channels = 0
        for buffer in listPtr {
            channels += Int(buffer.mNumberChannels)
        }
        return channels
    }

    // MARK: - Change listeners

    private func installListeners() {
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.onChange?()
            }
        }
        listenerBlock = block

        let selectors: [AudioObjectPropertySelector] = [
            kAudioHardwarePropertyDevices,
            kAudioHardwarePropertyDefaultOutputDevice,
            kAudioHardwarePropertyDefaultInputDevice
        ]

        for selector in selectors {
            var address = AudioObjectPropertyAddress(
                mSelector: selector,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            if AudioObjectAddPropertyListenerBlock(systemObject, &address, DispatchQueue.main, block) == noErr {
                listenedAddresses.append(address)
            }
        }
    }

    private func removeListeners() {
        guard let block = listenerBlock else { return }
        for var address in listenedAddresses {
            AudioObjectRemovePropertyListenerBlock(systemObject, &address, DispatchQueue.main, block)
        }
        listenedAddresses.removeAll()
        listenerBlock = nil
    }
}
