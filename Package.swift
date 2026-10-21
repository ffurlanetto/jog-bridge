// swift-tools-version:5.9
import PackageDescription
import Foundation

// libusb est requis uniquement à la compilation (`brew install libusb pkg-config`) :
// on le lie statiquement ci-dessous pour que le binaire produit n'ait aucune
// dépendance runtime à Homebrew sur la machine qui l'exécute.
private func shell(_ command: String) -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    // Le PATH par défaut n'inclut pas Homebrew lorsque ce manifeste est évalué par Xcode.
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

// NB : volontairement sans `pkgConfig:` ici — ce paramètre fait passer
// `-lusb-1.0` au link final et fait réapparaître la dépendance dynamique
// qu'on cherche justement à éviter. Le chemin d'en-tête est fourni à la
// place via `swiftSettings` sur la cible exécutable ci-dessous.
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
    ]
)
