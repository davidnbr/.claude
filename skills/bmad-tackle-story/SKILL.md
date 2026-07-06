---
name: bmad-tackle-story
description: 'Tackle an existing BMAD story (or story range like aks-1-3..aks-1-5) end-to-end by orchestrating a dev→review→resolve loop: a coder subagent runs /bmad-dev-story, the review gate runs /bmad-code-review inline (it fans out its own parallel adversarial layers), and a resolver subagent runs /bmad-resolve-review — looping until the review is clean with zero findings. Use when the user says "tackle story X", "tackle aks-1-3..aks-1-5", "run the dev/review loop on this story", or "build this story with a team".'
model: opus
disable-model-invocation: true
arguments: [story]
---

# Tackle Story Workflow

**Goal:** Drive BMAD story `$story` (single id or `a..b` range) from "drafted" to "review-clean" by orchestrating a loop — a subagent codes, an adversarial review gate judges, a subagent resolves — until the review produces zero findings.

**Your Role:** Build Loop Orchestrator, running in the main (Opus) session. You do NOT write story code yourself. You spawn subagents, run the review gate, route structured outputs, verify claims, and decide when the loop is done.

## Non-Negotiable Principles

1. **DO NOT ASSUME ANYTHING. VERIFY COMPLETELY.** Every plan claim, every review finding, every "done" — checked against authoritative sources (the loaded rule set, the actual code, vendor docs via MCP/WebFetch) before you act on it. Reconstructed-from-memory facts are forbidden.
2. **DRY, KISS, YAGNI.** Smallest correct change. No speculative resources, variables, or abstractions.
3. **Author and review are separate lanes.** The coder subagent never approves its own work. Review always runs in fresh contexts (the review skill's own layer subagents).
4. **The loop ends on evidence, not vibes.** Done = a clean review pass with zero actionable findings, confirmed by the validation chain. Not "significant progress."
5. **Surface surprises immediately.** Unexpected `destroy`/`replace` in a plan, a finding that contradicts a project rule, a HALT from a subagent → stop and report to the user. Do not paper over.

## Step 0a — Preconditions & config

1. **Dependency check (HALT if missing):** confirm `bmad-dev-story` and `bmad-code-review` appear in this session's available-skills list (they are usually project-level skills). If either is missing, STOP and tell the user which one is absent and where it's expected (`<repo>/.claude/skills/`). Do not improvise a substitute silently.
2. Read `customize.toml` (skill root). It pins `[loop].max_iter`, `[loop].stall_rounds`, `[loop].sequential`, `[loop].skip_plan_verification`, the `[models]` map, the `[validation].chain`, and `[scope].never_without_ask`. The loaded file wins over the defaults quoted below; if the file is missing, use the documented defaults.

## Step 0b — Load rules

Follow `~/.claude/skills/_shared/load-rules.md` (read it now). Build **the loaded rule set** and select the **stack-appropriate validation chain** exactly as it describes. Pass both (absolute paths + substance) to every subagent you spawn.

## Step 0c — Locate & confirm scope

1. Resolve `$story` to actual spec file(s) under the project's BMAD story location. For a range, expand to the explicit ordered list. If you cannot locate them, ask the user — do not guess paths.
2. Read each story spec fully: acceptance criteria, tasks/subtasks, referenced architecture/plan.
3. Echo back: exact stories in scope, in order, and the files you'll likely touch per story. One line each. Proceed unless the user objects.

## Step 1 — Verify the plan (no code yet)

Spawn a **read-only architect/plan-verification subagent** (`model:` per `[models].plan_verify`, default `opus`):

- It reads the story spec(s) + referenced architecture, checks the plan against the loaded rule set and vendor docs, and flags **creation-time ordering, sequencing, dependency, and destroy/replace risks**. VERIFY claims, not assume.
- It returns the structured contract below with `lane: "plan"` and `plan_sound: true|false` plus ordered risks.

**If `plan_sound: false`** or it surfaces a destroy/replace or sequencing flaw → STOP, report to the user with the evidence, and wait. Do not enter the loop on a broken plan.

## Step 2 — The dev → review → resolve loop

Process stories **sequentially in dependency order** (see Parallelism note). For each story:

```
iteration = 1
loop:
  (a) CODE    — spawn coder subagent (model per [models].code, default sonnet)
                → runs /bmad-dev-story <story>          [iteration 1 only]
  (b) REVIEW  — invoke the bmad-code-review skill INLINE (main thread, not
                wrapped in a subagent) on the current diff
  (c) TRIAGE  — zero actionable findings → story DONE, exit loop
  (d) RESOLVE — spawn resolver subagent (model per [models].resolve, default opus)
                → runs /bmad-resolve-review on the findings (local mode)
  (e) iteration += 1
      if iteration > MAX_ITER (default 5)      → STOP, report stall to user
      if stall detected (see Step 3)           → STOP, report stall to user
  goto (b)   # re-REVIEW the resolver's diff — never re-run the coder unless
             # the review found unimplemented acceptance criteria, in which
             # case goto (a) with those ACs called out explicitly
```

### (a) Coder subagent
Spawn via the Agent tool. Instruct it to invoke the `bmad-dev-story` skill on the target story and **only** that story. It must:
- Implement to satisfy ALL acceptance criteria + tasks/subtasks.
- Run the stack-appropriate validation chain and report results verbatim.
- Update only the allowed story-file sections (Tasks checkboxes, Dev Agent Record, File List, Change Log, Status).
- Return the structured contract below. NOT self-approve.

### (b) Review gate — inline, never in a subagent
Invoke `bmad-code-review` yourself via the Skill tool, in the main thread. It fans out its own parallel adversarial layer subagents (fresh contexts — the author/review separation lives there). **Do not wrap it in a subagent**: nested fan-out is unreliable, and its no-subagents fallback HALTs waiting for user input, which silently stalls this loop. Direct it to:
- **Think like a state machine**: enumerate states/transitions the change introduces (resource lifecycle, creation→update→destroy, ordering, drift) and check each.
- Honor the loaded rule set; cite the rule or vendor doc behind every finding.
- Return findings in the structured contract (severity, file:line, rule/source, smallest correct fix). Explicitly `findings: []` when clean.

### (c) Triage
- `findings` empty → story DONE.
- Otherwise assign each finding a stable `id` (`<file>#<rule-or-short-slug>`), record the iteration's findings (see Step 3), and carry them to resolve.
- If a finding contradicts a project rule or smells wrong, do NOT auto-fix — pass it to the resolver flagged as disputed; a finding can be wrong (YAGNI). The resolver verifies and rebuts with evidence if warranted.

### (d) Resolver subagent
Spawn a subagent to invoke `bmad-resolve-review` in **local mode** (no PR, no user interaction — it must not wait for user input). It verifies each finding against authoritative sources, applies the smallest correct fix to valid ones, rebuts invalid ones with cited evidence, re-runs the validation chain, and returns the structured contract. Then goto (b).

## Structured lane contract

Every lane returns exactly this JSON (as its final output — instruct each subagent explicitly):

```json
{
  "lane": "plan|code|review|resolve",
  "status": "done|halt",
  "halt_reason": "only when status=halt",
  "plan_sound": "plan lane only: true|false",
  "findings": [
    {"id": "path/file.tf#rule-slug", "severity": "critical|major|minor",
     "file": "path", "line": 0, "rule": "cited rule or doc URL",
     "summary": "one line", "fix": "smallest correct fix",
     "resolution": "resolve lane only: fixed|rebutted|deferred"}
  ],
  "files_changed": ["..."],
  "validation": [{"cmd": "...", "pass": true}]
}
```

If a lane returns freeform text instead, extract it into this shape yourself before triage — the loop's stall detection depends on stable finding ids.

## Step 3 — Convergence & stall handling

- Converged when a review pass returns `findings: []` AND the validation chain passes.
- **Stall detection:** persist each iteration's findings to `.omc/state/tackle-story/<story>.jsonl` (one JSON line per iteration). A finding whose `id` survives `stall_rounds` (default 2) consecutive review passes, or `iteration > max_iter` (default 5), = stall → STOP and report to the user with the surviving findings and evidence. Never loop silently forever.
- Log each iteration one line: `story aks-1-3 · iter 2 · review: 3 findings → resolved`.

## Step 4 — Finish

When all in-scope stories are review-clean:
- Summarize per story: status, files changed, iterations, final validation result.
- Do NOT commit, push, or open a PR unless the user asks (`[scope].never_without_ask`) — that's `bmad-resolve-review`/`open-pr` territory and outward-facing.

## Model Map

| Lane | Where it runs | Model (via Agent tool `model` param) | Skill |
|---|---|---|---|
| Orchestrator | main session | opus (pinned by this skill's frontmatter) | — |
| Plan verify | subagent, read-only | `opus` alias (latest Opus) | — |
| Code | subagent | `sonnet` alias (latest Sonnet) | `bmad-dev-story` |
| Review gate | **inline** (its layers are subagents inheriting the session model) | session model (opus) | `bmad-code-review` |
| Resolve | subagent | `opus` alias | `bmad-resolve-review` |

Aliases float to the latest model in each family — never pin version numbers here.

## Parallelism

Default **sequential in dependency order** (`[loop].sequential = true`). Parallel loops across independent stories are allowed ONLY if (1) the verified plan confirms independence AND (2) each story's coder/resolver subagents run with `isolation: "worktree"` — concurrent subagents editing one shared working tree corrupt each other's diffs and the review gate's scope. When in doubt, stay sequential (KISS).

## Spawning Notes

- Pass every subagent: the resolved story file path(s), the loaded rule set (absolute paths + guardrail substance), the stack-appropriate validation chain, the structured lane contract, and the explicit "VERIFY, don't assume / DRY-KISS-YAGNI" directive.
- Subagents cannot ask the user questions — give them everything they need up front; a HALT status is their only escape hatch.
- Relay only the substance of each lane's return to the user — not raw context dumps.
