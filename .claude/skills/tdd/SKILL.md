---
name: tdd
description: Drive an implementation test-first through the red-green-refactor loop. Use when adding or changing behavior in code that has, or should have, tests.
argument-hint: [behavior to implement]
allowed-tools: Read, Glob, Grep, Write, Edit, Bash(make test*), Bash(make lint), Bash(make typecheck)
---

Implement the requested behavior **test-first**. One cycle per behavior — never batch.

**Absolute rules:**
- No production line is written before a failing test exists
- A test that has never failed proves nothing — always observe the red
- Refactor only on green, and only with the test unchanged

---

## Cycle

### 🔴 RED — write the failing test
0. Name the scenario you are covering: `T-n` from the plan. No scenario id means
   the behaviour was never agreed — go back to `/plan` rather than inventing it here.
1. Name the test after the behaviour (A4) — Swift Testing: `@Test func buttonPressThenReleaseProducesNoteOnThenNoteOff()`
2. Assert the observable behavior, never the implementation
3. Run `make test` and **show the failure output**
4. Verify it fails for the right reason — not an import or syntax error

### 🟢 GREEN — minimum code to pass
5. Write the simplest code that passes, even if naive
6. Run `make test` and show it green
7. No extra feature, no anticipation of the next test

### 🔵 REFACTOR — clean up on green
8. Remove duplication, clarify names, extract where it helps
9. Re-run `make test` after every step — always green
10. `make lint` and `make typecheck` clean before moving on

### Repeat
Next behavior → back to 🔴. Stop when the acceptance criteria are covered.

---

## Closure checklist
- [ ] Every `T-n` in scope has a test, and each one was seen red first
- [ ] Each behavior has its own test, red first
- [ ] Nominal AND error paths covered
- [ ] No conditional logic inside tests
- [ ] Mocks limited to system boundaries (I/O, network, time)
- [ ] `make check` green

---

Behavior to implement: $ARGUMENTS
