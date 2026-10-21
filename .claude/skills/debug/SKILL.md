---
name: debug
description: Systematic debugging workflow — reproduce, isolate, hypothesize, fix minimally, verify. Use for any bug, failing test, or unexplained behavior rather than guessing at a fix.
argument-hint: [problem to debug]
allowed-tools: Read, Glob, Grep, Write, Edit, Bash(make test*), Bash(git log*), Bash(git diff*), Bash(git bisect*)
---

Apply a structured debugging process to the problem described.

**Absolute rules:**
- Write a test that reproduces the bug BEFORE proposing a fix
- Do not refactor at the same time as fixing
- The fix must be minimal — one root cause at a time
- Validate that the full test suite passes after the fix

---

## Step 1 — Reproduce

```
Environment  : [macOS version, chip, console model, installed agent or `swift run`]
Reproducible : [always | sometimes — estimated frequency]
First seen   : [date / commit if known]
Observed     : [actual behavior]
Expected     : [expected behavior]
Evidence     : [`jog-bridge --dump` output, /tmp/jog-bridge.log, launchctl print]
```

## Step 2 — Isolate

- Which module / layer is involved?
- What was the last known change in this area (`git log -S<symbol>`)?
- Do logs / traces confirm the location?
- Does an existing test cover this path?

## Step 3 — Hypotheses

At most 3 root-cause hypotheses, in descending probability order:

```
Hypothesis 1: [description] — probability: [high | medium | low]
  → How to validate: [command / test / inspection]
```

## Step 4 — Regression test (before the fix)

Write a test that reproduces the bug deterministically, fails with the current
code, and will pass after the correct fix.
Name it after the behaviour that was broken. A USB-level bug that cannot be reproduced
without the console is reproduced at the decoder level with a recorded frame (Fixtures/).

## Step 5 — Minimal fix

Single change, single root cause. No adjacent refactoring (open a separate issue).
Document the WHY in the commit if non-obvious.

## Step 6 — Validation

```bash
make test        # targeted first, then the full suite
make check       # zero regressions, zero warnings
```

### Closure criteria
- [ ] Regression test written and green
- [ ] Full suite: zero regressions
- [ ] Root cause documented in the commit or a comment if non-obvious
- [ ] Refactoring issue created if cleanup was identified but deferred

---

Problem to analyze: $ARGUMENTS
