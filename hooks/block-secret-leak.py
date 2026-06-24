#!/usr/bin/env python3
"""
PreToolUse:Bash hook — block commands that read/exfiltrate secrets from the
shell environment, regardless of how the command is shaped.

Where the permissions deny-globs in settings.json match only a command's
literal prefix, this scans the FULL command string (after light
de-obfuscation) so reordered flags, piped variants, quote-splitting, and
common indirection tricks still get caught.

Contract: reads the PreToolUse JSON event on stdin. Emits a deny decision as
JSON on stdout when a secret-leak pattern matches; otherwise stays silent and
exits 0 (allow / fall through to normal permission checks).
"""
import json
import re
import sys


# --- env-dumping commands -------------------------------------------------
# Whole-environment dumpers. Word-boundaried so "envsubst", "preset", etc. pass.
ENV_DUMP = re.compile(
    r"(?<![\w./-])"
    r"(env|printenv|export\s+-p|declare\s+-[xp]|typeset\s+-[xp]|compgen\s+-v)"
    r"(?![\w./-])"
)

# `set` with no following option/assignment dumps all vars; `set -e` etc. is fine.
SET_DUMP = re.compile(r"(?<![\w./-])set\s*(?:[;|&]|$)")

# Reading a process environment block directly.
PROC_ENVIRON = re.compile(r"/proc/[^/\s]+/environ")

# --- secret variable references ------------------------------------------
# Expanding a sensitive var by name: $TOKEN, ${TOKEN}, %TOKEN% style.
SECRET_VAR = re.compile(
    r"[$%]\{?(?P<name>[A-Z0-9_]*"
    r"(SECRET|TOKEN|PASSWORD|PASSWD|API[_-]?KEY|ACCESS[_-]?KEY|"
    r"PRIVATE[_-]?KEY|CREDENTIAL|SESSION|AUTH|BEARER|CLIENT[_-]?SECRET|"
    r"PASSPHRASE|ANTHROPIC_API_KEY|OPENAI_API_KEY|GH_TOKEN|GITHUB_TOKEN|"
    r"AWS_SECRET|AWS_ACCESS_KEY|GCP_|GOOGLE_APPLICATION)"
    r"[A-Z0-9_]*)\}?%?"
)

# Credential files on disk that aren't env vars but are the same risk class.
SECRET_FILE = re.compile(
    r"(~|/[^\s]*)?/\.(netrc|git-credentials|aws/credentials|"
    r"docker/config\.json|npmrc|pypirc|ssh/id_[a-z0-9]+)"
    r"|/\.config/gcloud/"
)


def deobfuscate(cmd: str) -> str:
    """Collapse the cheapest evasions: stripped quotes, backslash escapes,
    and run-together whitespace. Not a sandbox — just denies the easy bypass."""
    s = cmd.replace('"', "").replace("'", "").replace("\\", "")
    s = re.sub(r"\s+", " ", s)
    return s


def detect(cmd: str):
    """Return a (reason) string if the command looks like a secret leak, else None."""
    s = deobfuscate(cmd)

    if PROC_ENVIRON.search(s):
        return "reads a process environment block (/proc/<pid>/environ)"
    if ENV_DUMP.search(s):
        return "dumps the full shell environment (env/printenv/export -p/declare -x)"
    if SET_DUMP.search(s):
        return "bare `set` dumps all shell variables"
    m = SECRET_VAR.search(s)
    if m:
        return f"references a secret environment variable (${{{m.group('name')}}})"
    if SECRET_FILE.search(s):
        return "reads an on-disk credential file"
    return None


def main() -> int:
    try:
        event = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0  # malformed event — don't block, let the harness handle it

    if event.get("tool_name") != "Bash":
        return 0

    command = (event.get("tool_input") or {}).get("command", "")
    if not isinstance(command, str) or not command:
        return 0

    reason = detect(command)
    if reason is None:
        return 0

    decision = {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": (
                f"Blocked by secret-leak guard: command {reason}. "
                "If this is intentional, run it yourself outside Claude."
            ),
        }
    }
    print(json.dumps(decision))
    return 0


if __name__ == "__main__":
    sys.exit(main())
