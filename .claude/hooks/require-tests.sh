#!/usr/bin/env bash
# require-tests.sh — refuse a commit that changes source without changing a test.
#
# Claude Code : PreToolUse on Bash, narrowed with  if: "Bash(git commit*)"
# opencode    : tool.execute.before on bash, when the command is a commit
#
# The source/test boundary is declared in .claude/test-policy.json (ADR-002).
# The way out is a commit trailer:  Test-Exempt: <reason of 15+ characters>
# It is accepted, printed, and preserved in the git history — unlike --no-verify,
# which is forbidden by A3 and invisible in review.
#
# Exits 2 to block, with the reason on stderr.
set -uo pipefail
HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
. "$HOOK_DIR/lib.sh"

COMMAND="${1:-}"
if [ -z "$COMMAND" ]; then
  PAYLOAD="$(hook_stdin_json)"
  COMMAND="$(json_field "$PAYLOAD" tool_input command)"
fi

# Only guard actual commits.
case "$COMMAND" in
  *"git commit"*|*"git"*"commit"*) ;;
  *) exit 0 ;;
esac

git rev-parse --git-dir >/dev/null 2>&1 || exit 0

# The policy always belongs to the repository being committed. Never fall back to
# one sitting next to this script: that would apply a foreign project's rules.
POLICY="$(git rev-parse --show-toplevel 2>/dev/null)/.claude/test-policy.json"
[ -f "$POLICY" ] || POLICY=""

# `git commit -a` stages tracked changes at commit time, so the staged diff alone
# would miss them. Ask git for the right set before classifying.
if printf '%s' "$COMMAND" | grep -qE '(^|[[:space:]])(-a|--all|-[a-zA-Z]*a[a-zA-Z]*)([[:space:]]|$)'; then
  CHANGED="$(git diff HEAD --name-only 2>/dev/null)"
else
  CHANGED="$(git diff --cached --name-only 2>/dev/null)"
fi
[ -z "$CHANGED" ] && exit 0

# Some languages keep unit tests inside the source file (Rust's #[cfg(test)],
# a Go test in the same package, a nested JUnit class). Path globs cannot see
# those, so the added lines are scanned for unambiguous test declarations too.
if printf '%s' "$COMMAND" | grep -qE '(^|[[:space:]])(-a|--all)([[:space:]]|$)'; then
  ADDED="$(git diff HEAD -U0 2>/dev/null | grep -E '^\+' | grep -vE '^\+\+\+' || true)"
else
  ADDED="$(git diff --cached -U0 2>/dev/null | grep -E '^\+' | grep -vE '^\+\+\+' || true)"
fi

VERDICT="$(COMMIT_COMMAND="$COMMAND" CHANGED_FILES="$CHANGED" ADDED_LINES="$ADDED" \
           POLICY_FILE="$POLICY" python3 - <<'PY'
import fnmatch, json, os, re, shlex, sys

DEFAULTS = {
    "sources": ["src/**", "lib/**", "app/**", "apps/**", "internal/**", "cmd/**",
                "pkg/**", "packages/**", "modules/**", "*.py", "*.go", "*.ts",
                "*.tsx", "*.js", "*.jsx", "*.rb", "*.rs", "*.java", "*.kt",
                "*.cs", "*.dart", "*.tf"],
    "tests": ["test/**", "tests/**", "spec/**", "specs/**", "__tests__/**",
              "src/test/**", "**/*_test.go", "**/*_test.py", "**/test_*.py",
              "**/*.test.*", "**/*.spec.*", "**/*Test.java", "**/*Tests.cs",
              "**/*_spec.rb", "**/*_test.rb", "**/conftest.py"],
    "exempt": ["**/*.md", "**/*.json", "**/*.yml", "**/*.yaml", "**/*.toml",
               "**/*.lock", "**/migrations/**", "**/generated/**", "docs/**",
               ".github/**", ".claude/**", ".opencode/**"],
    # Unambiguous declarations of a test, for languages that keep tests inside
    # the source file. Deliberately narrow: a false positive here silently
    # disarms the gate.
    "test_markers": [r"#\[cfg\(test\)\]", r"#\[test\]", r"\bfunc Test[A-Z_]",
                     r"@Test\b", r"\bdef test_", r"\bclass Test[A-Z]",
                     r"\bit\(", r"\bdescribe\("],
}

def glob_to_regex(pattern: str) -> re.Pattern:
    """Translate a glob into a regex, giving ** its usual cross-directory meaning."""
    out, i = [], 0
    while i < len(pattern):
        char = pattern[i]
        if pattern.startswith("**/", i):
            out.append("(?:.*/)?"); i += 3
        elif pattern.startswith("**", i):
            out.append(".*"); i += 2
        elif char == "*":
            out.append("[^/]*"); i += 1
        elif char == "?":
            out.append("[^/]"); i += 1
        else:
            out.append(re.escape(char)); i += 1
    return re.compile("^" + "".join(out) + "$")

def load_policy(path):
    warning = None
    policy = DEFAULTS
    if path:
        try:
            loaded = json.load(open(path, encoding="utf-8"))
            policy = {key: loaded.get(key, DEFAULTS[key]) for key in DEFAULTS}
        except Exception as error:      # noqa: BLE001 - a broken policy must not block
            warning = f"{path} is unreadable ({error}); using built-in defaults"
    else:
        warning = None                  # absence is normal, not worth a warning
    return policy, warning

def commit_message(command: str) -> str:
    """Pull the message out of -m/-F. Other forms return '' and are refused."""
    try:
        args = shlex.split(command)
    except ValueError:
        return ""
    parts, index = [], 0
    while index < len(args):
        arg = args[index]
        if arg in ("-m", "--message", "-F", "--file"):
            if index + 1 < len(args):
                value = args[index + 1]
                if arg in ("-F", "--file"):
                    try:
                        value = open(value, encoding="utf-8").read()
                    except OSError:
                        value = ""
                parts.append(value)
            index += 2
            continue
        for prefix in ("--message=", "--file="):
            if arg.startswith(prefix):
                parts.append(arg[len(prefix):])
        index += 1
    return "\n".join(parts)

def uses_editor(command: str) -> bool:
    return not re.search(r"(^|\s)(-m|-F|--message|--file)(=|\s)", command)

policy, warning = load_policy(os.environ.get("POLICY_FILE") or "")
markers = [re.compile(p) for p in policy.pop("test_markers", DEFAULTS["test_markers"])]
matchers = {kind: [glob_to_regex(p) for p in patterns] for kind, patterns in policy.items()}

def classify(path: str) -> str:
    for kind in ("tests", "exempt", "sources"):
        if any(rx.match(path) for rx in matchers[kind]):
            return kind
    return "other"

changed = [line for line in os.environ["CHANGED_FILES"].splitlines() if line.strip()]
buckets = {"tests": [], "exempt": [], "sources": [], "other": []}
for path in changed:
    buckets[classify(path)].append(path)

inline = [line for line in os.environ.get("ADDED_LINES", "").splitlines()
          if any(rx.search(line) for rx in markers)]

result = {"warning": warning, "sources": buckets["sources"], "tests": buckets["tests"]}

if not buckets["sources"]:
    result["verdict"] = "pass"
elif buckets["tests"] or inline:
    result["verdict"] = "pass"
    if inline and not buckets["tests"]:
        result["inline"] = inline[0][:80]
else:
    command = os.environ["COMMIT_COMMAND"]
    if uses_editor(command):
        result["verdict"] = "no-message"
    else:
        match = re.search(r"^[ \t]*Test-Exempt:[ \t]*(.+)$",
                          commit_message(command), re.MULTILINE)
        reason = match.group(1).strip() if match else ""
        if len(reason) >= 15:
            result["verdict"] = "exempt"
            result["reason"] = reason
        elif match:
            result["verdict"] = "short-reason"
            result["reason"] = reason
        else:
            result["verdict"] = "block"

print(json.dumps(result))
PY
)" || { printf '%s\n' "⚠️  require-tests: could not classify the diff (python3 missing?) — letting the commit through." >&2; exit 0; }

read_field() { printf '%s' "$VERDICT" | python3 -c "import json,sys;d=json.load(sys.stdin);v=d.get(sys.argv[1]);print('\n'.join(v) if isinstance(v,list) else (v or ''))" "$1"; }

WARNING="$(read_field warning)"
[ -n "$WARNING" ] && printf '⚠️  require-tests: %s\n' "$WARNING" >&2

case "$(read_field verdict)" in
  pass) exit 0 ;;
  exempt)
    printf '✅ Test gate waived — %s\n   The reason stays in the commit, where a reviewer will see it.\n' \
      "$(read_field reason)" >&2
    exit 0 ;;
  short-reason)
    printf '⛔ Commit blocked — the Test-Exempt reason is too short (15 characters minimum).\n   Given: %s\n' \
      "$(read_field reason)" >&2
    exit 2 ;;
  no-message)
    printf '⛔ Commit blocked — this gate reads the message from -m or -F.\n   Re-run with -m so the Test-Exempt trailer can be checked if you need it.\n' >&2
    exit 2 ;;
  *)
    printf '%s\n' "⛔ Commit blocked — source changed, no test changed (AGENTS.md A4, ADR-002).

Source files in this commit:
$(read_field sources | sed 's/^/  - /')

Add or update a test, or — if this change genuinely carries no behaviour —
commit with a trailer stating why:

  git commit -m \"refactor(x): rename Foo to Bar

  Test-Exempt: pure rename, behaviour unchanged, covered by existing suite\"

Do not reach for --no-verify: it is denied in .claude/settings.json." >&2
    exit 2 ;;
esac
