import Testing
@testable import jog_bridge

/// Non-regression: recorded sessions (Fixtures/*.json) are replayed and compared with
/// hand-written expected results. A mismatch means the MIDI contract users see has changed
/// (see ADR 0007): that is a breaking change to note in the CHANGELOG, not just a test to update.
struct GoldenReplayTests {
    struct FrameSession: Decodable {
        struct Step: Decodable {
            let comment: String
            let frame: String
            let expected: [String]
        }
        let steps: [Step]
    }

    struct LEDSequence: Decodable {
        struct Step: Decodable {
            let comment: String
            let midi: String
            let changed: Bool
            let blocks: [UInt16]
        }
        let steps: [Step]
    }

    @Test func frameSessionProducesTheRecordedMIDI() throws {
        let session: FrameSession = try loadFixture("frame-session")
        #expect(!session.steps.isEmpty)

        var decoder = HerculesFrameDecoder()
        for (index, step) in session.steps.enumerated() {
            let frame = bytes(step.frame)
            #expect(frame.count == HerculesFrameDecoder.frameLength, "frame \(index): length")
            let actual = decoder.decode(frame).messages.map(hex)
            #expect(actual == step.expected, "frame \(index) — \(step.comment)")
        }
    }

    @Test func ledSequenceProducesTheRecordedBlocks() throws {
        let sequence: LEDSequence = try loadFixture("led-sequence")
        #expect(!sequence.steps.isEmpty)

        var leds = HerculesLEDs()
        for (index, step) in sequence.steps.enumerated() {
            let changed = leds.apply(bytes(step.midi))
            #expect(changed == step.changed, "step \(index) — \(step.comment): changed flag")
            #expect(leds.blocks == step.blocks, "step \(index) — \(step.comment): blocks")
        }
    }
}
