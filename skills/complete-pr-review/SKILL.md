---
name: complete-pr-review
description: >
  Run a grounded, senior-engineer PR review on a branch — verify EVERY claim
  against real source (no assumptions), trace the changed logic like a
  state-machine, check it against best patterns for the project's actual stack
  and architecture, and enforce DRY / KISS / YAGNI, maintainability, performance,
  reliability, security, and test coverage. Fans out a team of review
  subagents (5 max unless the user overrides), grounds findings with reporag +
  up-to-date primary docs (search + curl, never Fetch/WebFetch), runs the
  tests it can, and ends with an adversarial-review gate (bmad-code-review if
  available, else adversarial-review). Use when the user asks for a "complete
  PR review", a review "iteration", or a deep/grounded senior review of a
  branch or diff.
allowed-tools: 'Bash(git log:*), Bash(git diff:*), Bash(git show:*), Bash(gh pr view:*), Bash(gh pr diff:*), Bash(gh pr checks:*)'
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
  patterns and callers. Use `context7-docs` / `Ref` / `microsoft-learn` for
  version-specific stack claims; for the open web, **never use Fetch/WebFetch**
  — find URLs with search (WebSearch), then `curl` the page and grep/strip it
  locally. Pin every stack claim to the exact version in `requirements*.txt` /
  `package.json` / lockfiles. **If an MCP server is unavailable** (headless
  session, other machine), fall back to Grep/Glob/Read for pattern discovery
  and search + curl for docs — and mark in the report which claims had weaker
  grounding rather than silently skipping the check.
- **Best current patterns for the actual stack.** Judge the change against the
  best recommended, up-to-date patterns for the exact stack and version in use
  — verified from primary docs at review time, not recalled. Deviation from
  the recommended pattern without a stated reason is a finding.
- **DRY / KISS / YAGNI / maintainability.** If logic is duplicated 2+ times,
  recommend abstracting it. If a function/export/branch is created but unused,
  recommend removing it. Prefer the simplest correct design; flag cleverness
  that isn't paying rent and coupling that will hurt the next maintainer.
- **Performance counts.** Check the changed paths for avoidable cost: N+1
  queries, per-request work that belongs at startup, unbounded collections,
  missing indexes/caches, chatty network hops. A performance regression on a
  hot path is a Major finding, not a nit.
- **Hold the goal and scope.** Before judging, restate the PR's intent (ticket,
  PR body, story ledger) and review against it. Reliability is part of the
  goal: flag anything flaky, unrecoverable, or silently degrading. Out-of-scope
  wishes are non-blocking notes, never blockers.
- **Author vs. review separation.** This skill only reviews. Do not fix inline;
  report findings. (Fixes are a separate pass — e.g. `/bmad-resolve-review`.)

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
  abstraction is a finding. (No reporag → Grep for similar names/signatures.)
- `reporag get_architecture` / `ask_project` to confirm the change sits in the
  right layer for the repo's own architecture.
- Load the project rules per `~/.claude/skills/_shared/load-rules.md` (read it
  now — it covers the worktree/sandbox absolute-path pitfalls). A change that
  violates a loaded guardrail (e.g. "no PM references in shipped code/docs") is
  itself a finding.

### 3. Fan out a team of subagents (parallel, single message)

**Cap: 5 subagents total per run**, unless the user specifies a different
number — a user-given count overrides the cap. Launch the lanes concurrently
via the Agent tool, each with the diff scope. They inherit the session model
(from an Opus session, review lanes run on Opus — correct; do not downgrade
review lanes). Keep only their findings in the main thread:

- `pr-reviewer` — quality, contract drift, reliability (flaky paths, silent
  degradation, missing error handling).
- `architect-reviewer` — layer boundaries, stack best-pattern fit,
  API-contract validation, maintainability.
- `security-auditor` — auth / tenant isolation / injection / secrets /
  known-vulnerable dependencies. Swap in a domain-specific reviewer (e.g.
  `hipaa-compliance-reviewer`) whenever the diff touches regulated or
  sensitive data (PHI/PII).
- A DRY/KISS/YAGNI + performance sweep — `code-simplifier` or a
  `general-purpose` agent tasked to find duplicated logic to abstract,
  dead/unused code to remove, and avoidable cost on changed paths.
- A test-coverage lane — `oh-my-claudecode:test-engineer` (or
  `general-purpose`): every behavior change has a test that fails without it;
  mocks only at true system boundaries; assertions that cannot fail are
  findings; name untested changed paths explicitly.

Scale the team down for a tiny diff (one or two lanes may suffice); a broad or
security-sensitive diff warrants all five. Ask each lane to return findings as
a structured list (severity, file:line, rule/source, failure scenario) — dedup
overlapping findings before verifying.

### 4. Verify every surfaced finding yourself

Subagent claims are leads, not facts. For each:

- Open the cited file:line and confirm it says what the finding claims.
- For any stack/library behavior (filter parsing, defaults, ORM/framework
  semantics, client-side behavior), pull the **primary doc or library source**
  for the exact installed version (doc MCPs, or search → curl — never
  Fetch/WebFetch). Quote it.
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
  Hunter / Acceptance Auditor layers). Invoke it inline via the Skill tool —
  do not wrap it in a subagent (its layers are subagents; nested fan-out is
  unreliable and its fallback HALTs for user input).
- Otherwise use the `adversarial-review` skill (spawns an adversarial reviewer
  subagent in its own fresh context — that separation is the point).

### 7. Report

Emit a single severity-ranked report:

- **Verdict** — mechanical rule, not judgment:
  - any **Critical or Major** finding → `REQUEST-CHANGES`
  - only **Minor** findings → `APPROVE-WITH-NITS`
  - zero findings → `APPROVE`
- **Verified ✅** — what you traced and confirmed correct, with file:line and
  any doc URLs. Call out security/tenant-isolation reasoning explicitly.
- **Findings** — ranked Critical → Major → Minor. Each: one-line defect, a
  concrete failure scenario (inputs → wrong result), the file:line, and a
  recommended direction (not an inline fix).
- **DRY/YAGNI** — duplication to abstract; unused code to remove.
- **Coverage** — per behavior change: covered (cite the test) or uncovered
  (finding). State what the coverage claim is based on (tests run vs. read).
- **Performance** — changed hot paths checked; regressions found or "none
  observed" with what was examined.
- **Iteration note** (if ≥2) — confirm each prior-round item was addressed.
- Distinguish blocking findings from non-blocking nits; a stylistic nit with
  zero functional/security impact is explicitly non-blocking.

## Anti-patterns for this skill

- Reporting a behavior claim from memory instead of a retrieved source.
- Using Fetch/WebFetch — sources come from search (WebSearch/doc MCPs) plus
  `curl` + grep, per the global Sources rule.
- Exceeding the 5-subagent cap without an explicit user override.
- Trusting a subagent finding without re-verifying it at the cited line.
- Claiming tests pass without running them (or without citing CI).
- Silently skipping a grounding step because an MCP server is missing, instead
  of falling back and flagging the weaker grounding.
- Recommending an abstraction for something used once (YAGNI), or tolerating
  logic copied 2+ times (DRY) — check the count before deciding.
- Fixing code inline instead of reporting.
