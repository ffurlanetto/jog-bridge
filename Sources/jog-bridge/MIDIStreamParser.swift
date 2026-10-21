/// Splits a byte stream into complete MIDI 1.0 messages.
///
/// A transfer can carry several messages, or use "running status". This parser
/// rebuilds clean messages for CoreMIDI and for the LED path (application → console).
struct MIDIStreamParser {
    private var running: UInt8 = 0
    private var pending: [UInt8] = []
    private var expected = 0
    private var sysex: [UInt8]? = nil

    /// Resets the state, so that a stray byte is not interpreted as running status
    /// across two independent transfers.
    mutating func reset() {
        running = 0; pending = []; expected = 0; sysex = nil
    }

    mutating func feed(_ data: [UInt8], emit: ([UInt8]) -> Void) {
        for b in data {
            // Real-time messages: one byte, may be interleaved anywhere.
            if b >= 0xF8 { emit([b]); continue }

            // SysEx en cours.
            if sysex != nil {
                if b == 0xF7 {
                    sysex!.append(b); emit(sysex!); sysex = nil
                    continue
                } else if b < 0x80 {
                    sysex!.append(b); continue
                }
                sysex = nil // SysEx interrupted by a new status byte
            }

            if b >= 0x80 {
                if b == 0xF0 { sysex = [b]; running = 0; pending = []; continue }
                running = b < 0xF0 ? b : 0
                pending = [b]
                expected = Self.length(of: b)
                if expected == 1 { emit(pending); pending = [] }
                continue
            }

            // Data byte.
            if pending.isEmpty {
                guard running != 0 else { continue } // orphan: ignored
                pending = [running]
                expected = Self.length(of: running)
            }
            pending.append(b)
            if pending.count == expected { emit(pending); pending = [] }
        }
    }

    static func length(of status: UInt8) -> Int {
        switch status & 0xF0 {
        case 0xC0, 0xD0: return 2
        case 0xF0:
            switch status {
            case 0xF1, 0xF3: return 2
            case 0xF2: return 3
            default: return 1
            }
        default: return 3
        }
    }
}
