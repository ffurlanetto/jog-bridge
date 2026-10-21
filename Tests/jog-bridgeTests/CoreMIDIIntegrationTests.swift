import CoreMIDI
import Foundation
import Testing
@testable import jog_bridge

// MARK: - CoreMIDI helpers

/// True if CoreMIDI can create a client and a virtual source in this environment
/// (some headless runners have no MIDI server): otherwise the tests are disabled.
enum CoreMIDIProbe {
    static let isAvailable: Bool = {
        var client = MIDIClientRef()
        guard MIDIClientCreate("jog-bridge-probe" as CFString, nil, nil, &client) == noErr else { return false }
        defer { MIDIClientDispose(client) }
        var source = MIDIEndpointRef()
        guard MIDISourceCreate(client, "jog-bridge-probe" as CFString, &source) == noErr else { return false }
        MIDIEndpointDispose(source)
        return true
    }()
}

/// Accumulates messages received from another thread.
final class MessageCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [[UInt8]] = []

    var messages: [[UInt8]] {
        lock.lock(); defer { lock.unlock() }
        return storage
    }

    func add(_ message: [UInt8]) {
        lock.lock(); storage.append(message); lock.unlock()
    }
}

private func name(of endpoint: MIDIEndpointRef) -> String? {
    var value: Unmanaged<CFString>?
    guard MIDIObjectGetStringProperty(endpoint, kMIDIPropertyName, &value) == noErr else { return nil }
    return value?.takeRetainedValue() as String?
}

private func findSource(named wanted: String) -> MIDIEndpointRef? {
    (0..<MIDIGetNumberOfSources()).map { MIDIGetSource($0) }.first { name(of: $0) == wanted }
}

private func findDestination(named wanted: String) -> MIDIEndpointRef? {
    (0..<MIDIGetNumberOfDestinations()).map { MIDIGetDestination($0) }.first { name(of: $0) == wanted }
}

/// Bytes of each packet in a CoreMIDI packet list.
private func payloads(of list: UnsafePointer<MIDIPacketList>) -> [[UInt8]] {
    let dataOffset = MemoryLayout<MIDIPacket>.offset(of: \MIDIPacket.data)!
    return list.unsafeSequence().map { packet in
        let start = UnsafeRawPointer(packet).advanced(by: dataOffset)
        return Array(UnsafeRawBufferPointer(start: start, count: Int(packet.pointee.length)))
    }
}

/// Test CoreMIDI client: listens to a source and sends to a destination.
final class TestMIDIClient {
    private var client = MIDIClientRef()
    private var inputPort = MIDIPortRef()
    private var outputPort = MIDIPortRef()
    let received = MessageCollector()

    /// Probe message (Active Sensing) used to detect that the connection is established.
    static let probe: [UInt8] = [0xFE]

    /// Received messages, probe excluded. CoreMIDI may group several messages with the same
    /// timestamp into one packet: they are split again the way an application would.
    var messages: [[UInt8]] {
        received.messages.flatMap { payload -> [[UInt8]] in
            var parser = MIDIStreamParser()
            var split: [[UInt8]] = []
            parser.feed(payload) { split.append($0) }
            return split
        }
        .filter { $0 != Self.probe }
    }

    init() throws {
        let received = self.received
        try check(MIDIClientCreate("jog-bridge-test-client" as CFString, nil, nil, &client))
        // The "WithBlock" API is deprecated in favour of MIDIEventList; it remains the simplest
        // way to compare MIDI 1.0 bytes, and it is the one the daemon uses.
        try check(MIDIInputPortCreateWithBlock(client, "in" as CFString, &inputPort) { list, _ in
            for payload in payloads(of: list) { received.add(payload) }
        })
        try check(MIDIOutputPortCreate(client, "out" as CFString, &outputPort))
    }

    deinit { MIDIClientDispose(client) }

    func listen(to source: MIDIEndpointRef) throws {
        try check(MIDIPortConnectSource(inputPort, source, nil))
    }

    /// `MIDIPortConnectSource` is asynchronous: a message sent too early is lost. A probe is
    /// therefore sent until it arrives, which proves the connection is ready.
    func waitUntilConnected(sendProbe: () -> Void) async -> Bool {
        let deadline = ContinuousClock.now + .seconds(3)
        while ContinuousClock.now < deadline {
            sendProbe()
            if await waitUntil(timeout: .milliseconds(100), { !received.messages.isEmpty }) { return true }
        }
        return false
    }

    func send(_ message: [UInt8], to destination: MIDIEndpointRef) throws {
        var buffer = [UInt8](repeating: 0, count: 1024)
        try buffer.withUnsafeMutableBytes { raw in
            let list = raw.baseAddress!.assumingMemoryBound(to: MIDIPacketList.self)
            let packet = MIDIPacketListInit(list)
            _ = MIDIPacketListAdd(list, raw.count, packet, 0, message.count, message)
            try check(MIDISend(outputPort, destination, list))
        }
    }

    private func check(_ status: OSStatus) throws {
        guard status == noErr else { throw BridgeError.midi("test", status) }
    }
}

/// Reproduces main.swift's wiring for the application → console direction.
final class LEDPipeline: @unchecked Sendable {
    private let lock = NSLock()
    private var leds = HerculesLEDs()
    private var parser = MIDIStreamParser()
    private var pushed: [[UInt16]] = []

    var blocks: [UInt16] { lock.lock(); defer { lock.unlock() }; return leds.blocks }
    /// State sent to the console (one element per change), like `device.setLEDs`.
    var pushedStates: [[UInt16]] { lock.lock(); defer { lock.unlock() }; return pushed }

    func receive(_ bytes: [UInt8]) {
        lock.lock(); defer { lock.unlock() }
        var changed = false
        parser.feed(bytes) { message in
            if leds.apply(message) { changed = true }
        }
        if changed { pushed.append(leds.blocks) }
    }
}

private func uniqueName() -> String { "jog-bridge-test-\(UUID().uuidString.prefix(8))" }

// MARK: - Integration tests

/// These tests use real virtual CoreMIDI ports, with unique names so they do not interfere
/// with a jog-bridge agent already installed on the machine.
@Suite(.serialized, .enabled(if: CoreMIDIProbe.isAvailable, "CoreMIDI unavailable"))
struct CoreMIDIIntegrationTests {
    @Test func messagesPublishedByTheDaemonReachAnApplicationListeningToTheSource() async throws {
        let name = uniqueName()
        let ports = try VirtualMIDIPorts(name: name) { _ in }
        let source = try #require(findSource(named: name))
        let application = try TestMIDIClient()
        try application.listen(to: source)
        let connected = await application.waitUntilConnected { ports.send(TestMIDIClient.probe) }
        try #require(connected, "the connection to the source was not established")

        ports.send([0x90, 10, 127])
        ports.send([0xB0, 6, 0x40])

        let arrived = await waitUntil { application.messages.count >= 2 }
        #expect(arrived)
        #expect(application.messages == [[0x90, 10, 127], [0xB0, 6, 0x40]])
    }

    @Test func messagesSentByTheApplicationReachTheDaemon() async throws {
        let name = uniqueName()
        let collector = MessageCollector()
        let ports = try VirtualMIDIPorts(name: name) { collector.add($0) }
        _ = ports
        let destination = try #require(findDestination(named: name))
        let application = try TestMIDIClient()

        try application.send([0x90, 10, 127], to: destination)

        let arrived = await waitUntil { !collector.messages.isEmpty }
        #expect(arrived)
        #expect(collector.messages == [[0x90, 10, 127]])
    }

    @Test func applicationMessagesLightTheRightLEDsThroughTheWholeChain() async throws {
        let name = uniqueName()
        let pipeline = LEDPipeline()
        let ports = try VirtualMIDIPorts(name: name) { pipeline.receive($0) }
        _ = ports
        let destination = try #require(findDestination(named: name))
        let application = try TestMIDIClient()

        try application.send([0x90, 10, 127], to: destination)   // Play A steady
        try application.send([0x91, 39, 127], to: destination)   // Pitch Reset A blinking
        try application.send([0x90, 10, 127], to: destination)   // unchanged: nothing to send back

        let expected: [UInt16] = [0, 0x0004, 0x0001, 0, 0]
        let arrived = await waitUntil { pipeline.blocks == expected }
        #expect(arrived)
        // CoreMIDI may group the messages into a single packet: check the final state sent
        // to the console, and that nothing is sent for the message with no effect.
        #expect(pipeline.pushedStates.last == expected)
        #expect(pipeline.pushedStates.count <= 2)
    }

    /// Whole chain without hardware: recorded USB frames → decoder → virtual ports →
    /// application. The expected values are those of the reference file.
    @Test func recordedFramesArriveAsMIDIInTheApplication() async throws {
        let session: GoldenReplayTests.FrameSession = try loadFixture("frame-session")
        let expected = session.steps.flatMap(\.expected).map(bytes)
        #expect(!expected.isEmpty)

        let name = uniqueName()
        let ports = try VirtualMIDIPorts(name: name) { _ in }
        let source = try #require(findSource(named: name))
        let application = try TestMIDIClient()
        try application.listen(to: source)
        let connected = await application.waitUntilConnected { ports.send(TestMIDIClient.probe) }
        try #require(connected, "the connection to the source was not established")

        var decoder = HerculesFrameDecoder()
        for step in session.steps {
            for message in decoder.decode(bytes(step.frame)).messages { ports.send(message) }
        }

        let arrived = await waitUntil { application.messages.count >= expected.count }
        #expect(arrived)
        #expect(application.messages == expected)
    }

    @Test func portsAreDeclaredAsHerculesAndKeepTheirFixedIdentifiers() throws {
        let sourceID: MIDIUniqueID = 0x4845_5231      // « HER1 »
        let destinationID: MIDIUniqueID = 0x4845_5232 // « HER2 »

        // If a jog-bridge agent is already running it holds these identifiers: nothing to check.
        var existing = MIDIObjectRef()
        var type = MIDIObjectType.other
        let taken = MIDIObjectFindByUniqueID(sourceID, &existing, &type) == noErr
            || MIDIObjectFindByUniqueID(destinationID, &existing, &type) == noErr
        guard !taken else { return }

        let name = uniqueName()
        let ports = try VirtualMIDIPorts(name: name) { _ in }
        _ = ports
        let source = try #require(findSource(named: name))
        let destination = try #require(findDestination(named: name))

        var id: Int32 = 0
        #expect(MIDIObjectGetIntegerProperty(source, kMIDIPropertyUniqueID, &id) == noErr)
        #expect(id == sourceID)
        #expect(MIDIObjectGetIntegerProperty(destination, kMIDIPropertyUniqueID, &id) == noErr)
        #expect(id == destinationID)

        for endpoint in [source, destination] {
            var manufacturer: Unmanaged<CFString>?
            #expect(MIDIObjectGetStringProperty(endpoint, kMIDIPropertyManufacturer, &manufacturer) == noErr)
            #expect(manufacturer?.takeRetainedValue() as String? == "Hercules")
        }
    }
}

// MARK: - libusb

/// Checks the link with libusb (statically linked) with no hardware plugged in.
struct LibUSBSmokeTests {
    @Test func contextInitialisesWithoutAnyDevice() throws {
        let device = try HerculesDevice(config: Config())
        device.close()   // without a connection: must do nothing
    }

    @Test func listingDevicesDoesNotCrashWhenNothingMatches() throws {
        var config = Config()
        config.vendorID = 0xFFFF   // no real device
        try HerculesDevice(config: config).listDevices()
    }

    @Test func usbErrorNamesComeFromLibUSB() {
        #expect(usbErrorName(0).hasPrefix("LIBUSB_SUCCESS"))
        #expect(usbErrorName(-3) == "LIBUSB_ERROR_ACCESS")
    }
}
