---
name: bmad-verified-tackle
description: "End-to-end verified delivery for BMAD projects: runs the bmad-tackle-story dev→review→resolve loop on the given story id/range, then the code-enforced Workflow verification loop, empirical probes, gate artifacts, and gated shipping. Use in repos that have _bmad-output/. Usage: /bmad-verified-tackle <story-id | a..b>"
---

# BMAD Verified Tackle

One command from drafted story to verified, gated, shipped change. You are the
pipeline orchestrator in the main thread.

## Preconditions (HALT if unmet)

1. `_bmad-output/` exists in the repo — otherwise tell the user to run
   `/verified-tackle` instead and stop.
2. `bmad-tackle-story` appears in this session's available skills (it in turn
   checks its own dependencies). Missing → report and stop.
3. A story id/range argument was given. Missing → ask for it.

## Pipeline — strictly one story at a time

Expand a range to an ordered list. Then FOR EACH story, run the FULL pipeline
below to completion before touching the next story. Never start story N+1 while
story N has open findings, unfinished probes, or unwritten artifacts — a story
is left only in state "verified, artifacts written, shipped" or "escalated to
the user" (escalation pauses the whole run; do not skip ahead).

Per story:

**Stage 1 — Develop.** Invoke the `bmad-tackle-story` skill via the Skill tool
with THIS story id only, and follow it to completion: its internal loop must end
review-clean per its own convergence rules. Its findings already land in the
story `.md` — that file is the ledger for all later stages.

**Stages V, P, A, S.** Read `~/.claude/skills/_shared/verified-delivery-core.md`
(once per run is enough) and execute it as written on the diff this story
produced. The ledger is this story's `.md` under `_bmad-output/`. Stage 1's
internal review does NOT substitute for Stage V — tackle-story converges the
implementation; Stage V adversarially verifies the result in fresh contexts
with code-enforced voting.

Only after Stage S completes for this story: move to the next one.

## Reporting

Final message: per story — status, iterations used (stage 1 and stage V
separately), probe evidence, artifacts written, what shipped (commit/PR), and
anything escalated. Evidence over adjectives.
