---
name: commit
description: Create a Conventional Commit after running the pre-commit quality gates. Use when the user asks to commit, or once a coherent unit of work is finished.
argument-hint: [optional scope or message hint]
allowed-tools: Read, Bash(git status), Bash(git diff*), Bash(git log*), Bash(git add*), Bash(git commit*), Bash(make check), Bash(make test*), Bash(make lint)
---

Commit the current work as one coherent, reviewable change.

**Absolute rules (A3):**
- No commit with failing tests
- No commit containing a secret
- One commit = one logical change — split unrelated work
- Never use `git commit --no-verify`, never disable a hook to get through

---

## Step 1 — Inspect

Run and read the output before deciding anything:

```bash
git status
git diff --stat
git diff            # the staged and unstaged content, actually read it
git log --oneline -5   # match the repository's existing style
```

If the diff contains unrelated changes, stage them separately and make several commits.

## Step 2 — Gate

```bash
make check
```

Red gate → fix first, or report exactly what fails and stop. Never commit around it.

Two hooks also run on `git commit`: one refuses a staged secret, one refuses source
changed without a test (ADR 0009). The way out of the second is a trailer in the
message — `Test-Exempt: <reason, 15+ characters>` — never `--no-verify`.

## Step 3 — Message

```
type(scope): short imperative description

[body: WHY this change, not what — only if non-obvious]

[footer: refs PROJ-123 · BREAKING CHANGE: ...]
```

- `type` ∈ `feat` `fix` `docs` `test` `refactor` `chore` `security` `perf`
- `scope` = impacted component from Part B: `decoder` · `leds` · `midi` · `usb` · `config` · `pkg` · `launchd` · `ci` · `tests` · `docs` · `branding` · `agents`
- Subject ≤ 72 chars, imperative mood, no trailing period
- A breaking change requires a `BREAKING CHANGE:` footer

## Step 4 — Verify

```bash
git log -1 --stat
```

Confirm the commit contains exactly what was intended — nothing more.

---

Hint: $ARGUMENTS
