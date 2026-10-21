# 0007. Frame decoding by difference

- Status: Accepted
- Date: 2026-10-21

## Context

The console does not send events but **38-byte state frames, continuously** (buttons as bits,
analog controls as bytes). DJ applications expect MIDI events (notes, CCs), and a stable
mapping through MIDI Learn.

## Decision

`HerculesFrameDecoder` compares each frame with the previous one and only produces messages for
the bytes that changed:

- button (byte `n`, bit `b`) → note `n × 8 + b`, channel 1, Note On velocity 127 on press and
  Note Off on release;
- analog control (byte `n`) → CC `n`, value = byte ÷ 2, only emitted when the 7-bit value
  changes;
- the first frame sets the initial state and emits nothing; the counter (byte 37) is ignored.

The LED table reuses the same note numbers so that echoing a button's state back on its note
lights its LED ([ADR 0005](0005-leds-via-control-transfers.md)).

## Consequences

- No mapping file to maintain: the numbers follow from the layout of the frame.
- The numbers are a **public contract**: users' mappings depend on them, including the shipped
  djay mapping. Changing them is a breaking change.
- Buttons without a LED are not named in the documentation; `--dump` lets you identify them.
- The frame is an observed layout, not a specification: another firmware or model (`--pid`) may
  have a different one.
