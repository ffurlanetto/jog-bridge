---
name: pr
description: Write a pull request description from the branch diff, following the repository template. Use when opening a PR or when asked to summarize a branch for review.
argument-hint: [optional target branch]
allowed-tools: Read, Glob, Grep, Bash(git diff*), Bash(git log*), Bash(git status), Bash(git branch*)
---

Produce a pull request description that a reviewer can act on without reading
every line of the diff first.

## Step 1 — Gather

```bash
git log <base>..HEAD --oneline
git diff <base>...HEAD --stat
git diff <base>...HEAD          # read it, do not summarize blindly
```

Default `<base>` to the main branch declared in B8.

## Step 2 — Use the repository template

If `.github/pull_request_template.md` exists, fill **its** sections. Otherwise use:

```markdown
## What

[One paragraph: the change, in the reader's terms.]

## Why

[The problem or requirement. Link the spec / ADR / ticket.]

## How

[Design choices a reviewer would not guess from the diff. Trade-offs taken.]

## Testing

- [What was tested and how]
- `make check` : 🟢 / 🔴

## Risk & rollout

- Impact area: [modules]
- Migration / data change: [yes — detail | no]
- Rollback: [how]

## Review focus

- [The 1–3 places where the reviewer's attention is worth the most]
```

## Rules
- Describe only what the diff actually does — never announce future work as done
- Flag every breaking change explicitly
- Never include secrets, tokens, internal hostnames, or environment values
- If the diff is too large to review, say so and propose a split

---

Target branch: $ARGUMENTS
