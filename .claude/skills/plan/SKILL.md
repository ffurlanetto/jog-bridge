---
name: plan
description: Generate a structured implementation plan and wait for explicit approval before any development. Use at the start of every non-trivial request, as required by rule A1.
argument-hint: [request to plan]
allowed-tools: Read, Glob, Grep, Bash(git status), Bash(git diff*), Bash(git log*)
---

Analyze the request below and produce a plan an implementer can execute **without
arbitrating anything**.

That is the bar. If a coding agent reading this plan would have to decide where a
type lives, what an error returns, or which of two designs to follow, the plan is
not finished — no matter how complete the step list looks.

**Absolute rules:**
- Every architectural question raised during analysis gets an answer *here*, with
  its reason. "Questions ouvertes" must end up empty
- Every file touched is named with its full path, and every public signature it
  gains or changes is written out
- Every step references the test scenarios (`T-n`) it must satisfy — the scenarios are designed here, before the code
- Do NOT write any code — plan only
- End with the approval line

**Adapt to the stack in Part B of AGENTS.md.** Commands are the `make` targets in B4.

---

```
## Plan: [Concise task title]

### Context
[Problem solved, value delivered, relationship to project components]

### Scope
- Files created    : [full paths]
- Files modified   : [full paths]
- Files deleted    : [list or "none"]
- Impacted components : [modules/services/packages]
- ADR required  : yes / no — [if yes: proposed title]

### Decisions taken
[Every question the analysis raised, answered. This is what stops an implementer
from doing architecture in passing.]

| # | Question | Decision | Why |
|---|----------|----------|-----|
| D1 | [where does X live / what does Y return / which of A or B] | [the answer] | [the reason, in one line] |

### Open questions
[Blocking ambiguities. **If this section is not empty, the plan is not approvable** —
resolve them before presenting it.]
- [question, or "none"]

### Contracts
[Per file, what the implementer writes. Signatures, not prose.]

**`path/to/file.ext`**
- `functionName(arg: Type, ...) -> ReturnType` — [what it guarantees]
- Raises / returns on error: [case → error type → status code → client message → log level]
- May depend on: [allowed imports]; must not depend on: [forbidden direction]

### Test scenarios
[Designed during the analysis, before any code. Cover nominal and error paths, and say whether each one touches the public MIDI contract.]

| ID | Given | When | Then | Level |
|----|-------|------|------|-------|
| T-1 | ... | ... | ... | unit |

### Implementation steps
[Each step names its files and the scenarios it makes pass.]

1. [Precise action] — `file(s)` — satisfies T-1, T-2
2. [...]

### Acceptance criteria
- [ ] Every `T-n` has a test that failed before the change
- [ ] [Measurable criterion]
- [ ] `make check` green — zero regressions
- [ ] Security checklist (A5) completed

### Risks & trade-offs
- [Identified risk → proposed mitigation]

### Documentation
- [ ] ADR created if architectural decision
- [ ] Documentation comments on public exports
- [ ] README / CHANGELOG updated if applicable

---
Self-check: [ ] an implementer could execute this without arbitrating anything
✅ Awaiting approval before implementation.
```

## Before you present it

Reread the plan as if you were the implementer. Wherever you would have to decide
something — where a type lives, what an error returns, which of two designs to follow —
the plan is unfinished: answer it in "Decisions taken".

Anything touching the public contract (MIDI notes and CCs, LED mapping, virtual port
identifiers, launchd label) is a breaking change for users' mappings: say so explicitly
and plan the non-regression fixtures that change with it (docs/testing.md).

---

Request to analyze: $ARGUMENTS
