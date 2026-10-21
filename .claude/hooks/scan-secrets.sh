#!/usr/bin/env bash
# scan-secrets.sh — warn when a file that was just written looks like it holds a secret.
#
# Claude Code : PostToolUse on Edit|Write (JSON payload on stdin)
# opencode    : tool.execute.after on write|edit (file path as $1)
set -uo pipefail
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
. "$HOOK_DIR/lib.sh"

FILE="${1:-}"
if [ -z "$FILE" ]; then
  PAYLOAD="$(hook_stdin_json)"
  FILE="$(json_field "$PAYLOAD" tool_input file_path)"
  [ -z "$FILE" ] && FILE="$(json_field "$PAYLOAD" tool_input filePath)"
fi

[ -n "$FILE" ] && [ -f "$FILE" ] || exit 0

FINDINGS="$(scan_stream "$FILE" < "$FILE")" && exit 0

MESSAGE="⚠️  Potential hardcoded secret in ${FILE}:
${FINDINGS}

Rule A5: secrets come from environment variables or a vault, never from source.
Move the value out and reference it by variable name before committing."

printf '%s\n' "$MESSAGE" >&2
claude_context "PostToolUse" "$MESSAGE"
exit 0
