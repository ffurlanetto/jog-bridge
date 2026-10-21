import Testing
@testable import jog_bridge

struct MIDIStreamParserTests {
    /// Feeds a fresh parser with a series of transfers and returns the emitted messages.
    private func parse(_ chunks: [UInt8]...) -> [[UInt8]] {
        var parser = MIDIStreamParser()
        var messages: [[UInt8]] = []
        for chunk in chunks { parser.feed(chunk) { messages.append($0) } }
        return messages
    }

    @Test func completeNoteOn() {
        #expect(parse([0x90, 60, 100]) == [[0x90, 60, 100]])
    }

    @Test func severalMessagesInOneTransfer() {
        #expect(parse([0x90, 60, 100, 0x80, 60, 0]) == [[0x90, 60, 100], [0x80, 60, 0]])
    }

    @Test func runningStatusReusesThePreviousStatusByte() {
        #expect(parse([0x90, 60, 100, 62, 101]) == [[0x90, 60, 100], [0x90, 62, 101]])
    }

    @Test func messageSplitAcrossTransfersIsReassembled() {
        #expect(parse([0x90, 60], [100]) == [[0x90, 60, 100]])
    }

    @Test func realTimeByteInsideAMessageIsEmittedImmediately() {
        #expect(parse([0x90, 0xF8, 60, 100]) == [[0xF8], [0x90, 60, 100]])
    }

    @Test func twoByteChannelMessages() {
        #expect(parse([0xC0, 5]) == [[0xC0, 5]])
        #expect(parse([0xD0, 9]) == [[0xD0, 9]])
        #expect(parse([0xC0, 5, 6]) == [[0xC0, 5], [0xC0, 6]])
    }

    @Test func systemExclusiveIsEmittedWhole() {
        #expect(parse([0xF0, 1, 2, 3, 0xF7]) == [[0xF0, 1, 2, 3, 0xF7]])
    }

    @Test func realTimeByteInsideSysExDoesNotBreakIt() {
        #expect(parse([0xF0, 1, 0xF8, 2, 0xF7]) == [[0xF8], [0xF0, 1, 2, 0xF7]])
    }

    @Test func sysExInterruptedByAStatusByteIsDropped() {
        #expect(parse([0xF0, 1, 0x90, 60, 100]) == [[0x90, 60, 100]])
    }

    @Test func orphanDataBytesAreIgnored() {
        #expect(parse([60, 100]).isEmpty)
    }

    @Test func systemCommonMessagesAndTheirLength() {
        #expect(parse([0xF6]) == [[0xF6]])
        #expect(parse([0xF1, 5]) == [[0xF1, 5]])
        #expect(parse([0xF2, 1, 2]) == [[0xF2, 1, 2]])
    }

    @Test func systemCommonStatusClearsRunningStatus() {
        // After 0xF6, the data bytes that follow no longer have a running status.
        #expect(parse([0x90, 60, 100, 0xF6, 62, 101]) == [[0x90, 60, 100], [0xF6]])
    }

    @Test func resetForgetsRunningStatusAndPendingBytes() {
        var parser = MIDIStreamParser()
        var messages: [[UInt8]] = []
        parser.feed([0x90, 60]) { messages.append($0) }
        parser.reset()
        parser.feed([100]) { messages.append($0) }
        #expect(messages.isEmpty)
    }

    @Test(arguments: [
        (UInt8(0x80), 3), (0x90, 3), (0xA0, 3), (0xB0, 3), (0xC0, 2), (0xD0, 2), (0xE0, 3),
        (0xF1, 2), (0xF2, 3), (0xF3, 2), (0xF6, 1), (0xF8, 1),
    ])
    func messageLengthByStatus(status: UInt8, expected: Int) {
        #expect(MIDIStreamParser.length(of: status) == expected)
        // The channel number does not change the length.
        if status < 0xF0 { #expect(MIDIStreamParser.length(of: status | 0x0F) == expected) }
    }
}
