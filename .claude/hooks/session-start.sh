#!/usr/bin/env bash
# session-start.sh — hand the agent the repository's current state at session start.
#
# Claude Code: SessionStart hook. Keep the output short: it costs context on
# every single session.
set -uo pipefail
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
. "$HOOK_DIR/lib.sh"

git rev-parse --git-dir >/dev/null 2>&1 || exit 0

BRANCH="$(git branch --show-current 2>/dev/null || echo 'detached')"
DIRTY="$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
RECENT="$(git log --oneline -3 2>/dev/null || true)"

MESSAGE="Repository state:
- branch: ${BRANCH} (${DIRTY} file(s) modified)
- recent commits:
${RECENT}

Reminders: plan before coding (A1) · the command contract is \`make test|lint|build|check\` (B4) · the MIDI contract (notes, CC, LEDs, port ids) is public: see the non-regression tests before touching it."

printf '%s\n' "$MESSAGE" >&2
claude_context "SessionStart" "$MESSAGE"
exit 0
