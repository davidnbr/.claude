#!/usr/bin/env bash
# Controlled test of spec-gates.sh PR gate: any code change requires
# behavior-delta + coverage evidence; docs-only diffs exempt.
set -u
HOOK=~/.claude/hooks/spec-gates.sh
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

bash -n "$HOOK" || { echo "FAIL: syntax"; exit 1; }
echo "PASS: bash -n"

# Repo: origin/main + feature branch touching a code file.
git init -q "$T/repo"; cd "$T/repo"
git config user.email t@t; git config user.name t
mkdir -p apps _bmad-output
echo base > apps/base.yaml
echo x > _bmad-output/ledger.md
git add -A; git commit -q --no-verify -m init
git branch -M main
git clone -q --bare . "$T/origin.git"
git remote add origin "$T/origin.git"; git fetch -q origin
git checkout -qb feat

run_hook() {
  printf '{"tool_input":{"command":"gh pr create"},"cwd":"%s"}' "$PWD" | bash "$HOOK"
}

# Case 1: docs-only diff -> exempt, no deny.
echo doc > notes.md
git add -A; git commit -q --no-verify -m docs
OUT=$(run_hook)
[ -z "$OUT" ] && echo "PASS: docs-only diff -> no deny" || { echo "FAIL: docs-only denied: $OUT"; exit 1; }

# Case 2: code change, no evidence -> deny naming both.
echo change > apps/thing.yaml
git add -A; git commit -q --no-verify -m change
OUT=$(run_hook)
echo "$OUT" | grep -q '"permissionDecision":"deny"' \
  && echo "$OUT" | grep -q 'behavior-delta table' && echo "$OUT" | grep -q 'coverage evidence' \
  && echo "PASS: code change, no evidence -> deny (both named)" \
  || { echo "FAIL: code change not denied or names missing: $OUT"; exit 1; }

# Case 3: delta alone -> deny naming coverage only.
printf '## Behavior delta\n| a | b |\n' > _bmad-output/delta.md
OUT=$(run_hook)
echo "$OUT" | grep -q '"permissionDecision":"deny"' \
  && echo "$OUT" | grep -q 'coverage evidence' && ! echo "$OUT" | grep -q 'behavior-delta table' \
  && echo "PASS: delta without coverage -> deny (coverage named)" \
  || { echo "FAIL: delta-only wrong: $OUT"; exit 1; }

# Case 4: delta + coverage heading -> allow.
printf '## Coverage\n| unit | ran |\n' > _bmad-output/coverage.md
OUT=$(run_hook)
[ -z "$OUT" ] && echo "PASS: delta + coverage heading -> allow" || { echo "FAIL: coverage heading not honored: $OUT"; exit 1; }
rm _bmad-output/coverage.md

# Case 5: coverage via .omc/state mirror -> allow.
mkdir -p .omc/state
printf 'unit: ran\n' > .omc/state/coverage.md
OUT=$(run_hook)
[ -z "$OUT" ] && echo "PASS: coverage via .omc mirror -> allow" || { echo "FAIL: .omc coverage mirror not honored: $OUT"; exit 1; }
rm -rf .omc

# Case 6: coverage alone ("coverage ladder" phrase), no delta -> deny naming delta only.
rm _bmad-output/delta.md
printf 'coverage ladder\n' > _bmad-output/coverage.md
OUT=$(run_hook)
echo "$OUT" | grep -q '"permissionDecision":"deny"' \
  && echo "$OUT" | grep -q 'behavior-delta table' && ! echo "$OUT" | grep -q 'coverage evidence' \
  && echo "PASS: coverage without delta -> deny (delta named)" \
  || { echo "FAIL: coverage-only wrong: $OUT"; exit 1; }
rm _bmad-output/coverage.md

# Case 7: unresolvable base -> diff unknown -> deny (fail-closed).
git remote remove origin
git update-ref -d refs/remotes/origin/main 2>/dev/null || true
OUT=$(run_hook)
echo "$OUT" | grep -q '"permissionDecision":"deny"' \
  && echo "PASS: unresolvable base -> deny (fail-closed)" \
  || { echo "FAIL: unresolvable base not denied: $OUT"; exit 1; }

# Case 8: plain repo (no spec dirs, no .omc) -> graceful no-op.
git init -q "$T/plain"; cd "$T/plain"
git config user.email t@t; git config user.name t
echo a > code.py; git add -A; git commit -q --no-verify -m init
OUT=$(run_hook)
[ -z "$OUT" ] && echo "PASS: plain repo -> ungated" || { echo "FAIL: plain repo gated: $OUT"; exit 1; }

echo "ALL PASS"
