# 0002. Userspace USB access with libusb

- Status: Accepted
- Date: 2026-10-21

## Context

The MP3 e2 exposes vendor-specific interfaces (class `0xFF`): macOS loads no generic driver and
the console does not show up as a MIDI device. Something has to open the device and read its
endpoints. The options are a kernel extension, a DriverKit extension, or a userspace library.

## Decision

We use **libusb** from an ordinary process: `libusb_claim_interface`, bulk and control
transfers. No administrator privilege is needed at runtime.

## Consequences

- Simple installation: no kernel extension, no DriverKit, no system approval other than allowing
  the item in the background.
- An old Hercules driver that takes over the interface prevents the bridge from claiming it
  ("Cannot claim interface" message).
- **No iPadOS port**: libusb relies on IOKit USB, which is not available on iOS/iPadOS. A port
  would go through a DriverKit extension (entitlement
  `com.apple.developer.driverkit.transport.usb`, granted by Apple, M-series iPad), or through a
  bridge on a Mac that relays the MIDI over the network.

## Alternatives considered

- **Kernel extension**: deprecated, heavy installation.
- **DriverKit**: entitlement to obtain from Apple, mandatory signing, far more work for a
  daemon that only needs to read one endpoint.
