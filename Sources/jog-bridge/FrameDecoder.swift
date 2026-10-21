/// Décode les trames d'état de 38 octets que la MP3 e2 envoie en continu et ne
/// produit des messages MIDI que pour ce qui a changé depuis la trame précédente.
///
/// Disposition observée (index d'octet) :
///  - 0…5    : boutons, 1 bit par bouton (1 = appuyé)
///  - 6…18   : potentiomètres, faders et encodeurs, valeur 8 bits
///  - 20, 36 : recopies d'état liées à l'octet 3 (informatif, pas converti en MIDI)
///  - 37     : compteur de séquence (ignoré)
///
/// Correspondance MIDI (canal 1), à associer ensuite par MIDI Learn :
///  - bouton (octet n, bit b) → note n × 8 + b, vélocité 127 à l'appui, note off au relâchement
///  - contrôle analogique (octet n) → CC n, valeur = octet >> 1 (0…127)
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
        // La première trame sert d'état initial : rien n'est émis.
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
