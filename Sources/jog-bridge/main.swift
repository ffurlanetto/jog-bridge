import Foundation

setvbuf(stdout, nil, _IOLBF, 0)
let config = Config.parse(CommandLine.arguments)

let device: HerculesDevice
do {
    device = try HerculesDevice(config: config)
} catch {
    log("USB error: \(error)"); exit(1)
}

if config.listOnly {
    device.listDevices()
    exit(0)
}

// LED state and splitting of the received MIDI packets; only used from the CoreMIDI thread.
var leds = HerculesLEDs()
var ledParser = MIDIStreamParser()

let ports: VirtualMIDIPorts
do {
    ports = try VirtualMIDIPorts(name: config.portName) { bytes in
        if config.dump { log("MIDI → LEDs: \(hex(bytes))") }
        var changed = false
        ledParser.feed(bytes) { message in
            if leds.apply(message) { changed = true }
        }
        if changed { device.setLEDs(leds.blocks) }
    }
} catch {
    log("CoreMIDI error: \(error)"); exit(1)
}

log("Virtual MIDI ports “\(config.portName)” created.")

// Clean shutdown (releases the USB interface for the next open).
var signalSources: [DispatchSourceSignal] = []
for sig in [SIGINT, SIGTERM] {
    signal(sig, SIG_IGN)
    let src = DispatchSource.makeSignalSource(signal: sig, queue: .main)
    src.setEventHandler {
        log("Stopping.")
        device.close()
        exit(0)
    }
    src.resume()
    signalSources.append(src)
}

let reader = Thread {
    var decoder = HerculesFrameDecoder()
    device.run { data in
        guard data.count == HerculesFrameDecoder.frameLength else {
            if config.dump { log("USB: unexpected frame (\(data.count) bytes): \(hex(data))") }
            return
        }
        let output = decoder.decode(data)
        if config.dump, !output.changes.isEmpty {
            let changes = output.changes
                .map { String(format: "[%02d] %02X→%02X", $0.index, $0.old, $0.new) }
                .joined(separator: "  ")
            log("USB Δ: \(changes)")
            for message in output.messages { log("→ MIDI: \(hex(message))") }
        }
        for message in output.messages { ports.send(message) }
    }
}
reader.name = "hercules-usb-reader"
reader.qualityOfService = .userInteractive
reader.start()

dispatchMain()
