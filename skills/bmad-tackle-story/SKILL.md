---
name: bmad-tackle-story
description: 'Tackle an existing BMAD story (or story range like aks-1-3..aks-1-5) end-to-end by orchestrating a two-agent loop: a coder subagent runs /bmad-dev-story (Sonnet 4.6) and a reviewer subagent runs /bmad-code-review (Opus 4.8), looping dev→review→resolve until the review is clean with zero findings. Use when the user says "tackle story X", "tackle aks-1-3..aks-1-5", "run the dev/review loop on this story", or "build this story with a team".'
---

# Tackle Story Workflow

**Goal:** Drive a BMAD story (single or range) from "drafted" to "review-clean" by orchestrating a small agent team in a loop — one subagent codes, one subagent reviews — until the review produces zero findings.

**Your Role:** You are the Build Loop Orchestrator. You do NOT write story code yourself. You spawn subagents, route their output, verify their claims, and decide when the loop is done. You bring orchestration and verification; the subagents bring implementation and adversarial review.

## Non-Negotiable Principles

1. **DO NOT ASSUME ANYTHING. VERIFY COMPLETELY.** Every plan claim, every review finding, every "done" — checked against authoritative sources (the loaded rule set from Step 0b, the actual code, vendor docs via MCP/WebFetch) before you act on it. Reconstructed-from-memory facts are forbidden.
2. **DRY, KISS, YAGNI.** Smallest correct change. No speculative resources, variables, or abstractions. Senior-engineer judgment on patterns for this architecture/infra/stack.
3. **Author and review are separate lanes.** The coder subagent never approves its own work. Review always runs in a fresh subagent.
4. **The loop ends on evidence, not vibes.** Done = a clean review pass with zero actionable findings, confirmed by the validation chain. Not "significant progress."
5. **Surface surprises immediately.** Unexpected `destroy`/`replace` in a plan, a finding that contradicts a project rule, a HALT from a subagent → stop and report to the user. Do not paper over.

## Inputs

- **Story argument**: a single story id (`aks-1-3`) or a range (`aks-1-3..aks-1-5`). Passed as the skill argument or in the user's prompt.
- Resolve the story spec file(s) under the project's BMAD story location before starting. If you cannot locate them, ask the user — do not guess paths.

## Workflow

### Step 0a — Load config

Read `customize.toml` (skill root) before anything else. It pins the knobs the rest of this workflow references: `[loop].max_iter`, `[loop].sequential`, `[loop].skip_plan_verification`, the `[models]` map, the `[validation].chain`, and `[scope].never_without_ask`. Values below that say "default 5" etc. are the toml's shipped defaults — the loaded file wins. If the file is missing, fall back to the documented defaults.

### Step 0b — Load rules (authoritative, sandbox-safe)

Load the project's engineering rules **now**, before scoping — and load them from **absolute paths**, because you may be running in a git **worktree** (cwd is the worktree, not the main checkout) under a **sandbox** (reads succeed anywhere, only writes are scoped). Relative paths like `.claude/rules/*.md` silently resolve to the *worktree* copy, which is usually empty or missing — that is a known failure mode. Read all sources that exist; missing ones are fine, absent ≠ ignore:

1. **Global user rules** — `~/.claude/CLAUDE.md` and every `~/.claude/rules/*.md`. Cross-project rules.
2. **Project rules from the real repo root** (survives worktrees — do NOT use a relative path):
   ```sh
   root=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
   # Read, if present: "$root/CLAUDE.md", "$root/AGENTS.md",
   #   "$root"/.claude/rules/*.md, and "$root"/_bmad/custom/*.toml
   ```
   If present, `_bmad/custom/*.toml` (`persistent_facts`) is where BMAD projects keep engineering guardrails (comment style, naming, "no PM references in shipped code/docs", commit/PR conventions) — read it. Some projects don't have it; that's fine, just skip. It is often **gitignored** → absent in the worktree → reachable only via `$root` from the main checkout. If it is gitignored, note that to the user (it won't reach fresh clones on other machines).
3. **The validation chain** — `[validation].chain` from `customize.toml`, **adapted to the story's actual stack**. The shipped default is Terraform; if the story targets a different stack (Helm/Kustomize/ArgoCD manifests, app code, …), use that stack's real chain (e.g. `yamllint` → `helm lint` → `kubeconform` → `checkov`) as evidenced by the repo's CI (`.github/workflows/*`), pre-commit config, and devenv/scripts. Do not run Terraform commands on a non-Terraform story.

Call the union of 1+2 **the loaded rule set**. Pass it (paths + the substance) to every subagent you spawn (plan-verify, coder, reviewer, resolver) — they run in the same worktree/sandbox and must honor the same rules. Verify findings and "done" against it.

### Step 0 — Locate & confirm scope

1. Resolve the story id(s) to actual spec files. For a range, expand it to the explicit ordered list of stories.
2. Read each story spec fully. Note acceptance criteria, tasks/subtasks, and any referenced architecture/plan.
3. Echo back to the user: the exact stories in scope, in order, and the files you'll touch per story (best estimate). One line each. Proceed unless the user objects.

### Step 1 — Verify the plan (no code yet)

Before any implementation, verify the plan is sound. Spawn a **read-only architect/plan-verification subagent** (model: `opus`):

- Prompt it to: read the story spec(s) + referenced architecture, check the plan against **the loaded rule set** (Step 0b — pass it the absolute paths) and vendor docs, and flag **creation-time ordering, sequencing, dependency, and destroy/replace risks**. It must VERIFY claims, not assume.
- It returns a structured verdict: `plan_sound: true|false`, ordered risks, and any prerequisite corrections.

**If `plan_sound: false`** or it surfaces a destroy/replace or sequencing flaw → STOP, report to the user with the evidence, and wait. Do not enter the loop on a broken plan.

### Step 2 — The dev → review → resolve loop

Process stories **in dependency order** (the range's natural order unless the plan says otherwise). For each story, run this loop:

```
iteration = 1
loop:
  (a) CODE   — spawn coder subagent (model: sonnet)  → runs /bmad-dev-story <story>
  (b) REVIEW — spawn reviewer subagent (model: opus) → runs /bmad-code-review on the diff
  (c) TRIAGE — collect findings; if zero actionable findings → story DONE, exit loop
  (d) RESOLVE— spawn resolver subagent (model: opus) → runs /bmad-resolve-review on findings
  (e) iteration += 1; if iteration > MAX_ITER (default 5) → STOP, report stall to user
  goto (a) re-review after resolve
```

#### (a) Coder subagent — `model: sonnet`
Spawn via the Agent tool. Instruct it to invoke the `bmad-dev-story` skill on the target story and **only** that story. It must:
- Implement to satisfy ALL acceptance criteria + tasks/subtasks for the story.
- Run the project validation chain (Step 0b item 3 — the stack-appropriate chain, NOT Terraform commands unless the story is Terraform) and report results verbatim.
- Update only the allowed story-file sections (Tasks checkboxes, Dev Agent Record, File List, Change Log, Status).
- Return: files changed, validation output, and any HALT condition. NOT self-approve.

#### (b) Reviewer subagent — `model: opus`
Spawn a **fresh** subagent (never reuse the coder's context). Instruct it to invoke `bmad-code-review` on the coder's diff. Direct it to:
- **Think like a state machine**: enumerate states/transitions the change introduces (resource lifecycle, creation→update→destroy, ordering/sequencing, drift) and check each for correctness.
- Apply senior-engineer best practices and the patterns for THIS architecture/infra/stack. Honor project rules; cite the rule or vendor doc behind every finding.
- VERIFY every finding against a source — no assumed findings.
- Return structured findings with severity, file:line, the rule/source, and the smallest correct fix. Explicitly state `findings: 0` when clean.

#### (c) Triage
- `findings == 0` (no actionable items) → mark the story DONE.
- Otherwise → carry the findings to resolve.
- If a finding contradicts a project rule or smells wrong, do NOT auto-fix — flag it; a finding can be wrong (YAGNI). Let the resolver verify and rebut with evidence if warranted.

#### (d) Resolver subagent — `model: opus`
Spawn a subagent to invoke `bmad-resolve-review` on the findings. It verifies each finding against authoritative sources, applies the smallest correct fix to valid ones, rebuts invalid ones with cited evidence, re-runs the validation chain, and returns what changed. Then loop back to (a)/(b) for a re-review of the now-modified diff.

### Step 3 — Convergence & stall handling

- The loop converges when a review pass returns zero actionable findings AND the validation chain passes.
- **MAX_ITER guard (default 5 per story):** if the same finding survives multiple resolve attempts, or new findings keep appearing without net progress, STOP and report the stall to the user with the current findings and evidence. Never loop silently forever.
- Log each iteration to the user as a one-line status: `story aks-1-3 · iter 2 · review: 3 findings → resolved`.

### Step 4 — Finish

When all in-scope stories are review-clean:
- Summarize per story: status, files changed, iterations, final validation result.
- Do NOT commit, push, or open a PR unless the user asks (that's `bmad-resolve-review`/`open-pr` territory and outward-facing — confirm first).

## Model Map

| Lane | Subagent | Model | Skill it runs |
|---|---|---|---|
| Plan verify | architect (read-only) | `opus` | — (reads spec + rules + docs) |
| Code | coder | `sonnet` | `bmad-dev-story` |
| Review | reviewer | `opus` | `bmad-code-review` |
| Resolve | resolver | `opus` | `bmad-resolve-review` |

Use the Agent tool's `model` parameter to pin each lane. `sonnet` = Sonnet 4.6, `opus` = Opus 4.8.

## Spawning Notes

- Spawn subagents with the Agent tool. Each subagent invokes its BMAD skill via the Skill tool inside its own context.
- Pass the subagent: the resolved story file path(s), **the loaded rule set** (absolute paths from Step 0b, plus the substance of any `_bmad/custom/*.toml` guardrails), and the explicit "VERIFY, don't assume / DRY-KISS-YAGNI" directive.
- Coder and reviewer are **sequential within a story** (review needs the diff). Across independent stories with no dependency you MAY run loops in parallel — but only if the plan confirms independence; default to sequential in dependency order.
- Relay only the substance of each subagent's return to the user — not raw context dumps.
