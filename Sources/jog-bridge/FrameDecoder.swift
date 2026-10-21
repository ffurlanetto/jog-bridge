/// Decodes the 38-byte state frames the MP3 e2 sends continuously, and produces MIDI
/// messages only for what changed since the previous frame.
///
/// Observed layout (byte index):
///  - 0…5    : buttons, one bit per button (1 = pressed)
///  - 6…18   : knobs, faders and encoders, 8-bit value
///  - 20, 36 : state mirrors tied to byte 3 (informational, not converted to MIDI)
///  - 37     : sequence counter (ignored)
///
/// MIDI mapping (channel 1), to be bound afterwards with MIDI Learn:
///  - button (byte n, bit b) → note n × 8 + b, velocity 127 on press, note off on release
///  - analog control (byte n) → CC n, value = byte >> 1 (0…127)
struct HerculesFrameDecoder {
    static let frameLength = 38

    private static let buttonBytes = 0..<6
    private static let analogBytes = 6..<19
    private static let counterByte = 37

    struct Change {
        let index: Int
        let old: UInt8
        let new: UInt8
    }

    struct Output {
        var changes: [Change] = []
        var messages: [[UInt8]] = []
    }

    private var previous: [UInt8]?

    mutating func decode(_ frame: [UInt8]) -> Output {
        var output = Output()
        guard frame.count == Self.frameLength else { return output }
        defer { previous = frame }
        // The first frame only sets the initial state: nothing is emitted.
        guard let old = previous else { return output }

        for i in 0..<Self.counterByte where frame[i] != old[i] {
            output.changes.append(Change(index: i, old: old[i], new: frame[i]))

            if Self.buttonBytes.contains(i) {
                let pressed = frame[i] & ~old[i]
                let released = old[i] & ~frame[i]
                for bit in 0..<8 {
                    let mask = UInt8(1 << bit)
                    let note = UInt8(i * 8 + bit)
                    if pressed & mask != 0 { output.messages.append([0x90, note, 127]) }
                    if released & mask != 0 { output.messages.append([0x80, note, 0]) }
                }
            } else if Self.analogBytes.contains(i), frame[i] >> 1 != old[i] >> 1 {
                output.messages.append([0xB0, UInt8(i), frame[i] >> 1])
            }
        }
        return output
    }
}
