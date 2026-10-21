import Foundation

/// Bridge configuration (defaults target the Hercules DJ Control MP3 e2).
struct Config {
    var vendorID: UInt16 = 0x06F8
    var productID: UInt16 = 0xB105
    var interface: Int32 = 0
    /// nil = auto-detect from the USB descriptors.
    var endpointIn: UInt8? = nil
    var portName = "Hercules MP3 e2"
    var dump = false
    var listOnly = false

    static let usage = """
    jog-bridge — USB bulk → CoreMIDI bridge for the Hercules DJ Control MP3 e2

    Usage: jog-bridge [options]

      --list            List Hercules devices (VID 06F8) and their endpoints, then exit
      --dump            Print console state changes and the MIDI messages exchanged
      --name <name>     Name of the virtual MIDI ports (default: "Hercules MP3 e2")
      --pid <hex>       USB product ID (default: B105)
      --interface <n>   USB interface to claim (default: 0)
      --in <hex>        Force the input endpoint (e.g. 0x82)
      --help            Show this help
    """

    static func parse(_ args: [String]) -> Config {
        var cfg = Config()
        var it = args.dropFirst().makeIterator()
        while let arg = it.next() {
            switch arg {
            case "--list": cfg.listOnly = true
            case "--dump": cfg.dump = true
            case "--name": cfg.portName = it.next() ?? cfg.portName
            case "--pid": cfg.productID = it.next().flatMap { UInt16(stripHex($0), radix: 16) } ?? cfg.productID
            case "--interface": cfg.interface = it.next().flatMap { Int32($0) } ?? cfg.interface
            case "--in": cfg.endpointIn = it.next().flatMap { UInt8(stripHex($0), radix: 16) }
            case "--help", "-h":
                print(usage); exit(0)
            default:
                fputs("Unknown option: \(arg)\n\n\(usage)\n", stderr); exit(64)
            }
        }
        return cfg
    }

    private static func stripHex(_ s: String) -> String {
        s.lowercased().hasPrefix("0x") ? String(s.dropFirst(2)) : s
    }
}

enum BridgeError: Error, CustomStringConvertible {
    case usb(String, Int32)
    case midi(String, OSStatus)

    var description: String {
        switch self {
        case let .usb(call, rc): return "\(call): \(usbErrorName(rc))"
        case let .midi(call, st): return "\(call): OSStatus \(st)"
        }
    }
}

func log(_ message: String) {
    let ts = ISO8601DateFormatter.string(from: Date(), timeZone: .current,
                                         formatOptions: [.withTime, .withColonSeparatorInTime])
    fputs("[\(ts)] \(message)\n", stderr)
}

func hex(_ bytes: [UInt8]) -> String {
    bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
}
