# Architecture

`jog-bridge` is a single executable. It bridges the console's proprietary USB protocol and CoreMIDI.

```
                 ┌──────────────────────── jog-bridge ─────────────────────────────┐
                 │                                                                  │
 Console  ──USB──►  HerculesDevice ──38-byte frame──► HerculesFrameDecoder ──MIDI──►  VirtualMIDIPorts ──► DJ app
 (06F8:B105)     │  (libusb, thread       │                                         │   (virtual source)
                 │   hercules-usb-reader) │                                         │
                 │                        ◄── setLEDs ◄── HerculesLEDs ◄── MIDIStreamParser ◄── (virtual destination) ◄── DJ app
                 └──────────────────────────────────────────────────────────────────┘
```

## Components

| Component | File | Responsibility |
|---|---|---|
| Wiring | `main.swift` | Reads the config, creates the device and the ports, installs SIGINT/SIGTERM handling, starts the reader thread, then `dispatchMain()`. |
| Configuration | `Config.swift` | CLI options, errors (`BridgeError`), `log()` on stderr, `hex()`. |
| USB device | `HerculesDevice.swift` | Opens the console (VID/PID), claims the interface, detects the IN endpoint, plays the initialisation sequence, reads in a loop, reconnects, sends the LEDs. |
| Frame decoder | `FrameDecoder.swift` | Compares each 38-byte frame with the previous one and only emits what changed, as notes and CCs. |
| LEDs | `LEDs.swift` | Translates a MIDI note (channel 1 or 2) into a bit in 5 blocks of 16 bits. |
| MIDI parser | `MIDIStreamParser.swift` | Rebuilds complete MIDI messages from the bytes received from the application (running status, SysEx, real-time). |
| MIDI ports | `VirtualMIDIPorts.swift` | Creates a virtual CoreMIDI source and destination with fixed identifiers. |
| LaunchAgent | `local.jog-bridge.plist` | Starts and keeps the process alive in the user session; tied to the app bundle for its name and icon. |

## Console → application flow

1. `HerculesDevice.run` reads the IN endpoint in a loop (200 ms timeout).
2. Each 38-byte transfer is passed to `HerculesFrameDecoder.decode`. The first frame sets the
   initial state and emits nothing. The following ones produce notes (buttons) and CCs
   (analog controls) for the bytes that changed.
3. `VirtualMIDIPorts.send` publishes each message with `MIDIReceived` on the virtual source.

## Application → console flow (LEDs)

1. The application writes to the virtual destination; CoreMIDI calls the
   `MIDIDestinationCreateWithBlock` block on its own thread.
2. `MIDIStreamParser` splits the bytes into messages; `HerculesLEDs.apply` updates the blocks
   if the note matches a LED.
3. If a block changed, `HerculesDevice.setLEDs` sends the 5 blocks as control transfers
   ([protocol](usb-protocol.md)). After a reconnection, the remembered state is sent again.

## Concurrency

| Context | Role | State touched |
|---|---|---|
| Main thread (`dispatchMain`) | SIGINT/SIGTERM signals: closes USB, then `exit(0)`. | — |
| `hercules-usb-reader` | USB read loop, decoder, MIDI output. | `decoder` (local to the thread) |
| CoreMIDI thread | Receiving messages from the application. | `leds`, `ledParser` (globals in `main.swift`, only here) |

`HerculesDevice` protects `handle`, `endpoints` and `ledBlocks` with an `NSLock`: the USB thread
opens and closes the connection while the CoreMIDI thread writes the LEDs.

## Lifecycle and reconnection

`HerculesDevice.init` only initialises libusb: the console being absent is not an error. The
`run` loop retries `open()` every 2 s ("Waiting for the console…") and goes back to waiting if a
read fails ("Console disconnected"). The process therefore stays alive without the console;
the LaunchAgent's `KeepAlive` only matters after a crash.

Only two errors are fatal at startup (`exit(1)`): `libusb_init` failing, and the CoreMIDI ports
failing to be created.

## Distribution

`scripts/build-pkg.sh` builds in release, assembles the app bundle
`/Applications/Jog Bridge.app` (binary, `Info.plist`, `AppIcon.icns`,
ad-hoc signature) and calls `pkgbuild` with `scripts/pkg/postinstall`. That script copies the plist
into the logged-in user's `LaunchAgents` folder (found through `/dev/console`), registers the app
with Launch Services and loads the agent. The plist runs the bundle's executable and names the
bundle in `AssociatedBundleIdentifiers`, so System Settings shows the app's name and icon. See
[ADR 0006](adr/0006-launchagent-and-unsigned-pkg.md) and
[ADR 0011](adr/0011-app-bundle-for-the-launch-agent.md).
