---
name: review
description: Quality, security and contract review of the code changed in this session or branch. Use before opening a pull request or committing a significant change.
argument-hint: [optional scope or branch]
allowed-tools: Read, Glob, Grep, Bash(git diff*), Bash(git log*), Bash(git status), Bash(make lint), Bash(make typecheck)
---

Perform a complete review of the code modified in this session.
Adapt verifications to the language and stack defined in Part B of AGENTS.md.

**Steps:**
1. Identify the modified files (`git diff --stat` against the base branch)
2. Apply every grid below
3. Produce the structured report

---

## Grid — Architecture & Design
- [ ] Separation of concerns respected (decoding / LEDs / USB / CoreMIDI stay in their own types; `main.swift` only wires)
- [ ] Explicit interfaces / contracts between components
- [ ] No tight coupling introduced between distinct modules
- [ ] Project naming conventions respected (B3)
- [ ] No logic duplication (DRY)
- [ ] Reasonable cyclomatic complexity, one abstraction level per function

## Grid — Tests
- [ ] **Every `T-n` in the plan has a test — an uncovered scenario is blocking**
- [ ] No test was weakened or skipped to get the suite green
- [ ] Every new public function / method has at least one test
- [ ] Nominal cases AND error cases covered
- [ ] Test names describe the behaviour (Swift Testing: `@Test func buttonPressThenReleaseProducesNoteOnThenNoteOff()`)
- [ ] No conditional logic inside tests
- [ ] No mock of the types under test; real CoreMIDI / libusb contexts used for integration (docs/testing.md)
- [ ] Tests are deterministic (no dependency on external state)

## Grid — Code quality
- [ ] No silently swallowed error
- [ ] Errors wrapped with explicit context
- [ ] Logging goes through `log(_:)` on stderr — no stray `print` in the daemon (`print` is only for `--list` / `--help`)
- [ ] Documentation comments on public exports
- [ ] TODO only with ticket reference
- [ ] No dead or commented-out code

## Grid — Security (A5)
- [ ] No hardcoded secret
- [ ] External input (USB frames, MIDI bytes, CLI args) validated before use
- [ ] Error messages free of sensitive data
- [ ] Scripts that run as root (`postinstall`) touch only what they must
- [ ] No sensitive data in logs
- [ ] No critical CVE in new dependencies

## Grid — Public contract (ADR 0007, docs/midi-mapping.md)
- [ ] Note numbers (`byte × 8 + bit`) and CC numbers unchanged — or the change is declared as breaking
- [ ] Virtual port unique IDs and names unchanged
- [ ] LED table: still one bit per LED, no two LEDs share a bit
- [ ] Non-regression fixtures and `ContractTests` untouched, or updated *deliberately* with CHANGELOG + midi-mapping.md
- [ ] `Hercules MP3 e2.djayMidiMapping` still consistent with what the daemon emits

## Grid — Concurrency & hardware
- [ ] `handle`, `endpoints`, `ledBlocks` only touched under the `NSLock`
- [ ] `leds` / `ledParser` only used from the CoreMIDI thread
- [ ] USB errors never crash the reader loop: disconnect → reconnect path intact
- [ ] Frames of unexpected length are ignored, not trusted
- [ ] No blocking call added on the CoreMIDI callback thread

## Grid — Packaging & launchd
- [ ] `postinstall` never fails the installation because of `launchctl` (ADR 0006)
- [ ] Paths quoted (usernames and homes may contain spaces)
- [ ] Label / paths renamed consistently everywhere (`local.jog-bridge`)
- [ ] App bundle: bundle identifier identical in `build-pkg.sh` and the plist's `AssociatedBundleIdentifiers`; plist program path points inside the bundle (ADR 0011)
- [ ] libusb still statically linked (`make audit`)

## Grid — Documentation
- [ ] docs/usb-protocol.md and docs/midi-mapping.md match the behaviour
- [ ] ADR added for a structural decision (A6) · CHANGELOG updated for user-visible changes
- [ ] No Hercules logo, image or product photo added (ADR 0008)

---

## Report format

```
## Code Review — [date]

### Files analyzed
- [list]

### Overall score
🟢 PASS | 🟡 ATTENTION (points to address) | 🔴 BLOCKING (must fix before merge)

### Blocking issues
- [description + file:line + suggested fix]

### Attention points
- [description + file:line + recommended improvement]

### Positive notes
- [good practice observed]

### Required actions before merge
- [ ] [Action 1]
```

$ARGUMENTS
