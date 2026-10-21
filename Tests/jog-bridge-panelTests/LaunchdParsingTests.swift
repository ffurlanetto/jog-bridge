import Testing
@testable import jog_bridge_panel

struct LaunchdParsingTests {
    /// Shaped like a real `launchctl print` of the agent (trimmed): the job's own `state` comes
    /// first, nested sections repeat the key.
    private let runningOutput = """
    gui/501/local.jog-bridge = {
        active count = 1
        path = /Users/someone/Library/LaunchAgents/local.jog-bridge.plist
        state = running
        program = /Applications/Jog Bridge.app/Contents/MacOS/jog-bridge
        runs = 1
        pid = 90373
        last exit code = (never exited)
        event triggers = {
        }
        endpoints = {
            "local.jog-bridge" = {
                state = active
            }
        }
    }
    """

    @Test func runningAgent() {
        let state = ServiceState.parse(launchctlOutput: runningOutput, exitCode: 0)
        #expect(state.loaded)
        #expect(state.running)
        #expect(state.pid == 90373)
        #expect(state.lastExitCode == nil)   // "(never exited)" is not a number
    }

    @Test func nestedStateDoesNotOverrideTheJobsOwn() {
        let output = runningOutput.replacingOccurrences(of: "state = running", with: "state = waiting")
        #expect(!ServiceState.parse(launchctlOutput: output, exitCode: 0).running)
    }

    @Test func loadedButStoppedWithAnExitCode() {
        let output = """
        gui/501/local.jog-bridge = {
            state = not running
            last exit code = 1
        }
        """
        let state = ServiceState.parse(launchctlOutput: output, exitCode: 0)
        #expect(state.loaded)
        #expect(!state.running)
        #expect(state.pid == nil)
        #expect(state.lastExitCode == 1)
    }

    @Test func notLoadedWhenLaunchctlFails() {
        let state = ServiceState.parse(
            launchctlOutput: "Bad request.\nCould not find service \"local.jog-bridge\" in domain for user gui: 501",
            exitCode: 113)
        #expect(state == .notLoaded)
    }

    @Test(arguments: ["", "garbage", "state =", "pid = abc\nlast exit code = x"])
    func neverCrashesOnUnexpectedText(output: String) {
        let state = ServiceState.parse(launchctlOutput: output, exitCode: 0)
        #expect(state.loaded)
        #expect(!state.running)
        #expect(state.pid == nil)
    }
}
