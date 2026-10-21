import Foundation
import Testing
@testable import jog_bridge_panel

/// Records the commands instead of running them: these tests never touch launchd.
final class RecordingRunner: ProcessRunning, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [[String]] = []

    var commands: [[String]] { lock.lock(); defer { lock.unlock() }; return storage }

    func run(_ executable: String, _ arguments: [String]) async -> ProcessResult {
        lock.lock(); storage.append([executable] + arguments); lock.unlock()
        return ProcessResult(status: 0, output: "")
    }
}

struct ActionsTests {
    @Test func startBootstrapsThenKickstarts() async {
        let runner = RecordingRunner()
        await BridgeActions(runner: runner, uid: 501).start()
        #expect(runner.commands == [
            ["/bin/launchctl", "bootstrap", "gui/501", BridgeConstants.plistURL.path],
            ["/bin/launchctl", "kickstart", "gui/501/local.jog-bridge"],
        ])
    }

    @Test func restartKillsAndRestarts() async {
        let runner = RecordingRunner()
        await BridgeActions(runner: runner, uid: 501).restart()
        #expect(runner.commands == [["/bin/launchctl", "kickstart", "-k", "gui/501/local.jog-bridge"]])
    }

    @Test func neverAsksForAdministratorRights() async {
        let runner = RecordingRunner()
        let actions = BridgeActions(runner: runner, uid: 501)
        await actions.start()
        await actions.restart()
        #expect(runner.commands.allSatisfy { $0.first == "/bin/launchctl" })
        #expect(!runner.commands.joined().contains("sudo"))
    }
}
