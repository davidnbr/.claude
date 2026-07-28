#!/usr/bin/env bash
# spec-gates.sh — PreToolUse(Bash) delivery gates.
#
# Gates (only in repos that use spec-driven tooling — graceful no-op elsewhere):
#   git commit     -> a spec .md under _bmad-output/ or openspec/ must be
#                     updated since the last commit (findings ledger).
#   git push       -> a recent spec .md must record a PASSED review verdict,
#                     or fallback artifact .omc/state/adversarial-verdict.
#   gh pr create/edit (infra branches only) -> a behavior-delta table must
#                     exist in a recent spec .md or .omc/state/delta-table.md.
#
# Escape hatches: OMC_SKIP_HOOKS contains "spec-gates", or repo has neither
# spec directory. Blocking emits permissionDecision=deny with the reason.
set -u

deny() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$1"
  exit 0
}

INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[ -z "$CMD" ] && exit 0

case ",${OMC_SKIP_HOOKS:-}," in *,spec-gates,*|*,all,*) exit 0 ;; esac

# Which gate does this command hit? (regex over the whole string: compound
# commands like `git add … && git commit …` must still be caught)
GATE=""
if   printf '%s' "$CMD" | grep -qE '(^|[;&|]\s*)git\s+commit\b';      then GATE=commit
elif printf '%s' "$CMD" | grep -qE '(^|[;&|]\s*)git\s+push\b';        then GATE=push
elif printf '%s' "$CMD" | grep -qE '(^|[;&|]\s*)gh\s+pr\s+(create|edit)\b'; then GATE=pr
fi
[ -z "$GATE" ] && exit 0

[ -n "$CWD" ] && cd "$CWD" 2>/dev/null
ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$ROOT" || exit 0

SPEC_DIRS=()
[ -d _bmad-output ] && SPEC_DIRS+=(_bmad-output)
[ -d openspec ] && SPEC_DIRS+=(openspec)
# No spec tooling: fall back to .omc/state artifacts if this is an
# OMC-initialized project; plain repos (neither marker) are ungated.
if [ ${#SPEC_DIRS[@]} -eq 0 ]; then
  [ -d .omc ] || exit 0
  SPEC_DIRS=(.omc/state)
  mkdir -p .omc/state 2>/dev/null
fi

LAST_COMMIT_TS=$(git log -1 --format=%ct 2>/dev/null || echo 0)

# Spec .md files touched since the last commit (mtime-based, so it works for
# git-ignored spec dirs like CEP's _bmad-output/).
fresh_spec_mds() {
  find "${SPEC_DIRS[@]}" -name '*.md' -newermt "@${LAST_COMMIT_TS}" 2>/dev/null
}
# Spec .md files touched in the last 24h (push/pr gates: verdicts and delta
# tables may have been written before the final commit).
recent_spec_mds() {
  find "${SPEC_DIRS[@]}" -name '*.md' -mmin -1440 2>/dev/null
}

case "$GATE" in
  commit)
    [ -n "$(fresh_spec_mds)" ] && exit 0
    deny "spec-gates: no spec .md under ${SPEC_DIRS[*]} was updated since the last commit. Record findings/decisions in the story or spec doc (with a change-log row), then retry. Escape hatch: OMC_SKIP_HOOKS=spec-gates."
    ;;
  push)
    RECENT=$(recent_spec_mds)
    if [ -n "$RECENT" ] && printf '%s\n' "$RECENT" | xargs -r grep -l 'PASSED' >/dev/null 2>&1; then exit 0; fi
    if [ -f .omc/state/adversarial-verdict ] && grep -q 'PASSED' .omc/state/adversarial-verdict 2>/dev/null; then exit 0; fi
    deny "spec-gates: no PASSED review verdict found in a recent spec .md (${SPEC_DIRS[*]}) or .omc/state/adversarial-verdict. Run the adversarial review, record the verdict, then push. Escape hatch: OMC_SKIP_HOOKS=spec-gates."
    ;;
  pr)
    BASE=$(git remote show origin 2>/dev/null | sed -n 's/.*HEAD branch: //p')
    BASE=${BASE:-main}
    INFRA=$(git diff --name-only "origin/${BASE}...HEAD" 2>/dev/null | grep -E '^(\.github/workflows/|terraform/|Dockerfile)' || true)
    [ -z "$INFRA" ] && exit 0
    RECENT=$(recent_spec_mds)
    if [ -n "$RECENT" ] && printf '%s\n' "$RECENT" | xargs -r grep -li 'behavior[- ]delta' >/dev/null 2>&1; then exit 0; fi
    if [ -s .omc/state/delta-table.md ]; then exit 0; fi
    deny "spec-gates: this branch changes CI/infra but no behavior-delta table was found (a 'Behavior delta' section in a recent spec .md, or .omc/state/delta-table.md). Write one row per run type (branch/main/tag/prod), before vs after, then retry. Escape hatch: OMC_SKIP_HOOKS=spec-gates."
    ;;
esac
exit 0
