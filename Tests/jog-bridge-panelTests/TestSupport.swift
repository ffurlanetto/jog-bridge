import Foundation
@testable import jog_bridge_panel

/// Repository root, derived from this file's location (Tests/jog-bridge-panelTests/).
let repositoryRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()

/// Lines as the daemon really writes them.
enum LogLine {
    static let started = "[20:50:09] Virtual MIDI ports “Hercules MP3 e2” created."
    static let connected = "[20:50:09] Console connected — input 0x81 (bulk)"
    static let disconnected = "[21:02:11] Console disconnected (LIBUSB_ERROR_NO_DEVICE)"
    static let waiting = "[21:02:11] Waiting for the console…"
    static let claimFailed = "[21:03:00] Cannot claim interface 0: LIBUSB_ERROR_ACCESS. Is an old Hercules driver still installed?"
    static let noEndpoint = "[21:03:00] No input endpoint found on interface 0 — try --list."

    static func log(_ lines: String...) -> String { lines.joined(separator: "\n") }
}

extension ServiceState {
    static let healthy = ServiceState(loaded: true, running: true, pid: 4242, lastExitCode: nil)
    static let crashed = ServiceState(loaded: true, running: false, pid: nil, lastExitCode: 1)
}

extension BridgeSnapshot {
    /// A fully healthy snapshot; each test overrides what it needs.
    static func fixture(
        installed: Bool = true,
        service: ServiceState = .healthy,
        approval: ApprovalState = .approved,
        midi: Bool = true,
        usb: Bool = true,
        log: String = LogLine.log(LogLine.started, LogLine.connected)
    ) -> BridgeSnapshot {
        BridgeSnapshot(installed: installed, service: service, approval: approval,
                       midiPortPresent: midi, usbDevicePresent: usb, logTail: log, appVersion: "1.2.3")
    }
}
