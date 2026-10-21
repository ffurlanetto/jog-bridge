import Testing
@testable import jog_bridge_panel

struct DiagnosticsTests {
    private func report(_ snapshot: BridgeSnapshot, maxLogLines: Int = 40) -> String {
        BridgeStatus.diagnostics(snapshot: snapshot, status: .evaluate(snapshot),
                                 osVersion: "Version 15.0 (Build TEST)", maxLogLines: maxLogLines)
    }

    @Test func containsTheKeyFacts() {
        let text = report(.fixture())
        #expect(text.hasPrefix("Jog Bridge diagnostics"))
        #expect(text.contains("App version: 1.2.3"))
        #expect(text.contains("macOS: Version 15.0 (Build TEST)"))
        #expect(text.contains("Status: ok — Jog Bridge is running"))
        #expect(text.contains("- Background service: Running (pid 4242)"))
        #expect(text.contains("- Console: Connected"))
        #expect(text.contains("USB device present: yes"))
        #expect(text.contains("Console connected"))
    }

    @Test func boundsTheLogToTheLastLines() {
        let log = (1...100).map { "line \($0)" }.joined(separator: "\n")
        let text = report(.fixture(log: log), maxLogLines: 5)
        #expect(text.contains("line 100"))
        #expect(text.contains("line 96"))
        #expect(!text.contains("line 95"))
    }

    @Test func saysSoWhenTheLogIsEmpty() {
        #expect(report(.fixture(log: "")).contains("(empty or unreadable)"))
    }

    @Test func describesAProblem() {
        let text = report(.fixture(service: .crashed))
        #expect(text.contains("Status: problem — Jog Bridge stopped"))
        #expect(text.contains("lastExit=1"))
    }
}
