# Harness and rules refinement — audit ledger

Date: 2026-08-20
Origin: CEP-1140 staging perimeter-auth incident (wgfc-org/kubernetes).
Scope directive (final, from user): **ALL changes live in the local `~/.claude`
setup only.** Nothing ships to the repo.

## Withdrawal record

An earlier iteration shipped repo-side artifacts on branch
`worktree-harness-rules-refinement` (commit 2994b92): a repo root `CLAUDE.md`,
`.claude/spec-gates-infra.regex`, and a ledger under `_bmad-output/`. PR #18
was opened, then **closed as withdrawn** per the directive above; the remote
branch was deleted (verified `[deleted]` on push). The commit survives only in
the local worktree `.claude/worktrees/harness-rules-refinement` and can be
discarded with that worktree. Everything of value was relocated as below.

## Incident findings encoded as rules

| # | Finding (verified during the incident) | Where it now lives |
|---|---|---|
| 1 | Argo CD `selfHeal` reverts manual `kubectl apply` within minutes; hotfix = merge PR or flip ApplicationSet `targetRevision`, then revert | `~/.claude/CLAUDE.md` project-rules section; toml fact |
| 2 | ApplicationSet files are not self-managed; edits need `kubectl apply` | same |
| 3 | Cilium CNP flips selected endpoints to default-deny per direction; every edge A→B needs egress allow in A AND ingress allow in B; IC policies in `apps/ingress-nginx/policies/`, app-side in `apps/network-policies/` chart | same |
| 4 | `Valid=True` / `Synced` / CF Trace match are simulation, not traffic; "works" = real request observed in destination pod logs | same + delivery-core non-negotiable 10 |
| 5 | Third-party config (Cloudflare rules, Entra apps) verified by reading back the deployed object field-by-field incl. rule TYPE, plus an empirical probe | same |
| 6 | Cookie secrets consumed as URL-safe base64 must be generated that way: `openssl rand -base64 32 \| tr -- '+/' '-_'` | same |
| 7 | Behavior-delta PR gate never fired for this repo: default INFRA regex only matches `.github/workflows/`, `terraform/`, Dockerfiles etc., never `apps/`/`argocd/` | closed — see gate extension below |

## Changes implemented (all under ~/.claude, plus one gitignored local file)

1. **`~/.claude/CLAUDE.md`** — new section
   `## Project rules — wgfc-org/kubernetes (apply ONLY in that repo / its worktrees)`:
   GitOps operating rules, mutation split (user runs `kubectl apply/patch/delete`,
   `az` writes, `terraform apply`; assistant runs reads and `terraform plan` with
   state-lock announcement), Cilium reciprocal-policy law, wire-level verification
   bar, validation chain (`yamllint → helm lint/template → kubeconform → checkov`
   + wire probe), secrets rules, commit/PR conventions.
2. **`~/.claude/hooks/spec-gates.sh`** — PR-gate INFRA regex extension, two
   sources, first hit wins: repo-committed `.claude/spec-gates-infra.regex`
   (worktree copy over main checkout), else user-local
   `~/.claude/spec-gates-infra.d/<main-checkout-basename>.regex`. Fail-safe:
   extension regex validated alone (`grep -E` exit ≥2 → dropped) so a bad regex
   can neither break the hook nor silently open the gate.
3. **`~/.claude/spec-gates-infra.d/kubernetes.regex`** — `^(apps|argocd)/`.
   This is the ~/.claude-only opt-in that makes the behavior-delta gate fire
   for the kubernetes repo's manifests, with no repo file needed.
4. **`~/.claude/skills/_shared/verified-delivery-core.md`** — stages now
   V, P, A, R, S. Added: non-negotiable 9 (coverage ladder: unit → integration
   → e2e → mutation where the stack has a maintained tool, verified at run
   time; declarative stacks use kubeconform/conftest/checkov + empirical probe;
   skipped rungs need a one-line ledger reason); non-negotiable 10 (wire-level
   verification beats simulation; deployed third-party config read-back);
   behavior-delta table on EVERY unit (single row `none — internal only`
   allowed); Stage R report contract (what was done; behavior + delta table;
   logic & data flow with file:line hops; mermaid stateDiagram-v2 for stateful
   flows; 3–10 key functions/entry points; evidence links).
5. **`~/.claude/skills/verified-tackle/SKILL.md`** and
   **`~/.claude/skills/bmad-verified-tackle/SKILL.md`** — stages V, P, A, R, S;
   final message = the core's Stage R report contract.
6. **`_bmad/custom/bmad-dev-story.toml`** (main checkout, gitignored, local
   only) — 15 persistent facts incl. the five incident rules; header points to
   the ~/.claude/CLAUDE.md project-rules section as the canonical copy.

## Test evidence

Suite: `~/.claude/hooks/tests/spec-gates-regex-extension-test.sh`
(throwaway repo via `mktemp -d`, real PreToolUse JSON piped into the hook,
sandbox commits use `--no-verify` to bypass the global git-template hook).
Run 2026-08-20, literal output:

```
PASS: bash -n
PASS: no-extension -> no deny
PASS: extension -> deny
PASS: extension + delta -> allow
PASS: invalid regex -> default only, no deny
PASS: default regex survives invalid extension
PASS: user-side extension -> deny
PASS: repo file precedence over user-side
ALL PASS
```

One test bug was found and fixed during this run: `git reset --hard` in case 5
teardown removed the emptied `.claude/` directory, so case 7's regex write
silently failed (`mkdir -p .claude` added). The hook behaved correctly
throughout; a controlled reproduction proved the root cause before the fix.

## Behavior-delta table

| Surface | Before | After |
|---|---|---|
| `gh pr create/edit` in kubernetes repo, diff touches `apps/` or `argocd/` | allowed with no delta evidence | **denied** unless a behavior-delta table exists in a recent ledger (narrowing, intended) |
| Same, diff touches only other paths | gate skips | unchanged |
| Any repo with a committed `.claude/spec-gates-infra.regex` | file ignored | regex appended to INFRA default; repo file wins over user-side |
| Any repo with an invalid extension regex | n/a | extension dropped, default INFRA regex intact (fail-safe) |
| PRs opened via GitHub web UI | ungated | unchanged — known bypass, accepted |
| verified-tackle / bmad-verified-tackle final report | free-form summary | Stage R contract (delta table, data flow, state diagram, key functions, evidence) |
| Delivery-core coverage requirement | tests "as appropriate" | explicit ladder incl. mutation testing; skipped rungs justified in ledger |
| kubernetes repo working tree | repo CLAUDE.md + gate regex proposed (PR #18) | **withdrawn** — repo untouched; rules live in ~/.claude only |

## Known limitations

- Web-UI PR creation bypasses the gate (hook only sees `gh` commands).
- Extension regex is evaluated per `gh pr` invocation; negligible runtime cost accepted.
- `~/.claude/spec-gates-infra.d/` is keyed by main-checkout basename; a second
  repo also named `kubernetes` would share the entry.
- The gitignored toml does not propagate via git; copy manually onto new clones.

## Adversarial review record

Round 1 (separate critic lane): REVISE — (a) toml header falsely claimed the
file was committed; (b) test-suite claim lacked a persisted evidence artifact.
Both fixed. Round 2: ACCEPT-WITH-RESERVATIONS — residual: toml fact 7 grouped
`terraform plan` with user-run `apply`; fixed (plan is read-only,
assistant-runnable, announced). Critic re-ran the test suite independently;
output byte-identical.

Adversarial review: PASSED (round 2, 2026-08-20)

## Change log

| Date | Change |
|---|---|
| 2026-08-20 | Repo-side iteration built, reviewed (2 rounds), PR #18 opened |
| 2026-08-20 | User directive: ~/.claude only. PR #18 closed, remote branch deleted |
| 2026-08-20 | Rules relocated to ~/.claude/CLAUDE.md; gate opt-in relocated to spec-gates-infra.d/kubernetes.regex; hook extended with user-side fallback |
| 2026-08-20 | Test suite extended to 8 cases; case-7 test bug found (git reset pruned .claude/), fixed; 8/8 PASS |
| 2026-08-20 | toml header canonical pointer corrected; this ledger written |
| 2026-08-21 | Generalization pass (user directive: no single-project rules in global config). Project section removed from ~/.claude/CLAUDE.md; replaced by a Scoping Rule + "Systems Verification Lessons (general)" distilling the patterns: reconciled systems mutate source of truth; end-to-end observation only; deployed third-party read-back; default-deny is directional; verify the checker before the code; fail-safe extension points; persisted re-runnable evidence; state claims verified at write time; withdrawal is full unwind; complete instructions to humans. Project facts stay only in the repo-local gitignored toml (now canonical, header re-pointed, 15 facts, parses). delivery-core: project-flavored Stage R example generalized; non-negotiable 11 cross-refs the global lessons. Sweep confirms zero single-project references in global CLAUDE.md and all three skill files. Per-repo gate opt-in stays as data in ~/.claude/spec-gates-infra.d/ (general mechanism, per-repo slot). |
| 2026-08-21 | CLAUDE.md trim (user-approved items 1–4): agent-team table deleted (harness injects live agent list; table had drifted — `architect-review` vs live `architect-reviewer`), generic Code Quality bullets deleted (guardrails section kept, promoted to `##`), Security condensed to 2 lines, writing-style rules moved verbatim to ~/.claude/rules/writing-style.md (31 lines, loads every session). Result: 250→194 lines, under the 200 target. Verified: headings intact, style list present only in the rules file, Delivery Protocol untouched so cross-file pointers stay valid. Item 5 (Refactoring Protocol condense) and the AWS-preference flag left as-is per scope. |
| 2026-08-21 | Primary-source verification pass (user directive: verify against current Anthropic recommendations, no memory). Sources fetched and read: code.claude.com/docs/en/memory (CLAUDE.md: target <200 lines, specific/concise/consistent, hooks not instructions for must-run actions, ~/.claude/rules/ per-topic files), anthropic.com claude-code best-practices via docs (prune by "would removing this cause mistakes", give Claude a runnable check, fresh-context reviewer, hooks deterministic vs CLAUDE.md advisory), docs.claude.com agent-skills best-practices (third-person description with what+when, SKILL.md <500 lines, one-level references, copyable checklists, validation loops), anthropic.com effective-context-engineering (minimal high-signal tokens, right altitude, canonical examples). Fixes applied: general lessons moved from ~/.claude/CLAUDE.md (312→250 lines) into ~/.claude/rules/verification-lessons.md (48 lines, tightened, joins existing per-topic rules); copyable V-P-A-R-S stage checklist added to verified-delivery-core.md (181 lines, under 500). Confirmed compliant: skill descriptions (what+when+usage), reference depth, deterministic enforcement via spec-gates hooks. Residual recommendation (user's call): CLAUDE.md still 250 lines — trim candidates are self-evident bullets (e.g. "Adhere to Clean Code") and content duplicated by OMC skills. |
