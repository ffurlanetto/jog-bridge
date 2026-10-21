# USB protocol of the Hercules DJ Control MP3 e2

Established by reverse engineering; the initialisation sequence and the LED table come from
[foomatic/djcontrol](https://github.com/foomatic/djcontrol). This document describes what the
code in this repository actually does.

## Identification

| Field | Value |
|---|---|
| Vendor ID | `0x06F8` (Hercules) |
| Product ID | `0xB105` (DJ Control MP3 e2) |
| Interface class | `0xFF` (vendor specific): no generic macOS driver |

Sample output of `jog-bridge --list`:

```
Device 06F8:B105 (bus 0, address 3)
  Interface 0 alt 0 — class 0xFF
    Endpoint 0x81 IN  bulk (max 64 bytes)
  Interface 1 alt 0 — class 0xFF
    Endpoint 0x82 IN  bulk (max 12 bytes)
    Endpoint 0x03 OUT bulk (max 12 bytes)
```

The code claims **interface 0** by default and reads its IN endpoint (`0x81`). Interface 1 is
described with invalid packet sizes and macOS does not create its pipes; it is not used for data.

## Initialisation

After `libusb_claim_interface`, the console receives this sequence (`HerculesDevice.initialize`),
whose replies are ignored:

1. IN control requests (`bmRequestType 0xC0`, 2 bytes): `0x2C` / `wValue 0`, then `0x29` with
   `wValue` = `0x0300`, `0x0400`, `0x0500`, `0x0600`.
2. `0x2C` twice, then `0x29` with `0x0300`, `0x0400`, `0x0500`, `0x0600`, `0x0200`.
3. `CLEAR_FEATURE(ENDPOINT_HALT)` on endpoint `0x82`.
4. OUT control request (`bmRequestType 0x40`) `0x27`, with no data.

Each transfer has a 500 ms timeout. The exact role of each request is not documented; the
sequence is taken as is from djcontrol.

## Input frames

The console continuously sends **38-byte** frames on the IN endpoint. Any frame of another
length is ignored (and logged with `--dump`).

| Bytes | Content |
|---|---|
| 0…5 | Buttons, one bit per button (1 = pressed) |
| 6…18 | Knobs, faders and encoders, 8-bit value |
| 20, 36 | State mirrors tied to byte 3 (informational, not converted to MIDI) |
| 37 | Sequence counter (ignored) |

Bytes 19 and 21…35 are not interpreted. The decoding into MIDI is described in
[midi-mapping.md](midi-mapping.md).

## LEDs

The LEDs are driven by **control transfers on endpoint 0**, not through the bulk endpoints.
The console has 5 blocks of 16 bits:

| Item | Value |
|---|---|
| `bmRequestType` | `0x40` (OUT, vendor, device) |
| `bRequest` | `0x2D + n`, with `n` = block index (0…4) |
| `wValue` | the 16-bit block |
| Data | none |
| Timeout | 100 ms |

Blocks 0 to 2 hold the **steady** LEDs, blocks 2 to 4 the **blinking** LEDs. Block 2 holds both:
bits 0…6 blinking, bits 8…15 steady. On every change, all 5 blocks are sent again; they are
also sent after a reconnection. The button → block/bit mapping is in
`Sources/jog-bridge/LEDs.swift`.

## Disconnection

A read error other than timeout, overflow or interruption is treated as a disconnection: the
interface is released and the loop tries to open the console again every 2 s.
