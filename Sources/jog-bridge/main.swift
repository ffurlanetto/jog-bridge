import Foundation

setvbuf(stdout, nil, _IOLBF, 0)
let config = Config.parse(CommandLine.arguments)

let device: HerculesDevice
do {
    device = try HerculesDevice(config: config)
} catch {
    log("Erreur USB : \(error)"); exit(1)
}

if config.listOnly {
    device.listDevices()
    exit(0)
}

// État des LEDs et découpage des paquets MIDI reçus ; utilisés uniquement depuis le thread CoreMIDI.
var leds = HerculesLEDs()
var ledParser = MIDIStreamParser()

let ports: VirtualMIDIPorts
do {
    ports = try VirtualMIDIPorts(name: config.portName) { bytes in
        if config.dump { log("MIDI → LEDs : \(hex(bytes))") }
        var changed = false
        ledParser.feed(bytes) { message in
            if leds.apply(message) { changed = true }
        }
        if changed { device.setLEDs(leds.blocks) }
    }
} catch {
    log("Erreur CoreMIDI : \(error)"); exit(1)
}

log("Ports MIDI virtuels « \(config.portName) » créés.")

// Arrêt propre (libère l'interface USB pour la prochaine ouverture).
var signalSources: [DispatchSourceSignal] = []
for sig in [SIGINT, SIGTERM] {
    signal(sig, SIG_IGN)
    let src = DispatchSource.makeSignalSource(signal: sig, queue: .main)
    src.setEventHandler {
        log("Arrêt.")
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
            if config.dump { log("USB : trame inattendue (\(data.count) octets) : \(hex(data))") }
            return
        }
        let output = decoder.decode(data)
        if config.dump, !output.changes.isEmpty {
            let changes = output.changes
                .map { String(format: "[%02d] %02X→%02X", $0.index, $0.old, $0.new) }
                .joined(separator: "  ")
            log("USB Δ : \(changes)")
            for message in output.messages { log("→ MIDI : \(hex(message))") }
        }
        for message in output.messages { ports.send(message) }
    }
}
reader.name = "hercules-usb-reader"
reader.qualityOfService = .userInteractive
reader.start()

dispatchMain()
