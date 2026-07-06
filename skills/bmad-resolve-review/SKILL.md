---
name: bmad-resolve-review
description: 'Verify, address, and reply to PR/code-review findings from a senior-engineer perspective. Each finding is checked against authoritative sources (no assuming) before acting; valid findings get the smallest correct fix, invalid ones get a polite evidence-backed rebuttal. Loops until every finding is resolved. Runs in PR mode (interactive: replies + commit) or local mode (non-interactive, for orchestrators like /bmad-tackle-story). Use when the user says "address review", "resolve PR comments", "verify these reviews", or pastes review feedback.'
---

# Resolve Review Workflow

**Goal:** Take a set of review findings (PR comments, `/bmad-code-review` output, or pasted text) and drive each to a resolved state — fixed or rebutted with evidence.

**Your Role:** Senior engineer answering a review. You verify before you act, cite sources, change as little as possible, and write replies a human reviewer respects. DRY, KISS, YAGNI.

## Modes (decide first)

- **PR mode** — findings come from a PR and a human user is present. All steps apply, including drafting/posting replies and committing.
- **Local mode** — findings come from `/bmad-code-review` output or an orchestrating agent (e.g. `/bmad-tackle-story`'s resolver lane), or you are running as a subagent (no user available to answer questions). **Skip Steps 4–6** (replies, posting, commit). Never wait for user input; your escape hatch is returning `status: halt` with a reason. Finish by returning the structured report (see Output).

## Core Principles (never skip)

1. **Verify, don't assume.** Every factual claim in a finding — and every claim in your response — is checked against an authoritative source before you act: the loaded rule set, the actual code, and vendor docs (Microsoft Learn / Terraform Registry / provider docs via MCP or WebFetch). Reconstructed-from-memory facts are not allowed.
2. **A finding can be wrong.** Reviewers make mistakes. If the finding's premise is false, the correct action is a respectful rebuttal with a cited source — not a code change. Do not "fix" things that aren't broken (YAGNI).
3. **Smallest correct change.** When a finding is valid, make the minimal edit that resolves it. No drive-by refactors, no new abstractions.
4. **Evidence over opinion.** Both fixes and rebuttals reference something concrete: a rule line, a doc URL, a sibling resource, a provider default.
5. **Loop until done.** Every finding ends in one of: `fixed`, `rebutted`, or `deferred` (deferral needs explicit user sign-off in PR mode, or a stated reason in the structured report in local mode).

## Load rules

Follow `~/.claude/skills/_shared/load-rules.md` (read it now). Build **the loaded rule set** and note the **stack-appropriate validation chain** as it describes.

## Inputs

- A PR URL or number (findings sourced via `gh api repos/<owner>/<repo>/pulls/<n>/comments`), **or**
- Pasted review text, **or**
- The output of `/bmad-code-review` (structured findings with ids).

If the source is ambiguous and a user is present, ask once: "Which PR / which findings?" In local mode, HALT with `halt_reason` instead.

## Sandbox note

`gh` needs network + keyring. If a `gh` call fails with `401`/auth errors inside the sandbox, check `gh auth status` first; if auth is fine, the sandbox is likely blocking network/keyring — surface it to the user and ask them to run the command themselves or adjust sandbox network allowances. Do not attempt to disable the sandbox yourself.

## Workflow

### Step 1 — Gather findings
- Pull every finding into a numbered list, preserving any provided finding `id`s. For PRs: `gh api repos/<owner>/<repo>/pulls/<n>/comments --jq '.[] | {id, user:.user.login, path, line, body}'`.
- Note each finding's anchor (`path:line` and comment `id`) so replies can be threaded later via `in_reply_to`.

### Step 2 — Verify each finding (the heart of this skill)
For each finding, independently and in parallel where possible:
- Read the cited code at `path:line`.
- Check the relevant project rule (the loaded rule set) — does it support or contradict the finding?
- Check the authoritative vendor source for any technical claim (e.g. "AKS modifies the subnet NSG", "this default is X"). Use MCP doc tools or WebFetch. **Cite the URL you actually fetched.**
- Classify: **VALID** (premise holds), **INVALID** (premise false), or **PARTIAL** (real concern, wrong fix).

Produce a verdict table before touching code:

| # | Finding | Verdict | Evidence | Action |
|---|---------|---------|----------|--------|

### Step 3 — Address valid findings
- Apply the smallest correct change for each VALID / PARTIAL finding.
- If dev context exists, defer to `/bmad-dev-story` conventions (task mapping, File List, Change Log). For a pure review-fix outside a story, a direct minimal edit is fine.
- Run the stack-appropriate validation chain after edits (per `_shared/load-rules.md`). Report pre-existing failures separately from anything you introduced — never claim a fix passed checks it didn't run.

### Step 4 — Draft replies (PR mode only)
One reply per finding. Tone = a busy senior engineer, not a bot:
- Lead with the outcome ("Dropped it." / "Checked the docs — this doesn't apply here.").
- One or two sentences of *why*, with the cited source inline.
- For rebuttals: acknowledge the angle, then the evidence. No defensiveness, no walls of text, no emoji unless the repo's culture uses them.
- Never paste the verdict table into the PR. Replies are prose.

Show all drafts to the user before posting.

### Step 5 — Post replies (PR mode only, after user OK)
```
gh api repos/<owner>/<repo>/pulls/<n>/comments \
  -f body='<reply>' -F in_reply_to=<comment_id>
```
Verify threading with a follow-up `--jq '.[] | {id, in_reply_to_id, user}'`.

### Step 6 — Commit (PR mode only)
- Only when the user says "commit" (don't push unless asked).
- Branch and commit-message conventions come from **the loaded rule set** (commit/PR conventions often live in `_bmad/custom/*.toml` or the project CLAUDE.md) — e.g. a repo may require `[TICKET-123] <short description>` on a `TICKET-123-...` branch. Reference the PR in the body.
- Add `Co-Authored-By: Claude <noreply@anthropic.com>`.
- If on `main`, branch first.

### Step 7 — Loop check
Re-scan the findings list. Any finding not yet `fixed`/`rebutted`/`deferred`? Return to Step 2 for it. Only report done when the list is fully resolved.

## Output (local mode, or when an orchestrator asked for it)

Return this JSON as your final output:

```json
{
  "lane": "resolve",
  "status": "done|halt",
  "halt_reason": "only when status=halt",
  "findings": [
    {"id": "path/file.tf#rule-slug", "severity": "critical|major|minor",
     "file": "path", "line": 0, "rule": "cited rule or doc URL",
     "summary": "one line", "fix": "what was changed (or why rebutted)",
     "resolution": "fixed|rebutted|deferred"}
  ],
  "files_changed": ["..."],
  "validation": [{"cmd": "...", "pass": true}]
}
```

Preserve incoming finding `id`s verbatim — orchestrators use them for stall detection.

## Integration

- **`/bmad-code-review`** — run it first to *generate* findings, then feed its output into Step 1.
- **`/bmad-dev-story`** — when resolving review follow-ups inside an active story, mark the corresponding `[AI-Review]` tasks and update Dev Agent Record per that skill's rules.
- **`/bmad-tackle-story`** — invokes this skill in local mode as its resolver lane.

## Done criteria
- Every finding has a verdict backed by a cited source.
- Valid findings fixed with minimal diffs; validation chain run and reported honestly.
- PR mode: replies posted and correctly threaded; commit created (if requested), not pushed unless asked.
- Local mode: structured report returned with every finding resolved or explicitly deferred with a reason.
