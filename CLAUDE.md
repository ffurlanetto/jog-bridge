@AGENTS.md

---

# Claude Code specifics

Everything above is shared with the other agents. This section only concerns Claude Code.

## What is wired up

| Mechanism | Location | Notes |
|---|---|---|
| Skills | `.claude/skills/<name>/SKILL.md` | `/plan` `/tdd` `/debug` `/review` `/commit` `/pr` `/ship` `/prime` `/adr` `/security-audit` |
| Subagents | `.claude/agents/*.md` | `code-reviewer` and `security-auditor` read-only, `debugger` |
| Hooks | `.claude/settings.json` → `.claude/hooks/*.sh` | tested by `make test-hooks` |
| Permissions | `.claude/settings.json` | commands with side effects ask for confirmation |
| Test policy | `.claude/test-policy.json` | source / test split of the gate (ADR 0009) |

## Guarantees enforced outside the model

- **PostToolUse** on `Edit|Write` → `scan-secrets.sh` flags a likely secret in the file that was
  just written.
- **PreToolUse** on `git commit*` → `block-commit-secrets.sh` **refuses** the commit if the
  staged diff contains a secret.
- **PreToolUse** on `git commit*` → `require-tests.sh` **refuses** a commit that changes source
  code without changing a test, unless it has a justified `Test-Exempt:` trailer.

These hooks only protect commits run by the agent's Bash tool, not those from your own terminal.

## In Xcode

The project is open in Xcode: prefer `BuildProject` and `XcodeRefreshCodeIssuesInFile` to check
compilation; on the command line, `make check`.

## Hardware

Hardware tests (`--list`, `--dump`) need the console plugged in. Do not conclude that a USB / MIDI
change works without having run them, or without saying so clearly.

## Scope

Stick to the requested task: no opportunistic refactoring, no documentation files outside `docs/`.
