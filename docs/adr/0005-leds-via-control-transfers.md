# 0005. LEDs driven by control transfers

- Status: Accepted
- Date: 2026-10-21

## Context

Interface 1 of the console declares a bulk OUT endpoint (`0x03`, 12 bytes), which looks like
the natural channel for the LEDs. In practice, the declared packet size is invalid and macOS
does not create the corresponding pipes: no transfer is possible that way.

## Decision

The LEDs are driven by **control transfers on endpoint 0**: five requests
`bmRequestType 0x40`, `bRequest 0x2D + n`, `wValue` = 16-bit block. The full state of the 5
blocks is sent again on every change and after every reconnection. See
[usb-protocol.md](../usb-protocol.md).

## Consequences

- No OUT endpoint to configure: the `--out` option does not exist.
- The LED state is remembered on the daemon side, so it is restored after an unplug.
- Each change costs five control transfers (100 ms timeout each); acceptable for LEDs, to be
  watched if fast animation is added.
- The protocol comes from djcontrol's reverse engineering: another firmware might behave
  differently.
