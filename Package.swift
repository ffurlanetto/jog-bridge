// swift-tools-version:5.9
import PackageDescription
import Foundation

// libusb is only required at build time (`brew install libusb pkg-config`):
// it is linked statically below so the produced binary has no runtime
// dependency on Homebrew on the machine that runs it.
private func shell(_ command: String) -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    // The default PATH does not include Homebrew when this manifest is evaluated by Xcode.
    process.environment = [
        "PATH": "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:" + (ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin")
    ]
    process.arguments = ["-c", command]
    let pipe = Pipe()
    process.standardOutput = pipe
    try? process.run()
    process.waitUntilExit()
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}

let libusbLibDir = shell("pkg-config --variable=libdir libusb-1.0")
let libusbStaticLib = "\(libusbLibDir)/libusb-1.0.a"

// NB: deliberately no `pkgConfig:` here — that parameter passes `-lusb-1.0`
// to the final link and brings back the dynamic dependency we are precisely
// trying to avoid. The header path is provided instead through `swiftSettings`
// on the executable target below.
let libusbCFlags = shell("pkg-config --cflags libusb-1.0")
    .split(separator: " ")
    .flatMap { ["-Xcc", String($0)] }

let package = Package(
    name: "jog-bridge",
    platforms: [.macOS(.v12)],
    targets: [
        // libusb via Homebrew : `brew install libusb pkg-config`
        .systemLibrary(
            name: "CLibUSB",
            path: "Sources/CLibUSB"
        ),
        .executableTarget(
            name: "jog-bridge",
            dependencies: ["CLibUSB"],
            path: "Sources/jog-bridge",
            swiftSettings: [
                .unsafeFlags(libusbCFlags)
            ],
            linkerSettings: [
                .unsafeFlags([libusbStaticLib]),
                .linkedLibrary("objc"),
                .linkedFramework("CoreMIDI"),
                .linkedFramework("IOKit"),
                .linkedFramework("CoreFoundation"),
                .linkedFramework("Security"),
            ]
        ),
        // The tests import the executable with `@testable import jog_bridge`: the CLibUSB
        // C module therefore needs the same headers as the main target.
        .testTarget(
            name: "jog-bridgeTests",
            dependencies: ["jog-bridge"],
            path: "Tests/jog-bridgeTests",
            resources: [.copy("Fixtures")],
            swiftSettings: [
                .unsafeFlags(libusbCFlags)
            ]
        ),
    ]
)
