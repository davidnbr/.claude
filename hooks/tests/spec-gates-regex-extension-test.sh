#!/usr/bin/env bash
# Controlled test of spec-gates.sh PR-gate regex extension.
set -u
HOOK=~/.claude/hooks/spec-gates.sh
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

bash -n "$HOOK" || { echo "FAIL: syntax"; exit 1; }
echo "PASS: bash -n"

# Build a repo: origin/main + feature branch touching apps/ only.
git init -q "$T/repo"; cd "$T/repo"
git config user.email t@t; git config user.name t
mkdir -p apps _bmad-output .claude
echo base > apps/base.yaml
echo x > _bmad-output/ledger.md
git add -A; git commit -q --no-verify -m init
git branch -M main
git clone -q --bare . "$T/origin.git"
git remote add origin "$T/origin.git"; git fetch -q origin
git checkout -qb feat
echo change > apps/thing.yaml
git add -A; git commit -q --no-verify -m change
git fetch -q origin

run_hook() {
  printf '{"tool_input":{"command":"gh pr create"},"cwd":"%s"}' "$PWD" | bash "$HOOK"
}

# Case 1: no extension file -> apps/ path not infra -> gate skips (empty output).
OUT=$(run_hook)
[ -z "$OUT" ] && echo "PASS: no-extension -> no deny" || { echo "FAIL: no-extension denied: $OUT"; exit 1; }

# Case 2: valid extension -> apps/ now infra, no delta evidence -> deny.
printf '^(apps|argocd)/\n' > .claude/spec-gates-infra.regex
OUT=$(run_hook)
echo "$OUT" | grep -q '"permissionDecision":"deny"' && echo "PASS: extension -> deny" || { echo "FAIL: extension did not deny: $OUT"; exit 1; }

# Case 3: extension + fresh delta evidence -> allow.
printf '## Behavior delta\n| a | b |\n' > _bmad-output/delta.md
OUT=$(run_hook)
[ -z "$OUT" ] && echo "PASS: extension + delta -> allow" || { echo "FAIL: delta not honored: $OUT"; exit 1; }
rm _bmad-output/delta.md

# Case 4: INVALID extension regex -> fall back to default -> no deny (fail-safe, default intact).
printf '([\n' > .claude/spec-gates-infra.regex
OUT=$(run_hook)
[ -z "$OUT" ] && echo "PASS: invalid regex -> default only, no deny" || { echo "FAIL: invalid regex broke gate: $OUT"; exit 1; }

# Case 5: invalid extension must NOT disable default matching -> touch terraform/ -> deny.
mkdir -p terraform; echo t > terraform/main.tf
git add -A; git commit -q --no-verify -m tf
OUT=$(run_hook)
echo "$OUT" | grep -q '"permissionDecision":"deny"' && echo "PASS: default regex survives invalid extension" || { echo "FAIL: default regex lost: $OUT"; exit 1; }

# Back to an apps/-only diff for the user-side cases.
git reset -q --hard HEAD~1
run_hook_home() {
  printf '{"tool_input":{"command":"gh pr create"},"cwd":"%s"}' "$PWD" | HOME="$T/home" bash "$HOOK"
}
mkdir -p "$T/home/.claude/spec-gates-infra.d"
printf '^(apps|argocd)/\n' > "$T/home/.claude/spec-gates-infra.d/repo.regex"

# Case 6: no repo file, user-side ~/.claude/spec-gates-infra.d/<basename>.regex -> deny.
rm -f .claude/spec-gates-infra.regex
OUT=$(run_hook_home)
echo "$OUT" | grep -q '"permissionDecision":"deny"' && echo "PASS: user-side extension -> deny" || { echo "FAIL: user-side extension ignored: $OUT"; exit 1; }

# Case 7: repo file wins over user-side (repo regex matches nothing -> no deny).
# git reset above removed the empty .claude/ dir along with the tracked file.
mkdir -p .claude
printf '^never-matches-anything/\n' > .claude/spec-gates-infra.regex
OUT=$(run_hook_home)
[ -z "$OUT" ] && echo "PASS: repo file precedence over user-side" || { echo "FAIL: precedence wrong: $OUT"; exit 1; }

echo "ALL PASS"
