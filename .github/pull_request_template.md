## What

<!-- The change, in the reviewer's terms. One paragraph. -->

## Why

<!-- The problem or the need. Link the ADR, the issue or the discussion. -->

## How

<!-- Design choices a reviewer would not guess from the diff. Trade-offs taken. -->

## Testing

- [ ] `make check` green
- [ ] New behaviour covered by tests, nominal **and** error paths
- [ ] Tested with a real console — model / output of `jog-bridge --list` below — or not applicable
- <!-- What you tested by hand, if anything -->

```
(output of jog-bridge --list)
```

## Risk and rollout

- Area touched:
- Public MIDI contract changed (notes, CCs, LEDs, port identifiers): <!-- no / yes (detail, breaking change) -->
- Rollback:

## Checklist

- [ ] Plan approved before implementation (A1)
- [ ] No secret, token or internal hostname in the diff (A5)
- [ ] ADR added or updated if this is an architecture decision (A6)
- [ ] `docs/usb-protocol.md` / `docs/midi-mapping.md` updated if behaviour changes
- [ ] `CHANGELOG.md` updated if the change is user-visible
- [ ] Reference files (`Tests/jog-bridgeTests/Fixtures`) changed **deliberately**, never to "make a test pass"

## Review focus

<!-- One to three places where the reviewer's attention is worth the most. -->
