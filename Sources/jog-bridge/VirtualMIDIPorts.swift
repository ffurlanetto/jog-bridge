import CoreMIDI
import Foundation

/// Expose une paire de ports MIDI virtuels (entrée + sortie) visibles par
/// n'importe quelle application macOS (djay, rekordbox, Serato, Ableton…).
final class VirtualMIDIPorts {
    private var client = MIDIClientRef()
    private var source = MIDIEndpointRef()
    private var destination = MIDIEndpointRef()
    private let packetBuffer: UnsafeMutableRawPointer
    private let packetBufferSize = 1024

    // IDs fixes : l'application DJ retrouve son mapping après un redémarrage.
    private static let sourceUniqueID: MIDIUniqueID = 0x4845_5231      // "HER1"
    private static let destinationUniqueID: MIDIUniqueID = 0x4845_5232 // "HER2"

    init(name: String, onReceive: @escaping ([UInt8]) -> Void) throws {
        packetBuffer = UnsafeMutableRawPointer.allocate(byteCount: packetBufferSize,
                                                        alignment: MemoryLayout<MIDIPacketList>.alignment)

        var st = MIDIClientCreateWithBlock(name as CFString, &client) { _ in }
        guard st == noErr else { throw BridgeError.midi("MIDIClientCreate", st) }

        // Source virtuelle : la console → l'application.
        st = MIDISourceCreate(client, name as CFString, &source)
        guard st == noErr else { throw BridgeError.midi("MIDISourceCreate", st) }
        MIDIObjectSetIntegerProperty(source, kMIDIPropertyUniqueID, Self.sourceUniqueID)
        MIDIObjectSetStringProperty(source, kMIDIPropertyManufacturer, "Hercules" as CFString)

        // Destination virtuelle : l'application → la console (LEDs).
        st = MIDIDestinationCreateWithBlock(client, name as CFString, &destination) { list, _ in
            let dataOffset = MemoryLayout<MIDIPacket>.offset(of: \MIDIPacket.data)!
            for packet in list.unsafeSequence() {
                let length = Int(packet.pointee.length)
                let start = UnsafeRawPointer(packet).advanced(by: dataOffset)
                let bytes = Array(UnsafeRawBufferPointer(start: start, count: length))
                onReceive(bytes)
            }
        }
        guard st == noErr else { throw BridgeError.midi("MIDIDestinationCreate", st) }
        MIDIObjectSetIntegerProperty(destination, kMIDIPropertyUniqueID, Self.destinationUniqueID)
        MIDIObjectSetStringProperty(destination, kMIDIPropertyManufacturer, "Hercules" as CFString)
    }

    /// Publie un message MIDI complet sur la source virtuelle.
    func send(_ bytes: [UInt8]) {
        let list = packetBuffer.assumingMemoryBound(to: MIDIPacketList.self)
        var packet = MIDIPacketListInit(list)
        packet = MIDIPacketListAdd(list, packetBufferSize, packet, 0, bytes.count, bytes)
        MIDIReceived(source, list)
    }

    deinit {
        MIDIEndpointDispose(source)
        MIDIEndpointDispose(destination)
        MIDIClientDispose(client)
        packetBuffer.deallocate()
    }
}
