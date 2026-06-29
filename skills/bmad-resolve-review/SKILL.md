---
name: bmad-resolve-review
description: 'Verify, address, and reply to PR/code-review findings from a senior-engineer perspective. Each finding is checked against authoritative sources (no assuming) before acting; valid findings get the smallest correct fix, invalid ones get a polite evidence-backed rebuttal. Loops until every finding is resolved. Use when the user says "address review", "resolve PR comments", "verify these reviews", or pastes review feedback. Pairs with /bmad-dev-story (dev context) and /bmad-code-review (to source findings).'
---

# Resolve Review Workflow

**Goal:** Take a set of review findings (PR comments, `/bmad-code-review` output, or pasted text) and drive each to a resolved state — fixed or rebutted with evidence — then reply on the PR and commit.

**Your Role:** Senior engineer answering a review. You verify before you act, cite sources, change as little as possible, and write replies a human reviewer respects. DRY, KISS, YAGNI.

## Core Principles (never skip)

1. **Verify, don't assume.** Every factual claim in a finding — and every claim in your response — is checked against an authoritative source before you act. Project rules (`.claude/rules/*.md`, `CLAUDE.md`), the actual code, and vendor docs (Microsoft Learn / Terraform Registry / provider docs via MCP or WebFetch). Reconstructed-from-memory facts are not allowed.
2. **A finding can be wrong.** Reviewers make mistakes. If the finding's premise is false, the correct action is a respectful rebuttal with a cited source — not a code change. Do not "fix" things that aren't broken (YAGNI).
3. **Smallest correct change.** When a finding is valid, make the minimal edit that resolves it. No drive-by refactors, no new abstractions.
4. **Evidence over opinion.** Both fixes and rebuttals reference something concrete: a rule line, a doc URL, a sibling resource, a provider default.
5. **Loop until done.** Do not stop at "most" findings. Every finding ends in one of: `fixed`, `rebutted`, or `deferred (with explicit user sign-off)`.

## Inputs

- A PR URL or number (findings sourced via `gh api repos/<owner>/<repo>/pulls/<n>/comments`), **or**
- Pasted review text, **or**
- The output of `/bmad-code-review`.

If the source is ambiguous, ask once: "Which PR / which findings?"

## Sandbox note

`gh` needs network + keyring. If a `gh` call returns `401`/auth failure inside the sandbox, retry the same call with sandbox disabled — auth is usually fine outside it. Confirm with `gh auth status` before assuming the token is bad.

## Workflow

### Step 1 — Gather findings
- Pull every finding into a numbered list. For PRs: `gh api repos/<owner>/<repo>/pulls/<n>/comments --jq '.[] | {id, user:.user.login, path, line, body}'`.
- Note each finding's anchor (`path:line` and comment `id`) so replies can be threaded later via `in_reply_to`.

### Step 2 — Verify each finding (the heart of this skill)
For each finding, independently and in parallel where possible:
- Read the cited code at `path:line`.
- Check the relevant project rule (`.claude/rules/`, `CLAUDE.md`) — does it support or contradict the finding?
- Check the authoritative vendor source for any technical claim (e.g. "AKS modifies the subnet NSG", "this default is X"). Use Microsoft Learn / Terraform Registry MCP tools or WebFetch. **Cite the URL you actually fetched.**
- Classify: **VALID** (premise holds), **INVALID** (premise false), or **PARTIAL** (real concern, wrong fix).

Produce a verdict table before touching code:

| # | Finding | Verdict | Evidence | Action |
|---|---------|---------|----------|--------|

### Step 3 — Address valid findings
- Apply the smallest correct change for each VALID / PARTIAL finding.
- If dev context exists, defer to `/bmad-dev-story` conventions (task mapping, File List, Change Log). For a pure review-fix outside a story, a direct minimal edit is fine.
- Run the project validation chain after edits (for this repo: `terraform fmt` → `tflint` → `checkov`; see `CLAUDE.md`). Report pre-existing failures separately from anything you introduced — never claim a fix passed checks it didn't run.

### Step 4 — Draft replies (concise, human)
One reply per finding. Tone = a busy senior engineer, not a bot:
- Lead with the outcome ("Dropped it." / "Checked the docs — this doesn't apply here.").
- One or two sentences of *why*, with the cited source inline.
- For rebuttals: acknowledge the angle, then the evidence. No defensiveness, no walls of text, no emoji unless the repo's culture uses them.
- Never paste the verdict table into the PR. Replies are prose.

Show all drafts to the user before posting.

### Step 5 — Post replies (threaded)
After user OK:
```
gh api repos/<owner>/<repo>/pulls/<n>/comments \
  -f body='<reply>' -F in_reply_to=<comment_id>
```
Verify threading with a follow-up `--jq '.[] | {id, in_reply_to_id, user}'`.

### Step 6 — Commit
- Only when the user says "commit" (don't push unless asked).
- Branch convention: `CEP-XXX-...`; commit message `[CEP-XXX] <short description>` (see `CLAUDE.md`). Reference the PR in the body.
- Add `Co-Authored-By: Claude <noreply@anthropic.com>`.
- If on `main`, branch first.

### Step 7 — Loop check
Re-scan the findings list. Any finding not yet `fixed`/`rebutted`/`deferred`? Return to Step 2 for it. Only report done when the list is fully resolved.

## Integration

- **`/bmad-code-review`** — run it first to *generate* findings, then feed its output into Step 1.
- **`/bmad-dev-story`** — when resolving review follow-ups inside an active story, mark the corresponding `[AI-Review]` tasks and update Dev Agent Record per that skill's rules.

## Done criteria
- Every finding has a verdict backed by a cited source.
- Valid findings fixed with minimal diffs; validation chain run and reported honestly.
- Replies posted and correctly threaded.
- Commit created (if requested), not pushed unless asked.
