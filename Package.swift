// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AudioPicker",
    platforms: [
        .macOS(.v13) // SMAppService (launch at login) requires macOS 13+
    ],
    targets: [
        .executableTarget(
            name: "AudioPicker",
            path: "Sources/AudioPicker"
        )
    ]
)
