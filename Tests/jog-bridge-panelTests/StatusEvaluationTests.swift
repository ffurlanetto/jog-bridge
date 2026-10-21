import Testing
@testable import jog_bridge_panel

struct StatusEvaluationTests {
    private func evaluate(_ snapshot: BridgeSnapshot) -> BridgeStatus { BridgeStatus.evaluate(snapshot) }

    @Test func healthyIsOkWithNothingToDo() {
        let status = evaluate(.fixture())
        #expect(status.level == .ok)
        #expect(status.title == "Jog Bridge is running")
        #expect(status.actions.isEmpty)
        #expect(status.checks.allSatisfy { $0.result == .ok })
    }

    @Test func notInstalledIsAProblemWithoutActions() {
        let status = evaluate(.fixture(installed: false, service: .notLoaded))
        #expect(status.level == .problem)
        #expect(status.actions.isEmpty)
    }

    @Test func approvalRequiredOffersLoginItems() {
        let status = evaluate(.fixture(service: .notLoaded, approval: .requiresApproval))
        #expect(status.level == .problem)
        #expect(status.actions == [.openLoginItems])
    }

    @Test func notLoadedOffersStart() {
        let status = evaluate(.fixture(service: .notLoaded))
        #expect(status.level == .problem)
        #expect(status.actions == [.start])
    }

    @Test func stoppedOffersRestartAndMentionsTheExitCode() {
        let status = evaluate(.fixture(service: .crashed))
        #expect(status.level == .problem)
        #expect(status.actions == [.restart])
        #expect(status.detail.contains("exit code 1"))
    }

    @Test func missingMIDIPortsOffersRestart() {
        let status = evaluate(.fixture(midi: false))
        #expect(status.level == .attention)
        #expect(status.actions == [.restart])
    }

    @Test func consoleNotPluggedInIsAttentionWithAHint() {
        let status = evaluate(.fixture(usb: false, log: LogLine.log(LogLine.started, LogLine.waiting)))
        #expect(status.level == .attention)
        #expect(status.title == "Waiting for the console")
        #expect(status.actions.isEmpty)
    }

    @Test func consoleUnpluggedAfterBeingConnected() {
        let status = evaluate(.fixture(usb: false, log: LogLine.log(
            LogLine.started, LogLine.connected, LogLine.disconnected, LogLine.waiting)))
        #expect(status.title == "Waiting for the console")
    }

    @Test func consolePresentButNotConnectedOffersRestart() {
        let status = evaluate(.fixture(usb: true, log: LogLine.log(LogLine.started, LogLine.waiting)))
        #expect(status.level == .attention)
        #expect(status.actions == [.restart])
    }

    @Test func consoleHeldByAnotherAppIsExplained() {
        let status = evaluate(.fixture(log: LogLine.log(LogLine.started, LogLine.claimFailed, LogLine.waiting)))
        #expect(status.level == .attention)
        #expect(status.title == "Another app is using the console")
        #expect(status.actions == [.restart])
        #expect(status.checks.last?.result == .failure)
    }

    @Test func unrecognisedConsoleHasNoRestartButAnExplanation() {
        let status = evaluate(.fixture(log: LogLine.log(LogLine.started, LogLine.noEndpoint)))
        #expect(status.level == .attention)
        #expect(status.actions.isEmpty)
    }

    /// A stale "connected" from a previous run must not make a stopped service look healthy.
    @Test func staleLogDoesNotHideAStoppedService() {
        let status = evaluate(.fixture(service: .crashed))
        #expect(status.level == .problem)
        #expect(status.checks.last?.value == "Plugged in (bridge stopped)")
    }

    /// Exhaustive: "ok" is only ever reported when everything really is fine.
    @Test func okIfAndOnlyIfEverythingIsFine() {
        let services: [ServiceState] = [.healthy, .crashed, .notLoaded]
        let approvals: [ApprovalState] = [.approved, .requiresApproval, .notRegistered, .notFound, .unknown]
        let logs = [
            LogLine.log(LogLine.started, LogLine.connected),
            LogLine.log(LogLine.started, LogLine.connected, LogLine.disconnected),
            LogLine.log(LogLine.started, LogLine.waiting),
            LogLine.log(LogLine.started, LogLine.claimFailed, LogLine.waiting),
            LogLine.log(LogLine.started, LogLine.noEndpoint),
            "",
        ]
        var combinations = 0
        for installed in [true, false] {
            for service in services {
                for approval in approvals {
                    for midi in [true, false] {
                        for usb in [true, false] {
                            for log in logs {
                                let snapshot = BridgeSnapshot.fixture(
                                    installed: installed, service: service, approval: approval,
                                    midi: midi, usb: usb, log: log)
                                let expectedOK = installed && approval != .requiresApproval
                                    && service.running && midi && snapshot.log == .connected
                                #expect((evaluate(snapshot).level == .ok) == expectedOK,
                                        "installed=\(installed) service=\(service) approval=\(approval) midi=\(midi) usb=\(usb) log=\(snapshot.log)")
                                combinations += 1
                            }
                        }
                    }
                }
            }
        }
        #expect(combinations == 2 * 3 * 5 * 2 * 2 * 6)
    }

    @Test func everyProblemOrAttentionHasATitleAndDetail() {
        for service in [ServiceState.crashed, .notLoaded] {
            let status = evaluate(.fixture(service: service))
            #expect(!status.title.isEmpty && !status.detail.isEmpty)
        }
    }
}
