import Foundation
import Testing
@testable import jog_bridge

/// Non-regression of the public contract: note and CC numbers (docs/midi-mapping.md) and
/// consistency with the shipped djay mapping. Changing any of these numbers breaks users'
/// mappings.
struct ContractTests {
    /// Buttons named in docs/midi-mapping.md and their note (byte × 8 + bit of the input frame).
    struct DocumentedButton: Sendable, CustomTestStringConvertible {
        let name: String
        let note: UInt8
        var testDescription: String { "\(name) (note \(note))" }
    }

    static let documentedButtons: [DocumentedButton] = [
        ("Listen A", 8), ("CUE A", 9), ("Play A", 10),
        ("Listen B", 16), ("CUE B", 17), ("Play B", 18),
        ("Pitch Bend − A", 1), ("Pitch Bend + A", 2), ("Sync A", 37), ("Pitch Reset A", 39),
        ("Pitch Bend − B", 25), ("Pitch Bend + B", 26), ("Sync B", 35), ("Pitch Reset B", 33),
        ("Magic", 32), ("Vinyl", 36), ("Folders", 13), ("Files", 14),
    ].map { DocumentedButton(name: $0.0, note: UInt8($0.1)) }

    @Test(arguments: ContractTests.documentedButtons)
    func documentedButtonStillEmitsItsDocumentedNote(button: DocumentedButton) {
        var decoder = HerculesFrameDecoder()
        _ = decoder.decode(makeFrame())
        let byte = Int(button.note) / 8
        let bit = Int(button.note) % 8
        let output = decoder.decode(makeFrame([byte: UInt8(1 << bit)]))
        #expect(output.messages == [[0x90, button.note, 127]], "\(button.name)")
    }

    @Test(arguments: ContractTests.documentedButtons)
    func documentedButtonStillLightsItsLED(button: DocumentedButton) {
        var leds = HerculesLEDs()
        let lit = leds.apply([0x90, button.note, 127])
        #expect(lit, "\(button.name)")
    }

    @Test func mapsEveryButtonNoteBelowFortyEight() {
        // 6 button bytes × 8 bits: the notes occupy exactly 0…47.
        var decoder = HerculesFrameDecoder()
        _ = decoder.decode(makeFrame())
        var notes: Set<UInt8> = []
        for byte in 0..<6 {
            for bit in 0..<8 {
                var probe = decoder
                notes.insert(probe.decode(makeFrame([byte: UInt8(1 << bit)])).messages[0][1])
            }
        }
        #expect(notes == Set(0..<48))
    }
}

/// The djay mapping shipped in the repository must stay consistent with what the daemon emits.
struct DjayMappingTests {
    struct Control {
        let keyPath: String
        let channel: Int
        let type: Int
        let data: Int
    }

    private func loadControls() throws -> [Control] {
        let url = repositoryRoot.appendingPathComponent("Hercules MP3 e2.djayMidiMapping")
        let data = try Data(contentsOf: url)
        let plist = try #require(
            try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        let controls = try #require(plist["controls"] as? [[String: Any]])
        return controls.compactMap { entry in
            guard let keyPath = entry["keyPath"] as? String,
                  let channel = entry["midiChannel"] as? Int,
                  let type = entry["midiMessageType"] as? Int,
                  let data = entry["midiData"] as? Int else { return nil }
            return Control(keyPath: keyPath, channel: channel, type: type, data: data)
        }
    }

    @Test func mappingIsReadable() throws {
        #expect(try loadControls().count == 59)
    }

    @Test func everyControlIsOnMIDIChannelOne() throws {
        for control in try loadControls() {
            #expect(control.channel == 0, "\(control.keyPath)")
        }
    }

    @Test func noteControlsUseNotesTheDaemonCanEmit() throws {
        let notes = try loadControls().filter { $0.type == 1 }
        #expect(!notes.isEmpty)
        for control in notes {
            #expect((0..<48).contains(control.data), "\(control.keyPath) : note \(control.data)")
        }
    }

    @Test func controlChangeControlsCoverExactlyTheAnalogBytes() throws {
        let ccs = try loadControls().filter { $0.type == 3 }.map(\.data)
        #expect(Set(ccs) == Set(6...18))
        #expect(ccs.count == Set(ccs).count, "the same CC is mapped twice")
    }

    @Test func noMessageIsMappedTwice() throws {
        let keys = try loadControls().map { "\($0.type)/\($0.data)" }
        #expect(keys.count == Set(keys).count)
    }

    @Test func onlyKnownMessageTypesAreUsed() throws {
        for control in try loadControls() {
            #expect([1, 3].contains(control.type), "\(control.keyPath) : type \(control.type)")
        }
    }
}
