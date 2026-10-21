# 0003. Virtual CoreMIDI ports with fixed identifiers

- Status: Accepted
- Date: 2026-10-21

## Context

DJ software (djay, rekordbox, Serato…) does not speak proprietary USB: it expects a MIDI device.
A return path is also needed for the LEDs, and a user's mapping must survive a restart.

## Decision

The daemon creates, with CoreMIDI, a **virtual source** (console → application) and a
**virtual destination** (application → console), both named "Hercules MP3 e2" (changeable with
`--name`). Their unique identifiers are fixed: `0x48455231` ("HER1") and `0x48455232`
("HER2"). The manufacturer is "Hercules".

## Consequences

- Works with any macOS MIDI application, with no specific configuration.
- Applications find their mapping and their device selection again.
- The ports only exist while the daemon is running.
- Changing these identifiers breaks existing mappings: only do it in a major version, with a
  migration note.
