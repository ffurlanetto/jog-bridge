# 0009. Guardrails enforced outside the model: secrets and tests

- Status: Accepted
- Date: 2026-10-21

## Context

The project is developed with coding agents. Some rules tolerate no exception: never commit a
secret, never ship code without a test. In `AGENTS.md`, they compete with everything else in the
context; at the end of a session, after a compaction or under pressure, an agent ships the code
and postpones the test. Nothing stops it, and nothing records that it happened.

The repository is about to become public and will soon distribute a binary installed as root
(`postinstall`): a secret or a regression of the MIDI contract costs more there than in a
personal script.

The rule from [vibe-template](https://github.com/ffurlanetto/vibe-template) applies: *a rule the
model should follow goes in the instructions file; a rule that must hold whatever the model
decides goes in a hook.*

## Decision

Three Claude Code hooks (`.claude/settings.json`, scripts in `.claude/hooks/`):

1. **`scan-secrets.sh`** (PostToolUse on `Edit|Write`) flags a likely secret in the file that
   was just written.
2. **`block-commit-secrets.sh`** (PreToolUse on `git commit`) **refuses** a commit whose staged
   diff contains a secret.
3. **`require-tests.sh`** (PreToolUse on `git commit`) **refuses** a commit that changes source
   code without changing a test.

The split is declared in `.claude/test-policy.json`: `Sources/**` is code, `Tests/**` is tests
(reference files included); documentation, scripts, `Package.swift`, resources and
configuration are exempt.

The only way out is a commit trailer, `Test-Exempt: <reason of 15 characters or more>`. It is
accepted, printed, and the reason **stays in the git history**. `--no-verify` is refused by the
permissions.

`make test-hooks` (`scripts/test-hooks.sh`, 25 checks) proves the guardrails fire; it runs in
CI's `guardrails` job, together with a gitleaks scan over the whole history.

## Consequences

- An agent's commit with no test, or with a secret, is refused rather than merely discouraged.
- Every waiver is justified and auditable in `git log`. A rising rate of `Test-Exempt` points to
  a policy to fix, not a rule to bypass.
- **`scripts/` is exempt**: `postinstall` and `build-pkg.sh` cannot be tested without modifying
  the machine (they write into the user's folder and call `launchctl`). This is a known gap,
  documented in [docs/testing.md](../testing.md), not an oversight.
- The hooks only govern the agent's Bash tool: a commit made from your own terminal is not
  affected. CI (gitleaks, tests) remains the second line of defence.
- The gate may get in the way of a legitimate behaviour-free commit (rename, move): the
  trailer settles it in one line.
- The secret scanner relies on patterns; it has false negatives. `scripts/test-hooks.sh`
  assembles its fake secrets at runtime so as not to block its own commit.

## Alternatives considered

- **Coverage threshold in CI**: feedback comes afterwards, and a coverage figure is satisfied by
  tests that assert nothing. Useful as a second layer, not as a replacement.
- **A git `pre-commit` hook for everyone**: overwriting a contributor's git hooks is intrusive;
  the problem being solved is an agent that forgets.
- **No waiver at all**: `--no-verify` would become the normal path within a week.
- **Heuristic detection of test files**: too fragile; versioned globs can be read and reviewed.
