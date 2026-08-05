#!/usr/bin/env bash
# spec-gates.sh — PreToolUse(Bash) delivery gates.
#
# Gates (only in repos that use spec-driven tooling — graceful no-op elsewhere):
#   git commit     -> a spec .md under _bmad-output/ or openspec/ must be
#                     updated since the last commit (findings ledger).
#   git push       -> a recent spec .md must record a verdict line
#                     "Adversarial review: PASSED (round N, YYYY-MM-DD)" dated
#                     today or yesterday, or the same in .omc/state/adversarial-verdict.
#   gh pr create/edit (infra branches only) -> a behavior-delta table must
#                     exist in a recent spec .md or .omc/state/delta-table.md.
#
# Spec-dir resolution follows trackedness: a git-tracked spec dir is gated in the
# worktree (it travels with the branch); an ignored one has no worktree copy at
# all, so the main checkout is read as a fallback — and because that directory is
# shared by every linked worktree, a ledger there must carry a "Branch: <name>"
# line to count for the commit gate. Push/PR evidence
# is the exception — it is read from this worktree alone, because the main
# checkout's ignored spec dir is shared by every linked worktree.
#
# Escape hatches: OMC_SKIP_HOOKS contains "spec-gates", or repo has neither
# spec directory. Blocking emits permissionDecision=deny with the reason.
set -u

# Built with jq: the reason interpolates filesystem paths, and a quote or
# backslash in one would otherwise emit unparseable JSON — which reads as "no
# decision" and silently drops the gate.
deny() {
  jq -cn --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
  exit 0
}

INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$CMD" ] && exit 0

case ",${OMC_SKIP_HOOKS:-}," in *,spec-gates,*|*,all,*) exit 0 ;; esac

# Which gate does this command hit? (regex over the whole string: compound
# commands like `git add … && git commit …` must still be caught)
# Tolerates the ordinary forms that break a naive anchor: a leading VAR=value
# prefix, and git's own pre-verb flags (-C dir, --git-dir=...).
GIT_RE='(^|[;&|]\s*)([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*git[[:space:]]+(-[^[:space:]]+[[:space:]]+([^-[:space:]][^[:space:]]*[[:space:]]+)?)*'
GATE=""
# A backslash-continuation is one logical command, but grep anchors per line, so
# a flag and its verb landing on separate lines would slip the match. Keep the
# raw form too: a bare newline separates statements the anchor must still see.
CMD_MATCH="$CMD
$(printf '%s' "$CMD" | sed ':a;N;$!ba;s/\\\n/ /g')"
if   printf '%s' "$CMD_MATCH" | grep -qE "${GIT_RE}commit\b";         then GATE=commit
elif printf '%s' "$CMD_MATCH" | grep -qE "${GIT_RE}push\b";           then GATE=push
elif printf '%s' "$CMD_MATCH" | grep -qE '(^|[;&|]\s*)([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]*[[:space:]]+)*gh[[:space:]]+(-[^[:space:]]+[[:space:]]+([^-[:space:]][^[:space:]]*[[:space:]]+)?)*pr[[:space:]]+(create|edit)\b'; then GATE="pr"
fi
[ -z "$GATE" ] && exit 0

# A failed cd would evaluate the gates against whatever repo the hook happens to
# be running in; no-op instead.
if [ -n "$CWD" ]; then cd "$CWD" 2>/dev/null || exit 0; fi
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$ROOT" || exit 0

# In a linked worktree, --show-toplevel is the worktree; the main checkout is
# the parent of the common git dir. Search both: a git-tracked spec dir lives in
# the worktree, a git-ignored one only ever exists in the main checkout.
MAIN_ROOT=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)" 2>/dev/null)
ROOTS=("$ROOT")
[ -n "$MAIN_ROOT" ] && [ "$MAIN_ROOT" != "$ROOT" ] && [ -d "$MAIN_ROOT" ] && ROOTS+=("$MAIN_ROOT")

# Per spec dir: if it is git-tracked, the worktree copy is canonical (it travels
# with the branch), so gate on that alone. If it is untracked/ignored, the
# worktree copy cannot merge and dies with the worktree — the main checkout is
# canonical. Unioning both would let a stale doc in one satisfy a gate about the
# other.
SPEC_DIRS=()
LOCAL_SPEC_DIRS=()
for d in _bmad-output openspec; do
  # Trackedness is decided by the spec documents themselves: a lone tracked
  # placeholder (.gitkeep) in an otherwise-ignored dir must not flip the branch.
  if git ls-files --cached -- "$d" 2>/dev/null | grep -q '\.md$'; then
    [ -d "$ROOT/$d" ] && SPEC_DIRS+=("$ROOT/$d")
  else
    for r in "${ROOTS[@]}"; do
      [ -d "$r/$d" ] && SPEC_DIRS+=("$r/$d")
    done
  fi
  [ -d "$ROOT/$d" ] && LOCAL_SPEC_DIRS+=("$ROOT/$d")
done
# No spec tooling: fall back to .omc/state artifacts if this is an
# OMC-initialized project; plain repos (neither marker) are ungated.
if [ ${#SPEC_DIRS[@]} -eq 0 ]; then
  [ -d "$ROOT/.omc" ] || [ -d "${MAIN_ROOT:-/nonexistent}/.omc" ] || exit 0
  SPEC_DIRS=("$ROOT/.omc/state")
  mkdir -p "$ROOT/.omc/state" 2>/dev/null
fi
[ ${#LOCAL_SPEC_DIRS[@]} -eq 0 ] && LOCAL_SPEC_DIRS=("$ROOT/.omc/state")

LAST_COMMIT_TS=$(git log -1 --format=%ct 2>/dev/null || echo 0)
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
# A detached HEAD reports the literal "HEAD" in every worktree, so the marker
# would collide instead of discriminating. The worktree path is unique.
[ "$BRANCH" = HEAD ] && BRANCH="detached:${ROOT}"

# The marker is a header field, not prose: only the first lines count, so a
# worked example further down cannot claim the branch. CRLF is stripped so a
# file authored on Windows matches. Compared in awk against ENVIRON, not grep -F
# (a newline in the value splits an -F pattern into alternatives) and not awk -v
# (which backslash-escape-decodes the value); both would misread a path.
marker_present() {
  head -n 10 "$1" 2>/dev/null | tr -d '\r' |
    MARKER="Branch: ${BRANCH}" awk '$0 == ENVIRON["MARKER"] { f = 1 } END { exit !f }'
}

# Spec .md files touched since the last commit. mtime-based so it works for
# git-ignored spec dirs, but a fresh worktree checkout stamps every tracked file
# with "now", so a tracked candidate must also be dirty in git's eyes.
fresh_spec_mds() {
  find "${SPEC_DIRS[@]}" -name '*.md' -newermt "@${LAST_COMMIT_TS}" 2>/dev/null |
    while IFS= read -r f; do
      # Anything outside this worktree lives in the shared main checkout, which
      # every linked worktree sees, so it must name this branch to count.
      case "$f" in
        "$ROOT"/*) ;;
        *) marker_present "$f" || continue ;;
      esac
      if git ls-files --error-unmatch -- "$f" >/dev/null 2>&1; then
        [ -n "$(git status --porcelain -- "$f" 2>/dev/null)" ] && printf '%s\n' "$f"
      else
        printf '%s\n' "$f"
      fi
    done
}
# Verdict/delta evidence for push and PR is searched in THIS worktree only. The
# main checkout's ignored spec dir is shared by every linked worktree, so
# including it lets an unrelated branch's fresh verdict open this branch's gate.
recent_spec_mds() {
  find "${LOCAL_SPEC_DIRS[@]}" -name '*.md' -mmin -2880 2>/dev/null
}

case "$GATE" in
  commit)
    [ -n "$(fresh_spec_mds)" ] && exit 0
    MARKER=""
    [ "${MAIN_ROOT:-$ROOT}" != "$ROOT" ] && MARKER=" A ledger outside this worktree is shared with every other worktree, so it only counts if it carries a line reading exactly 'Branch: ${BRANCH}'."
    deny "spec-gates: no spec .md under ${SPEC_DIRS[*]} was updated since the last commit. Record findings/decisions in the story or spec doc (with a change-log row), then retry.${MARKER} Escape hatch: OMC_SKIP_HOOKS=spec-gates."
    ;;
  push)
    # A bare "PASSED" anywhere in a week-old ledger satisfied this gate; require
    # a verdict line dated today or yesterday instead.
    VERDICT_RE="Adversarial review: PASSED \(round [0-9]+, ($(date +%F)|$(date -d yesterday +%F 2>/dev/null || date -v-1d +%F))\)"
    RECENT=$(recent_spec_mds)
    if [ -n "$RECENT" ] && printf '%s\n' "$RECENT" | xargs -r grep -lE "$VERDICT_RE" >/dev/null 2>&1; then exit 0; fi
    if [ -f "$ROOT/.omc/state/adversarial-verdict" ] && grep -qE "$VERDICT_RE" "$ROOT/.omc/state/adversarial-verdict" 2>/dev/null; then exit 0; fi
    deny "spec-gates: no current PASSED verdict found in this worktree. A recent spec .md (${LOCAL_SPEC_DIRS[*]}) or ${ROOT}/.omc/state/adversarial-verdict must contain a line of the form 'Adversarial review: PASSED (round N, YYYY-MM-DD)' dated today or yesterday. Evidence from another worktree does not count. Escape hatch: OMC_SKIP_HOOKS=spec-gates."
    ;;
  pr)
    # Local ref only — `git remote show origin` hits the network and can hang.
    BASE=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')
    BASE=${BASE:-main}
    # An unresolvable base means the diff is unknown, not that nothing changed.
    if git rev-parse --verify --quiet "origin/${BASE}" >/dev/null 2>&1; then
      INFRA=$(git diff --name-only "origin/${BASE}...HEAD" 2>/dev/null | grep -E '(^|/)(\.github/workflows/|\.github/actions/|terraform/|Dockerfile([./]|$)|docker-compose[^/]*\.ya?ml|\.pre-commit-config\.yaml|action\.ya?ml)' || true)
    else
      INFRA="origin/${BASE} unresolvable"
    fi
    [ -z "$INFRA" ] && exit 0
    RECENT=$(recent_spec_mds)
    if [ -n "$RECENT" ] && printf '%s\n' "$RECENT" | xargs -r grep -li 'behavior[- ]delta' >/dev/null 2>&1; then exit 0; fi
    if [ -s "$ROOT/.omc/state/delta-table.md" ]; then exit 0; fi
    deny "spec-gates: this branch changes CI/infra but no behavior-delta table was found (a 'Behavior delta' section in a recent spec .md, or .omc/state/delta-table.md). Write one row per run type (branch/main/tag/prod), before vs after, then retry. Escape hatch: OMC_SKIP_HOOKS=spec-gates."
    ;;
esac
exit 0
