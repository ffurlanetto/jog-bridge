/// Découpe un flux d'octets en messages MIDI 1.0 complets.
///
/// La MP3 e2 envoie déjà du MIDI brut (ex. `B3 38 38`) sur son endpoint bulk,
/// mais un transfert USB peut contenir plusieurs messages, ou utiliser le
/// "running status". Ce parseur reconstitue des messages propres pour CoreMIDI.
struct MIDIStreamParser {
    private var running: UInt8 = 0
    private var pending: [UInt8] = []
    private var expected = 0
    private var sysex: [UInt8]? = nil

    /// Remet l'état à zéro (appelé entre deux transferts USB : la console envoie
    /// des messages complets, on évite ainsi qu'un octet parasite soit interprété
    /// en running status).
    mutating func reset() {
        running = 0; pending = []; expected = 0; sysex = nil
    }

    mutating func feed(_ data: [UInt8], emit: ([UInt8]) -> Void) {
        for b in data {
            // Messages temps réel : 1 octet, peuvent s'intercaler n'importe où.
            if b >= 0xF8 { emit([b]); continue }

            // SysEx en cours.
            if sysex != nil {
                if b == 0xF7 {
                    sysex!.append(b); emit(sysex!); sysex = nil
                    continue
                } else if b < 0x80 {
                    sysex!.append(b); continue
                }
                sysex = nil // SysEx interrompu par un nouvel octet de statut
            }

            if b >= 0x80 {
                if b == 0xF0 { sysex = [b]; running = 0; pending = []; continue }
                running = b < 0xF0 ? b : 0
                pending = [b]
                expected = Self.length(of: b)
                if expected == 1 { emit(pending); pending = [] }
                continue
            }

            // Octet de données.
            if pending.isEmpty {
                guard running != 0 else { continue } // orphelin : ignoré
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
