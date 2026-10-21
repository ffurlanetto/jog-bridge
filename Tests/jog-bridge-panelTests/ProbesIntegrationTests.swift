import CoreMIDI
import Foundation
import Testing
@testable import jog_bridge_panel

/// True if CoreMIDI can create a client and a virtual source here (some headless runners have
/// no MIDI server): otherwise the CoreMIDI test is disabled instead of failing.
private let coreMIDIAvailable: Bool = {
    var client = MIDIClientRef()
    guard MIDIClientCreate("panel-probe" as CFString, nil, nil, &client) == noErr else { return false }
    defer { MIDIClientDispose(client) }
    var source = MIDIEndpointRef()
    guard MIDISourceCreate(client, "panel-probe" as CFString, &source) == noErr else { return false }
    MIDIEndpointDispose(source)
    return true
}()

struct ProbesIntegrationTests {
    @Test(.enabled(if: coreMIDIAvailable, "CoreMIDI unavailable"))
    func midiProbeSeesAVirtualSourceByName() async throws {
        let name = "panel-test-\(UUID().uuidString.prefix(8))"
        var client = MIDIClientRef()
        try #require(MIDIClientCreate("panel-test-client" as CFString, nil, nil, &client) == noErr)
        defer { MIDIClientDispose(client) }

        var source = MIDIEndpointRef()
        try #require(MIDISourceCreate(client, name as CFString, &source) == noErr)

        #expect(CoreMIDINames.sources().contains(name))

        MIDIEndpointDispose(source)
        // Disposal is reflected in the next enumeration.
        var gone = false
        for _ in 0..<100 where !gone {
            gone = !CoreMIDINames.sources().contains(name)
            if !gone { try await Task.sleep(for: .milliseconds(10)) }
        }
        #expect(gone)
    }

    @Test func usbProbeReportsAbsenceForADeviceThatDoesNotExist() {
        #expect(!USBProbe.devicePresent(vendorID: 0xFFFF, productID: 0xFFFF))
    }

    @Test func systemRunnerCapturesOutputAndStatus() async {
        let ok = await SystemProcessRunner().run("/bin/echo", ["hello"])
        #expect(ok.status == 0)
        #expect(ok.output == "hello\n")

        let failure = await SystemProcessRunner().run("/usr/bin/false", [])
        #expect(failure.status == 1)
    }

    @Test func systemRunnerSurvivesAMissingExecutable() async {
        let result = await SystemProcessRunner().run("/definitely/not/here", [])
        #expect(result.status == -1)
    }

    @Test func logTailKeepsOnlyTheEndOfALargeFile() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("panel-log-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: url) }
        let body = (1...5000).map { "line \($0)" }.joined(separator: "\n")
        try body.write(to: url, atomically: true, encoding: .utf8)

        let tail = LogTail.read(path: url.path, maxBytes: 1024, maxLines: 10)
        let lines = tail.split(separator: "\n")
        #expect(lines.count == 10)
        #expect(lines.last == "line 5000")
        #expect(!tail.contains("line 1\n"))
    }

    @Test func logTailOfAMissingFileIsEmpty() {
        #expect(LogTail.read(path: "/tmp/definitely-missing-\(UUID().uuidString)") == "")
    }
}
