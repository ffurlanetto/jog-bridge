import AppKit
import Foundation
import ServiceManagement

/// What the panel can do about a problem. Nothing here needs administrator rights: it only
/// drives the user's own LaunchAgent.
struct BridgeActions: Sendable {
    var runner: any ProcessRunning = SystemProcessRunner()
    var uid: uid_t = getuid()

    private var domain: String { "gui/\(uid)" }
    private var service: String { "\(domain)/\(BridgeConstants.label)" }

    /// Loads the agent and starts it. Loading an agent that is already loaded fails harmlessly,
    /// which is why the result of `bootstrap` is ignored.
    func start() async {
        _ = await runner.run("/bin/launchctl", ["bootstrap", domain, BridgeConstants.plistURL.path])
        _ = await runner.run("/bin/launchctl", ["kickstart", service])
    }

    /// Kills the running process (if any) and starts it again.
    func restart() async {
        _ = await runner.run("/bin/launchctl", ["kickstart", "-k", service])
    }

    @MainActor
    func openLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }

    @MainActor
    func showLog() {
        NSWorkspace.shared.open(URL(fileURLWithPath: BridgeConstants.logPath))
    }

    @MainActor
    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
