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
import shlex
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

# --- Terraform state, saved plans, tfvars ---------------------------------
# A file name needs a stem character or glob before the extension, so a regex
# like `\.tfstate` in a grep of .gitignore passes. A bare `tfplan` needs a dir.
TF_FILE = re.compile(
    r"[\w*?-]\.(tfstate(\.[\w.-]*)?|tfplan(\.json)?|tfvars(\.json)?)(?![\w-])"
    r"|[/\\]tfplan(\.[\w.-]*)?(?![\w-])"
)
TF_STATE_CMD = re.compile(
    r"(?<![\w./-])terraform(\s+-\S+)*\s+(show|output|console|state\s+(pull|show))(?![\w-])"
)
HEREDOC = re.compile(r"<<-?\s*(['\"]?)(\w+)\1[^\n]*\n(.*?)\n\s*\2[ \t]*(?:\n|$)", re.S)
HEREDOC_WRITERS = {"cat", "tee"}
SEGMENT_BREAKS = {";", "&", "&&", "|", "||", "|&", "(", ")", ";;"}
# Commands that only name a path and never print its content.
NAME_ONLY = {"ls", "stat", "test", "[", "rm", "mkdir", "echo", "printf"}
GIT_NAME_ONLY = {"check-ignore", "ls-files", "status"}


def _segments(cmd: str):
    lexer = shlex.shlex(cmd.replace("\n", ";"), posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    seg = []
    for tok in lexer:
        if tok in SEGMENT_BREAKS:
            if seg:
                yield seg
            seg = []
        else:
            seg.append(tok)
    if seg:
        yield seg


def _name_only(seg) -> bool:
    words = [t for t in seg if not re.match(r"^\w+=", t)]
    if not words or any("`" in t for t in words):
        return False
    prog = words[0].rsplit("/", 1)[-1]
    if prog == "git":
        sub = next((t for t in words[1:] if not t.startswith("-")), "")
        return sub in GIT_NAME_ONLY
    # Terraform reads that print state are denied earlier by TF_STATE_CMD.
    return prog in NAME_ONLY or prog == "terraform"


def detect_terraform(cmd: str):
    """Return a reason if the command reads a Terraform state, plan or tfvars file."""
    # A heredoc into cat/tee is text being written; into anything else it is code.
    code_bodies = []

    def strip_body(m):
        line = cmd[cmd.rfind("\n", 0, m.start()) + 1:m.start()]
        words = re.split(r"[;&|()]", line)[-1].split()
        prog = words[0].rsplit("/", 1)[-1] if words else ""
        if prog not in HEREDOC_WRITERS:
            code_bodies.append(m.group(3))
        return "<<" + m.group(2) + "\n"

    body_free = HEREDOC.sub(strip_body, cmd)
    if any(TF_STATE_CMD.search(deobfuscate(s)) for s in [body_free, *code_bodies]):
        return "reads Terraform state (terraform show/output/state)"
    if any(TF_FILE.search(b) for b in code_bodies):
        return "reads a Terraform state, plan or tfvars file"
    try:
        for seg in _segments(body_free):
            if not _name_only(seg) and any(TF_FILE.search(t) for t in seg):
                return "reads a Terraform state, plan or tfvars file"
    except ValueError:
        if TF_FILE.search(body_free):
            return "reads a Terraform state, plan or tfvars file"
    return None


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
    return detect_terraform(cmd)


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
