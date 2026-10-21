import Foundation

// MARK: - Constants

/// Identifiers shared with the daemon and the installer (ADR 0011, ADR 0012).
enum BridgeConstants {
    static let label = "local.jog-bridge"
    static let portName = "Hercules MP3 e2"
    static let logPath = "/tmp/jog-bridge.log"
    static let vendorID = 0x06F8
    static let productID = 0xB105

    /// The LaunchAgent plist the installer puts in the user's LaunchAgents folder.
    static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }
}

/// Texts the daemon writes to its log and that the panel relies on to tell *why* the console is
/// not connected. A test checks that each of them still exists in the daemon's sources, so
/// rewording a log message breaks CI instead of silently blinding the panel.
enum DaemonLogMarkers {
    static let started = "Virtual MIDI ports"
    static let connected = "Console connected"
    static let disconnected = "Console disconnected"
    static let waiting = "Waiting for the console"
    static let claimFailed = "Cannot claim interface"
    static let noEndpoint = "No input endpoint found"

    static let all = [started, connected, disconnected, waiting, claimFailed, noEndpoint]
}

// MARK: - Inputs of the evaluation

/// What launchd says about the agent.
struct ServiceState: Equatable {
    var loaded: Bool
    var running: Bool
    var pid: Int?
    var lastExitCode: Int?

    static let notLoaded = ServiceState(loaded: false, running: false, pid: nil, lastExitCode: nil)

    /// Parses the output of `launchctl print gui/<uid>/<label>`. Anything unexpected degrades to
    /// "loaded but not running" rather than failing: the format is not a documented interface.
    static func parse(launchctlOutput: String, exitCode: Int32) -> ServiceState {
        guard exitCode == 0 else { return .notLoaded }

        var state: String?
        var pid: Int?
        var lastExit: Int?
        for rawLine in launchctlOutput.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            // Only the first `state =` is the job's: nested sections repeat the key.
            if state == nil, line.hasPrefix("state = ") {
                state = String(line.dropFirst("state = ".count))
            } else if pid == nil, line.hasPrefix("pid = ") {
                pid = Int(line.dropFirst("pid = ".count))
            } else if lastExit == nil, line.hasPrefix("last exit code = ") {
                lastExit = Int(line.dropFirst("last exit code = ".count))
            }
        }
        return ServiceState(loaded: true, running: state == "running", pid: pid, lastExitCode: lastExit)
    }
}

/// Whether the user allowed the item in System Settings → Login Items & Extensions.
enum ApprovalState: Equatable {
    case approved, requiresApproval, notRegistered, notFound, unknown
}

/// What the end of the daemon's log says about the console.
enum ConsoleLogState: Equatable {
    case connected, disconnected, waiting, claimFailed, noEndpoint, unknown

    /// Reads the tail of the log. Only the latest daemon run counts (it starts with the
    /// "Virtual MIDI ports … created" line), and within it the latest connection event wins —
    /// except that a failure to claim the interface is not erased by the "Waiting for the
    /// console…" line the daemon logs right after it.
    static func analyse(logTail: String) -> ConsoleLogState {
        let lines = logTail.split(whereSeparator: \.isNewline).map(String.init)

        let run: ArraySlice<String>
        if let start = lines.lastIndex(where: { $0.contains(DaemonLogMarkers.started) }) {
            run = lines[(start + 1)...]
        } else {
            run = lines[...]
        }

        let lastEvent = run.lastIndex {
            $0.contains(DaemonLogMarkers.connected) || $0.contains(DaemonLogMarkers.disconnected)
        }
        if let lastEvent {
            if run[lastEvent].contains(DaemonLogMarkers.connected) { return .connected }
            return pending(run[(lastEvent + 1)...], afterDisconnect: true)
        }
        return pending(run, afterDisconnect: false)
    }

    private static func pending(_ lines: ArraySlice<String>, afterDisconnect: Bool) -> ConsoleLogState {
        if lines.contains(where: { $0.contains(DaemonLogMarkers.claimFailed) }) { return .claimFailed }
        if lines.contains(where: { $0.contains(DaemonLogMarkers.noEndpoint) }) { return .noEndpoint }
        if lines.contains(where: { $0.contains(DaemonLogMarkers.waiting) }) { return .waiting }
        return afterDisconnect ? .disconnected : .unknown
    }
}

/// Everything the panel knows at one instant.
struct BridgeSnapshot: Equatable {
    var installed: Bool
    var service: ServiceState
    var approval: ApprovalState
    var midiPortPresent: Bool
    var usbDevicePresent: Bool
    var logTail: String
    var appVersion: String

    var log: ConsoleLogState { .analyse(logTail: logTail) }
}

// MARK: - Result of the evaluation

enum StatusLevel: String, Equatable {
    case ok, attention, problem
}

/// Something the panel can offer to do about a problem.
enum BridgeAction: Equatable {
    case start, restart, openLoginItems

    var title: String {
        switch self {
        case .start: "Start Jog Bridge"
        case .restart: "Restart Jog Bridge"
        case .openLoginItems: "Open Login Items Settings"
        }
    }
}

struct CheckRow: Equatable, Identifiable {
    enum Result: Equatable { case ok, warning, failure, unknown }

    let title: String
    let value: String
    let result: Result

    var id: String { title }
}

struct BridgeStatus: Equatable {
    var level: StatusLevel
    var title: String
    var detail: String
    var checks: [CheckRow]
    /// Actions that may fix the problem, most useful first. Empty when all is well.
    var actions: [BridgeAction]

    static func evaluate(_ snapshot: BridgeSnapshot) -> BridgeStatus {
        let checks = checkRows(for: snapshot)
        func status(_ level: StatusLevel, _ title: String, _ detail: String,
                    _ actions: [BridgeAction] = []) -> BridgeStatus {
            BridgeStatus(level: level, title: title, detail: detail, checks: checks, actions: actions)
        }

        guard snapshot.installed else {
            return status(.problem, "Jog Bridge isn't installed correctly",
                          "The background service file is missing. Reinstall the Jog Bridge package.")
        }
        if snapshot.approval == .requiresApproval {
            return status(.problem, "Jog Bridge isn't allowed to run in the background",
                          "Turn on Jog Bridge in System Settings → General → Login Items & Extensions.",
                          [.openLoginItems])
        }
        guard snapshot.service.loaded else {
            return status(.problem, "Jog Bridge isn't running",
                          "The background service isn't loaded.", [.start])
        }
        guard snapshot.service.running else {
            let exit = snapshot.service.lastExitCode.flatMap { $0 != 0 ? $0 : nil }
            let detail = exit.map { "It exited unexpectedly (exit code \($0))." } ?? "It isn't running."
            return status(.problem, "Jog Bridge stopped", detail, [.restart])
        }

        guard snapshot.midiPortPresent else {
            return status(.attention, "MIDI ports aren't available",
                          "The service is running but the “\(BridgeConstants.portName)” MIDI ports are missing.",
                          [.restart])
        }
        switch snapshot.log {
        case .claimFailed:
            return status(.attention, "Another app is using the console",
                          "Close other DJ software, or uninstall any old Hercules driver, then restart Jog Bridge.",
                          [.restart])
        case .noEndpoint:
            return status(.attention, "The console isn't recognised",
                          "Its USB layout is unexpected. Copy the diagnostics and report it.")
        case .connected:
            return status(.ok, "Jog Bridge is running",
                          "Everything is OK — your Hercules DJ Control MP3 e2 is connected.")
        case .disconnected, .waiting, .unknown:
            if snapshot.usbDevicePresent {
                return status(.attention, "Console detected, connecting…",
                              "If this does not resolve within a few seconds, restart Jog Bridge.",
                              [.restart])
            }
            return status(.attention, "Waiting for the console",
                          "Plug in your Hercules DJ Control MP3 e2.")
        }
    }

    private static func checkRows(for s: BridgeSnapshot) -> [CheckRow] {
        let service: CheckRow
        if !s.installed {
            service = CheckRow(title: "Background service", value: "Not installed", result: .failure)
        } else if !s.service.loaded {
            service = CheckRow(title: "Background service", value: "Not loaded", result: .failure)
        } else if !s.service.running {
            let exit = s.service.lastExitCode.flatMap { $0 != 0 ? " (exit \($0))" : nil } ?? ""
            service = CheckRow(title: "Background service", value: "Stopped" + exit, result: .failure)
        } else {
            let pid = s.service.pid.map { " (pid \($0))" } ?? ""
            service = CheckRow(title: "Background service", value: "Running" + pid, result: .ok)
        }

        let permission: CheckRow
        switch s.approval {
        case .approved:
            permission = CheckRow(title: "Background permission", value: "Allowed", result: .ok)
        case .requiresApproval:
            permission = CheckRow(title: "Background permission", value: "Needs your approval", result: .failure)
        case .notRegistered, .notFound, .unknown:
            permission = CheckRow(title: "Background permission", value: "Unknown", result: .unknown)
        }

        let midi: CheckRow
        if s.midiPortPresent {
            midi = CheckRow(title: "MIDI ports", value: "“\(BridgeConstants.portName)” available", result: .ok)
        } else {
            midi = CheckRow(title: "MIDI ports", value: "Not available",
                            result: s.service.running ? .failure : .unknown)
        }

        let console: CheckRow
        if s.service.running, s.log == .connected {
            console = CheckRow(title: "Console", value: "Connected", result: .ok)
        } else if s.service.running, s.log == .claimFailed {
            console = CheckRow(title: "Console", value: "In use by another app", result: .failure)
        } else if s.service.running, s.log == .noEndpoint {
            console = CheckRow(title: "Console", value: "Not recognised", result: .failure)
        } else if !s.usbDevicePresent {
            console = CheckRow(title: "Console", value: "Not detected — plug it in", result: .warning)
        } else if s.service.running {
            console = CheckRow(title: "Console", value: "Detected, waiting to connect", result: .warning)
        } else {
            console = CheckRow(title: "Console", value: "Plugged in (bridge stopped)", result: .unknown)
        }

        return [service, permission, midi, console]
    }

    /// A plain-text report the user can paste into an issue.
    static func diagnostics(snapshot: BridgeSnapshot, status: BridgeStatus,
                            osVersion: String, maxLogLines: Int = 40) -> String {
        var lines = [
            "Jog Bridge diagnostics",
            "App version: \(snapshot.appVersion)",
            "macOS: \(osVersion)",
            "Status: \(status.level.rawValue) — \(status.title)",
            status.detail,
            "",
            "Checks:",
        ]
        lines += status.checks.map { "- \($0.title): \($0.value)" }
        lines += [
            "",
            "launchd: loaded=\(snapshot.service.loaded) running=\(snapshot.service.running) "
                + "pid=\(snapshot.service.pid.map(String.init) ?? "-") "
                + "lastExit=\(snapshot.service.lastExitCode.map(String.init) ?? "-")",
            "Agent plist installed: \(snapshot.installed ? "yes" : "no")",
            "USB device present: \(snapshot.usbDevicePresent ? "yes" : "no")",
            "MIDI source present: \(snapshot.midiPortPresent ? "yes" : "no")",
            "",
            "Log (last \(maxLogLines) lines of \(BridgeConstants.logPath)):",
        ]
        let tail = snapshot.logTail.split(whereSeparator: \.isNewline).suffix(maxLogLines).map(String.init)
        lines += tail.isEmpty ? ["(empty or unreadable)"] : tail
        return lines.joined(separator: "\n")
    }
}
