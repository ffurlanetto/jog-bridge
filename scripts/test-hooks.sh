#!/usr/bin/env bash
# test-hooks.sh — prove the guardrails actually fire. Run via `make test-hooks`.
#
# Every case is asserted in the two invocation modes of the hooks: JSON on stdin
# (Claude Code) and a command-line argument.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS="$ROOT/.claude/hooks"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Fake secrets assembled at runtime: no literal appears in this file, otherwise
# block-commit-secrets.sh would refuse to commit it.
FAKE_SK="sk-""abcdefghijklmnopqrstuvwx"
FAKE_GH="ghp_""abcdefghijklmnopqrstuvwxyz0123"

PASS=0; FAIL=0
ok()    { printf '  \033[0;32m✓\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
ko()    { printf '  \033[0;31m✗\033[0m %s — %s\n' "$1" "$2"; FAIL=$((FAIL+1)); }
check() { # check <name> <expected exit code> <actual exit code>
  [ "$2" = "$3" ] && ok "$1" || ko "$1" "expected $2, got $3"
}

printf '\n\033[0;36mscan-secrets.sh\033[0m\n'

printf 'let apiKey = "%s"\n' "$FAKE_SK" > "$TMP/leaky.swift"
cat > "$TMP/clean.swift" <<'SWIFT'
let apiKey = ProcessInfo.processInfo.environment["API_KEY"]
let placeholder = "CHANGEME"
let sourceUniqueID: MIDIUniqueID = 0x4845_5231
SWIFT

OUT="$("$HOOKS/scan-secrets.sh" "$TMP/leaky.swift" 2>&1)"; RC=$?
check "warns on a hardcoded secret (argv mode)" 0 "$RC"
case "$OUT" in *"Potential hardcoded secret"*) ok "warning message emitted";; *) ko "warning message emitted" "missing";; esac
case "$OUT" in *"$FAKE_SK"*) ko "secret value masked" "raw value in the report";; *) ok "secret value masked";; esac

OUT="$(printf '{"tool_input":{"file_path":"%s"},"hook_event_name":"PostToolUse"}' "$TMP/leaky.swift" | "$HOOKS/scan-secrets.sh" 2>/dev/null)"
case "$OUT" in *'"hookEventName":"PostToolUse"'*) ok "emits Claude Code JSON (stdin mode)";; *) ko "emits Claude Code JSON (stdin mode)" "no hookSpecificOutput";; esac

OUT="$("$HOOKS/scan-secrets.sh" "$TMP/clean.swift" 2>&1)"; RC=$?
check "silent on an environment variable, a placeholder and a hex constant" 0 "$RC"
[ -z "$OUT" ] && ok "no false positive" || ko "no false positive" "$OUT"

printf '\n\033[0;36mblock-commit-secrets.sh\033[0m\n'

REPO="$TMP/repo"; mkdir -p "$REPO"
git -C "$REPO" init -q
git -C "$REPO" config user.email hooks@test.local
git -C "$REPO" config user.name "hook test"

printf 'let token = "%s"\n' "$FAKE_GH" > "$REPO/Conf.swift"
git -C "$REPO" add Conf.swift
( cd "$REPO" && "$HOOKS/block-commit-secrets.sh" "git commit -m test" >/dev/null 2>&1 ); RC=$?
check "blocks a commit carrying a secret (argv mode)" 2 "$RC"

( cd "$REPO" && printf '{"tool_input":{"command":"git commit -m x"}}' | "$HOOKS/block-commit-secrets.sh" >/dev/null 2>&1 ); RC=$?
check "blocks a commit carrying a secret (stdin mode)" 2 "$RC"

( cd "$REPO" && "$HOOKS/block-commit-secrets.sh" "git status" >/dev/null 2>&1 ); RC=$?
check "ignores commands that are not commits" 0 "$RC"

git -C "$REPO" reset -q
printf 'let token = ProcessInfo.processInfo.environment["GH_TOKEN"]\n' > "$REPO/Conf.swift"
git -C "$REPO" add Conf.swift
( cd "$REPO" && "$HOOKS/block-commit-secrets.sh" "git commit -m test" >/dev/null 2>&1 ); RC=$?
check "lets a clean commit through" 0 "$RC"

printf '\n\033[0;36mrequire-tests.sh\033[0m\n'

GATE="$TMP/gate"; mkdir -p "$GATE/Sources/jog-bridge" "$GATE/Tests/jog-bridgeTests/Fixtures" "$GATE/docs" "$GATE/scripts/pkg" "$GATE/.claude"
git -C "$GATE" init -q
git -C "$GATE" config user.email gate@test.local
git -C "$GATE" config user.name "gate test"
cp "$ROOT/.claude/test-policy.json" "$GATE/.claude/test-policy.json"
printf 'struct A {}\n' > "$GATE/Sources/jog-bridge/A.swift"

gate()     { ( cd "$GATE" && "$HOOKS/require-tests.sh" "$1" >/dev/null 2>&1 ); echo $?; }
# stderr carries the verdict; stdout is the machine-readable JSON.
gate_out() { ( cd "$GATE" && { "$HOOKS/require-tests.sh" "$1" >/dev/null; } 2>&1 ); }

git -C "$GATE" add Sources/jog-bridge/A.swift
check "blocks source code with no test" 2 "$(gate 'git commit -m "feat: a"')"
case "$(gate_out 'git commit -m "feat: a"')" in
  *"Sources/jog-bridge/A.swift"*) ok "names the offending source files";;
  *) ko "names the offending source files" "file not listed";;
esac

printf 'import Testing\n@Test func a() {}\n' > "$GATE/Tests/jog-bridgeTests/ATests.swift"
git -C "$GATE" add Tests/jog-bridgeTests/ATests.swift
check "lets source + test through" 0 "$(gate 'git commit -m "feat: a"')"

git -C "$GATE" reset -q
printf '[]\n' > "$GATE/Tests/jog-bridgeTests/Fixtures/x.json"
git -C "$GATE" add Sources/jog-bridge/A.swift Tests/jog-bridgeTests/Fixtures/x.json
check "a JSON reference file under Tests/ counts as a test" 0 "$(gate 'git commit -m "feat: a"')"

git -C "$GATE" reset -q
printf '# doc\n' > "$GATE/docs/x.md"
git -C "$GATE" add docs/x.md
check "ignores a documentation-only commit" 0 "$(gate 'git commit -m "docs: x"')"

git -C "$GATE" reset -q
printf '#!/bin/bash\n' > "$GATE/scripts/pkg/postinstall"
printf '// swift-tools-version:5.9\n' > "$GATE/Package.swift"
git -C "$GATE" add scripts/pkg/postinstall Package.swift
check "scripts/ and Package.swift do not trigger the gate" 0 "$(gate 'git commit -m "chore: scripts"')"

git -C "$GATE" reset -q
printf 'struct B {}\n@Test func inline() {}\n' > "$GATE/Sources/jog-bridge/B.swift"
git -C "$GATE" add Sources/jog-bridge/B.swift
check "accepts a @Test declared inside the source file" 0 "$(gate 'git commit -m "feat: b"')"

git -C "$GATE" reset -q
git -C "$GATE" add Sources/jog-bridge/A.swift
check "accepts a Test-Exempt trailer with a reason" 0 \
  "$(gate 'git commit -m "refactor: rename

Test-Exempt: pure rename, behaviour unchanged")')"
case "$(gate_out 'git commit -m "x

Test-Exempt: pure rename, behaviour unchanged")')" in
  *"waived"*) ok "prints the waiver so it is not silent";;
  *) ko "prints the waiver so it is not silent" "no notice";;
esac
check "rejects a Test-Exempt reason under 15 characters" 2 "$(gate 'git commit -m "x

Test-Exempt: wip")')"
check "refuses a commit with no -m to inspect" 2 "$(gate 'git commit')"
check "ignores commands that are not commits" 0 "$(gate 'git status')"

# `git commit -a` stages tracked files at commit time: the index alone would miss
# them, so the gate must look at git diff HEAD.
git -C "$GATE" reset -q
git -C "$GATE" add -A
git -C "$GATE" commit -qm "chore: base

Test-Exempt: base commit for the gate fixture"
printf 'struct A { var x = 1 }\n' > "$GATE/Sources/jog-bridge/A.swift"
check "sees changes staged by -a" 2 "$(gate 'git commit -am "feat: b"')"
check "passes when nothing is staged" 0 "$(gate 'git commit -m "feat: b"')"

( cd "$GATE" && printf '{"tool_input":{"command":"git commit -am \\"feat: b\\""}}' \
  | "$HOOKS/require-tests.sh" >/dev/null 2>&1 ); check "blocks in stdin mode too" 2 "$?"

printf '\n%s passed, %s failed\n\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
