#!/usr/bin/env bash
# block-commit-secrets.sh — refuse a commit whose staged diff contains a secret.
#
# Claude Code : PreToolUse on Bash, narrowed with  if: "Bash(git commit*)"
# opencode    : tool.execute.before on bash, when the command starts with git commit
#
# Exits 2 to block — Claude Code uses stderr as the denial reason, and the
# opencode plugin turns a non-zero exit into a thrown error.
set -uo pipefail
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
. "$HOOK_DIR/lib.sh"

COMMAND="${1:-}"
if [ -z "$COMMAND" ]; then
  PAYLOAD="$(hook_stdin_json)"
  COMMAND="$(json_field "$PAYLOAD" tool_input command)"
fi

# Only guard actual commits; anything else passes through untouched.
case "$COMMAND" in
  *"git commit"*|*"git"*"commit"*) ;;
  "") ;;                      # no command available — guard anyway, it is cheap
  *) exit 0 ;;
esac

git rev-parse --git-dir >/dev/null 2>&1 || exit 0

STAGED="$(git diff --cached -U0 2>/dev/null | grep -E '^\+' | grep -vE '^\+\+\+' || true)"
[ -z "$STAGED" ] && exit 0

FINDINGS="$(printf '%s\n' "$STAGED" | scan_stream "staged")" && exit 0

printf '%s\n' "⛔ Commit blocked — potential secret in the staged changes:
${FINDINGS}

Rule A5: no commit with a secret. Unstage the file, move the value to an
environment variable, and commit again. Do not bypass this check with --no-verify." >&2
exit 2
