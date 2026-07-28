---
name: verified-tackle
description: "End-to-end verified delivery for non-BMAD projects (openspec/ or no spec tooling): plan-verify, implement, then the code-enforced Workflow verification loop, empirical probes, gate artifacts, and gated shipping. Same quality bar as /bmad-verified-tackle. Usage: /verified-tackle <task description | openspec change id>"
---

# Verified Tackle

One command from task to verified, gated, shipped change, for repos without
BMAD. Same quality bar as `/bmad-verified-tackle` — the shared core guarantees
it. You are the pipeline orchestrator in the main thread.

## Preconditions

1. If `_bmad-output/` exists, tell the user to run `/bmad-verified-tackle`
   instead and stop (the BMAD loop is stricter for story work).
2. Resolve the spec source: `openspec/` change doc if present and referenced;
   otherwise the user's task description. Ambiguous scope → ask once, up front.
3. Resolve the ledger per the core's ledger-resolution rules
   (`openspec/` doc, else `.omc/state/findings.md` — create it).

## Pipeline — strictly one unit of work at a time

If the argument names multiple changes/tasks, order them by dependency and run
the FULL pipeline per unit. Never start the next unit while the current one has
open findings, unfinished probes, or unwritten artifacts — a unit is left only
"verified, artifacts written, shipped" or "escalated" (escalation pauses the
run).

Per unit:

**Stage 0 — Plan-verify (read-only).** Spawn a read-only architect subagent to
verify the intended approach against the spec/task, the project's CLAUDE.md and
ADRs, and stack best practices via primary docs — flagging ordering, dependency,
and destroy/replace risks. VERIFY claims, don't assume. `plan_sound: false` →
STOP and report; never enter implementation on a broken plan.

**Stage 1 — Implement.** Execute the plan: subagent(s) for multi-file work, main
thread for trivial edits (project delegation rules apply). Implementers must run
the project's validation chain (lint, typecheck, tests — as defined by the
project) and report results verbatim. They do not self-approve.

**Stages V, P, A, S.** Read `~/.claude/skills/_shared/verified-delivery-core.md`
NOW and execute it as written on the full diff stage 1 produced.

## Reporting

Final message: plan verdict, files changed, stage V rounds, probe evidence,
artifacts written, what shipped, anything escalated. Evidence over adjectives.
