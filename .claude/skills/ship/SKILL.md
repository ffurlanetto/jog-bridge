---
name: ship
description: Take a finished change from working tree to a reviewable pull request — branch, commit, push, open it as a draft, wait for the build, then fix or promote to ready. Use when work is complete and needs to reach the forge.
argument-hint: [optional PR title]
allowed-tools: Read, Glob, Grep, Bash(git *), Bash(gh *), Bash(glab *), Bash(make check), Bash(make test*), Bash(make lint)
---

Deliver the current change. Rule A14 describes the flow; **B8 holds every value it
depends on** — forge, branch convention, required checks, merge strategy, wait
budget. Read B8 first. If a field you need is empty, ask rather than guess.

## 1 — Be on a branch

```bash
git branch --show-current
```

On the integration branch named in B8, stop and create one now, following B8's
convention. A change is never committed on the integration branch.

## 2 — Gate before pushing

```bash
make check
```

Red → fix it here. Pushing a red branch costs a CI cycle and the reviewers' trust.

## 3 — Commit and push

Follow `/commit` for the message. Then:

```bash
git push -u origin <branch>
```

## 4 — Open it as a draft

Always draft, even when the work feels finished (A14). Fill the repository's
template; `/pr` writes the description.

```bash
gh pr create --draft --fill                    # GitHub
glab mr create --draft --fill                  # GitLab
# Bitbucket: no first-party CLI — use the REST endpoint recorded in B8
```

## 5 — Wait for the build

This is the step that is usually skipped, and the one that matters. Do not report
"pushed" and move on.

```bash
gh pr checks --watch                           # GitHub
glab ci status --live                          # GitLab
```

Honour the wait budget in B8. When it runs out, hand back the check status as it
stands — say what is still running, do not pretend it passed.

## 6 — Act on the result

**Green** → verify the remaining ready criteria (threads resolved, no conflict,
template followed), then promote:

```bash
gh pr ready        # GitHub
glab mr update --ready
```

**Red** → read the actual failure, in the log, not the summary. Fix the cause,
push, and wait again. There is no round limit; there are rules:

- never disable, skip or weaken a test to get green (A4)
- never re-run a job hoping for a different outcome. "Flaky" is not a root cause
- never `--no-verify`, never `--force` on a shared branch
- if the failure is not yours — a check already red on the base branch — say so
  with the evidence, and do not widen the change to fix it

**Still red after a genuine attempt** → stop and report: which check, which line
of the log, what you tried, what you need. A clear blocker beats a silent retry.

## Report

```
## Shipped — [title]

Branch  : [name]
PR      : [url] — draft | ready
CI      : 🟢 green on [sha] | 🔴 [check] failing | ⏳ still running after [n] min
Gate    : make check 🟢

Remaining before merge:
- [ ] [what is left, and who owns it]
```

---

$ARGUMENTS
