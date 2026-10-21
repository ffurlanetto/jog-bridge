import CLibUSB
import Foundation

func usbErrorName(_ rc: Int32) -> String {
    String(cString: libusb_error_name(rc))
}

enum TransferKind: String { case bulk, interrupt }

struct Endpoints {
    var inAddress: UInt8
    var inKind: TransferKind
}

/// USB access to the console through libusb, with automatic reconnection.
///
/// Inputs arrive on a bulk endpoint. The LEDs do not go through the interface 1 bulk
/// endpoints (their packet size is invalid and macOS does not create the pipes) but
/// through control transfers on endpoint 0.
final class HerculesDevice {
    private var ctx: OpaquePointer?
    private var handle: OpaquePointer?
    private var endpoints: Endpoints?
    private var ledBlocks = [UInt16](repeating: 0, count: HerculesLEDs.blockCount)
    private let lock = NSLock()
    private let config: Config

    // Console-specific (vendor) control requests.
    private let requestTypeIn: UInt8 = 0xC0
    private let requestTypeOut: UInt8 = 0x40
    private let ledRequestBase: UInt8 = 0x2D

    init(config: Config) throws {
        self.config = config
        let rc = libusb_init(&ctx)
        guard rc == 0 else { throw BridgeError.usb("libusb_init", rc) }
    }

    // MARK: - Connexion

    private func open() -> Bool {
        guard let h = libusb_open_device_with_vid_pid(ctx, config.vendorID, config.productID) else {
            return false
        }
        // No effect if no kernel driver holds the interface (the normal case).
        _ = libusb_set_auto_detach_kernel_driver(h, 1)

        let rc = libusb_claim_interface(h, config.interface)
        guard rc == 0 else {
            log("Cannot claim interface \(config.interface): \(usbErrorName(rc)). "
                + "Is an old Hercules driver still installed?")
            libusb_close(h)
            return false
        }
        guard let eps = resolveEndpoints(h) else {
            log("No input endpoint found on interface \(config.interface) — try --list.")
            libusb_release_interface(h, config.interface)
            libusb_close(h)
            return false
        }

        initialize(h)

        lock.lock(); handle = h; endpoints = eps; lock.unlock()
        log(String(format: "Console connected — input 0x%02X (%@)", eps.inAddress, eps.inKind.rawValue))
        sendLEDs() // restores the LED state after a reconnection
        return true
    }

    /// Console initialisation sequence (from https://github.com/foomatic/djcontrol).
    private func initialize(_ h: OpaquePointer) {
        var reply = [UInt8](repeating: 0, count: 2)
        func query(_ request: UInt8, _ value: UInt16) {
            _ = libusb_control_transfer(h, requestTypeIn, request, value, 0, &reply, 2, 500)
        }

        query(0x2C, 0x0000)
        for value: UInt16 in [0x0300, 0x0400, 0x0500, 0x0600] { query(0x29, value) }
        query(0x2C, 0x0000)
        query(0x2C, 0x0000)
        for value: UInt16 in [0x0300, 0x0400, 0x0500, 0x0600, 0x0200] { query(0x29, value) }
        // CLEAR_FEATURE(ENDPOINT_HALT) on endpoint 0x82, then the final command.
        _ = libusb_control_transfer(h, 0x02, 0x01, 0, 0x82, nil, 0, 500)
        _ = libusb_control_transfer(h, requestTypeOut, 0x27, 0, 0, nil, 0, 500)
    }

    func close() {
        lock.lock(); defer { lock.unlock() }
        guard let h = handle else { return }
        libusb_release_interface(h, config.interface)
        libusb_close(h)
        handle = nil
        endpoints = nil
    }

    private func resolveEndpoints(_ h: OpaquePointer) -> Endpoints? {
        var found = Endpoints(inAddress: 0, inKind: .bulk)
        var haveIn = false

        var desc: UnsafeMutablePointer<libusb_config_descriptor>?
        if libusb_get_active_config_descriptor(libusb_get_device(h), &desc) == 0, let cfg = desc {
            defer { libusb_free_config_descriptor(cfg) }
            for i in 0..<Int(cfg.pointee.bNumInterfaces) {
                let iface = cfg.pointee.interface[i]
                for a in 0..<Int(iface.num_altsetting) {
                    let alt = iface.altsetting[a]
                    guard Int32(alt.bInterfaceNumber) == config.interface else { continue }
                    for e in 0..<Int(alt.bNumEndpoints) {
                        let ep = alt.endpoint[e]
                        let kind: TransferKind
                        switch ep.bmAttributes & 0x03 {
                        case 2: kind = .bulk
                        case 3: kind = .interrupt
                        default: continue
                        }
                        if ep.bEndpointAddress & 0x80 != 0, !haveIn {
                            found.inAddress = ep.bEndpointAddress; found.inKind = kind; haveIn = true
                        }
                    }
                }
            }
        }

        // --in takes precedence over detection.
        if let forcedIn = config.endpointIn { found.inAddress = forcedIn; haveIn = true }
        return haveIn ? found : nil
    }

    // MARK: - Transferts

    private func transfer(_ h: OpaquePointer, _ ep: UInt8, _ kind: TransferKind,
                          _ data: UnsafeMutablePointer<UInt8>, _ length: Int32,
                          _ transferred: inout Int32, timeout: UInt32) -> Int32 {
        switch kind {
        case .bulk: return libusb_bulk_transfer(h, ep, data, length, &transferred, timeout)
        case .interrupt: return libusb_interrupt_transfer(h, ep, data, length, &transferred, timeout)
        }
    }

    /// Blocking read loop (to be run on a dedicated thread).
    func run(onData: ([UInt8]) -> Void) -> Never {
        var buffer = [UInt8](repeating: 0, count: 512)
        var waitingLogged = false

        while true {
            if handle == nil {
                if open() {
                    waitingLogged = false
                } else {
                    if !waitingLogged { log("Waiting for the console…"); waitingLogged = true }
                    Thread.sleep(forTimeInterval: 2)
                    continue
                }
            }
            guard let h = handle, let eps = endpoints else { continue }

            var n: Int32 = 0
            let rc = buffer.withUnsafeMutableBufferPointer { p in
                transfer(h, eps.inAddress, eps.inKind, p.baseAddress!, Int32(p.count), &n, timeout: 200)
            }

            if rc == 0 || rc == LIBUSB_ERROR_TIMEOUT.rawValue {
                if n > 0 { onData(Array(buffer[0..<Int(n)])) }
                continue
            }
            if rc == LIBUSB_ERROR_OVERFLOW.rawValue || rc == LIBUSB_ERROR_INTERRUPTED.rawValue {
                log("USB read: \(usbErrorName(rc)) (ignored)")
                continue
            }
            log("Console disconnected (\(usbErrorName(rc)))")
            close()
        }
    }

    /// Remembers the LED state and sends it to the console if it is connected.
    /// Called from the CoreMIDI thread.
    func setLEDs(_ blocks: [UInt16]) {
        lock.lock(); defer { lock.unlock() }
        ledBlocks = blocks
        sendLEDsLocked()
    }

    private func sendLEDs() {
        lock.lock(); defer { lock.unlock() }
        sendLEDsLocked()
    }

    /// Sends the 5 LED blocks; the lock must be held.
    private func sendLEDsLocked() {
        guard let h = handle else { return }
        for (index, value) in ledBlocks.enumerated() {
            let rc = libusb_control_transfer(h, requestTypeOut, ledRequestBase + UInt8(index),
                                             value, 0, nil, 0, 100)
            if rc < 0 {
                log("LED write: \(usbErrorName(rc))")
                return
            }
        }
    }

    // MARK: - Diagnostic

    /// Lists the vendor's devices (by VID) and their endpoints.
    func listDevices() {
        var list: UnsafeMutablePointer<OpaquePointer?>?
        let count = libusb_get_device_list(ctx, &list)
        guard count >= 0, let devices = list else {
            print("libusb_get_device_list: \(usbErrorName(Int32(count)))"); return
        }
        defer { libusb_free_device_list(devices, 1) }

        var any = false
        for i in 0..<count {
            guard let dev = devices[i] else { continue }
            var d = libusb_device_descriptor()
            guard libusb_get_device_descriptor(dev, &d) == 0, d.idVendor == config.vendorID else { continue }
            any = true
            print(String(format: "Device %04X:%04X (bus %d, address %d)",
                         d.idVendor, d.idProduct, libusb_get_bus_number(dev), libusb_get_device_address(dev)))

            var desc: UnsafeMutablePointer<libusb_config_descriptor>?
            guard libusb_get_active_config_descriptor(dev, &desc) == 0, let cfg = desc else {
                print("  (unreadable configuration descriptor)"); continue
            }
            defer { libusb_free_config_descriptor(cfg) }
            for f in 0..<Int(cfg.pointee.bNumInterfaces) {
                let iface = cfg.pointee.interface[f]
                for a in 0..<Int(iface.num_altsetting) {
                    let alt = iface.altsetting[a]
                    print(String(format: "  Interface %d alt %d — class 0x%02X", alt.bInterfaceNumber,
                                 alt.bAlternateSetting, alt.bInterfaceClass))
                    for e in 0..<Int(alt.bNumEndpoints) {
                        let ep = alt.endpoint[e]
                        let type = ["control", "isochronous", "bulk", "interrupt"][Int(ep.bmAttributes & 3)]
                        let dir = ep.bEndpointAddress & 0x80 != 0 ? "IN " : "OUT"
                        print(String(format: "    Endpoint 0x%02X %@ %@ (max %d bytes)",
                                     ep.bEndpointAddress, dir, type, ep.wMaxPacketSize))
                    }
                }
            }
        }
        if !any { print(String(format: "No device with VID %04X is plugged in.", config.vendorID)) }
    }
}
