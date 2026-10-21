---
name: prime
description: Load the essential project context at the start of a session — architecture, commands, current branch state, open decisions. Use as the first action of a new session before planning or coding.
allowed-tools: Read, Glob, Grep, Bash(git status), Bash(git log*), Bash(git branch*), Bash(ls*)
---

Build a compact working picture of this project, then state it back in under 20 lines.

**Rule: read selectively.** Do not dump whole directories into context — the point
is to spend the smallest amount of context for the largest amount of orientation.

## Step 1 — Standing instructions
Read `AGENTS.md`, focusing on Part B (identity, stack, commands, architecture, constraints).

## Step 2 — Repository shape
```bash
git branch --show-current
git status --short
git log --oneline -10
```
Then list the top-level source directories only — do not recurse into every file.

## Step 3 — Open decisions
- `docs/adr/README.md` — the decisions already taken, and any `Proposed` ADR
- `CHANGELOG.md` — what is unreleased

## Step 4 — Report

```
## Context loaded

Project     : [name] — [one-line description]
Stack       : [from B2]
Commands    : make test | lint | build  (see B4)
Architecture: [2 lines on the layering from B5]

Branch      : [current] — [clean | N files modified]
Recent work : [what the last commits were doing]

Open        : [Proposed ADRs, unreleased changes, TODOs that matter]
Constraints : [the 1–3 rules from B6 most likely to bite]

Ready. What are we working on?
```

Ask a question only if Part B is unfilled or contradicts what the code shows.
