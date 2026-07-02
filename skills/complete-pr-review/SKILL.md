---
name: complete-pr-review
description: >
  Run a grounded, senior-engineer PR review on a branch — verify EVERY claim
  against real source (no assumptions), trace the changed logic like a
  state-machine, check it against best patterns for the project's actual stack
  and architecture, and enforce DRY / KISS / YAGNI (flag duplication to abstract,
  dead code to remove). Fans out a team of subagents for coverage, grounds
  findings with reporag + up-to-date library docs, runs the tests it can, and
  ends with an adversarial-review gate (bmad-code-review if available, else
  adversarial-review). Use when the user asks for a "complete PR review", a
  review "iteration", or a deep/grounded senior review of a branch or diff.
---

# Complete PR Review

A hostile, evidence-first review that treats "looks correct" as unproven. The
deliverable is a severity-ranked report where **every non-trivial claim is
backed by a file:line you actually read or a doc URL you actually fetched** —
never by recall.

Core rules (non-negotiable):

- **VERIFY EVERYTHING. ASSUME NOTHING.** Every statement about behavior,
  defaults, types, or the stack must be traced to source (repo code) or a
  fetched primary doc. If you cannot verify, say "could not verify" — do not
  guess.
- **Think like a state-machine.** For each changed code path, enumerate the
  input/config states (null / false / empty / crafted / concurrent) and walk
  what happens in each. Bugs hide in the transitions, not the happy path.
- **Ground with tools, not memory.** Use `reporag` (`find_existing`,
  `query_code`, `get_symbol`, `get_architecture`, `ask_project`) to locate real
  patterns and callers. Use `context7-docs` / `Ref` / `microsoft-learn` /
  `WebFetch` against primary sources for any version-specific stack claim.
  Pin every stack claim to the exact version in `requirements*.txt` /
  `package.json` / lockfiles.
- **DRY / KISS / YAGNI.** If logic is duplicated 2+ times, recommend abstracting
  it for maintainability. If a function/export/branch is created but unused,
  recommend removing it. Prefer the simplest correct design; flag cleverness
  that isn't paying rent.
- **Author vs. review separation.** This skill only reviews. Do not fix inline;
  report findings. (Fixes are a separate pass.)

## Inputs

- Target branch (default: current). Iteration number if the user gave one — on
  iteration ≥2, explicitly confirm prior-round feedback was addressed.
- Review base (default: `main`).

## The workflow

### 1. Scope

- `git log --oneline <base>..<branch>` and `git diff --stat <base>...<branch>`.
- Read the **full diff** of the core logic files yourself (not just the stat).
  Separate generated/vendored files from hand-written ones — generated changes
  are verified by checking they match the source that generates them.
- On iteration ≥2: pull prior review threads / commit messages that say
  "address PR review" and list what each was supposed to fix, so you can verify
  each was actually done.

### 2. Ground the change

- `reporag find_existing(task=...)` before judging any "new" helper — surface
  existing functions/patterns it should have reused. Duplication of an existing
  abstraction is a finding.
- `reporag get_architecture` / `ask_project` to confirm the change sits in the
  right layer for the repo's own architecture. Read the project's rules for the
  intended layering and conventions — from **absolute paths**, since you may be
  in a git **worktree** (cwd ≠ main checkout) under a sandbox; relative paths
  resolve to the worktree copy, which is often empty/missing:
  ```sh
  root=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
  # if present: "$root/CLAUDE.md", "$root/AGENTS.md", "$root"/.claude/rules/*.md,
  #   "$root"/_bmad/custom/*.toml (engineering guardrails; may be gitignored →
  #   absent in the worktree → reachable only via $root), plus any ADRs.
  ```
  Also load global rules: `~/.claude/CLAUDE.md`, `~/.claude/rules/*.md`.
  Verify findings against this loaded rule set — a change that violates a project
  guardrail (e.g. "no PM references in shipped code/docs") is itself a finding.

### 3. Fan out a team of subagents (parallel, single message)

Launch these concurrently via the Agent tool, each with the diff scope. Keep
only their findings in the main thread:

- `pr-reviewer` — quality, coverage, contract drift.
- `architect-reviewer` — layer boundaries, pattern fit, API-contract validation.
- `security-auditor` — auth / tenant isolation / injection / secrets. Swap in a
  domain-specific reviewer (e.g. `hipaa-compliance-reviewer`) whenever the diff
  touches regulated or sensitive data (PHI/PII).
- A DRY/KISS/YAGNI sweep — `code-simplifier` or a `general-purpose` agent tasked
  explicitly to find duplicated logic to abstract and dead/unused code to remove.

Scale the team to the change: a tiny diff may need only one or two lanes; a
broad or security-sensitive one warrants all of them. Dedup overlapping findings
before verifying.

### 4. Verify every surfaced finding yourself

Subagent claims are leads, not facts. For each:

- Open the cited file:line and confirm it says what the finding claims.
- For any stack/library behavior (filter parsing, defaults, ORM/framework
  semantics, client-side behavior), fetch the **primary doc or library source**
  for the exact installed version. Quote it.
- Walk the state-machine for the code path and confirm the failure scenario is
  reachable. Drop findings you cannot reproduce in the logic.

### 5. Run what you can (Definition of Done gate)

- Run the affected test targets if the toolchain is available (venv / installed
  deps); if not, say so and fall back to CI status (`gh pr checks` / latest
  commit). Typecheck/lint the touched files where cheap.
- State plainly what you ran and the result. Never claim "tests pass" you didn't
  observe.

### 6. Adversarial gate

Run an adversarial pass and loop until it stops finding blockers (cap 3 rounds,
then escalate):

- Prefer `bmad-code-review` if available (parallel Blind Hunter / Edge Case
  Hunter / Acceptance Auditor layers).
- Otherwise use the `adversarial-review` skill (spawns an adversarial reviewer
  subagent in its own fresh context — that separation is the point).

### 7. Report

Emit a single severity-ranked report:

- **Verdict:** APPROVE / APPROVE-WITH-NITS / REQUEST-CHANGES.
- **Verified ✅** — what you traced and confirmed correct, with file:line and
  any doc URLs. Call out security/tenant-isolation reasoning explicitly.
- **Findings** — ranked Critical → Major → Minor. Each: one-line defect, a
  concrete failure scenario (inputs → wrong result), the file:line, and a
  recommended direction (not an inline fix).
- **DRY/YAGNI** — duplication to abstract; unused code to remove.
- **Iteration note** (if ≥2) — confirm each prior-round item was addressed.
- Distinguish blocking findings from non-blocking nits; a stylistic nit with
  zero functional/security impact is explicitly non-blocking.

## Anti-patterns for this skill

- Reporting a behavior claim from memory instead of a fetched source.
- Trusting a subagent finding without re-verifying it at the cited line.
- Claiming tests pass without running them (or without citing CI).
- Recommending an abstraction for something used once (YAGNI), or tolerating
  logic copied 2+ times (DRY) — check the count before deciding.
- Fixing code inline instead of reporting.
