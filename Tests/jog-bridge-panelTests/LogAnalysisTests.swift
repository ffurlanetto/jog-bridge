import Testing
@testable import jog_bridge_panel

struct LogAnalysisTests {
    private func analyse(_ lines: String...) -> ConsoleLogState {
        ConsoleLogState.analyse(logTail: lines.joined(separator: "\n"))
    }

    @Test func connectedAfterStart() {
        #expect(analyse(LogLine.started, LogLine.connected) == .connected)
    }

    @Test func disconnectedThenWaitingIsWaiting() {
        #expect(analyse(LogLine.started, LogLine.connected, LogLine.disconnected, LogLine.waiting) == .waiting)
    }

    @Test func disconnectedAloneIsDisconnected() {
        #expect(analyse(LogLine.started, LogLine.connected, LogLine.disconnected) == .disconnected)
    }

    /// The daemon logs "Waiting for the console…" right after failing to claim the interface:
    /// the failure must not be hidden by it.
    @Test func claimFailureSurvivesTheWaitingLineThatFollowsIt() {
        #expect(analyse(LogLine.started, LogLine.claimFailed, LogLine.waiting) == .claimFailed)
    }

    @Test func claimFailureAfterAReplug() {
        #expect(analyse(LogLine.started, LogLine.connected, LogLine.disconnected,
                        LogLine.claimFailed, LogLine.waiting) == .claimFailed)
    }

    @Test func missingEndpoint() {
        #expect(analyse(LogLine.started, LogLine.noEndpoint, LogLine.waiting) == .noEndpoint)
    }

    /// An old run's "connected" must not leak into a new run that has not connected yet.
    @Test func onlyTheLatestRunCounts() {
        #expect(analyse(LogLine.started, LogLine.connected, LogLine.started) == .unknown)
        #expect(analyse(LogLine.started, LogLine.connected, LogLine.started, LogLine.waiting) == .waiting)
    }

    @Test func aNewRunThatConnectsOverridesAnOldFailure() {
        #expect(analyse(LogLine.started, LogLine.claimFailed, LogLine.waiting,
                        LogLine.started, LogLine.connected) == .connected)
    }

    @Test func logWithoutAStartLineIsStillRead() {
        #expect(analyse(LogLine.connected) == .connected)
        #expect(analyse(LogLine.claimFailed) == .claimFailed)
    }

    @Test(arguments: ["", "\n\n", "nothing relevant here", "Console"])
    func unknownWhenThereIsNothingToGoOn(log: String) {
        #expect(ConsoleLogState.analyse(logTail: log) == .unknown)
    }
}
