import CoreMIDI
import Foundation
import IOKit
import ServiceManagement

// MARK: - Running commands

struct ProcessResult: Equatable, Sendable {
    var status: Int32
    var output: String
}

/// Runs an external command. A protocol so the actions and the probe can be tested without
/// touching launchd.
protocol ProcessRunning: Sendable {
    func run(_ executable: String, _ arguments: [String]) async -> ProcessResult
}

struct SystemProcessRunner: ProcessRunning {
    func run(_ executable: String, _ arguments: [String]) async -> ProcessResult {
        await withCheckedContinuation { continuation in
            // Blocking work (reading the pipe, waiting for exit) stays off the cooperative pool.
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: ProcessResult(status: -1, output: "\(error)"))
                    return
                }
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                continuation.resume(returning: ProcessResult(
                    status: process.terminationStatus,
                    output: String(decoding: data, as: UTF8.self)))
            }
        }
    }
}

// MARK: - Individual probes

enum CoreMIDINames {
    /// Names of every MIDI source CoreMIDI currently knows about.
    static func sources() -> [String] {
        (0..<MIDIGetNumberOfSources()).compactMap { name(of: MIDIGetSource($0)) }
    }

    private static func name(of endpoint: MIDIEndpointRef) -> String? {
        var value: Unmanaged<CFString>?
        guard MIDIObjectGetStringProperty(endpoint, kMIDIPropertyName, &value) == noErr else { return nil }
        return value?.takeRetainedValue() as String?
    }
}

enum USBProbe {
    /// Whether a USB device with this vendor and product ID is plugged in (whoever holds it).
    static func devicePresent(vendorID: Int, productID: Int) -> Bool {
        guard let matching = IOServiceMatching("IOUSBHostDevice") as NSMutableDictionary? else { return false }
        matching["idVendor"] = vendorID
        matching["idProduct"] = productID

        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return false
        }
        defer { IOObjectRelease(iterator) }

        let service = IOIteratorNext(iterator)
        defer { if service != 0 { IOObjectRelease(service) } }
        return service != 0
    }
}

enum LogTail {
    /// The last lines of a log file, without reading all of it.
    static func read(path: String, maxBytes: Int = 64 * 1024, maxLines: Int = 200) -> String {
        guard let handle = FileHandle(forReadingAtPath: path) else { return "" }
        defer { try? handle.close() }

        let size = (try? handle.seekToEnd()) ?? 0
        let offset = size > UInt64(maxBytes) ? size - UInt64(maxBytes) : 0
        try? handle.seek(toOffset: offset)
        let data = (try? handle.readToEnd()) ?? Data()

        let lines = String(decoding: data, as: UTF8.self).split(separator: "\n", omittingEmptySubsequences: false)
        return lines.suffix(maxLines).joined(separator: "\n")
    }
}

extension ApprovalState {
    /// The user's decision for the installed agent, as System Settings records it.
    static func current() -> ApprovalState {
        switch SMAppService.statusForLegacyPlist(at: BridgeConstants.plistURL) {
        case .enabled: .approved
        case .requiresApproval: .requiresApproval
        case .notRegistered: .notRegistered
        case .notFound: .notFound
        @unknown default: .unknown
        }
    }
}

// MARK: - Putting it together

protocol BridgeProbing: Sendable {
    func snapshot() async -> BridgeSnapshot
}

struct LiveBridgeProbe: BridgeProbing {
    var runner: any ProcessRunning = SystemProcessRunner()
    var uid: uid_t = getuid()

    func snapshot() async -> BridgeSnapshot {
        let launchd = await runner.run("/bin/launchctl", ["print", "gui/\(uid)/\(BridgeConstants.label)"])
        return BridgeSnapshot(
            installed: FileManager.default.fileExists(atPath: BridgeConstants.plistURL.path),
            service: ServiceState.parse(launchctlOutput: launchd.output, exitCode: launchd.status),
            approval: ApprovalState.current(),
            midiPortPresent: CoreMIDINames.sources().contains(BridgeConstants.portName),
            usbDevicePresent: USBProbe.devicePresent(vendorID: BridgeConstants.vendorID,
                                                     productID: BridgeConstants.productID),
            logTail: LogTail.read(path: BridgeConstants.logPath),
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")
    }
}
