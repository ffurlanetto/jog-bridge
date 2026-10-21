/// État des LEDs de la console et traduction des messages MIDI reçus de l'application.
///
/// La console pilote ses LEDs par 5 blocs de 16 bits (requêtes de contrôle 0x2D…0x31).
/// Les blocs 0 à 2 contiennent les LEDs fixes, les blocs 2 à 4 les LEDs clignotantes
/// (le bloc 2 porte les deux : bits 0…6 clignotants, bits 8…15 fixes).
///
/// Côté MIDI, une LED porte le numéro de note du bouton correspondant (le même que
/// celui émis par `HerculesFrameDecoder`), de sorte qu'une application qui renvoie
/// l'état d'un bouton sur la même note allume la bonne LED :
///  - canal 1 : LED fixe (note on = allumée, note off ou vélocité 0 = éteinte)
///  - canal 2 : LED clignotante (même principe)
///
/// Table d'après https://github.com/foomatic/djcontrol (Protocol.txt, djcontrol.py).
struct HerculesLEDs {
    static let blockCount = 5

    private struct Position {
        let block: Int
        let bit: Int
        init(_ block: Int, _ bit: Int) { self.block = block; self.bit = bit }
    }

    private struct LED {
        let fixed: Position
        let blink: Position
    }

    /// Note MIDI (octet × 8 + bit du bouton dans la trame d'entrée) → LED.
    private static let table: [UInt8: LED] = {
        // (octet du bouton, bit du bouton, bloc/bit fixe, bloc/bit clignotant)
        let entries: [(Int, Int, Position, Position)] = [
            // Deck A
            (4, 7, Position(0, 8), Position(2, 0)),    // PitchReset_A
            (0, 1, Position(1, 8), Position(3, 0)),    // PitchBendMinus_A
            (0, 2, Position(1, 0), Position(4, 8)),    // PitchBendPlus_A
            (4, 5, Position(0, 10), Position(2, 2)),   // Sync_A
            (4, 6, Position(0, 9), Position(2, 1)),    // N1_A
            (0, 4, Position(0, 1), Position(3, 9)),    // N2_A
            (0, 5, Position(1, 9), Position(3, 1)),    // N3_A
            (0, 6, Position(1, 1), Position(4, 9)),    // N4_A
            (5, 0, Position(2, 8), Position(4, 0)),    // N5_A
            (5, 1, Position(2, 9), Position(4, 1)),    // N6_A
            (5, 2, Position(2, 10), Position(4, 2)),   // N7_A
            (5, 3, Position(2, 11), Position(4, 3)),   // N8_A
            (1, 1, Position(1, 10), Position(3, 2)),   // CUE_A
            (1, 2, Position(1, 2), Position(4, 10)),   // Play_A
            (1, 0, Position(0, 2), Position(3, 10)),   // Listen_A
            // Deck B
            (4, 1, Position(0, 14), Position(2, 6)),   // PitchReset_B
            (3, 1, Position(1, 14), Position(3, 6)),   // PitchBendMinus_B
            (3, 2, Position(1, 6), Position(4, 14)),   // PitchBendPlus_B
            (4, 3, Position(0, 12), Position(2, 4)),   // Sync_B
            (4, 2, Position(0, 13), Position(2, 5)),   // N1_B
            (2, 4, Position(0, 5), Position(3, 13)),   // N2_B
            (2, 5, Position(1, 13), Position(3, 5)),   // N3_B
            (2, 6, Position(1, 5), Position(4, 13)),   // N4_B
            (5, 4, Position(2, 12), Position(4, 4)),   // N5_B
            (5, 5, Position(2, 13), Position(4, 5)),   // N6_B
            (5, 6, Position(2, 14), Position(4, 6)),   // N7_B
            (5, 7, Position(2, 15), Position(4, 7)),   // N8_B
            (2, 1, Position(1, 12), Position(3, 4)),   // CUE_B
            (2, 2, Position(1, 4), Position(4, 12)),   // Play_B
            (2, 0, Position(0, 4), Position(3, 12)),   // Listen_B
            // Commun
            (4, 4, Position(0, 11), Position(2, 3)),   // Vinyl
            (4, 0, Position(0, 3), Position(3, 11)),   // Magic
            (1, 5, Position(1, 11), Position(3, 3)),   // Folders
            (1, 6, Position(1, 3), Position(4, 11)),   // Files
        ]
        var table: [UInt8: LED] = [:]
        for (byte, bit, fixed, blink) in entries {
            table[UInt8(byte * 8 + bit)] = LED(fixed: fixed, blink: blink)
        }
        return table
    }()

    private(set) var blocks = [UInt16](repeating: 0, count: HerculesLEDs.blockCount)

    /// Applique un message MIDI complet. Retourne `true` si l'état des LEDs a changé.
    mutating func apply(_ message: [UInt8]) -> Bool {
        guard message.count == 3 else { return false }
        let kind = message[0] & 0xF0
        let channel = message[0] & 0x0F
        guard kind == 0x90 || kind == 0x80, channel <= 1,
              let led = Self.table[message[1]] else { return false }

        let on = kind == 0x90 && message[2] > 0
        let position = channel == 0 ? led.fixed : led.blink
        let mask = UInt16(1) << position.bit
        let updated = on ? blocks[position.block] | mask : blocks[position.block] & ~mask
        guard updated != blocks[position.block] else { return false }
        blocks[position.block] = updated
        return true
    }
}
