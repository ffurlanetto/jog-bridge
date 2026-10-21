# MIDI and LED mapping

Everything is on **MIDI channel 1** in the console → application direction. The numbers are
determined by the position in the 38-byte USB frame ([protocol](usb-protocol.md)); they are
therefore stable and do not depend on a configuration file.

## Console → application

| Source | Message |
|---|---|
| Button (byte `n`, bit `b`, with `n` from 0 to 5) | Note `n × 8 + b`: Note On velocity 127 on press, Note Off velocity 0 on release |
| Analog control (byte `n`, with `n` from 6 to 18) | CC number `n`, value = byte ÷ 2 (0…127) |

A CC is only emitted when the 7-bit value changes. The first frame received after a connection
sets the initial state and emits nothing.

CC 6 to 18 correspond to the 13 analog controls; to find out which is which, run
`jog-bridge --dump` and move them one at a time.

### Known buttons

Buttons that have a LED have a name (from the djcontrol table):

| Note | Button | Note | Button | Note | Button |
|---|---|---|---|---|---|
| 8 | Listen A | 16 | Listen B | 32 | Magic |
| 9 | CUE A | 17 | CUE B | 36 | Vinyl |
| 10 | Play A | 18 | Play B | 13 | Folders |
| 1 | Pitch Bend − A | 25 | Pitch Bend − B | 14 | Files |
| 2 | Pitch Bend + A | 26 | Pitch Bend + B | | |
| 37 | Sync A | 35 | Sync B | | |
| 39 | Pitch Reset A | 33 | Pitch Reset B | | |
| 38, 4, 5, 6 | N1 to N4 A | 34, 20, 21, 22 | N1 to N4 B | | |
| 40, 41, 42, 43 | N5 to N8 A | 44, 45, 46, 47 | N5 to N8 B | | |

The other bits of bytes 0 to 5 (buttons without a LED, such as the navigation keys) do emit
notes, but are not named here: use `--dump`.

## Application → console (LEDs)

A LED uses **the same note number** as its button. An application that echoes a button's
state back on the same note therefore lights the right LED.

| Channel | Effect |
|---|---|
| 1 | **Steady** LED: Note On velocity > 0 = lit; Note Off or velocity 0 = unlit |
| 2 | **Blinking** LED: same principle |

Other channels, other message types and notes without a LED are ignored.

## Virtual ports

| Port | Direction | Unique identifier |
|---|---|---|
| "Hercules MP3 e2" (source) | console → application | `0x48455231` ("HER1") |
| "Hercules MP3 e2" (destination) | application → console | `0x48455232` ("HER2") |

The name can be changed with `--name`. The identifiers are fixed so that the DJ application
finds its mapping again from one session to the next.

## djay mapping

[`Hercules MP3 e2.djayMidiMapping`](../Hercules%20MP3%20e2.djayMidiMapping) binds these notes
and CCs to djay's commands. It uses the same numbers as above (for example
`turntable1.playPause` ↔ note 10, i.e. Play A).
