import Testing
@testable import jog_bridge

struct LEDsTests {
    /// Notes that have a LED (see docs/midi-mapping.md): 34 buttons.
    static let ledNotes: [UInt8] = [
        1, 2, 4, 5, 6, 8, 9, 10, 13, 14, 16, 17, 18, 20, 21, 22, 25, 26,
        32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47,
    ]

    private func setBits(_ blocks: [UInt16]) -> Int {
        blocks.reduce(0) { $0 + $1.nonzeroBitCount }
    }

    @Test func startsWithEveryLEDOff() {
        let leds = HerculesLEDs()
        #expect(leds.blocks == [0, 0, 0, 0, 0])
        #expect(leds.blocks.count == HerculesLEDs.blockCount)
    }

    @Test func fixedLEDTurnsOnAndOff() {
        var leds = HerculesLEDs()
        let changed = leds.apply([0x90, 10, 127])
        #expect(changed)
        #expect(leds.blocks == [0, 0x0004, 0, 0, 0])
        let changedAgain = leds.apply([0x80, 10, 0])
        #expect(changedAgain)
        #expect(leds.blocks == [0, 0, 0, 0, 0])
    }

    @Test func noteOnWithZeroVelocityTurnsTheLEDOff() {
        var leds = HerculesLEDs()
        _ = leds.apply([0x90, 10, 127])
        let changed = leds.apply([0x90, 10, 0])
        #expect(changed)
        #expect(leds.blocks == [0, 0, 0, 0, 0])
    }

    @Test func channelTwoDrivesTheBlinkingLED() {
        var leds = HerculesLEDs()
        let changed = leds.apply([0x91, 10, 127])
        #expect(changed)
        #expect(leds.blocks == [0, 0, 0, 0, 0x0400])
    }

    @Test func reportsNoChangeWhenTheStateIsAlreadyRight() {
        var leds = HerculesLEDs()
        let changed = leds.apply([0x90, 10, 127])
        #expect(changed)
        let changedAgain = leds.apply([0x90, 10, 127])
        #expect(!changedAgain)
        let changedLast = leds.apply([0x80, 11, 0])
        #expect(!changedLast)   // note without a LED
    }

    @Test(arguments: [
        [UInt8(0x92), 10, 127],           // channel 3
        [0x9F, 10, 127],                  // channel 16
        [0xB0, 10, 127],                  // Control Change
        [0xE0, 10, 127],                  // Pitch Bend
        [0x90, 99, 127],                  // note without a LED
        [0x90, 10],                       // truncated message
        [0x90, 10, 127, 0],               // message too long
        [],
    ])
    func ignoresMessagesThatAreNotLEDCommands(message: [UInt8]) {
        var leds = HerculesLEDs()
        let changed = leds.apply(message)
        #expect(!changed)
        #expect(leds.blocks == [0, 0, 0, 0, 0])
    }

    /// Each button with a LED lights exactly one bit when steady and one when blinking.
    @Test(arguments: LEDsTests.ledNotes)
    func eachLEDOwnsExactlyOneFixedAndOneBlinkingBit(note: UInt8) {
        var fixed = HerculesLEDs()
        let fixedChanged = fixed.apply([0x90, note, 127])
        #expect(fixedChanged)
        #expect(setBits(fixed.blocks) == 1)

        var blinking = HerculesLEDs()
        let blinkingChanged = blinking.apply([0x91, note, 127])
        #expect(blinkingChanged)
        #expect(setBits(blinking.blocks) == 1)

        #expect(fixed.blocks != blinking.blocks)
    }

    /// Two LEDs never share a bit: otherwise lighting one would light the other.
    @Test func noTwoLEDsShareABit() {
        var all = HerculesLEDs()
        for note in Self.ledNotes {
            let fixedChanged = all.apply([0x90, note, 127])
            #expect(fixedChanged, "note \(note) steady")
            let blinkingChanged = all.apply([0x91, note, 127])
            #expect(blinkingChanged, "note \(note) blinking")
        }
        #expect(setBits(all.blocks) == Self.ledNotes.count * 2)
    }

    @Test func turningOneLEDOffLeavesTheOthersUntouched() {
        var leds = HerculesLEDs()
        _ = leds.apply([0x90, 10, 127])
        _ = leds.apply([0x90, 18, 127])
        let both = leds.blocks
        _ = leds.apply([0x80, 10, 0])
        #expect(setBits(leds.blocks) == 1)
        #expect(setBits(both) == 2)
    }
}
