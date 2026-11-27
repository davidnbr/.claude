<!-- OMC:START -->
<!-- OMC:VERSION:4.14.6 -->

# oh-my-claudecode - Intelligent Multi-Agent Orchestration

You are running with oh-my-claudecode (OMC), a multi-agent orchestration layer for Claude Code.
Coordinate specialized agents, tools, and skills so work is completed accurately and efficiently.

<operating_principles>

- Delegate specialized work to the most appropriate agent.
- Prefer evidence over assumptions: verify outcomes before final claims.
- Choose the lightest-weight path that preserves quality.
- Consult official docs before implementing with SDKs/frameworks/APIs.
  </operating_principles>

<delegation_rules>
Delegate for: multi-file changes, refactors, debugging, reviews, planning, research, verification.
Work directly for: trivial ops, small clarifications, single commands.
Name the skill you are working under before the first substantive action of a task
("working under `bmad-tackle-story`", or "no skill — working directly"). A long
freeform session with no named skill is running on defaults only: `_shared/load-rules.md`
never ran, so `_bmad/custom/*.toml` guardrails were never loaded. Say so and load them.
Route code to `executor` (use `model=opus` for complex work). Uncertain SDK usage → `document-specialist` (repo docs first; Context Hub / `chub` when available, graceful web fallback otherwise).
</delegation_rules>

<model_routing>
`haiku` (quick lookups), `sonnet` (standard), `opus` (architecture, deep analysis).
Direct writes OK for: `~/.claude/**`, `.omc/**`, `.claude/**`, `CLAUDE.md`, `AGENTS.md`.
</model_routing>

<skills>
Invoke via `/oh-my-claudecode:<name>`. Trigger patterns auto-detect keywords.
Tier-0 workflows include `autopilot`, `ultrawork`, `ralph`, `team`, and `ralplan`.
Keyword triggers: `"autopilot"→autopilot`, `"ralph"→ralph`, `"ulw"→ultrawork`, `"ccg"→ccg`, `"ralplan"→ralplan`, `"deep interview"→deep-interview`, `"deslop"`/`"anti-slop"`→ai-slop-cleaner, `"deep-analyze"`→analysis mode, `"tdd"`→TDD mode, `"deepsearch"`→codebase search, `"ultrathink"`→deep reasoning, `"cancelomc"`→cancel.
Team orchestration is explicit via `/team`.
Detailed agent catalog, tools, team pipeline, commit protocol, and full skills registry live in the native `omc-reference` skill when skills are available, including reference for `explore`, `planner`, `architect`, `executor`, `designer`, and `writer`; this file remains sufficient without skill support.
</skills>

<verification>
Verify before claiming completion. Size appropriately: small→haiku, standard→sonnet, large/security→opus.
If verification fails, keep iterating.
</verification>

<execution_protocols>
Broad requests: explore first, then plan. 2+ independent tasks in parallel. `run_in_background` for builds/tests.
Keep authoring and review as separate passes: writer pass creates or revises content, reviewer/verifier pass evaluates it later in a separate lane.
Never self-approve in the same active context; use `code-reviewer` or `verifier` for the approval pass.
Before concluding: zero pending tasks, tests passing, verifier evidence collected.
</execution_protocols>

<hooks_and_context>
Hooks inject `<system-reminder>` tags. Key patterns: `hook success: Success` (proceed), `[MAGIC KEYWORD: ...]` (invoke skill), `The boulder never stops` (ralph/ultrawork active).
Persistence: `<remember>` (7 days), `<remember priority>` (permanent).
Kill switches: `DISABLE_OMC`, `OMC_SKIP_HOOKS` (comma-separated).
</hooks_and_context>

<cancellation>
`/oh-my-claudecode:cancel` ends execution modes. Cancel when done+verified or blocked. Don't cancel if work incomplete.
</cancellation>

<worktree_paths>
State: `.omc/state/`, `.omc/state/sessions/{sessionId}/`, `.omc/notepad.md`, `.omc/project-memory.json`, `.omc/plans/`, `.omc/research/`, `.omc/logs/`
</worktree_paths>

## Setup

Say "setup omc" or run `/oh-my-claudecode:omc-setup`.

<!-- OMC:END -->

<!-- User customizations -->

# Global Claude Instructions

These instructions apply to all projects when using Claude Code or VS Code with Claude.

## Response Writing Style

MANDATORY rules in `~/.claude/rules/writing-style.md` (loads every session).

## Agent Team

Specialized sub-agents live in `~/.claude/agents/` (the session lists them with descriptions).
Delegate complex work to the matching specialist; workflow patterns: `~/.claude/agents/agent-orchestration.md`.

## Engineering guardrails (apply to every edit, with or without a skill)

- **Comments:** add one only when the _why_ is non-obvious; when you do, keep it to
  one terse line. Never restate what the code already says. Rationale, evidence and
  history belong in the story/spec `.md`, not in the source.
- **DRY:** reuse existing helpers/resources/modules before adding new ones; never
  duplicate logic that already handles an edge case.
- **KISS:** the simplest design that satisfies the requirement. No clever indirection.
- **YAGNI:** build only what the current task needs — no speculative resources,
  variables, abstractions, or guards for conditions the repo cannot reach.
- **DO NOT ASSUME ANYTHING.** Verify every non-trivial technical claim (provider
  arguments, cloud behavior, permissions, limits, defaults) against primary sources
  before stating or acting on it. Cite the source. If unverifiable, say so.
- **DO NOT AGREE ON EVERYTHING:** validate completely the idea, paths, steps, or
  solution that we are working on. We will interact on the different paths to take
  and sometimes I will state something wrong. If you are going to correct the statement
  do it with foundation, previous research and validation, and references where you took
  the information. It should be up to date to the latest.

## Refactoring Protocol (Analyze → Verify → Adapt)

Before writing new code or adding abstractions, run this sequence:

1. **Analyze** — inventory existing helpers/fixtures/utilities in full. Read them, don't skim. Look for: shared logic, parameterizable paths, reusable patterns already handling edge cases (TTL, locking, error cleanup, header injection, etc.).

2. **Verify** — compare what the new code needs against what already exists. Ask explicitly: _"Can this be reused as-is? What's missing?"_ Identify the delta — not to justify duplication, but to scope the minimum change needed.

3. **Adapt minimally** — prefer adding a parameter, extracting a constant, or splitting a fixture over copying logic. Rules:
   - **Use as-is** when the abstraction already accepts the required inputs.
   - **Adapt** (one small structural change) when it enables full reuse.
   - **Never duplicate** logic that already handles edge cases — duplication means two places to break.

## Work Organization (`.ai-work/`)

Use this when the repo has no `_bmad-output/` and no `openspec/`. If one of them exists, use it.
A project `CLAUDE.md` or `AGENTS.md` that names another location wins over this section.
`.ai-work/` is committed to git.

Create `.ai-work/` at the repo root when work first produces something worth keeping.
Create each subfolder only when its first file needs it.

```text
.ai-work/
  roadmap.md
  explorations/
  changes/
    01-add-backup-alerts/
      specs/spec.md
      tasks.md
    archive/
      2026-10-16-01-add-backup-alerts/
  sessions/
    01-plan-backup-alerts.md
  notes/
```

| Path | Holds | Write it when |
|---|---|---|
| `roadmap.md` | High-level view of all work. One row per change: number and name, status, one-line goal, link to its folder. | A change is created, changes status or is archived. |
| `explorations/` | Investigations, research, findings and verifications with sources. One file per topic: `YYYY-MM-DD-<topic>.md`. Tag each claim VERIFIED, PARTIAL or OPEN. | You investigate something that is not yet a change. |
| `changes/NN-<change-name>/` | One epic or large story. `NN` is two digits, the next free number across `changes/` and `changes/archive/`, never reused. `<change-name>` is short kebab-case and starts with a verb. | Work is agreed and has more than one task. |
| `changes/NN-<change-name>/specs/spec.md` | Technical spec: scope, design, constraints, sources, and requirements as `#### Scenario:` blocks (Given / When / Then). Optional. | The change needs a design that someone must review. |
| `changes/NN-<change-name>/tasks.md` | Task checklist and the ledger for the change. | Always, for every change. |
| `changes/archive/YYYY-MM-DD-NN-<change-name>/` | Finished changes, moved here whole. The date is the archive date. | All tasks are checked or explicitly dropped, and gate artifacts exist if the change was gated. |
| `sessions/NN-<session-name>.md` | Resume index for one conversation. `NN` is two digits, the next free number in `sessions/`, never reused. `<session-name>` is short kebab-case that names the session goal. See "Session files" below. | Created at session start, completed at session end or before context is summarized. |
| `notes/` | Decisions, adversarial verdicts, coverage, behavior-delta tables, verification notes, sources notes (`YYYY-MM-DD-<topic>-sources.md`) and cross-change findings (`notes/findings.md`). | The note does not belong to one change or one exploration. |

`tasks.md` shape:

```markdown
# NN-<change-name>

Status: proposed | in-progress | blocked | done
Spec: specs/spec.md (or n/a)

## Tasks
- [ ] 1.1 <task>

## Ledger
| Date | Task | Action, finding or decision | Result | Evidence |
|---|---|---|---|---|
```

### Session files

A session is one Claude Code conversation. A resumed conversation, or one that is summarized
mid-way, keeps the same file. A new conversation gets the next number.

The ledger records what happened to a change. The session file records what happened in one
conversation and where to resume. It links to ledger rows, explorations and notes. It does not
copy them. Test: if a line could live in a ledger, exploration or note, write it there and link it.

```markdown
# NN-<session-name> (YYYY-MM-DD)

## Goal
<what the user asked for in this conversation>

## Touched
- changes/NN-<name>/tasks.md: tasks 1.2, 1.3 (ledger rows of YYYY-MM-DD)
- explorations/YYYY-MM-DD-<topic>.md: created

## Instructions and approvals from chat
- <preference, approval or direction given in chat, with a link to where it was recorded>

## Stopped at
<the exact state when the conversation ended: last command, what was running, what failed>

## Next
1. <first action for the next session>

## Open questions
- <question for the user, or a blocker>
```

Never put evidence, command output, findings, raw transcripts, secrets, PII or customer data in a session file.

### Sources

- Record each source in a sources note: `notes/YYYY-MM-DD-<topic>-sources.md`, one table row per source:
  `| Source (URL, or path or command checked) | What it confirms | Status (VERIFIED, PARTIAL, FAILED FETCH) |`
- A ledger row, exploration or spec cites the URL in its own text and links the sources note.
- For a local check, record the path or the command. Do not save its full output as a source.
- Download web pages, PDFs, spreadsheets, man pages and code files only to read or grep them.
  Save them in the session scratchpad or the system temp folder. Never save them in the repo, and never commit them.

### Rules

- At session start: read `roadmap.md`, the latest session file and the `tasks.md` of each active
  change, then create the new session file with its Goal.
- A finding for one change goes in that change's ledger. A finding that crosses changes goes in
  `notes/findings.md`. Research results stay in the exploration file.
- When an exploration turns into work, create the change and link the exploration from `spec.md` or `tasks.md`.
- Update `roadmap.md` in the same step as a change status update or archive move.
- Archive with `git mv`, then fix links in `roadmap.md` and in session files that point to the change.
- Append to ledgers. Never rewrite earlier rows.
- Gate artifacts (verdict line, `## Behavior delta`, `## Coverage`) go in the change's `tasks.md`,
  with copies in `notes/`.

## Security

- Never commit secrets or credentials (full rules: Delivery Protocol below + `~/.claude/rules/verification-lessons.md`)
- Least-privilege IAM; validate all user input; encrypt at rest and in transit

## When Working on Any Project

1. Check for project-level `CLAUDE.md` or `.claude/CLAUDE.md` first — those override these instructions
2. Check for `AGENTS.md` in the project root for project-specific conventions
3. Follow existing codebase patterns over generic best practices
4. Run linters/formatters before committing

## Verified Answer Protocol (MANDATORY)

**Always** apply the `verified-answer` skill protocol when:

- Answering any technical question (tool syntax, API, CLI flags, config keys, argument names)
- Searching for information or documentation
- Debugging errors or root-cause analysis
- Verifying facts, defaults, quotas, limits, or version-specific behavior
- Answering "does X support Y" or "how do I do Z"

Rules that are NEVER optional:

- Look up verifiable claims against primary sources before stating them
- Cite every non-trivial technical claim with a fetched URL
- Say "I could not verify this" instead of guessing
- Never reconstruct URLs from memory — only cite URLs returned by tool calls
- Flag uncertainty explicitly; do not paper over it with confident-sounding prose

## Empirical Verification Protocol (MANDATORY — extends Verified Answer)

Docs-reading is the floor, not the ceiling. When a claim is cheaply testable, test it:

- **Two failed attempts at the same thing is the trip-wire.** Count them. On the
  _second_ failure of a given approach, stop guessing and either run a controlled
  experiment isolating the failing variable — one decisive A/B (same input, different
  environment; or known-good control vs. candidate) — or say out loud that you are
  about to guess a third time and why no experiment is possible. A third shape-guess
  without an experiment or that statement is a protocol violation, not bad luck.
- **Decode opaque errors by reproduction**: trigger the same error with a _known_ cause
  in a sandbox, and the error's real meaning falls out. Theorizing about error strings
  without a reproduction is guessing.
- **Sandbox pattern**: throwaway tenant/account/app + isolated config
  (`AZURE_CONFIG_DIR`, separate profiles) + self-deleting probes. Free-tier directory
  objects and dry-runs cost nothing; propose the experiment at failure #1, not after
  the user demands it.
- **Creation ≠ working**: a credential/config/resource being accepted proves nothing
  about runtime. Follow every "it created fine" with the end-to-end probe before
  migrating anything that currently works.

## Delivery Protocol (MANDATORY)

- **Design pivots need an explicit go.** When direction changes from what was previously
  agreed — even in autonomous/background mode — post a ≤10-line proposal plus the
  behavior-delta table, and WAIT. Autonomy covers executing the agreed direction, not
  choosing a new one. Reversible ≠ unsurprising.
- **Behavior-delta table** for any infra/CI/workflow change: one row per run type
  (branch / main / tag / prod / etc.), before vs. after. Every narrowing or regression
  is its own flagged row — never buried in prose.
- **Runbooks for third parties** (admins, teammates) must be: self-contained
  (re-derive every variable — shell sessions die), shipped in Bash AND PowerShell AND
  portal-UI steps when Azure is involved, with expected success output, expected
  failure output + interpretation, cleanup commands, and a cost/billing note.
- **Secrets never transit chat.** The user runs `gh secret set` / vault writes locally.
  Any new long-lived credential is annotated at creation with: scope floor, what a leak
  actually exposes, rotation mechanism, expiry, revoke path, audit trail.
- **Findings ledger.** Reviews and investigations append findings — and, when
  addressed, the implemented solutions — to the relevant story/spike `.md`, with a
  change-log row per decision. The doc is the audit trail that survives the session.
  Without BMAD or OpenSpec, that doc is the change's `tasks.md` under `.ai-work/` (see Work Organization).

## Technology Preferences

- **IaC**: Terraform >= 1.7, Terragrunt for multi-env
- **Containers**: Docker multi-stage builds, ECS Fargate / EKS
- **Cloud**: whatever the project uses (AWS: prefer AWSCC provider for Terraform; Azure: azurerm/azapi). No default — read the repo's providers/lockfiles first
- **Monitoring**: Datadog, CloudWatch, Prometheus/Grafana
- **Security scanning**: Checkov, Trivy, Snyk

@RTK.md

# graphify

- **graphify** (`~/.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`
  When the user types `/graphify`, use the installed graphify skill or instructions before doing anything else.
