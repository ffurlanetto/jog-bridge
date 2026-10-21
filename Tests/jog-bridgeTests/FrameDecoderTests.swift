import Testing
@testable import jog_bridge

struct FrameDecoderTests {
    @Test func firstFrameOnlySetsTheInitialState() {
        var decoder = HerculesFrameDecoder()
        let output = decoder.decode(makeFrame([1: 0x04, 6: 0xFF]))
        #expect(output.messages.isEmpty)
        #expect(output.changes.isEmpty)
    }

    @Test func frameWithWrongLengthIsIgnoredAndKeepsPreviousState() {
        var decoder = HerculesFrameDecoder()
        _ = decoder.decode(makeFrame())
        #expect(decoder.decode([0x00, 0x04]).messages.isEmpty)
        // The previous state is kept: the press is still detected afterwards.
        #expect(decoder.decode(makeFrame([1: 0x04])).messages == [[0x90, 10, 127]])
    }

    @Test func buttonPressThenReleaseProducesNoteOnThenNoteOff() {
        var decoder = HerculesFrameDecoder()
        _ = decoder.decode(makeFrame())

        let press = decoder.decode(makeFrame([1: 0x04]))
        #expect(press.messages == [[0x90, 10, 127]])
        #expect(press.changes.count == 1)
        #expect(press.changes.first?.index == 1)
        #expect(press.changes.first?.old == 0x00)
        #expect(press.changes.first?.new == 0x04)

        let release = decoder.decode(makeFrame())
        #expect(release.messages == [[0x80, 10, 0]])
    }

    /// A button's note is `byte × 8 + bit`, for all 48 positions.
    @Test(arguments: 0..<6, 0..<8)
    func everyButtonBitMapsToItsNote(byte: Int, bit: Int) {
        var decoder = HerculesFrameDecoder()
        _ = decoder.decode(makeFrame())
        let output = decoder.decode(makeFrame([byte: UInt8(1 << bit)]))
        #expect(output.messages == [[0x90, UInt8(byte * 8 + bit), 127]])
    }

    @Test func releaseAndPressInTheSameByteAreEmittedInBitOrder() {
        var decoder = HerculesFrameDecoder()
        _ = decoder.decode(makeFrame([2: 0b01]))
        let output = decoder.decode(makeFrame([2: 0b10]))
        #expect(output.messages == [[0x80, 16, 0], [0x90, 17, 127]])
    }

    @Test func simultaneousChangesAreEmittedInAscendingByteOrder() {
        var decoder = HerculesFrameDecoder()
        _ = decoder.decode(makeFrame())
        let output = decoder.decode(makeFrame([10: 0x20, 5: 0x08, 0: 0x02]))
        #expect(output.messages == [[0x90, 1, 127], [0x90, 43, 127], [0xB0, 10, 0x10]])
    }

    /// The 13 analog controls (bytes 6 to 18) become CC 6 to 18, value = byte ÷ 2.
    @Test(arguments: 6...18)
    func everyAnalogByteMapsToItsControlChange(byte: Int) {
        var decoder = HerculesFrameDecoder()
        _ = decoder.decode(makeFrame())
        let output = decoder.decode(makeFrame([byte: 0xFE]))
        #expect(output.messages == [[0xB0, UInt8(byte), 0x7F]])
    }

    @Test func analogValueIsTheByteShiftedByOne() {
        var decoder = HerculesFrameDecoder()
        _ = decoder.decode(makeFrame())
        #expect(decoder.decode(makeFrame([6: 0x80])).messages == [[0xB0, 6, 0x40]])
        #expect(decoder.decode(makeFrame([6: 0xFF])).messages == [[0xB0, 6, 0x7F]])
        #expect(decoder.decode(makeFrame([6: 0x01])).messages == [[0xB0, 6, 0x00]])
    }

    @Test func changeOnTheLeastSignificantBitDoesNotProduceAControlChange() {
        var decoder = HerculesFrameDecoder()
        _ = decoder.decode(makeFrame([6: 0x80]))
        let output = decoder.decode(makeFrame([6: 0x81]))
        #expect(output.messages.isEmpty)
        // The raw change is still reported (useful for --dump).
        #expect(output.changes.count == 1)
    }

    @Test func identicalFramesProduceNothing() {
        var decoder = HerculesFrameDecoder()
        _ = decoder.decode(makeFrame([1: 0x04, 6: 0x80]))
        let output = decoder.decode(makeFrame([1: 0x04, 6: 0x80]))
        #expect(output.messages.isEmpty)
        #expect(output.changes.isEmpty)
    }

    /// Bytes 19 to 36: state mirrors, reported as changes but never converted to MIDI.
    @Test(arguments: 19...36)
    func informationalBytesAreReportedButNotConverted(byte: Int) {
        var decoder = HerculesFrameDecoder()
        _ = decoder.decode(makeFrame())
        let output = decoder.decode(makeFrame([byte: 0xFF]))
        #expect(output.messages.isEmpty)
        #expect(output.changes.count == 1)
    }

    @Test func sequenceCounterIsCompletelyIgnored() {
        var decoder = HerculesFrameDecoder()
        _ = decoder.decode(makeFrame(counter: 0))
        let output = decoder.decode(makeFrame(counter: 200))
        #expect(output.messages.isEmpty)
        #expect(output.changes.isEmpty)
    }
}
