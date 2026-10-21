#!/usr/bin/env bash
# lib.sh — shared guardrail helpers.
#
# Sourced by every hook script. The same scripts back both agents:
#   · Claude Code — declared in .claude/settings.json, JSON payload on stdin
#   · opencode    — invoked by .opencode/plugins/guardrails.js
#
# Exit contract (identical for both callers):
#   0 + empty stderr        → clean
#   0 + stderr message      → warning (stdout carries Claude's additionalContext JSON)
#   2 + stderr message      → BLOCK the action
# shellcheck shell=bash

set -uo pipefail

# ── Secret detection ─────────────────────────────────────────────────────────
# Assignment of a sensitive-looking name to a quoted literal of 8+ chars.
SECRET_ASSIGNMENT='(pass(wd|word)?|secret|token|api[-_]?key|apikey|access[-_]?key|auth|credential|client[-_]?secret|private[-_]?key|dsn|connection[-_]?string)[[:space:]]*[:=][[:space:]]*.?["'"'"'`][^"'"'"'`]{8,}'

# Well-known credential shapes, regardless of the variable name.
SECRET_LITERAL='(AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|xox[abprs]-[A-Za-z0-9-]{10,}|sk-[A-Za-z0-9]{20,}|sk-ant-[A-Za-z0-9-]{20,}|AIza[0-9A-Za-z_-]{30,}|-----BEGIN [A-Z ]*PRIVATE KEY-----|eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.)'

# Lines that look like secrets but are placeholders, references, or test data.
SECRET_ALLOWLIST='(CHANGE[_-]?ME|REPLACE[_-]?ME|YOUR[_-]|<[^>]+>|\$\{|\$\(|%s|\{\{|process\.env|os\.environ|getenv|System\.getenv|ENV\[|Deno\.env|import\.meta\.env|example|placeholder|dummy|redacted|fake|sample|xxxx|\*\*\*\*|password123|SECRET_ALLOWLIST|SECRET_ASSIGNMENT|SECRET_LITERAL)'

# scan_stream — read text on stdin, print offending lines, return 1 if any.
# Usage: scan_stream "<label>" < file
scan_stream() {
  local label="${1:-input}" hits
  hits="$(grep -nEi "${SECRET_ASSIGNMENT}|${SECRET_LITERAL}" 2>/dev/null \
          | grep -vEi "${SECRET_ALLOWLIST}" \
          | head -20)" || true
  [ -z "$hits" ] && return 0
  # Never echo the value itself — report the location only.
  printf '%s\n' "$hits" | sed -E 's/([:=][[:space:]]*.?["'"'"'`])[^"'"'"'`]*/\1********/g' \
    | while IFS= read -r line; do printf '  %s:%s\n' "$label" "$line"; done
  return 1
}

# hook_stdin_json — capture the JSON payload Claude Code sends on stdin (may be empty).
hook_stdin_json() {
  [ -t 0 ] && { printf ''; return 0; }
  cat 2>/dev/null || printf ''
}

# json_field — read a dotted field from a JSON document, without requiring jq.
# Usage: json_field "$payload" tool_input file_path
json_field() {
  local payload="$1"; shift
  [ -z "$payload" ] && { printf ''; return 0; }
  if command -v jq >/dev/null 2>&1; then
    local filter="."; local k
    for k in "$@"; do filter="${filter}[\"${k}\"]?"; done
    printf '%s' "$payload" | jq -r "${filter} // empty" 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    PAYLOAD="$payload" python3 -c '
import json, os, sys
try:
    node = json.loads(os.environ["PAYLOAD"])
except Exception:
    sys.exit(0)
for key in sys.argv[1:]:
    if not isinstance(node, dict):
        sys.exit(0)
    node = node.get(key)
    if node is None:
        sys.exit(0)
print(node if isinstance(node, str) else json.dumps(node))
' "$@"
  else
    printf ''
  fi
}

# claude_context — emit the JSON Claude Code reads on stdout to add context.
claude_context() {
  local event="$1" message="$2"
  if command -v jq >/dev/null 2>&1; then
    jq -nc --arg e "$event" --arg m "$message" \
      '{hookSpecificOutput:{hookEventName:$e, additionalContext:$m}}'
  else
    local escaped
    escaped="$(printf '%s' "$message" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' '~' | sed 's/~/\\n/g')"
    printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' "$event" "$escaped"
  fi
}
