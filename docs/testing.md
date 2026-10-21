# Tests

```sh
swift test
```

No hardware is needed. The suite uses Swift Testing. Two test targets, one per executable, each
importing it with `@testable import`: `jog-bridgeTests` (the daemon, `jog_bridge`) and
`jog-bridge-panelTests` (the status panel, `jog_bridge_panel`).

## Organisation

| Type | Files | What is checked |
|---|---|---|
| Unit | `FrameDecoderTests`, `LEDsTests`, `MIDIStreamParserTests`, `ConfigTests` | Frame decoding (48 buttons, 13 analog controls, informational bytes, counter), LED table (one bit per LED, no sharing), MIDI splitting (running status, SysEx, real-time), CLI options |
| Integration | `CoreMIDIIntegrationTests` | Real virtual CoreMIDI ports: daemon → application, application → daemon, whole LED chain, recorded frames → MIDI received by a client, fixed identifiers and "Hercules" manufacturer; libusb link with no hardware |
| Non-regression | `GoldenReplayTests`, `ContractTests`, `DjayMappingTests` | Reference sessions replayed, documented note numbers, consistency of the djay mapping with what the daemon emits |

### Status panel (`jog-bridge-panelTests`)

| Type | Files | What is checked |
|---|---|---|
| Unit | `LaunchdParsingTests`, `LogAnalysisTests`, `StatusEvaluationTests`, `DiagnosticsTests`, `ActionsTests` | Parsing `launchctl print`, reading the daemon's log (latest run wins; a claim failure is not hidden by the "Waiting" line after it), the level for every combination of service × permission × MIDI × USB × log (exhaustive: "OK" only when everything is fine), the diagnostics report, the `launchctl` commands the actions issue (recorded, never executed) |
| Integration | `ProbesIntegrationTests` | The CoreMIDI probe sees a virtual source by name, the USB probe reports absence, the process runner, the log tail |
| Contract | `DaemonContractTests` | Every log line the panel relies on still exists in the daemon's sources; the port name, USB IDs and agent label agree with the daemon and the plist |

The SwiftUI view itself is not tested automatically: check it by hand (`make panel`, or the
installed app).

## What is not tested

- **Real USB**: reading the endpoint, the initialisation sequence, the LED control transfers.
  This needs the console; check it by hand (`jog-bridge --dump`).
- **The `.pkg` and the LaunchAgent**: CI builds the package and checks its contents, but
  `postinstall` is not executed (it writes into the user's folder and calls `launchctl`).
- **Options that exit the process** (`--help`, unknown option): `Config.parse` calls `exit`.
- **The panel's window and its buttons** (the real `launchctl bootstrap`, System Settings opening).

## CoreMIDI integration tests

- Each test creates ports with a **unique name** (`jog-bridge-test-xxxxxxxx`): they do not
  interfere with a jog-bridge agent installed on the machine.
- The fixed-identifier test (`HER1`, `HER2`) is skipped if an agent already holds them.
- If CoreMIDI is not usable (a runner with no MIDI server), the integration suite is
  **disabled** instead of failing (`CoreMIDIProbe`).
- CoreMIDI **groups** messages with the same timestamp into one packet; the tests split them
  again with `MIDIStreamParser`, the way an application would.
- Connecting an input port is asynchronous: the tests first send a probe (Active Sensing, `FE`)
  until it is received, then exclude it from the comparisons.

## Reference files (non-regression)

`Tests/jog-bridgeTests/Fixtures/`:

| File | Content |
|---|---|
| `frame-session.json` | A series of 38-byte frames and the MIDI messages expected for each |
| `led-sequence.json` | MIDI messages applied to the LEDs, with the "changed" flag and the 5 expected blocks |

The expected values are **written by hand** from [midi-mapping.md](midi-mapping.md) and
[usb-protocol.md](usb-protocol.md), not produced by running the code: they act as an
independent contract.

**A failure of these tests means the MIDI contract has changed** (notes, CCs, LEDs, message
order). Users' mappings depend on it, including the shipped djay file. Do not update the
expected values to "make the test pass": if the change is intended, update the reference file,
`midi-mapping.md`, the `CHANGELOG` (breaking change) and, if needed, an ADR.

### Adding a case

1. Add a step to the JSON: `frame` (38 bytes in hexadecimal) and `expected` (the MIDI messages
   expected for that frame), or `midi` / `changed` / `blocks` for the LEDs.
2. Work out the expected value by hand, from the specification.
3. `swift test`.

## Checking that the tests really protect

A quick way: break the code on purpose, watch the failure, then undo.

```sh
sed -i '' 's/UInt8(i), frame\[i\] >> 1\]/UInt8(i), frame[i]]/' Sources/jog-bridge/FrameDecoder.swift
swift test          # must fail
git checkout -- Sources/jog-bridge/FrameDecoder.swift
```

## Adding a unit test

The daemon's types are `internal`: use `@testable import jog_bridge`. Inside `#expect`, do not
call a mutating method directly (`#expect(leds.apply(…))` does not compile): store the result
in a local variable first. For parameterised tests, use a struct rather than a named tuple as
the argument.
